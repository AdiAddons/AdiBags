--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local filterMod = addon:NewModule('Filters', 'AceEvent-3.0')

addon.filterProto = {
	OnEnable = function()
		filterMod:UpdateFilters()
	end,
	OnDisable = function()
		filterMod:UpdateFilters()
	end,
	Debug = addon.Debug,
}

filterMod:SetDefaultModulePrototype(addon.filterProto)

function filterMod:OnInitialize()
	addon:SetupDefaultFilters()
	self:UpdateFilters()
end

local function CompareFilters(a, b)
	return (a and a.priority or 0) > (b and b.priority or 0)
end

local filters = {}
function filterMod:UpdateFilters()	
	wipe(filters)
	for name, filter in self:IterateModules() do
		if filter:IsEnabled() then
			tinsert(filters, filter)
		end
	end
	table.sort(filters, CompareFilters)
	self:SendMessage('AdiBags_FiltersChanged')
end

function addon:RegisterFilter(name, priority, Filter, ...)
	local filter
	if type(Filter) == "function" then
		filter = filterMod:NewModule(name, ...)
		filter.Filter = Filter
	else
		filter = filterMod:NewModule(name, Filter, ...)
	end
	filter.priority = priority or 0
	return filter
end

local function safecall_return(success, ...)
	if success then
		return ...
	else
		geterrorhandler()((...))
	end
end

local function safecall(func, ...)
	if type(func) == "function" then
		return safecall_return(pcall(func, ...))
	end
end

function addon:Filter(slotData)
	for i, filter in ipairs(filters) do
		local sectionName, stack = safecall(filter.Filter, filter, slotData)
		if sectionName then
			return filter.name, sectionName, stack
		end
	end
end

