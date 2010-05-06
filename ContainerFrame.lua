--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local GetSlotId = addon.GetSlotId 
local GetBagSlotFromId = addon.GetBagSlotFromId

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local SECTION_SPACING = addon. SECTION_SPACING
local BAG_WIDTH = addon.BAG_WIDTH
local BAG_INSET = addon.BAG_INSET
local TOP_PADDING = addon.TOP_PADDING

--------------------------------------------------------------------------------
-- Widget scripts
--------------------------------------------------------------------------------

local function CloseButton_OnClick(button)
	button:GetParent():Hide()
end

local function BagSlotButton_OnClick(button)
	if button:GetChecked() then
		button.panel:Show()
	else
		button.panel:Hide()
	end
end

local function BagSlotButton_OnEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT", -8, 0)
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Equipped bags", 1, 1, 1)
	GameTooltip:AddLine("Click to show/hide the equipped bags so you can change them.")
	GameTooltip:Show()
end

local function BagSlotButton_OnLeave(button)
	if GameTooltip:GetOwner() == button then
		GameTooltip:Hide()
	end
end

--------------------------------------------------------------------------------
-- Bag creation
--------------------------------------------------------------------------------

local containerClass, containerProto = addon:NewClass("Container", "Frame", "AceEvent-3.0", "AceBucket-3.0")

function addon:CreateContainerFrame(...) return containerClass:Create(...) end

local bagSlots = {}
function containerProto:OnCreate(name, bags, isBank)
	self:SetParent(UIParent)
	self:EnableMouse(true)
	self:SetScale(0.8)
	self:SetFrameStrata("HIGH")

	self:SetBackdrop(addon.BACKDROP)
	self:SetBackdropColor(unpack(addon.BACKDROPCOLOR[isBank and "bank" or "backpack"]))
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)

	self.name = name
	self.bags = bags
	self.isBank = isBank
	self.buttons = {}
	self.content = {}
	self.stacks = {}
	self.sections = {}

	self.noNew = true
	self.itemCounts = {}
	self.newItems = {}
	
	self.added = {}
	self.removed = {}

	for bag in pairs(self.bags) do
		self.content[bag] = { size = 0 }
		tinsert(bagSlots, bag)
	end
	
	local bagSlotPanel = addon:CreateBagSlotPanel(self, name, bagSlots, isBank)
	bagSlotPanel:Hide()
	wipe(bagSlots)

	local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	self.closeButton = closeButton
	closeButton:SetPoint("TOPRIGHT")
	closeButton:SetScript('OnClick', CloseButton_OnClick)

	local bagSlotButton = CreateFrame("CheckButton", nil, self)
	bagSlotButton:SetNormalTexture([[Interface\Buttons\Button-Backpack-Up]])
	bagSlotButton:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	bagSlotButton:GetCheckedTexture():SetBlendMode("ADD")
	bagSlotButton:SetScript('OnClick', BagSlotButton_OnClick)
	bagSlotButton:SetScript('OnEnter', BagSlotButton_OnEnter)
	bagSlotButton:SetScript('OnLeave', BagSlotButton_OnLeave)
	bagSlotButton.panel = bagSlotPanel
	bagSlotButton:SetWidth(18)
	bagSlotButton:SetHeight(18)
	bagSlotButton:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)

	local title = self:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
	title:SetText(L[name])
	title:SetTextColor(1, 1, 1)
	title:SetHeight(18)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", bagSlotButton, "TOPRIGHT", 4, 0)
	title:SetPoint("RIGHT", closeButton, "LEFT", -4, 0)
end

function containerProto:ToString() return self.name or self:GetName() end

--------------------------------------------------------------------------------
-- Scripts & event handlers
--------------------------------------------------------------------------------

function containerProto:RegisterUpdateEvents()
	self.bagUpdateBucket = self:RegisterBucketMessage('AdiBags_BagUpdated', 0.2, "BagsUpdated")
	self:RegisterMessage('AdiBags_UpdateAllBags', 'UpdateAllContent')
	self:UpdateAllContent()
end

function containerProto:UnregisterUpdateEvents()
	if self.bagUpdateBucket then
		self:UnregisterBucket(self.bagUpdateBucket)
		self.bagUpdateBucket = nil
	end
