--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--------------------------------------------------------------------------------
-- Bag prototype
--------------------------------------------------------------------------------

local bagProto = {
	Debug = addon.Debug
}

function bagProto:OnDisable()
	self:Close()
end

function bagProto:Open()
	if not self:CanOpen() then return end
	self:Debug('Open')
	local frame = self:GetFrame()
	if not frame:IsShown() then
		frame:Show()
		addon:SendMessage('AdiBags_BagOpened', name, self)
	end
end

function bagProto:Close()
	self:Debug('Close')
	if self:IsOpen() then
		self:GetFrame():Hide()
		addon:SendMessage('AdiBags_BagClosed', name, self)
	end
end

function bagProto:IsOpen()
	return self.frame and self.frame:IsShown()
end

function bagProto:CanOpen()
	return true
end

function bagProto:HasFrame()
	return not not self.frame
end

function bagProto:GetFrame()
	if not self.frame then
		self.frame = self:CreateFrame()
		addon:SendMessage('AdiBags_BagFrameCreated', self)
	end
	return self.frame
end

function bagProto:CreateFrame()
	return addon:CreateContainerFrame(self.bagName, self.bagIds, self.isBank, addon.anchor)
end

--------------------------------------------------------------------------------
-- Bags methods
--------------------------------------------------------------------------------

local bags = {}

local function CompareBags(a, b)
	return a.order < b.order
end

function addon:NewBag(name, order, bagIds, isBank, ...)
	self:Debug('NewBag', name, order, bagIds, isBank, ...)
	local bag = addon:NewModule(name, bagProto, 'AceEvent-3.0', ...)
	bag.bagName = name
	bag.bagIds = bagIds
	bag.isBank = isBank
	bag.order = order
	tinsert(bags, bag)
	table.sort(bags, CompareBags)
	return bag
end

local function IterateOpenBags(bags, index)
	local bag
	repeat
		index = index + 1
		bag = bags[index]
	until not bag or bag:IsOpen()
	if bag then
		return index, bag
	end
end

function addon:IterateBags(onlyOpen)
	if onlyOpen then
		return IterateOpenBags, bags, 0
	else
		return ipairs, bags
	end
end

function addon:AreAllBagsOpen()
	for i, bag in ipairs(bags) do
		if bag:CanOpen() and not bag:IsOpen() then
			return false
		end
	end
	return true
end

function addon:OpenAllBags(forceOpen)
	if not forceOpen and self:AreAllBagsOpen() then
		return self:CloseAllBags()
	end
	for i, bag in ipairs(bags) do
		bag:Open()
	end
end

function addon:CloseAllBags()
	for i, bag in ipairs(bags) do
		if bag:IsOpen() then
			bag:Close()
		end
	end
end

--------------------------------------------------------------------------------
-- Helper for modules
--------------------------------------------------------------------------------

local hooks = {}

function addon:HookBagFrameCreation(target, callback)
	local hook = hooks[target]
	if not hook then
		local target, callback, seen = target, callback, {}
		hook = function(event, bag)
			if seen[bag] then return end
			seen[bag] = true
			local res, msg
			if type(callback) == "string" then
				res, msg = pcall(target[callback], target, bag)
			else
				res, msg = pcall(callback, bag)
			end
			if not res then
				geterrorhandler()(msg)
			end
		end
		hooks[target] = hook
	end
	local listen = false
	for index, bag in pairs(bags) do
		if bag:HasFrame() then
			hook("HookBagFrameCreation", bag)
		else
			listen = true
		end
	end
	if listen then
		target:RegisterMessage("AdiBags_BagFrameCreated", hook)
	end
end

--------------------------------------------------------------------------------
-- Backpack
--------------------------------------------------------------------------------

do
	local backpack = addon:NewBag("Backpack", 410, addon.BAG_IDS.BAGS, false, 'AceHook-3.0')
	
	function backpack:OnEnable()	
		self:RegisterEvent('BANKFRAME_OPENED', 'Open')
		self:RegisterEvent('BANKFRAME_CLOSED', 'Close')	
		self:RawHook('OpenBackpack', 'Open', true)
		self:RawHook('CloseBackpack', 'Close', true)
		self:RawHook('ToggleBackpack', true)
	end

	function backpack:ToggleBackpack()
		if self:IsOpen() then self:Close() else self:Open() end
	end
	
end

--------------------------------------------------------------------------------
-- Bank
--------------------------------------------------------------------------------

do
	local bank = addon:NewBag("Bank", 20, addon.BAG_IDS.BANK, true, 'AceHook-3.0')
	
	local function NOOP() end
	
	function bank:OnEnable()	
		self:RegisterEvent('BANKFRAME_OPENED')
		self:RegisterEvent('BANKFRAME_CLOSED')
		
		self:RawHook(BankFrame, "Show", NOOP, true)
		self:RawHookScript(BankFrame, "OnEvent", NOOP, true)
		BankFrame:Hide()
	end
	
	function bank:OnDisable()
		if self.atBank then
			BankFrame:Show()
		end
		bagProto.OnDisable(self)
	end

	function bank:BANKFRAME_OPENED()	
		self.atBank = true
		self:Open()
	end

	function bank:BANKFRAME_CLOSED()	
		self.atBank = false
		self:Close()
	end
	
	function bank:CanOpen()
		return self.atBank
	end
	
	function bank:Close()
		if self.atBank then
			CloseBankFrame()
		end
		bagProto.Close(self)
	end
	
end

