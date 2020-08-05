--
-- $Id: BugGrabber.lua 238 2019-09-25 01:35:39Z funkydude $
--
-- The BugSack and !BugGrabber team is:
-- Current Developer: Funkydude
-- Past Developers: Rowne, Ramble, industrial, Fritti, kergoth, ckknight, Rabbit
-- Testers: Ramble, Sariash
--
--[[

!BugGrabber, World of Warcraft addon that catches errors and formats them with a debug stack.
Copyright (C) 2015 The !BugGrabber Team

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

]]

-----------------------------------------------------------------------
-- local-ization, mostly for use with the FindGlobals script to catch
-- misnamed variable names. We're not hugely concerned with performance.

local _G = _G
local type, table, next, tostring, tonumber, print =
      type, table, next, tostring, tonumber, print
local debuglocals, debugstack, wipe, IsEncounterInProgress, GetTime =
      debuglocals, debugstack, wipe, IsEncounterInProgress, GetTime
-- GLOBALS: LibStub, GetLocale, GetBuildInfo, DisableAddOn, Swatter, GetAddOnInfo
-- GLOBALS: BugGrabberDB, ItemRefTooltip, date
-- GLOBALS: seterrorhandler, IsAddOnLoaded, GetAddOnMetadata
-- GLOBALS: MAX_BUGGRABBER_ERRORS, BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE
-- GLOBALS: SlashCmdList, SLASH_SWATTER1, SLASH_SWATTER2

-----------------------------------------------------------------------
-- Check if we already exist in the global space
-- If we do - bail out early, there's no version checks.
if _G.BugGrabber then return end

-----------------------------------------------------------------------
-- If we're embedded we create a .BugGrabber object on the addons
-- table, unless we find a standalone !BugGrabber addon.

local bugGrabberParentAddon, parentAddonTable = ...
local STANDALONE_NAME = "!BugGrabber"
if bugGrabberParentAddon ~= STANDALONE_NAME then
	local tbl = { STANDALONE_NAME, "!Swatter", "!ImprovedErrorFrame" }
	for i = 1, 3 do
		local _, _, _, enabled = GetAddOnInfo(tbl[i])
		if enabled then return end -- Bail out
	end
end
if not parentAddonTable.BugGrabber then parentAddonTable.BugGrabber = {} end
local addon = parentAddonTable.BugGrabber

local real_seterrorhandler = seterrorhandler

-----------------------------------------------------------------------
-- Global config variables
--

MAX_BUGGRABBER_ERRORS = 1000

-- If we get more errors than this per second, we stop all capturing
BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE = 10

-----------------------------------------------------------------------
-- Localization
--

local L = {
	ADDON_CALL_PROTECTED = "[%s] AddOn '%s' tried to call the protected function '%s'.",
	ADDON_CALL_PROTECTED_MATCH = "^%[(.*)%] (AddOn '.*' tried to call the protected function '.*'.)$",
	ADDON_DISABLED = "|cffffff00!BugGrabber and %s cannot coexist; %s has been forcefully disabled. If you want to, you may log out, disable !BugGrabber, and enable %s.|r",
	BUGGRABBER_STOPPED = "|cffffff00There are too many errors in your UI. As a result, your game experience may be degraded. Disable or update the failing addons if you don't want to see this message again.|r",
	ERROR_DETECTED = "%s |cffffff00captured, click the link for more information.|r",
	ERROR_UNABLE = "|cffffff00!BugGrabber is unable to retrieve errors from other players by itself. Please install BugSack or a similar display addon that might give you this functionality.|r",
	NO_DISPLAY_1 = "|cffffff00You seem to be running !BugGrabber with no display addon to go along with it. Although a slash command is provided for accessing error reports, a display can help you manage these errors in a more convenient way.|r",
	NO_DISPLAY_2 = "|cffffff00The standard display is called BugSack, and can probably be found on the same site where you found !BugGrabber.|r",
	NO_DISPLAY_STOP = "|cffffff00If you don't want to be reminded about this again, run /stopnag.|r",
	STOP_NAG = "|cffffff00!BugGrabber will not nag about missing a display addon again until next patch.|r",
	USAGE = "|cffffff00Usage: /buggrabber <1-%d>.|r",
}

