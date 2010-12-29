--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId

local mod = addon:NewModule('TidyBags', 'AceEvent-3.0', 'AceBucket-3.0')
mod.uiName = L['Tidy bags']
mod.uiDesc = L['Tidy your bags by clicking on the small "T" button at the top left of bags. Special bags with free slots will be filled with macthing items and stackable items will be stacked to save space.']

local containers = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			autoTidy = false,
		},
	})
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	self:RegisterMessage('AdiBags_PreContentUpdate')
	self:RegisterMessage('AdiBags_ContainerLayoutDirty')
	self:RegisterMessage('AdiBags_InteractingWindowChanged')
	self:RegisterEvent('LOOT_CLOSED', 'AutomaticTidy')
	for container in pairs(containers) do
		container[self].button:Show()
		self:UpdateButton(container)
	end
end

function mod:OnDisable()
	for container in pairs(containers) do
		container[self].button:Hide()
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

function mod:AdiBags_InteractingWindowChanged(_, new)
	if not new then
		return self:AutomaticTidy()
	end
end

function mod:AutomaticTidy()
	if not self.db.profile.autoTidy then return end
	for container in pairs(containers) do
		if not container.isBank then
			mod:Start(container)
		end
	end
end

local function TidyButton_OnClick(button)
	PlaySound("igMainMenuOptionCheckBoxOn")
	mod:Start(button.container)
end

function mod:OnBagFrameCreated(bag)
	local container = bag:GetFrame()

	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.container = container
	button:SetText("T")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", TidyButton_OnClick)
	addon.SetupTooltip(button, {
		L["Tidy bags"],
		L["Click to tidy bags."]
	}, "ANCHOR_TOPLEFT", 0, 8)
	container:AddHeaderWidget(button, 0)

	container[self] = {
		button = button
	}

	containers[container] = true
end

local bor = bit.bor
local band = bit.band
local GetItemFamily = GetItemFamily
local GetContainerFreeSlots = GetContainerFreeSlots
local GetContainerItemInfo = GetContainerItemInfo

local freeSlots = {}
local function FindFreeSlot(container, family)
	for bag, slots in pairs(container.content) do
		if slots.size > 0 and slots.family ~= 0 and band(family, slots.family) ~= 0 then
			GetContainerFreeSlots(bag, freeSlots)
			local slot = freeSlots[1]
			wipe(freeSlots)
			if slot then
				return bag, slot
			end
		end
	end
end

local GetItemFamily = addon.GetItemFamily

local incompleteStacks = {}
local function FindNextMove(container)
	wipe(incompleteStacks)

	local availableFamilies = 0
	for bag, slots in pairs(container.content) do
		if slots.size > 0 and slots.family then
			availableFamilies = bor(availableFamilies, slots.family)
		end
	end

	for bag, slots in pairs(container.content) do
		if slots.size > 0 then
			local bagFamily = slots.family
			for slot, slotData in ipairs(slots) do

				if slotData and slotData.link then
					local itemFamily = GetItemFamily(slotData.itemId) or 0

					if slotData.count < slotData.maxStack then
						-- Incomplete stack
						local existingStack = incompleteStacks[slotData.itemId]
						if existingStack then
							-- Another incomplete stack exists for this item, try to merge both
							if slotData.count < existingStack.count then
								return bag, slot, existingStack.bag, existingStack.slot
							else
								return existingStack.bag, existingStack.slot, bag, slot
							end
						else
							-- First incomplete stack of this item
							incompleteStacks[slotData.itemId] = slotData
						end
					end

					if band(itemFamily, availableFamilies) ~= 0 and bagFamily == 0 then
						-- Not in the right bag, look for a better one
						local toBag, toSlot = FindFreeSlot(container, itemFamily)
						if toBag then
							return bag, slot, toBag, toSlot
						end
					end

				end

			end
		end
	end
end

function mod:GetNextMove(container)
	local data = container[self]
	if not data.cached then
		data.cached, data[1], data[2], data[3], data[4] = true, FindNextMove(container)
	end
	return unpack(data, 1, 4)
end

local PickupItem = PickupContainerItem -- Might require something more sophisticated for bank

function mod:Process(container)
	if not GetCursorInfo() then
		local fromBag, fromSlot, toBag, toSlot = self:GetNextMove(container)
		if fromBag then
			if addon:SetGlobalLock(true) then
				self:Debug('Locked all items')
			end
			PickupItem(fromBag, fromSlot)
			if GetCursorInfo() == "item" then
				PickupItem(toBag, toSlot)
				if not GetCursorInfo() then
					self:Debug('Moved', fromBag, fromSlot, 'to', toBag, toSlot)
					return
				end
			end
		end
	end
	if addon:SetGlobalLock(false) then
		self:Debug('Unlocked all items')
	elseif container.dirtyLayout then
		self:Debug('Cleaning up layout')
		container:LayoutSections(0)
	else
		self:Debug('Done')
		container[self].running = nil
	end
end

function mod:UpdateButton(container)
	local data = container[self]
	self:Debug('UpdateButton', container, '|', container.dirtyLayout, '|', self:GetNextMove(container))
	if not data.running and (container.dirtyLayout or self:GetNextMove(container)) then
		data.button:Enable()
	else
		data.button:Disable()
	end
end

function mod:Start(container)
	local data = container[self]
	data.running = true
	data.button:Disable()
	self:Debug('Starting on', container)
	return self:Process(container)
end

function mod:AdiBags_PreContentUpdate(event, container)
	local data = container[self]
	data.cached = nil
	if data.running then
		self:Process(container)
	else
		self:UpdateButton(container)
	end
end

function mod:AdiBags_ContainerLayoutDirty(event, container)
	local data = container[self]
	if data.running then
		self:Process(container)
	else
		self:UpdateButton(container)
	end
end

