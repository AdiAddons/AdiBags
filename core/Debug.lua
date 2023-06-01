--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2021 Adirelle (adirelle@gmail.com)
All rights reserved.

This file is part of AdiBags.

AdiBags is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

AdiBags is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdiBags.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addonName = ...

local CBH = LibStub('CallbackHandler-1.0')
--@alpha@
CBH = LibStub('CallbackHandler-1.0-dev')
--@end-alpha@

local dl = LibStub("AceAddon-3.0"):GetAddon("_DebugLog")

---@class AdiDebug
local AdiDebug = {}

AdiDebug.hexColors = {
	["nil"]      = "aaaaaa",
	["boolean"]  = "77aaff",
	["number"]   = "ff77ff",
	["table"]    = "44ffaa",
	["UIObject"] = "ffaa44",
	["function"] = "77ffff",
--	["string"]   = "ffffff",
}

local function safecall_inner(ok, ...)
	if ok then
		return ...
	else
		geterrorhandler()(...)
	end
end

local function safecall(func, ...)
	return safecall_inner(pcall(func, ...))
end

local function GuessTableName(t)
	return
		(type(t.GetName) == "function" and t:GetName())
		or (type(t.ToString) == "function" and t:ToString())
		or t.name
end

local function GetRawTableName(t)
	local mt = getmetatable(t)
	setmetatable(t, nil)
	local name = tostring(t)
	setmetatable(t, mt)
	return name
end

local tableNameCache = setmetatable({}, {
	__mode = 'k',
	__index = function(self, t)
		local name = safecall(GuessTableName, t) or GetRawTableName(t)
		self[t] = name
		return name
	end
})

--- Get an human-readable name for a table, which could be an object or an UIObject.
-- Firstly try to use :GetName() and :ToString() methods, if they exist.
-- Then try to get the "name" field.
-- Finally, returns tostring(t).
-- @param t The table to examine.
-- @return A table name, hopefully human-readable.
function AdiDebug:GetTableName(t)
	return type(t) == "table" and tableNameCache[t] or tostring(t)
end

local function BuildHyperLink(t)
	local name, valueType = tostring(AdiDebug:GetTableName(t)), AdiDebug:GetSmartType(t)
	return format("|cff%s|HAdiDebug%s:%s|h[%s]|h|r", AdiDebug.hexColors[valueType], valueType, name, name)
end

local linkRefs = setmetatable({}, {__mode = 'v'})
local linkCache = setmetatable({}, {
	__mode = 'k',
	__index = function(self, t)
		local link = BuildHyperLink(t)
		linkRefs[link] = t
		self[t] = link
		return link
	end
})

--- Enhanced version of the built-in type() function that detects Blizzard's UIObject.
---@param value any The value to examine.
---@return string Type Either type(value) or "UIObject"
function AdiDebug:GetSmartType(value)
	local t = type(value)
	if t == "table" and type(value[0]) == "userdata" then
		return "UIObject"
	end
	return t
end

---Build a hyperlink for a table.
---@param t table The table.
---@return string Result A hyperlink, suitable to be used in any FontString.
function AdiDebug:GetTableHyperlink(t)
	return type(t) == "table" and linkCache[t] or tostring(t)
end

--- Convert an Lua value into a color, human-readable representation.
---@param value any The value to represent.
---@param noLink boolean Do not return hyperlinks for tables if true ; defaults to false.
---@param maxLength integer The maximum length of the value ; defaults to no limit.
---@return string Result human-readable representation of the value.
function AdiDebug:PrettyFormat(value, noLink, maxLength)
	local valueType = self:GetSmartType(value)
	local stringRepr
	if valueType == "table" or valueType == "UIObject" then
		if not noLink then
			return self:GetTableHyperlink(value)
		else
			stringRepr = self:GetTableName(value)
		end
	elseif valueType == "number" and maxLength then
		stringRepr = strtrim(format('%'..maxLength..'g', value))
	else
		stringRepr = tostring(value)
		if maxLength and strlen(stringRepr) > maxLength then
			stringRepr = strsub(stringRepr, 1, maxLength-3) .. '|cffaaaaaa...|r'
		end
	end
	local color = self.hexColors[valueType]
	return color and strjoin('', '|cff', color, stringRepr, '|r') or stringRepr
end

local function Format(...)
  local tmp = {}
	local n = select('#', ...)
	if n == 0 then
		return
	elseif n == 1 then
		return AdiDebug:PrettyFormat(...)
	end
	for i = 1, n do
		local v = select(i, ...)
		tmp[i] = type(v) == "string" and v or AdiDebug:PrettyFormat(v, false, nil)
	end
	return table.concat(tmp, " ", 1, n)
