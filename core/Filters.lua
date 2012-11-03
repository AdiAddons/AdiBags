--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local assert = _G.assert
local ipairs = _G.ipairs
local setmetatable = _G.setmetatable
local tinsert = _G.tinsert
local tsort = _G.table.sort
local type = _G.type
local wipe = _G.wipe
--GLOBALS>

--------------------------------------------------------------------------------
-- Filter prototype
--------------------------------------------------------------------------------

local filterProto = setmetatable({
	isFilter = true,
	priority = 0,
	OpenOptions = function(self)
		return addon:OpenOptions("filters", self.filterName)
	end,
}, { __index = addon.moduleProto })
addon.filterProto = filterProto

function filterProto:OnEnable()
	addon:UpdateFilters()
end

function filterProto:OnDisable()
	addon:UpdateFilters()
end

function filterProto:GetPriority()
	return addon.db.profile.filterPriorities[self.filterName] or self.priority or 0
end

function filterProto:SetPriority(value)
	if value ~= self:GetPriority() then
		addon.db.profile.filterPriorities[self.filterName] = (value ~= self.priority) and value or nil
		addon:UpdateFilters()
	end
end

--------------------------------------------------------------------------------
-- Filter handling
--------------------------------------------------------------------------------

function addon:InitializeFilters()
	self:SetupDefaultFilters()
	self:UpdateFilters()
end

local function CompareFilters(a, b)
	local prioA, prioB = a:GetPriority(), b:GetPriority()
	if prioA == prioB then
		return a.filterName < b.filterName
	else
		return prioA > prioB
	end
end

local activeFilters = {}
local allFilters = {}
function addon:UpdateFilters()
	wipe(allFilters)
	for name, filter in self:IterateModules() do
		if filter.isFilter then
			tinsert(allFilters, filter)
		end
	end
	tsort(allFilters, CompareFilters)
	wipe(activeFilters)
	for i, filter in ipairs(allFilters) do
		if filter:IsEnabled() then
			tinsert(activeFilters, filter)
		end
	end
	self:SendMessage('AdiBags_FiltersChanged')
end

function addon:IterateFilters()
	return ipairs(allFilters)
end

function addon:RegisterFilter(name, priority, Filter, ...)
	local filter
	if type(Filter) == "function" then
		filter = addon:NewModule(name, filterProto, ...)
		filter.Filter = Filter
	elseif Filter then
		filter = addon:NewModule(name, filterProto, Filter, ...)
	else
		filter = addon:NewModule(name, filterProto)
	end
	filter.filterName = name
	filter.priority = priority
	return filter
end

--------------------------------------------------------------------------------
-- Filtering process
--------------------------------------------------------------------------------

local safecall = addon.safecall
function addon:Filter(slotData, defaultSection, defaultCategory)
	for i, filter in ipairs(activeFilters) do
		local sectionName, category = safecall(filter.Filter, filter, slotData)
		if sectionName then
			--@alpha@
			assert(type(sectionName) == "string", "Filter "..filter.name.." returned "..type(sectionName).." as section name instead of a string")
			assert(category == nil or type(category) == "string", "Filter "..filter.name.." returned "..type(category).." as category instead of a string")
			--@end-alpha@
			return sectionName, category, filter.uiName
		end
	end
	return defaultSection, defaultCategory
end
