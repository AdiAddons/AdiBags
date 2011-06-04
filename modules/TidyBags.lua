--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local band = _G.bit.band
local ClearCursor = _G.ClearCursor
local CreateFrame = _G.CreateFrame
local GetContainerFreeSlots = _G.GetContainerFreeSlots
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetCursorInfo = _G.GetCursorInfo
local GetItemInfo = _G.GetItemInfo
local InCombatLockdown = _G.InCombatLockdown
local ipairs = _G.ipairs
local next = _G.next
local pairs = _G.pairs
local PickupContainerItem = _G.PickupContainerItem
local PlaySound = _G.PlaySound
local select = _G.select
local setmetatable = _G.setmetatable
local tinsert = _G.tinsert
local tsort = _G.table.sort
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId

local mod = addon:NewModule('TidyBags', 'AceEvent-3.0', 'AceBucket-3.0')
mod.uiName = L['Tidy bags']
mod.uiDesc = L['Tidy your bags by clicking on the small "T" button at the top left of bags. Special bags with free slots will be filled with macthing items and stackable items will be stacked to save space.']

local bags = {}

-- Internal bag object
local bagProto = { Debug = addon.Debug }
local bagMeta = { __index = bagProto }

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			autoTidy = false,
		},
	})
end

function mod:OnEnable()
	for i, bag in addon:IterateDefinedBags() do
		local name = bag.bagName
		if not bags[name] then
			self:Debug('Adding bag', bag, name, bag.bagIds)
			bags[name] = setmetatable({
				name = "Tidy-"..name,
				bagIds = bag.bagIds,
				obj = bag,
				locked = {},
			}, bagMeta)
			self:Debug('Registered', bags[name])
		end
	end
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')

	self:RegisterMessage('AdiBags_InteractingWindowChanged')
	self:RegisterBucketEvent('BAG_UPDATE', 0)
	self:RegisterEvent('PLAYER_REGEN_DISABLED', 'RefreshAllBags')
	self:RegisterEvent('PLAYER_REGEN_ENABLED')
	self:RegisterEvent('LOOT_CLOSED', 'AutomaticTidy')

	for name, bag in pairs(bags) do
		bag:ShowButton()
	end
end

function mod:OnDisable()
	for name, bag in pairs(bags) do
		bag:HideButton()
	end
end

function mod:GetOptions()
	return {
		autoTidy = {
			name = L['Semi-automated tidy'],
			desc = L['Check this so tidying is performed when you close the loot windows or you leave merchants, mailboxes, etc.'],
			type = 'toggle',
			order = 10,
		},
	}, addon:GetOptionHandler(self)
end

function mod:AdiBags_InteractingWindowChanged(event, new)
	if not new then
		return self:AutomaticTidy(event)
	end
end

function mod:OnBagFrameCreated(bag)
	bags[bag.bagName]:AttachContainer(bag:GetFrame())
end

function mod:AutomaticTidy(event)
	if not self.db.profile.autoTidy or InCombatLockdown() then return end
	self:Debug('AutomaticTidy on', event)
	for name, bag in pairs(bags) do
		bag:Tidy()
	end
end

local wasLocked = {}
local wasCached = {}
function mod:BAG_UPDATE(bagIds)
	self:Debug('BAG_UPDATE')
	wipe(wasLocked)
	wipe(wasCached)
	for name, bag in pairs(bags) do
		if bag:IsAvailable() then
			for bagID in pairs(bagIds) do
				if bag.bagIds[bagID] then
					if bag.cached then
						bag:Debug("Bag", bagID, "updated")
						wasCached[bag] = true
						bag.cached = nil
					end
					if bag.locked[bagID] then
						bag:Debug('Bag', bagID, "unlocked")
						bag.locked[bagID] = nil
						wasLocked[bag] = true
					end
				end
			end
		end
	end
	for bag in pairs(wasLocked) do
		if bag.running and not next(bag.locked) then
			wasCached[bag] = nil
			bag:Process()
		end
	end
	for bag in pairs(wasCached) do
		bag:UpdateButton("BAG_UPDATE")
	end
end

function mod:RefreshAllBags(event)
	for name, bag in pairs(bags) do
		bag:UpdateButton(event)
	end
end

function mod:PLAYER_REGEN_ENABLED(event)
	self:RefreshAllBags(event)
	self:AutomaticTidy(event)
end

--------------------------------------------------------------------------------
-- Bag methods
--------------------------------------------------------------------------------

local function TidyButton_OnClick(button)
	PlaySound("igMainMenuOptionCheckBoxOn")
	return button.bag:Tidy()
end

local function TidyButton_OnShow(button)
	return button.bag:UpdateButton('OnShow')
end

function bagProto:AttachContainer(container)
	self:Debug('Attaching container', container)
	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.bag = self
	button:SetText("T")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", TidyButton_OnClick)
	button:SetScript("OnShow", TidyButton_OnShow)
	addon.SetupTooltip(button, {
		L["Tidy bags"],
		L["Click to tidy bags."]
	}, "ANCHOR_TOPLEFT", 0, 8)
	container:AddHeaderWidget(button, 0)

	self.container = container
	self.button = button
end

function bagProto:ShowButton()
	if self.button then
		self.button:Show()
	end
