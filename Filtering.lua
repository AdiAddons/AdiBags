--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local AceBucket = LibStub('AceBucket-3.0')

local filters = {}

function addon:RegisterFilter(name, priority, Filter, PreFilter, PostFilter, OnEnable, OnDisable)
	local t
	if type(name) == "table" then
		t = name
	else
		t = {
			name = name,
			priority = priority,
			Filter = Filter,
			PreFilter = PreFilter,
			PostFilter = PostFilter,
			OnEnable = OnEnable,
			OnDisable = OnDisable,
		}
	end
	t.label = t.label or L[t.name]
	t.priority = t.priority or 0
	tinsert(filters, t)
end

local function CompareFilters(a, b)
	return (a and a.priority or 0) > (b and b.priority or 0)
end

function addon:SetupFilters()
	self:SetupDefaultFilters()
	table.sort(filters, CompareFilters)
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

function addon:EnableFilters()
	for i, filter in ipairs(filters) do
		if filter.updateOnEvent then
			AceBucket.RegisterBucketEvent(filter, filter.updateOnEvent, 0.1, addon.UpdateAllBags)
		end
		safecall(filter.OnEnable, filter)
	end
end

function addon:DisableFilters()
	for i, filter in ipairs(filters) do
		safecall(filter.OnDisable, filter)
		AceBucket.UnregisterAllBuckets(filter)
	end
end

function addon:PreFilter(event, container)
	for i, filter in ipairs(filters) do
		safecall(filter.PreFilter, filter)
	end
end

function addon:PostFilter(event, container)
	for i, filter in ipairs(filters) do
		safecall(filter.PostFilter, filter)
	end
end

function addon:Filter(bag, slot, itemId, link)
	for i, filter in ipairs(filters) do
		local sectionName, stack = safecall(filter.Filter, filter, bag, slot, itemId, link)
		if sectionName then
			return filter.name, sectionName, stack
		end
	end
end

