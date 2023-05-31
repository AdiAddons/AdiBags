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
		DLAPI.DebugLog("AdiBags", format("%s~%s", id, Format(...)))
	end
	return target.Debug
end

-- Custom Log Format.

local logformats = {}
logformats.adi = {}
logformats.adi.colNames = { "ID", "Time", "Cat", "Vrb", "Message", }
logformats.adi.colWidth = { 0.05, 0.12, 0.15, 0.03, 1 - 0.05 - 0.12 - 0.15 - 0.03, }
logformats.adi.colFlex = { "flex", "flex", "drop", "drop", "search", }
logformats.adi.statusText = {
			"Sort by ID",
			"Sort by Time",
			"Sort by Category",
			"Sort by Verbosity",
			"Sort by Message",
		}
do
  if DLAPI then
    logformats.adi.GetSTData = DLAPI.IsFormatRegistered("default").GetSTData
    DLAPI.RegisterFormat("adi", logformats.adi)
    DLAPI.SetFormat("AdiBags", "adi")
  end
end

_G.AdiDebug = AdiDebug