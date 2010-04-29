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
	addon.bags = {
		Bank = true,
		Backpack = true,
	}
end

function addon:OnEnable()
	--self:RegisterBucketEvent('BAG_UPDATE', 0.5, 'BagUpdated')
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('BANKFRAME_CLOSED')
	
	self:RawHook('ToggleBackpack', true)
	self:RawHook('OpenBackpack', true)
	self:RawHook('CloseBackpack', true)
	self:RawHook("OpenAllBags", true)
	self:RawHook("CloseAllBags", true)
	
	self:RegisterEvent('MAIL_CLOSED', 'CloseAllBags')
	self:SecureHook('CloseSpecialWindows', 'CloseAllBags')
end

function addon:CreateBag(name, mainBag, bagOffset, numBags, isBank)
	local bags = { [mainBag] = true }
	if bagOffset and numBags then
		for i = bagOffset + 1, bagOffset + numBags do
			bags[i] = true
		end
	end
	local container = self:CreateContainerFrame(name, bags, isBank)
	local cname = container:GetName()
	for id in pairs(bags) do
		local f = CreateFrame("Frame", cname..'Bag'..id, container)
		f:SetID(id)
		addon.itemParentFrames[id] = f
	end
	self.bags[name] = container
	return container
end

function addon:GetBag(name, noCreate)
	local bag = self.bags[name]
	if bag and bag ~= true then
		return bag
	elseif noCreate then
		return
	end
	if name == "Backpack" then
		bag = self:CreateBag("Backpack", BACKPACK_CONTAINER, 0, NUM_BAG_SLOTS)
		bag:SetPoint("BOTTOMRIGHT", -20, 300)
	elseif name == "Bank" then
		bag = self:CreateBag("Bank", BANK_CONTAINER, ITEM_INVENTORY_BANK_BAG_OFFSET, NUM_BANKBAGSLOTS, true)
		bag:SetPoint("BOTTOMRIGHT", self:GetBag("Backpack"), "BOTTOMLEFT", -10, 0)
		bag:SetBackdropColor(0, 0, 0.5, 1)
	end
	self.bags[name] = bag
	return bag
end

function addon:CanOpenBag(name)
	return name ~= 'Bank' or self.atBank
end

function addon:OpenBag(name)
	if self:CanOpenBag(name) then
		local bag = self:GetBag(name)
		if not bag:IsShown() then
			bag:Show()
		else
			return true
		end
	end
end

function addon:CloseBag(name)
	if self:IsBagOpen(name) then
		self:GetBag(name):Hide()
	end
end

function addon:IsBagOpen(name)
	local bag = self:GetBag(name, true)
	return bag and bag:IsShown()
end

function addon:AreAllBagsOpen()
	for name in pairs(self.bags) do
		if self:CanOpenBag(name) and not self:IsBagOpen(name) then
			return false
		end
	end
	return true
end

function addon:OpenBackpack() 
	return self:OpenBag("Backpack") 
end

function addon:CloseBackpack() 
	self:CloseBag("Backpack")
end

function addon:ToggleBackpack()
	if self:IsBagOpen("Backpack") then
		self:CloseBag("Backpack")
	else
		self:OpenBag("Backpack")
	end
end

function addon:OpenAllBags(forceOpen)
	if not forceOpen and self:AreAllBagsOpen() then
		self:CloseAllBags()
	else
		for name in pairs(self.bags) do
			self:OpenBag(name)
		end
	end
end

function addon:CloseAllBags()
	for name in pairs(self.bags) do
		self:CloseBag(name)
	end
end

function addon:BANKFRAME_OPENED()
	self.atBank = true
	self:OpenAllBags(true)
end

function addon:BANKFRAME_CLOSED()
	self.atBank = false
	self:CloseAllBags()
end