end


function AdiDebug:Embed(target, streamId)
  if not DLAPI then
    target.Debug = function(...) end
    return target.Debug
  end
	target.Debug = function(s, ...)
		assert(#... > 0, "Usage: self:Debug(message, ...)")
		local id = streamId
		if s.class then
			id = s.class.name
		end
		local lines = {string.match(debugstack(2), '^%[string %"%@Interface%/AddOns%/AdiBags%/(.-)%"%]:(%d-): in function [`<](.-)[\'>]')}
		-- Lines contains:
		-- 1: File name
		-- 2: Line number
		-- 3: Function name
		local event = {string.match(CBH.currentStack, '^%[string %"%@Interface%/AddOns%/AdiBags%/(.-)%"%]:(%d-): in function [`<](.-)[\'>]')}
		local eventTrigger = format("%s:%s", event[1] or " ", event[2] or " ")
		--TODO(lobato): Add location information as a column.
		DLAPI.DebugLog("AdiBags", format("%s~%s~%d~%s~%s~%s", id, lines[1], lines[2], CBH.currentEvent[1] or " ", eventTrigger, Format(...)))
	end
	return target.Debug
end

function AdiDebug.GetSTData(a, flex, filter)
	local content = {}
	dl.debuglog = dl.debuglog or {}
	local logs = dl.debuglog[a]
	if not logs then
		return content, flex
	end

	local k = 1

	for _, row in pairs(logs) do
		local data = {}
		data[2] = row.t 			-- Time
		data[3] = nil   			-- Category
		data[4] = nil   			-- File
		data[5] = 0 					-- Line
		data[6] = nil 				-- Event
		data[7] = nil					-- Event Trigger
		data[8] = row.m or "" -- Message

		local flag = strmatch(data[8], "^([^~]+)~")
		local counter = 3
		while flag do
			data[8] = strmatch(data[8], "^[^~]+~(.*)$")
			data[counter] = flag
			counter = counter + 1
			flag = strmatch(data[8], "^([^~]+)~")
		end
		local en = {}
		en.data = {}
		en.data[1] = {k, k}
		en.data[2] = {DLAPI.TimeToString(data[2]), data[2]}
		en.data[3] = {data[3], data[3] or ""}
		en.data[4] = {data[4], data[4] or ""}
		en.data[5] = {data[5], data[5] or ""}
		en.data[6] = {data[6], data[6] or ""}
		en.data[7] = {data[8], data[8]}
		en.data[8] = {data[7], data[7]}
		table.insert(content, en)
		k = k + 1
	end

	return content, flex
end

-- Custom Log Format.

local logformats = {}
logformats.adi = {}
logformats.adi.colNames = { "ID", "Time", "Cat", "File", "Line", "Event", "Message", }
logformats.adi.colWidth = { 0.05, 0.12, 0.15, 0.20, 0.05, 0.20, 1 - 0.05 - 0.12 - 0.15 - 0.20 - 0.05 - 0.20 - 0.03, }
logformats.adi.colFlex = { "flex", "flex", "drop", "drop", "flex", "drop", "search", }
logformats.adi.statusText = {
			"Sort by ID",
			"Sort by Time",
			"Sort by Category",
			"Sort by Verbosity",
			"Sort by Message",
		}

-- Setup onEnter and onLeave functions for each row to show more debug info.
function dl.GUI.debugLog_OnEnter.adi(btn, data)
	GameTooltip:SetOwner(btn, "ANCHOR_TOPLEFT")
	GameTooltip:ClearLines()
	local category = data.data[3][1]
	local file = data.data[4][1]
	local line = data.data[5][1]
	local event = data.data[6][1]
	local eventTrigger = data.data[8][1]
	local message = data.data[7][1]

	GameTooltip:AddDoubleLine("Category", category)
	GameTooltip:AddDoubleLine("Line", format("%s:%d", file or " ", line or 0))
	GameTooltip:AddDoubleLine("Event", event)
	GameTooltip:AddDoubleLine("Event Trigger", eventTrigger)
	GameTooltip:AddLine("Message:")
	GameTooltip:AddLine(message, 1, 1, 1, false)
	GameTooltip:Show()
end

function dl.GUI.debugLog_OnLeave.adi(btn, data)
	GameTooltip:Hide()
	GameTooltip:ClearLines()
end

do
  if DLAPI then
    --logformats.adi.GetSTData = DLAPI.IsFormatRegistered("default").GetSTData
		logformats.adi.GetSTData = AdiDebug.GetSTData
    DLAPI.RegisterFormat("adi", logformats.adi)
    DLAPI.SetFormat("AdiBags", "adi")
  end
end

_G.AdiDebug = AdiDebug