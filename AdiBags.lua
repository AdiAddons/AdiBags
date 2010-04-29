--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0', 'AceBucket-3.0', 'AceHook-3.0')
--@debug@
_G[addonName] = addon
--@end-debug@

--------------------------------------------------------------------------------
-- Debug stuff
--------------------------------------------------------------------------------

if tekDebug then
	local frame = tekDebug:GetFrame(addonName)
	function addon:Debug(...)
		if self.GetName then
			self = self:GetName()
		elseif self == addon then
			self = 'Core'
		else
			self = self.moduleName or self.name or tostring(self)
		end
		frame:AddMessage(string.join(" ", "|cffff7700["..self.."]|r", tostringall(...)))
	end
else
	function addon.Debug() end
end

--------------------------------------------------------------------------------
-- Addon initialization and enabling
--------------------------------------------------------------------------------

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", {
		profile = {},
	}, true)
	addon.itemParentFrames = {}
end

function addon:OnEnable()
	--self:RegisterBucketEvent('BAG_UPDATE', 0.5, 'BagUpdated')
	self:RegisterEvent('BANKFRAME_OPENED')
	self:SecureHook('OpenBackpack')
	self:SecureHook('CloseBackpack')
	self:SecureHook('ToggleBackpack')
end

local function CreateContainer(name, mainBag, bagOffset, numBags, isBank)
	local bags = { [mainBag] = true }
	if bagOffset and numBags then
		for i = bagOffset + 1, bagOffset + numBags do
			bags[i] = true
		end
	end
	local container = addon:CreateContainerFrame(name, bags, isBank)
	local cname = container:GetName()
	for id in pairs(bags) do
		addon.itemParentFrames[id] = CreateFrame("Frame", cname..'Bag'..id, container)
	end
	return container
end

function addon:GetBagContainer()
	if self.bagContainer then return self.bagContainer end
	local container = CreateContainer("Backpack", BACKPACK_CONTAINER, 0, NUM_BAG_SLOTS)
	container:SetPoint("BOTTOMRIGHT", -20, 300)
	self.bagContainer = container
	return container
end

function addon:GetBankContainer()
	if self.bankContainer then return self.bankContainer end
	local container = CreateContainer("Bank", BANK_CONTAINER, ITEM_INVENTORY_BANK_BAG_OFFSET, NUM_BANKBAGSLOTS, true)
	container:SetPoint("BOTTOMLEFT", self:GetBagContainer(), "BOTTOMRIGHT", -10, 0)
	container:SetBackdropColor(0.5, 1, 0.5, 1)
	self.bankContainer = container
	return container
end

function addon:OpenBackpack()
	self:GetBagContainer():Show()
end

function addon:CloseBackpack()
	local bag = self.bagContainer
	if bag and bag:IsShown() then
		bag:Hide()
	end
end

function addon:ToggleBackpack()
	local bag = self:GetBagContainer()
	if bag:IsShown() then
		bag:Hide()
	else
		bag:Show()
	end
end

function addon:BANKFRAME_OPENED()
	self:GetBankContainer():Show()
end
