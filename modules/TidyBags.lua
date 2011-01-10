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
	self:RegisterMessage('AdiBags_ContainerLayoutDirty')
	self:RegisterMessage('AdiBags_InteractingWindowChanged')
	self:RegisterEvent('BAG_UPDATE')
	self:RegisterEvent('PLAYER_REGEN_DISABLED', 'RefreshAllBags')
	self:RegisterEvent('PLAYER_REGEN_ENABLED')
	self:RegisterEvent('LOOT_CLOSED', 'AutomaticTidy')
	for container in pairs(containers) do
		container[self].button:Show()
		self:UpdateButton('OnEnable', container)
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

function mod:AdiBags_InteractingWindowChanged(event, new)
	if not new then
		return self:AutomaticTidy(event)
	end
end

function mod:AutomaticTidy(event)
	if not self.db.profile.autoTidy or InCombatLockdown() then return end
	self:Debug('AutomaticTidy on', event)
	for container in pairs(containers) do
		local data = container[self]
		if not data.running and data.bag:CanOpen() then
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
		button = button,
		bag = bag,
		locked = {}
	}

	containers[container] = true
end

local bor = bit.bor
local band = bit.band
local GetItemFamily = GetItemFamily
local GetContainerFreeSlots = GetContainerFreeSlots
local GetContainerItemInfo = GetContainerItemInfo
local CanPutItemInContainer = addon.CanPutItemInContainer
local GetItemFamily = addon.GetItemFamily

local incompleteStacks = {}
local bagList = {}
local freeSlots = {}
function mod:FindNextMove(container)
	if InCombatLockdown() then return end
	self:Debug('FindNextMove', container)
	wipe(incompleteStacks)
	wipe(bagList)

	local availableFamilies = 0
	for bag in pairs(container.bagIds) do
		local size, _, family = GetContainerNumSlots(bag), GetContainerNumFreeSlots(bag)
		if size > 0 and family then
			tinsert(bagList, bag)
			availableFamilies = bor(availableFamilies, family)
		end
	end
	table.sort(bagList)
	self:Debug('FindNextMove, bags:', unpack(bagList))

	for i, bag in ipairs(bagList) do
		local _, bagFamily = GetContainerNumFreeSlots(bag)
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			local _, count, locked, _, _, _, link = GetContainerItemInfo(bag, slot)
			if id and link and not locked then
				count = count or 1

				-- Merge incomplete stacks
				if count < (select(8, GetItemInfo(id)) or 1) then
					local existingStack = incompleteStacks[id]
					if existingStack then
						local existingCount, toBag, toSlot = strsplit(':', existingStack)
						-- Another incomplete stack exists for this item, try to merge both
						if count < tonumber(existingCount) then
							return bag, slot, tonumber(toBag), tonumber(toSlot)
						else
							return tonumber(toBag), tonumber(toSlot), bag, slot
						end
					else
						-- First incomplete stack of this item
						incompleteStacks[id] = strjoin(':', tostringall(count, bag, slot))
					end
				end

				-- Move items into appropriate profession bags
				local itemFamily = GetItemFamily(link) or 0
				if band(itemFamily, availableFamilies) ~= 0 and bagFamily == 0 then
					for j, toBag in ipairs(bagList) do
						if CanPutItemInContainer(id, toBag) then
							wipe(freeSlots)
							GetContainerFreeSlots(toBag, freeSlots)
							return bag, slot, toBag, freeSlots[1]
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
		data.cached, data[1], data[2], data[3], data[4] = true, self:FindNextMove(container)
	end
	return unpack(data, 1, 4)
end

function mod:PickupItem(container, bag, slot, expectedCursorInfo)
	PickupContainerItem(bag, slot)
	if GetCursorInfo() == expectedCursorInfo then
		if addon:SetGlobalLock(true) then
			self:Debug('Locked all items')
		end
		if not container[self].locked[bag] then
			self:Debug('Bag', bag, 'locked, waiting for update')
			container[self].locked[bag] = true
		end
		return true
	end
end

function mod:Process(container)
	local phase = container[self].running
	container[self].running = nil
	self:Debug('Processing', container, phase)
	if phase == 1 then
		if not GetCursorInfo() then
			local fromBag, fromSlot, toBag, toSlot = self:GetNextMove(container)
			if fromBag then
				self:Debug('Trying to move from', fromBag, fromSlot, 'to', toBag, toSlot)
				if self:PickupItem(container, fromBag, fromSlot, "item") then
					if self:PickupItem(container, toBag, toSlot, nil) then
						self:Debug('Moved', fromBag, fromSlot, 'to', toBag, toSlot)
						container[self].running = 1
						return
					else
						self:Debug('Something failed !')
						ClearCursor()
					end
				end
			end
		end
		container[self].running = 2
		addon:SetGlobalLock(false)
	end
	if container.dirtyLayout then
		self:Debug('Cleaning up layout')
		container:LayoutSections(0)
		container[self].running = 2
	else
		self:Debug('Done')
	end
end

function mod:BAG_UPDATE(event, bag)
	for container in pairs(containers) do
		if container.bagIds[bag] then
			local data = container[self]
			data.cached = nil
			if data.locked[bag] then
				self:Debug('Bag', bag, 'unlocked')
				data.locked[bag] = nil
				if data.running and not next(data.locked) then
					self:Debug('All bags unlocked for', container)
					return self:Process(container)
				end
			end
			self:UpdateButton('BAG_UPDATE', container)
		end
	end
end

function mod:UpdateButton(event, container)
	local data = container[self]
	self:Debug('UpdateButton on ', event, 'for', container, ': running=', data.running, ' dirtyLayout=', container.dirtyLayout, '|', self:GetNextMove(container))
	if not data.running and (container.dirtyLayout or self:GetNextMove(container)) then
		data.button:Enable()
	else
		data.button:Disable()
	end
end

function mod:Start(container)
	local data = container[self]
	if not data.running then
		data.running = 1
		data.button:Disable()
		self:Debug('Starting', container)
	end
	return self:Process(container)
end

function mod:AdiBags_ContainerLayoutDirty(event, container)
	if (container[self].running or 0) > 1 then
		self:Process(container)
	end
	self:UpdateButton(event, container)
end

function mod:RefreshAllBags(event)
	for container in pairs(containers) do
		container[self].cached = nil
		self:UpdateButton(event, container)
	end
end

function mod:PLAYER_REGEN_ENABLED(event)
	self:RefreshAllBags(event)
	self:AutomaticTidy()
end

