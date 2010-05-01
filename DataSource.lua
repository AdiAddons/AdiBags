--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local mod = addon:NewModule('DataSource', 'AceEvent-3.0', 'AceBucket-3.0')

local dataobj = {
	type = 'data source',
	label = addonName,
	text = addonName,
	icon = [[Interface\Buttons\Button-Backpack-Up]],
	OnClick = function() addon:OpenAllBags() end,
}

function mod:OnInitialize()
	local DataBroker = LibStub('LibDataBroker-1.1', true)
	if not DataBroker then
		self:SetEnabledState(false)
		return
	end
	DataBroker:NewDataObject(addonName, dataobj)
end

function mod:OnEnable()
	self:RegisterBucketEvent('BAG_UPDATE', 0.5, "Update")
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('BANKFRAME_CLOSED')
	self:Update()
end

function mod:BANKFRAME_OPENED()
	self.atBank = true
	return self:Update()
end

function mod:BANKFRAME_CLOSED()
	self.atBank = false
	return self:Update()
end

local FAMILY_ORDER = { 
	0x0000, -- Regular bag
	0x0001, -- Quiver
  0x0002, -- Ammo Pouch
  0x0004, -- Soul Bag
  0x0008, -- Leatherworking Bag
  0x0010, -- Inscription Bag
  0x0020, -- Herb Bag
  0x0040, -- Enchanting Bag
  0x0080, -- Engineering Bag
  0x0100, -- Keyring
  0x0200, -- Gem Bag
  0x0400, -- Mining Bag
}

local size = {}
local free = {}
local data = {}

local function BuildSpaceString(bags)
	wipe(size)
	wipe(free)
	for bag in pairs(bags) do
		local bagSize = GetContainerNumSlots(bag)
		if bagSize and bagSize > 0 then
			local bagFree, bagFamily = GetContainerNumFreeSlots(bag)
			size[bagFamily] = (size[bagFamily] or 0) + bagSize
			free[bagFamily] = (free[bagFamily] or 0) + bagFree
		end
	end
	wipe(data)
	local numIcons = 0
	for i, family in ipairs(FAMILY_ORDER) do
		if size[family] then			
			local tag, icon = addon:GetFamilyTag(family)
			local text = string.format("%d/%d", free[family], size[family])
			if icon then
				numIcons = numIcons + 1 -- fix a bug with fontstring embedding several textures
				text = string.format("%s|T%s:0:0:0:%d:64:64:4:60:4:60|t", text, icon, -numIcons)
			elseif tag then
				text = strjoin(':', tag, text)
			end
			tinsert(data, text)
		end
	end
	return table.concat(data, " ")
end

function mod:Update(event)
	local bags = BuildSpaceString(addon.BAG_IDS.BAGS)
	if self.atBank then
		dataobj.text = string.format("%s |cff7777ff%s|r", bags, BuildSpaceString(addon.BAG_IDS.BANK))
	else
		dataobj.text = bags
	end
end