end

function containerProto:BagsUpdated(bags)
	for bag in pairs(bags) do
		if self.bags[bag] then
			self:UpdateContent(bag)
		end
	end
	if self:HasContentChanged() and self:Update() then
		return
	end
	for i, button in pairs(self.buttons) do
		if bags[button.bag] then
			button:FullUpdate()
		end
	end
end

function containerProto:OnShow()
	if self.isBank then
		self:RegisterEvent('BANKFRAME_CLOSED', "Hide")
	end
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING', "UnregisterUpdateEvents")
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED', "RegisterUpdateEvents")
	self:RegisterUpdateEvents("OnShow")
end

function containerProto:OnHide()
	self.bagUpdateBucket = nil
	self:UnregisterAllEvents()
	self:UnregisterAllBuckets()
end

--------------------------------------------------------------------------------
-- Bag content scanning
--------------------------------------------------------------------------------

local seen = {}
function containerProto:UpdateContent(bag)
	self:Debug('UpdateContent', bag)
	local added, removed = self.added, self.removed
	local content = self.content[bag]
	local newSize = GetContainerNumSlots(bag)
	content.family = select(2, GetContainerNumFreeSlots(bag))
	for slot = 1, newSize do
		local oldItem, newItem = content[slot], (GetContainerItemLink(bag, slot) or false)
		if oldItem ~= newItem then
			content[slot] = newItem
			local slotId = GetSlotId(bag, slot)
			added[slotId] = newItem
			removed[slotId] = oldItem
		end
		if newItem and not seen[newItem] then
			seen[newItem] = true
			self:UpdateNewItem(newItem)
		end
		if oldItem and not seen[oldItem] then
			seen[oldItem] = true
			self:UpdateNewItem(oldItem)
		end
	end
	wipe(seen)
	for slot = content.size, newSize + 1, -1 do
		removed[GetSlotId(bag, slot)] = content[slot]
		content[slot] = nil
	end
	content.size = newSize
end

function containerProto:UpdateAllContent()
	self:Debug('UpdateAllContent')
	for bag in pairs(self.bags) do
		self:UpdateContent(bag)
	end
	self:Update(true)
end

function containerProto:HasContentChanged()
	return not not (next(self.added) or next(self.removed))
end

--------------------------------------------------------------------------------
-- New items feature
--------------------------------------------------------------------------------

function containerProto:UpdateNewItem(link)
	if not link then return end
	local id = tonumber(link:match('item:(%d+)'))
	local count
	if self.isBank then
		count = GetItemCount(id, true) - GetItemCount(id)
	else
		count = GetItemCount(id)
	end
	local oldCount = self.itemCounts[id] or 0
	self.itemCounts[id] = count
	if not self.noNew and count > oldCount then
		self:Debug(GetItemInfo(id), oldCount, '=>', count)
		self.newItems[id] = (oldCount == 0) and "New" or "+++"
		self.hasNew = true
	end
end

function containerProto:IsNewItem(linkOrId)
	local id = tonumber(linkOrId) or tonumber(linkOrId:match('item:(%d+)'))
	if id then
		return self.newItems[id]
	end
end

function containerProto:ResetNewItems()
	self.hasNew = nil
	self.noNew = true
	wipe(self.itemCounts)
	wipe(self.newItems)
end

function containerProto:UpdateNewButtons()
	if self.hasNew then
		self:Debug('UpdateNewButtons')
		for _, button in pairs(self.buttons) do
			button:UpdateNew()
		end
		self.hasNew = nil
	end
	self.noNew = nil
end

--------------------------------------------------------------------------------
-- Item dispatching
--------------------------------------------------------------------------------

function containerProto:GetStackButton(key)
	local stack = self.stacks[key]
	if not stack then
		stack = addon:AcquireStackButton(self, key)
		self.stacks[key] = stack
	end
	return stack
end

function containerProto:GetSection(name)
	local section = self.sections[name]
	if not section then
		section = addon:AcquireSection(self, name)
		self.sections[name] = section
	end
	return section
end