-----------------------------------------------------------------------
-- Locals
--

-- Should implement :FormatError(errorTable).
local displayObjectName = nil
for i = 1, GetNumAddOns() do
	local meta = GetAddOnMetadata(i, "X-BugGrabber-Display")
	if meta then
		local _, _, _, enabled = GetAddOnInfo(i)
		if enabled then
			displayObjectName = meta
			break
		end
	end
end

-- Shorthand to BugGrabberDB.errors
local db = nil

-- Errors we catch during the addon loading process, before our saved
-- variables are available. After the SVs have loaded, these will be
-- inserted into the proper DB.
local loadErrors = {}

local paused = nil
local isBugGrabbedRegistered = nil
local callbacks = nil
local playerName = UnitName("player")
local chatLinkFormat = "|Hbuggrabber:%s:%s:|h|cffff0000[Error %s]|r|h"
local tableToString = "table: %s"

-----------------------------------------------------------------------
-- Callbacks
--

local function setupCallbacks()
	if not callbacks and LibStub and LibStub("CallbackHandler-1.0", true) then
		callbacks = LibStub("CallbackHandler-1.0"):New(addon)
		function callbacks:OnUsed(target, eventname)
			if eventname == "BugGrabber_BugGrabbed" then isBugGrabbedRegistered = true end
		end
		function callbacks:OnUnused(target, eventname)
			if eventname == "BugGrabber_BugGrabbed" then isBugGrabbedRegistered = nil end
		end
		setupCallbacks = nil
	end
end
addon.setupCallbacks = setupCallbacks; -- make it accessible from the outside for add-ons relying on BugGrabber events so they can make BugGrabber.RegisterCallback appear when they need it (CallbackHandler-1.0 is not embedded in BugGrabber)

local function triggerEvent(...)
	if not callbacks then setupCallbacks() end
	if callbacks then callbacks:Fire(...) end
end

-----------------------------------------------------------------------
-- Utility
--

local function fetchFromDatabase(database, target)
	for i, err in next, database do
		if err.message == target then
			-- This error already exists
			err.counter = err.counter + 1
			err.session = addon:GetSessionId()

			return table.remove(database, i)
		end
	end
end

local function printErrorObject(err)
	local found = nil
	if displayObjectName and _G[displayObjectName] then
		local display = _G[displayObjectName]
		if type(display) == "table" and type(display.FormatError) == "function" then
			found = true
			print(display:FormatError(err))
		end
	end
	if not found then
		print(err.message)
		if err.stack then
			print(err.stack)
		end
		if err.locals then
			print(err.locals)
		end
	end
end

-----------------------------------------------------------------------
-- Slash handler
--

