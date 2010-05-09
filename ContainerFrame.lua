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
	GameTooltip:AddLine(L["Equipped bags"], 1, 1, 1)
	GameTooltip:AddLine(L["Click to show/hide the equipped bagIds so you can change them."])
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
function containerProto:OnCreate(name, bagIds, isBank, anchor)
	self:SetParent(anchor)
	self:EnableMouse(true)
	self:SetScale(0.8)
	self:SetFrameStrata("HIGH")

	self:SetBackdrop(addon.BACKDROP)
	self:SetBackdropColor(unpack(addon.BACKDROPCOLOR[isBank and "bank" or "backpack"]))
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)

	self.name = name
	self.bagIds = bagIds
	self.isBank = isBank

	self.buttons = {}
	self.dirtyButtons = {}
	self.content = {}
	self.stacks = {}
	self.sections = {}

	self.added = {}
	self.removed = {}
	self.changed = {}

	for bagId in pairs(self.bagIds) do
		self.content[bagId] = { size = 0 }
		tinsert(bagSlots, bagId)
		if not addon.itemParentFrames[bagId] then
			local f = CreateFrame("Frame", addonName..'ItemContainer'..bagId, self)
			f.isBank = isBank
			f:SetID(bagId)
			addon.itemParentFrames[bagId] = f
		end
	end

	local bagSlotPanel = addon:CreateBagSlotPanel(self, name, bagSlots, isBank)
	bagSlotPanel:Hide()
	wipe(bagSlots)

	local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	self.CloseButton = closeButton
	closeButton:SetPoint("TOPRIGHT")

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
	self.Title = title
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
	self:RegisterMessage('AdiBags_FiltersChanged', 'FiltersChanged')
	self:RegisterMessage('AdiBags_UpdateAllButtons', 'UpdateAllButtons')
	self:UpdateAllContent()
end

function containerProto:UnregisterUpdateEvents()
	if self.bagUpdateBucket then
		self:UnregisterBucket(self.bagUpdateBucket)
		self.bagUpdateBucket = nil
	end
end

function containerProto:BagsUpdated(bagIds)
	for bag in pairs(bagIds) do
		if self.bagIds[bag] then
			self:UpdateContent(bag)
		end
	end
	if self:UpdateButtons() then
		self:LayoutSections()
	end
end

function containerProto:FiltersChanged()
	for bag, content in pairs(self.content) do
		for slotId, slotData in ipairs(content) do
			slotData.link = nil
		end
	end
	return self:UpdateAllContent()
end

function containerProto:OnShow()
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING', "UnregisterUpdateEvents")
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED', "RegisterUpdateEvents")
	self:RegisterUpdateEvents()
end

function containerProto:OnHide()
	self.bagUpdateBucket = nil
	self:UnregisterAllEvents()
	self:UnregisterAllBuckets()
end

function containerProto:UpdateAllButtons(event)
	for _, button in pairs(self.buttons) do
		button:FullUpdate()
	end
end

function containerProto:UpdateAllContent()
	self:Debug('UpdateAllContent')
	for bag in pairs(self.bagIds) do
		self:UpdateContent(bag)
	end
	self:UpdateButtons()
	self:LayoutSections(true)
end

--------------------------------------------------------------------------------
-- Bag content scanning
--------------------------------------------------------------------------------

function containerProto:UpdateContent(bag)
	self:Debug('UpdateContent', bag)
	local added, removed, changed = self.added, self.removed, self.changed
	local content = self.content[bag]
	local newSize = GetContainerNumSlots(bag)
	local _, bagFamily = GetContainerNumFreeSlots(bag)
	content.family = bagFamily
	for slot = 1, newSize do
		local slotData = content[slot]
		if not slotData then
			slotData = {
				bag = bag,
				slot = slot,
				slotId = GetSlotId(bag, slot),
				bagFamily = bagFamily,
				count = 0,
				isBank = self.isBank,
			}
			content[slot] = slotData
		end
		local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
		link = link or false
		count = count or 0
		if slotData.count ~= count or slotData.link ~= link then
			if slotData.link ~= link then
				removed[slotData.slotId] = slotData.link
				slotData.link = link
				slotData.itemId = link and tonumber(link:match("item:(%d+)"))
				slotData.name, _, slotData.quality, slotData.iLevel, slotData.reqLevel, slotData.class, slotData.subclass, slotData.maxStack, slotData.equipSlot, slotData.texture, slotData.vendorPrice = GetItemInfo(link or "")
				added[slotData.slotId] = slotData
			else
				changed[slotData.slotId] = link
			end
			slotData.count = count
		end
	end
	for slot = content.size, newSize + 1, -1 do
		local slotData = content[slot]
		if slotData then
			removed[slotData.slotId] = slotData.link
			content[slot] = nil
		end
	end
	content.size = newSize
end

function containerProto:HasContentChanged()
	return not not (next(self.added) or next(self.removed) or next(self.changed))
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

function containerProto:DispatchItem(slotData)
	local filter, sectionName, stack
	local bag, slotId, slot, link, itemId = slotData.bag, slotData.slotId, slotData.slot, slotData.link, slotData.itemId
	if link then
		filter, sectionName, stack = addon:Filter(slotData)
	else
		filter, sectionName, stack = "Free", L["Free space"], true
	end
	local button = self.buttons[slotId]
	if stack then
		local key = strjoin(':', tostringall(itemId, slotData.bagFamily))
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

function containerProto:UpdateButtons()
	if not self:HasContentChanged() then return end
	self:Debug('UpdateButtons')
	self.inUpdate = true

	local added, removed, changed = self.added, self.removed, self.changed
	self:SendMessage('AdiBags_PreContentUpdate', self, added, removed, changed)

	for slotId in pairs(removed) do
		self:RemoveSlot(slotId)
	end

	if next(added) then
		self:SendMessage('AgiBags_PreFilter', self)
		for slotId, slotData in pairs(added) do
			self:DispatchItem(slotData)
		end
		self:SendMessage('AgiBags_PostFilter', self)
	end

	for slotId in pairs(changed) do
		self.buttons[slotId]:FullUpdate()
	end

	self:SendMessage('AdiBags_PostContentUpdate', self, added, removed, changed)

	wipe(added)
	wipe(removed)
	wipe(changed)

	for name, section in pairs(self.sections) do
		if section:DispatchDone() then
			dirtyLayout = true
		end
	end

	self.inUpdate = nil
	for button in pairs(self.dirtyButtons) do
		button:FullUpdate()
	end
	wipe(self.dirtyButtons)
	
	return dirtyLayout
end

--------------------------------------------------------------------------------
-- Section layout
--------------------------------------------------------------------------------

local function CompareSections(a, b)
	if a.order == b.order then
		if a.count == b.count then
			return a.name < b.name
		else
			return b.count < a.count
		end
	else
		return b.order < a.order
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
function containerProto:LayoutSections(forceLayout)
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