function containerProto:DispatchItem(slotId, link)
	local filter, sectionName, stack
	local bag, slot = GetBagSlotFromId(slotId)
	local itemId = 0
	if link then
		itemId = tonumber(link:match('item:(%d+)'))
		filter, sectionName, stack = addon:Filter(bag, slot, itemId, link)
	else
		filter, sectionName, stack = "Free", L["Free space"], true
	end
	local button = self.buttons[slotId]
	if stack then
		local key = strjoin(':', tostringall(itemId, self.content[bag].family))
		button = self:GetStackButton(key)
		button:AddSlot(slotId)
	elseif not button then
		button = addon:AcquireItemButton(self, bag, slot)
	end
	local section = self:GetSection(sectionName)
	section:AddItemButton(slotId, button)
	self.buttons[slotId] = button
end

function containerProto:RemoveSlot(slotId)
	local button = self.buttons[slotId]
	if button then
		self.buttons[slotId] = nil
		if button:IsStack() then
			button:RemoveSlot(slotId)
			if button:IsEmpty() then
				self:Debug('Removing empty stack', button)
				self.stacks[button:GetKey()] = nil
				button:Release()
			end
		else
			self:Debug('Removing item', button)
			button:Release()
		end
	end
end

function containerProto:Update(forceLayout)
	local dirtyLayout = forceLayout	

	if self:HasContentChanged() then
		self:Debug('Content changed')
		
		local added, removed = self.added, self.removed
		
		local n
		if next(removed) then
			n = 0
			for slotId, link in pairs(removed) do
				self:RemoveSlot(slotId)
				n = n + 1
			end	
			self:Debug('Removed', n, 'items')
			wipe(removed)
		end

		if next(added) then
			addon:SendMessage('AgiBags_PreFilter', self)
			n = 0
			for slotId, link in pairs(added) do
				self:DispatchItem(slotId, link)
				n = n + 1
			end
			self:Debug('Added', n, 'items')
			wipe(added)
			addon:SendMessage('AgiBags_PostFilter', self)
		end

		for name, section in pairs(self.sections) do
			if section:DispatchDone() then
				dirtyLayout = true
			end
		end
	end
	
	self:UpdateNewButtons()

	if dirtyLayout then
		self:Debug('Update: dirty layout')
		self:Layout(forceLayout)
		return true
	end
end

--------------------------------------------------------------------------------
-- Section layout
--------------------------------------------------------------------------------

local function CompareSections(a, b)
	local numA, numB = a.count, b.count
	if numA == numB then
		return a.name < b.name
	else
		return numA > numB
	end
end

local function GetBestSection(sections, remainingWidth)
	local bestIndex, leastWasted
	for index, section in ipairs(sections) do
		local wasted = remainingWidth - section:GetWidth()
		if wasted >= 0 and (not leastWasted or wasted < leastWasted) then
			bestIndex, leastWasted = index, wasted
		end
	end
	if bestIndex then
		return tremove(sections, bestIndex)
	end
end

local orderedSections = {}
function containerProto:Layout(forceLayout)
	self:Debug('Layout required')
	
	for name, section in pairs(self.sections) do
		if section:LayoutButtons(forceLayout) then
			tinsert(orderedSections, section)
		else
			section:Release()
			self.sections[name] = nil
		end
	end

	table.sort(orderedSections, CompareSections)

	local bagWidth = ITEM_SIZE * BAG_WIDTH + ITEM_SPACING * (BAG_WIDTH - 1)
	local y, realWidth = 0, 0

	while next(orderedSections) do
		local rowHeight, x = 0, 0
		local section = tremove(orderedSections, 1)
		while section do
			section:SetPoint('TOPLEFT', BAG_INSET + x, - TOP_PADDING - y)
			section:Show()
			
			local sectionWidth = section:GetWidth()
			realWidth = math.max(realWidth, x + sectionWidth)
			rowHeight = math.max(rowHeight, section:GetHeight())
			
			x = x + sectionWidth + SECTION_SPACING
			
			section = GetBestSection(orderedSections, bagWidth - x)
		end
		y = y + rowHeight + ITEM_SPACING
	end

	self:SetWidth(BAG_INSET * 2 + realWidth)
	self:SetHeight(BAG_INSET + TOP_PADDING + y - ITEM_SPACING)
end
