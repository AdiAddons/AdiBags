--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local BankFrame = _G.BankFrame
local CloseBankFrame = _G.CloseBankFrame
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local tinsert = _G.tinsert
local tsort = _G.table.sort
--GLOBALS>

local hookedBags = addon.hookedBags

--------------------------------------------------------------------------------
-- Bag prototype
--------------------------------------------------------------------------------

local bagProto = setmetatable({
	isBag = true,
}, { __index = addon.moduleProto })
addon.bagProto = bagProto

function bagProto:OnEnable()
	local open = false
	for id in pairs(self.bagIds) do
		local frame = addon:GetContainerFrame(id)
		if frame then
			open = true
			frame:Hide()
		end
		hookedBags[id] = self
	end
	if self.PostEnable then
		self:PostEnable()
	end
	self:Debug('Enabled')
	if open then
		self:Open()
	end
end

function bagProto:OnDisable()
	local open = self:IsOpen()
	self:Close()
	for id in pairs(self.bagIds) do
		hookedBags[id] = nil
		if open then
			addon:GetContainerFrame(id, true)
		end
	end
	if self.PostDisable then
		self:PostDisable()
	end
	self:Debug('Disabled')
end

function bagProto:Open()
	if not self:CanOpen() then return end
	local frame = self:GetFrame()
	if not frame:IsShown() then
		self:Debug('Open')
		frame:Show()
		addon:SendMessage('AdiBags_BagOpened', self.bagName, self)
		return true
	end
end

function bagProto:Close()
	if self.frame and self.frame:IsShown() then
		self:Debug('Close')
		self.frame:Hide()
		addon:SendMessage('AdiBags_BagClosed', self.bagName, self)
		if self.PostClose then
			self:PostClose()
		end
		return true
	end
end

function bagProto:IsOpen()
	return self.frame and self.frame:IsShown()
end

function bagProto:CanOpen()
	return self:IsEnabled()
end

function bagProto:Toggle()
	if self:IsOpen() then
		self:Close()
	elseif self:CanOpen() then
		self:Open()
	end
end

function bagProto:HasFrame()
	return not not self.frame
end

function bagProto:GetFrame()
	if not self.frame then
		self.frame = self:CreateFrame()
		self.frame.CloseButton:SetScript('OnClick', function() self:Close() end)
		addon:SendMessage('AdiBags_BagFrameCreated', self)
	end
	return self.frame
end

function bagProto:CreateFrame()
	return addon:CreateContainerFrame(self.bagName, self.bagIds, self.isBank)
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
	tsort(bags, CompareBags)
	return bag
end

do
	local function iterateOpenBags(numBags, index)
		while index < numBags do
			index = index + 1
			local bag = bags[index]
			if bag:IsEnabled() and bag:IsOpen() then
				return index, bag
			end
		end
	end

	local function iterateBags(numBags, index)
		while index < numBags do
			index = index + 1
			local bag = bags[index]
			if bag:IsEnabled() then
				return index, bag
			end
		end
	end

	function addon:IterateBags(onlyOpen)
		return onlyOpen and iterateOpenBags or iterateBags, #bags, 0
	end
end

function addon:IterateDefinedBags()
	return ipairs(bags)
end

--------------------------------------------------------------------------------
-- Backpack
--------------------------------------------------------------------------------

do
	-- L["Backpack"]
	local backpack = addon:NewBag("Backpack", 10, addon.BAG_IDS.BAGS, false, 'AceHook-3.0')

	function backpack:PostEnable()
		self:RegisterMessage('AdiBags_InteractingWindowChanged')
	end

	function backpack:AdiBags_InteractingWindowChanged(event, window)
		if window then
			self.wasOpen = self:IsOpen()
			if not self.wasOpen then
				self:Open()
			end
		elseif self:IsOpen() and not self.wasOpen then
			self:Close()
		end
	end

end

--------------------------------------------------------------------------------
-- Bank
--------------------------------------------------------------------------------

do
	-- L["Bank"]
	local bank = addon:NewBag("Bank", 20, addon.BAG_IDS.BANK, true, 'AceHook-3.0')

	local function NOOP() end

	function bank:PostEnable()
		self:RegisterMessage('AdiBags_InteractingWindowChanged')

		BankFrame:Hide()
		self:RawHookScript(BankFrame, "OnEvent", NOOP, true)
		self:RawHook(BankFrame, "Show", "Open", true)
		self:RawHook(BankFrame, "Hide", "Close", true)
		self:RawHook(BankFrame, "IsShown", "IsOpen", true)

		if addon:GetInteractingWindow() == "BANKFRAME" then
			self:Open()
		end
	end

	function bank:PostDisable()
		if addon:GetInteractingWindow() == "BANKFRAME" then
			self.hooks[BankFrame].Show(BankFrame)
		end
	end

	function bank:AdiBags_InteractingWindowChanged(event, new, old)
		if new == 'BANKFRAME' and not self:IsOpen() then
			self:Open()
		elseif old == 'BANKFRAME' and self:IsOpen() then
			self:Close()
		end
	end

	function bank:CanOpen()
		return self:IsEnabled() and addon:GetInteractingWindow() == "BANKFRAME"
	end

	function bank:PostClose()
		CloseBankFrame()
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