end

function bagProto:HideButton()
	if self.button then
		self.button:Hide()
	end
end

function bagProto:UpdateButton(event)
	if self.button then
		--@debug@
		self:Debug('UpdateButton on', event, self.running and "(running)" or "", 'GetNextMove:', self:GetNextMove())
		--@end-debug@
		if not self.running and self:GetNextMove() then
			self.button:Enable()
		else
			self.button:Disable()
		end
	end
end

function bagProto:IsAvailable()
	return self.obj:CanOpen()
end

function bagProto:Tidy()
	if not self.running and self:IsAvailable() then
		self.running = true
		self:UpdateButton("Tidy")
		return self:Process()
	end
end

function bagProto:GetNextMove()
	if not self.cached then
		self.cached, self[1], self[2], self[3], self[4] = true, self:FindNextMove()
	end
	return unpack(self, 1, 4)
end

function bagProto:PickupItem(bag, slot, expectedCursorInfo)
	PickupContainerItem(bag, slot)
	if GetCursorInfo() == expectedCursorInfo then
		if addon:SetGlobalLock(true) then
			self:Debug('Locked all items')
		end
		if not self.locked[bag] then
			self:Debug('Bag', bag, 'locked, waiting for update')
			self.locked[bag] = true
		end
		return true
	end
end

function bagProto:ProcessInternal()
	self:Debug('Processing')
	if not GetCursorInfo() then
		local fromBag, fromSlot, toBag, toSlot = self:GetNextMove()
		if fromBag then
			self:Debug('Trying to move from', fromBag, fromSlot, 'to', toBag, toSlot)
			if self:PickupItem(fromBag, fromSlot, "item") then
				if self:PickupItem(toBag, toSlot, nil) then
					self:Debug('Moved', fromBag, fromSlot, 'to', toBag, toSlot)
					return
				end
			end
			self:Debug('Something failed !')
			ClearCursor()
		end
	end
	if addon:SetGlobalLock(false) then
		self:Debug('Unlocked all items')
	end
	self.running = nil
	self:UpdateButton("ProcessInternal")
	self:Debug("Done")
end

function bagProto:Process()
	if self.running and not self.processing then
		self.processing = true
		self:ProcessInternal()
		self.processing = nil
	end
end

-- Tidying logic

local CanPutItemInContainer = addon.CanPutItemInContainer
local GetItemFamily = addon.GetItemFamily
local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId

-- Memoization tables
local itemMaxStackMemo = setmetatable({}, {__index = function(t, id)
	if not id then return end
	local count = select(8, GetItemInfo(id)) or false
	t[id] = count
	return count
end})
local itemFamilyMemo = setmetatable({}, {__index = function(t, id)
if not id then return end
	local family = GetItemFamily(id) or false
	t[id] = family
	return family
end})

local incompleteStacks = {}
local bagList = {}
local freeSlots = {}
local profBags = {}
function bagProto:FindNextMove()
	if InCombatLockdown() then return end

	wipe(bagList)
	for bag in pairs(self.bagIds) do
		local size = GetContainerNumSlots(bag)
		if size > 0 then
			tinsert(bagList, bag)
		end
	end
	tsort(bagList)
	self:Debug('FindNextMove in bags', unpack(bagList))

	-- Firstly, merge incomplete stacks
	wipe(incompleteStacks)
	wipe(profBags)
	for i, bag in ipairs(bagList) do
		local numFree, bagFamily = GetContainerNumFreeSlots(bag)
		if numFree > 0 and bagFamily ~= 0 and not profBags[bagFamily] then
			profBags[bagFamily] = bag
		end
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			local maxStack = itemMaxStackMemo[id]
			if maxStack and maxStack > 1 then
				local _, count = GetContainerItemInfo(bag, slot)
				if id and count < maxStack then
					local existingStack = incompleteStacks[id]
					if existingStack then
						local toBag, toSlot = GetBagSlotFromId(existingStack)
						self:Debug('FindNextMove: should merge stacks:', bag, slot, toBag, toSlot)
						if toBag < bag or (toBag == bag and toSlot < slot) then
							return bag, slot, toBag, toSlot
						else
							return toBag, toSlot, bag, slot
						end
					else
						incompleteStacks[id] = GetSlotId(bag, slot)
					end
				end
			end
		end
	end

	-- Then move profession materials into profession bags, if we have some
	if next(profBags) then
		for i, bag in ipairs(bagList) do
			local _, bagFamily = GetContainerNumFreeSlots(bag)
			if bagFamily == 0 then
				for slot = 1, GetContainerNumSlots(bag) do
					local id = GetContainerItemID(bag, slot)
					local itemFamily = itemFamilyMemo[id]
					if itemFamily and itemFamily ~= 0 then
						for family, toBag in pairs(profBags) do
							if band(family, itemFamily) ~= 0 then
								wipe(freeSlots)
								GetContainerFreeSlots(toBag, freeSlots)
								self:Debug("FindNextMove: should move into profession bag:", bag, slot, toBag, freeSlots[1])
								return bag, slot, toBag, freeSlots[1]
							end
						end
					end
				end
			end
		end
	end

	self:Debug('FindNextMove: nothing to do')
end
