--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local GetItemInfo = _G.GetItemInfo
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local ITEM_QUALITY_UNCOMMON = _G.ITEM_QUALITY_UNCOMMON
local select = _G.select
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber
local type = _G.type
local wipe = _G.wipe
--GLOBALS>

local JUNK = addon.BI['Junk']

local mod = addon:RegisterFilter("Junk", 85, "AceEvent-3.0", "AceHook-3.0")
mod.uiName = JUNK
mod.uiDesc = L['Put items of poor quality or labeled as junk in the "Junk" section.']

local DEFAULTS = {
	profile = {
		sources = { ['*'] = true },
		include = {},
		exclude = {},
	},
}

local prefs

local cache = setmetatable({}, { __index = function(t, itemId)
	local isJunk = mod:CheckItem(itemId)
	t[itemId] = isJunk
	return isJunk
end})

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, DEFAULTS)
	prefs = self.db.profile
end

function mod:OnEnable()
	prefs = self.db.profile
	self:RegisterMessage('AdiBags_OverrideFilter')
	self:Hook(addon, 'IsJunk')
	wipe(cache)
end

function mod:BaseCheckItem(itemId, force)
	local _, _, quality, _, _, class, subclass = GetItemInfo(itemId)
	if ((force or prefs.sources.lowQuality) and quality == ITEM_QUALITY_POOR)
		or ((force or prefs.sources.junkCategory) and quality and quality < ITEM_QUALITY_UNCOMMON and (class == JUNK or subclass == JUNK)) then
		return true
	end
	return false
end

function mod:ExtendedCheckItem(itemId, force)
	return false
end

function mod:CheckItem(itemId)
	if not itemId then
		return false
	elseif not GetItemInfo(itemId) then
		return nil -- Should cause to rescan later
	elseif prefs.exclude[itemId] then
		return false
	elseif prefs.include[itemId] then
		return true
	elseif self:BaseCheckItem(itemId) then
		return true
	elseif self:ExtendedCheckItem(itemId) then
		return true
	end
	return false
end

function mod:IsJunk(_, itemId)
	return tonumber(itemId) and cache[tonumber(itemId)] or false
end

function mod:Filter(slotData)
	return cache[slotData.itemId] and JUNK or nil
end

function mod:AdiBags_OverrideFilter(event, section, category, ...)
	local changed = false
	local include, exclude = prefs.include, prefs.exclude
	for i = 1, select('#', ...) do
		local id = select(i, ...)
		local incFlag, exclFlag
		if section == JUNK then
			incFlag = not self:BaseCheckItem(id, true) or nil
		else
			exclFlag = (self:BaseCheckItem(id, true) or self:ExtendedCheckItem(id, true)) and true or nil
		end
		if include[id] ~= incFlag or exclude[id] ~= exclFlag then
			include[id], exclude[id] = incFlag, exclFlag
			changed = true
		end
	end
	if changed then
		self:Update()
	end
end

function mod:Update()
	wipe(cache)
	self:SendMessage('AdiBags_FiltersChanged')
	local acr = LibStub('AceConfigRegistry-3.0', true)
	if acr then
		acr:NotifyChange(addonName)
	end
end

-- Options

local sourceList = {
	lowQuality = L['Low quality items'],
	junkCategory = L['Junk category'],
}
function mod:GetOptions()
	local handler = addon:GetOptionHandler(self)

	local Set = handler.Set
	function handler.Set(...)
		Set(...)
		return mod:Update()
	end

	function handler:ListItems(info)
		return prefs[info[#info]]
	end

	function handler:SetItem(info, key, value)
		return self:Set(info, key, value and true or nil)
	end

	local function True() return true end

	return {
		sources = {
			type = 'multiselect',
			name = L['Included categories'],
			values = sourceList,
			order = 10,
		},
		include = {
			type = 'multiselect',
			dialogControl = 'ItemList',
			name = L['Include list'],
			desc = L['Items in this list are always considered as junk. Click an item to remove it from the list.'],
			order = 20,
			values = 'ListItems',
			get = True,
			set = 'SetItem',
		},
		exclude = {
			type = 'multiselect',
			dialogControl = 'ItemList',
			name = L['Exclude list'],
			desc = L['Items in this list are never considered as junk. Click an item to remove it from the list.'],
			order = 30,
			values = 'ListItems',
			get = True,
			set = 'SetItem',
		},
	}, handler
end

-- Third-party addon support

local Scrap = _G.Scrap
local BrainDead = LibStub('AceAddon-3.0'):GetAddon('BrainDead', true)

if Scrap and type(Scrap.IsJunk) == "function" then
	-- Scrap support

	function mod:ExtendedCheckItem(itemId, force)
		return (force or prefs.sources.Scrap) and Scrap:IsJunk(itemId)
	end

	Scrap:HookScript('OnReceiveDrag', function()
		if prefs.sources.Scrap then
			wipe(cache)
			addon:SendMessage("AdiBags_FiltersChanged")
		end
	end)

	sourceList.Scrap = "Scrap"

elseif BrainDead then
	-- BrainDead support

	local SellJunk = BrainDead:GetModule('SellJunk')

	function mod:ExtendedCheckItem(itemId, force)
		return (force or prefs.sources.BrainDead) and SellJunk.db.profile.items[itemId]
	end

	sourceList.BrainDead = "BrainDead"
end