local function slashHandler(index)
	if not db then return end
	index = tonumber(index)
	local err = type(index) == "number" and db[index] or nil
	if not index or not err or type(err) ~= "table" or (type(err.message) ~= "string" and type(err.message) ~= "table") then
		print(L.USAGE:format(#db))
		return
	end
	printErrorObject(err)
end

-----------------------------------------------------------------------
-- Error catching
--

local findVersions = nil
do
	local function scanObject(o)
		local version, revision = nil, nil
		for k, v in next, o do
			if type(k) == "string" and (type(v) == "string" or type(v) == "number") then
				local low = k:lower()
				if not version and low:find("version") then
					version = v
				elseif not revision and low:find("revision") then
					revision = v
				end
			end
			if version and revision then break end
		end
		return version, revision
	end

	local matchCache = setmetatable({}, { __index = function(self, object)
		if type(object) ~= "string" or #object < 3 then return end
		local found = nil
		-- First see if it's a library
		if LibStub then
			local _, minor = LibStub(object, true)
			found = minor
		end
		-- Then see if we can get some addon metadata
		if not found and IsAddOnLoaded(object) then
			found = GetAddOnMetadata(object, "X-Curse-Packaged-Version")
			if not found then
				found = GetAddOnMetadata(object, "Version")
			end
		end
		-- Perhaps it's a global object?
		if not found then
			local o = _G[object] or _G[object:upper()]
			if type(o) == "table" then
				local v, r = scanObject(o)
				if v or r then
					found = tostring(v) .. "." .. tostring(r)
				end
			elseif o then
				found = o
			end
		end
		if not found then
			found = _G[object:upper() .. "_VERSION"]
		end
		if type(found) == "string" or type(found) == "number" then
			self[object] = found
			return found
		end
	end })

	local tmp = {}
	local function replacer(start, object, tail)
		-- Have we matched this object before on the same line?
		-- (another pattern could re-match a previous match...)
		if tmp[object] then return end
		local found = matchCache[object]
		if found then
			tmp[object] = true
			return (type(start) == "string" and start or "") .. object .. "-" .. found .. (type(tail) == "string" and tail or "")
		end
	end

	local matchers = {
		"(\\)([^\\]+)(%.lua)",       -- \Anything-except-backslashes.lua
		"^()([^\\]+)(\\)",           -- Start-of-the-line-until-first-backslash\
		"()(%a+%-%d%.?%d?)()",       -- Anything-#.#, where .# is optional
		"()(Lib%u%a+%-?%d?%.?%d?)()" -- LibXanything-#.#, where X is any capital letter and -#.# is optional
	}
	function findVersions(line)
		if not line or line:find("FrameXML\\") then return line end
		for i = 1, 4 do
			line = line:gsub(matchers[i], replacer)
		end
		wipe(tmp)
		return line
	end
end

-- Error handler
local grabError
do
	local tmp = {}
	local msgsAllowed = BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE
	local msgsAllowedLastTime = GetTime()
	local lastWarningTime = 0
	function grabError(errorMessage, isSimple)
		-- Flood protection --
		msgsAllowed = msgsAllowed + (GetTime()-msgsAllowedLastTime)*BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE
		msgsAllowedLastTime = GetTime()
		if msgsAllowed < 1 then
			if not paused then
				if bugGrabberParentAddon == STANDALONE_NAME then
					if GetTime() > lastWarningTime + 10 then
						print(L.BUGGRABBER_STOPPED)
						lastWarningTime = GetTime()
					end
				end
				paused=true
				triggerEvent("BugGrabber_CapturePaused")
			end
			return
		end
		paused=false
		if msgsAllowed > BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE then
			msgsAllowed = BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE
		end
		msgsAllowed = msgsAllowed - 1

		-- Grab it --
		errorMessage = tostring(errorMessage)

		local looping = errorMessage:find("BugGrabber") and true or nil
		if looping then
			print(errorMessage)
			return
		end

		local sanitizedMessage = findVersions(errorMessage)

		-- Insert the error into the correct database if it's not there
		-- already. If it is, just increment the counter.
		local found = nil
		if db then
			found = fetchFromDatabase(db, sanitizedMessage)
		else
			found = fetchFromDatabase(loadErrors, sanitizedMessage)
		end
		-- XXX Note that fetchFromDatabase will set the error objects
		-- XXX session ID to the current one, if found - and it will also
		-- XXX increment the counter on it. This is probably wrong, it should
		-- XXX be done here instead, as "fetchFromDatabase" implies a simple
		-- XXX :Get procedure.

		local errorObject = found

		if not errorObject then
			-- Store the error
			if isSimple then
				errorObject = {
					message = sanitizedMessage,
					session = addon:GetSessionId(),
					time = date("%Y/%m/%d %H:%M:%S"),
					counter = 1,
				}
			else
				local stack = debugstack(3)

				-- Scan for version numbers in the stack
				for line in stack:gmatch("(.-)\n") do
					tmp[#tmp+1] = findVersions(line)
				end
				local inCombat = IsEncounterInProgress() -- debuglocals can be slow sometimes (200ms+)
				errorObject = {
					message = sanitizedMessage,
					stack = table.concat(tmp, "\n"),
					locals = inCombat and "Skipped (In Encounter)" or debuglocals(3),
					session = addon:GetSessionId(),
					time = date("%Y/%m/%d %H:%M:%S"),
					counter = 1,
				}

				wipe(tmp)
			end
		end

		if not isBugGrabbedRegistered then
			print(L.ERROR_DETECTED:format(addon:GetChatLink(errorObject)))
		end

		addon:StoreError(errorObject)

		triggerEvent("BugGrabber_BugGrabbed", errorObject)
	end
end

-----------------------------------------------------------------------
-- API
--

function addon:StoreError(errorObject)
	if db then
		db[#db + 1] = errorObject
		-- Save only the last MAX_BUGGRABBER_ERRORS errors (otherwise the SV gets too big)
		if #db > MAX_BUGGRABBER_ERRORS then
			table.remove(db, 1)
		end
	else
		loadErrors[#loadErrors + 1] = errorObject
	end
end

do
	local function createChatHook()
		-- Set up the ItemRef hook that allow us to link bugs.
		local SetHyperlink = ItemRefTooltip.SetHyperlink
		function ItemRefTooltip:SetHyperlink(link, ...)
			local player, tableId = link:match("^buggrabber:([^:]+):([^:]+):")
			if player then
				addon:HandleBugLink(player, tableId, link)
			else
				SetHyperlink(self, link, ...)
			end
		end
	end

	-- We need to hook the chat frame when anyone requests a chat link from us,
	-- in case some other addon has hooked :HandleBugLink to process it. If not,
	-- we could've just created the hook in grabError when we do the print.
	function addon:GetChatLink(errorObject)
		if createChatHook then createChatHook() createChatHook = nil end
		local tableId = tostring(errorObject):sub(8)
		return chatLinkFormat:format(playerName, tableId, tableId)
	end
end

function addon:GetErrorByPlayerAndID(player, id)
	if player == playerName then return addon:GetErrorByID(id) end
	print(L.ERROR_UNABLE)
end

function addon:GetErrorByID(id)
	local errorId = tableToString:format(id)
	for i, err in next, db do
		if tostring(err) == errorId then
			return err
		end
	end
end

function addon:GetErrorID(errorObject) return tostring(errorObject):sub(8) end
function addon:Reset() if BugGrabberDB then wipe(BugGrabberDB.errors) end end
function addon:GetDB() return db or loadErrors end
function addon:GetSessionId() return BugGrabberDB and BugGrabberDB.session or -1 end
function addon:IsPaused() return paused end

function addon:HandleBugLink(player, id)
	local errorObject = addon:GetErrorByPlayerAndID(player, id)
	if errorObject then
		printErrorObject(errorObject)
	end
end

-----------------------------------------------------------------------
-- Initialization
--

local function initDatabase()
	-- Persist defaults and make sure we have sane SavedVariables
	if type(BugGrabberDB) ~= "table" then BugGrabberDB = {} end
	local sv = BugGrabberDB
	if type(sv.session) ~= "number" then sv.session = 0 end
	if type(sv.errors) ~= "table" then sv.errors = {} end

	-- From now on we can persist errors. Create a new session.
	sv.session = sv.session + 1

	-- Determine the correct database
	db = BugGrabberDB.errors -- db is a file-local variable
	-- Cut down on the nr of errors if it is over the MAX_BUGGRABBER_ERRORS
	while #db > MAX_BUGGRABBER_ERRORS do
		table.remove(db, 1)
	end

	-- If there were any load errors, we need to iterate them and
	-- insert the relevant ones into our SV DB.
	for i, err in next, loadErrors do
		err.session = sv.session -- Update the session ID directly
		local exists = fetchFromDatabase(db, err.message)
		addon:StoreError(exists or err)
	end
	wipe(loadErrors)

	if type(sv.lastSanitation) ~= "number" or sv.lastSanitation ~= 3 then
		for i, v in next, db do
			if type(v.message) == "table" then table.remove(db, i) end
		end
		sv.lastSanitation = 3
	end

	-- load locales
	if type(addon.LoadTranslations) == "function" then
		local locale = GetLocale()
		if locale ~= "enUS" and locale ~= "enGB" then
			addon:LoadTranslations(locale, L)
		end
		addon.LoadTranslations = nil
	end

	-- Only warn about missing display if we're running standalone.
	if not displayObjectName and bugGrabberParentAddon == STANDALONE_NAME then
		local _, _, _, currentInterface = GetBuildInfo()
		if type(currentInterface) ~= "number" then currentInterface = 0 end
		if not sv.stopnag or sv.stopnag < currentInterface then
			print(L.NO_DISPLAY_1)
			print(L.NO_DISPLAY_2)
			print(L.NO_DISPLAY_STOP)
			_G.SlashCmdList.BugGrabberStopNag = function()
				print(L.STOP_NAG)
				sv.stopnag = currentInterface
			end
			_G.SLASH_BugGrabberStopNag1 = "/stopnag"
		end
	end

	initDatabase = nil
end

local events = {}
do
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, ...) events[event](events, event, ...) end)
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("ADDON_ACTION_BLOCKED")
	frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	frame:RegisterEvent("LUA_WARNING")
	local function noop() end -- Prevent abusive addons
	frame.RegisterEvent = noop
	frame.UnregisterEvent = noop
	frame.SetScript = noop
end

do
	local function createSwatter()
		-- Need this so Stubby will feed us errors instead of just
		-- dumping them to the chat frame.
		_G.Swatter = {
			IsEnabled = function() return true end,
			OnError = function(msg, _, stack)
				grabError(tostring(msg) .. tostring(stack))
			end,
			isFake = true,
		}
	end

	local swatterDisabled = nil
	function events:ADDON_LOADED(_, msg)
		if not callbacks then setupCallbacks() end
		if msg == "Stubby" then createSwatter() end
		if initDatabase then
			-- If we're running embedded, just init as soon as possible,
			-- but if we are running separately we init when !BugGrabber
			-- loads so that our SVs are available.
			if bugGrabberParentAddon ~= STANDALONE_NAME or msg == bugGrabberParentAddon then
				initDatabase()
			end
		end

		if not swatterDisabled and _G.Swatter and not _G.Swatter.isFake then
			swatterDisabled = true
			if bugGrabberParentAddon == STANDALONE_NAME then
				print(L.ADDON_DISABLED:format("Swatter", "Swatter", "Swatter"))
			end
			DisableAddOn("!Swatter")
			SlashCmdList.SWATTER = nil
			SLASH_SWATTER1, SLASH_SWATTER2 = nil, nil
			for k, v in next, Swatter do
				if type(v) == "table" then
					if v.UnregisterAllEvents then
						v:UnregisterAllEvents()
					end
					if v.Hide then
						v:Hide()
					end
				end
			end
			Swatter = nil

			local _, _, _, enabled = GetAddOnInfo("Stubby")
			if enabled then createSwatter() end

			real_seterrorhandler(grabError)
		end
	end
end

function events:PLAYER_LOGIN()
	if not callbacks then setupCallbacks() end
	real_seterrorhandler(grabError)
end
do
	local badAddons = {}
	function events:ADDON_ACTION_FORBIDDEN(event, addonName, addonFunc)
		local name = addonName or "<name>"
		if not badAddons[name] then
			badAddons[name] = true
			grabError(L.ADDON_CALL_PROTECTED:format(event, name or "<name>", addonFunc or "<func>"))
		end
	end
end
events.ADDON_ACTION_BLOCKED = events.ADDON_ACTION_FORBIDDEN
function events:LUA_WARNING(_, warnType, warningText)
	-- Temporary hack for the few dropdown libraries that exist that were designed poorly
	-- Hopefully we will see a rewrite of dropdowns soon
	if warnType == 0 and warningText:find("DropDown", nil, true) then return end
	grabError(warningText, true)
end

UIParent:UnregisterEvent("LUA_WARNING")
real_seterrorhandler(grabError)
function seterrorhandler() --[[ noop ]] end

-- Set up slash command
_G.SlashCmdList.BugGrabber = slashHandler
_G.SLASH_BugGrabber1 = "/buggrabber"
_G.BugGrabber = setmetatable({}, { __index = addon, __newindex = function() grabError("Modifications not allowed.") end, __metatable = false })

