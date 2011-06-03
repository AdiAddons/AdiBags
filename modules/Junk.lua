--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

-- GLOBALS: setmetatable Scrap LibStub
local _G = _G
local GetItemInfo = _G.GetItemInfo
local ITEM_QUALITY_POOR = _G.ITEM_QUALITY_POOR
local ITEM_QUALITY_UNCOMMON = _G.ITEM_QUALITY_UNCOMMON
local select = _G.select
local wipe = _G.wipe

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
	if not itemId then return false end
	if prefs.exclude[itemId] then
		self:Debug('CheckItem', GetItemInfo(itemId), '=> excluded')
		return false
	elseif prefs.include[itemId] then
		self:Debug('CheckItem', GetItemInfo(itemId), '=> included')
		return true
	elseif self:BaseCheckItem(itemId) then
		self:Debug('CheckItem', GetItemInfo(itemId), '=> BaseCheckItem')
		return true
	elseif self:ExtendedCheckItem(itemId) then
		self:Debug('CheckItem', GetItemInfo(itemId), '=> ExtendedCheckItem')
		return true
	end
	self:Debug('CheckItem', GetItemInfo(itemId), '=> not junk')
	return false
end

function mod:IsJunk(itemId)
	return itemId and cache[itemId] or false
end

function mod:Filter(slotData)
	return cache[slotData.itemId] and JUNK or nil
end

function mod:AdiBags_OverrideFilter(event, section, category, ...)
	self:Debug(event, section, category, ...)
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
			self:Debug('OverrideFilter', GetItemInfo(id), "included=", incFlag, "excluded=", exclFlag)
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
		mod:Update()
	end
	
	local t = {}
	function handler:ListItems(info)
		local items = prefs[info[#info]]
		wipe(t)
		for itemId in pairs(items) do
			local name, _, quality, _, _, _, _,  _, _, icon = GetItemInfo(itemId)
			if not name then
				t[itemId] = format("#%d (item not found)", itemId)
			else
				local color = ITEM_QUALITY_COLORS[quality or 1]
				local hex = color and color.hex or ''
				t[itemId] = format("|T%s:20:20|t %s%s|r", icon, (color and color.hex or ''), name)
			end
		end
		return t
	end
	
	function handler:Remove(info, key)
		return handler:Set(info, key, nil)
	end
	
	function handler:HasNoItem(info)
		return not next(prefs[info[#info]])
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
			name = L['Included items'],
			order = 20,
			values = 'ListItems',
			get = True,
			set = 'Remove',
			hidden = 'HasNoItem',
		},
		exclude = {
			type = 'multiselect',
			name = L['Excluded items'],
			order = 30,
			values = 'ListItems',			
			get = True,
			set = 'Remove',
			hidden = 'HasNoItem',
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

