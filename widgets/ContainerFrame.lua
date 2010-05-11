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

--------------------------------------------------------------------------------
-- Bag creation
--------------------------------------------------------------------------------

local containerClass, containerProto = addon:NewClass("Container", "Frame", "AceEvent-3.0", "AceBucket-3.0")

function addon:CreateContainerFrame(...) return containerClass:Create(...) end

local bagSlots = {}
function containerProto:OnCreate(name, bagIds, isBank, anchor)
	self:SetParent(anchor)
	self:EnableMouse(true)
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

	self.headerWidgets = {}

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
	addon.SetupTooltip(closeButton, L["Close"])

	local bagSlotButton = CreateFrame("CheckButton", nil, self)
	bagSlotButton:SetNormalTexture([[Interface\Buttons\Button-Backpack-Up]])
	bagSlotButton:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	bagSlotButton:GetCheckedTexture():SetBlendMode("ADD")
	bagSlotButton:SetScript('OnClick', BagSlotButton_OnClick)
	bagSlotButton.panel = bagSlotPanel
	bagSlotButton:SetWidth(18)
	bagSlotButton:SetHeight(18)
	bagSlotButton:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)
	addon.SetupTooltip(bagSlotButton, {
		L["Equipped bags"],
		L["Click to toggle the equipped bag panel, so you can change them."]
	}, "ANCHOR_BOTTOMLEFT", -8, 0)

	local title = self:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge")
	self.Title = title
	title:SetText(L[name])
	title:SetTextColor(1, 1, 1)
	title:SetHeight(18)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", bagSlotButton, "TOPRIGHT", 4, 0)
	title:SetPoint("RIGHT", -36, 0)
end

function containerProto:ToString() return self.name or self:GetName() end

--------------------------------------------------------------------------------
-- Scripts & event handlers
--------------------------------------------------------------------------------

function containerProto:RegisterUpdateEvents()
	self.bagUpdateBucket = self:RegisterBucketMessage('AdiBags_BagUpdated', 0.2, "BagsUpdated")
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
	if addon.holdYourBreath then return end
	self:Debug('FiltersChanged')
	return self:UpdateAllContent(true)
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
	self:Debug('UpdateAllButtons')
	for _, button in pairs(self.buttons) do
		button:FullUpdate()
	end
end

function containerProto:UpdateAllContent(forceUpdate)
	self:Debug('UpdateAllContent')
	for bag in pairs(self.bagIds) do
		self:UpdateContent(bag, forceUpdate)
	end
	self:UpdateButtons()
	self:LayoutSections(true)
end

--------------------------------------------------------------------------------
-- Bag header layout
--------------------------------------------------------------------------------

local function HeaderWidget_VisibilityChanged(widget)
	local isShown = not not widget:IsShown()
	if isShown ~= widget._isShown then
		widget._isShown = isShown
		widget._container:LayoutHeaderWidgets()
	end
end

function containerProto:AddHeaderWidget(widget, order, width, yOffset)
	widget._container = self
	widget._order = order or 0
	widget._width = width
	widget._yOffset = yOffset or 0
	widget:HookScript('OnShow', HeaderWidget_VisibilityChanged)
	widget:HookScript('OnHide', HeaderWidget_VisibilityChanged)
	tinsert(self.headerWidgets, widget)
	HeaderWidget_VisibilityChanged(widget)
end

local function CompareHeaderWidgets(a, b)
	return a._order > b._order
end

function containerProto:LayoutHeaderWidgets()
	table.sort(self.headerWidgets, CompareHeaderWidgets)
	local x = 32
	for i, widget in ipairs(self.headerWidgets) do
		if widget._isShown then
			widget:ClearAllPoints()
			widget:SetPoint("TOPRIGHT", self, "TOPRIGHT", -x, -5 + widget._yOffset)
			x = x + (widget._width or widget:GetWidth()) + 4
		end
	end
	self.Title:SetPoint("RIGHT", -x, 0)
end

--------------------------------------------------------------------------------
-- Bag content scanning
--------------------------------------------------------------------------------

function containerProto:UpdateContent(bag, forceUpdate)
	self:Debug('UpdateContent', bag, forceUpdate)
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
		if slotData.link ~= link or forceUpdate then
			removed[slotData.slotId] = slotData.link
			slotData.count = count
			slotData.link = link
			slotData.itemId = link and tonumber(link:match("item:(%d+)"))
			slotData.name, _, slotData.quality, slotData.iLevel, slotData.reqLevel, slotData.class, slotData.subclass, slotData.maxStack, slotData.equipSlot, slotData.texture, slotData.vendorPrice = GetItemInfo(link or "")
			added[slotData.slotId] = slotData
		elseif slotData.count ~= count then
			slotData.count = count
			changed[slotData.slotId] = link
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
	local filter, sectionName
	local bag, slotId, slot, link, itemId = slotData.bag, slotData.slotId, slotData.slot, slotData.link, slotData.itemId
	if link then
		filter, sectionName = addon:Filter(slotData)
	else
		filter, sectionName = "Free", L["Free space"]
	end
	local button = self.buttons[slotId]
	if addon:ShouldStack(slotData) then
		local key = strjoin(':', tostringall(itemId, slotData.bagFamily))
		button = self:GetStackButton(key)
		button:AddSlot(slotId)
	elseif not button then
		button = addon:AcquireItemButton(self, bag, slot)
	end
	local section = self:GetSection(sectionName or L['Miscellaneous'])
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
	local dirtyButtons = self.dirtyButtons
	self:SendMessage('AdiBags_PreContentUpdate', self, added, removed, changed)

	--@debug@
	local numAdded, numRemoved, numChanged = 0, 0, 0
	--@end-debug@

	for slotId in pairs(removed) do
		self:RemoveSlot(slotId)
		--@debug@
		numRemoved = numRemoved + 1
		--@end-debug@
	end

	if next(added) then
		self:SendMessage('AgiBags_PreFilter', self)
		for slotId, slotData in pairs(added) do
			self:DispatchItem(slotData)
			--@debug@
			numAdded = numAdded + 1
			--@end-debug@
		end
		self:SendMessage('AgiBags_PostFilter', self)
	end

	-- Just push the buttons into dirtyButtons
	local buttons = self.buttons
	for slotId in pairs(changed) do
		dirtyButtons[buttons[slotId]] = true
		--@debug@
		numChanged = numChanged + 1
		--@end-debug@
	end

	self:SendMessage('AdiBags_PostContentUpdate', self, added, removed, changed)

	--@debug@
	self:Debug(numRemoved, 'slot(s) removed', numAdded, 'slot(s) added and', numChanged, 'slot(s) changed')
	--@end-debug@

	wipe(added)
	wipe(removed)
	wipe(changed)

	for name, section in pairs(self.sections) do
		if section:DispatchDone() then
			dirtyLayout = true
		end
	end

	self.inUpdate = nil
	
	if next(dirtyButtons) then
		--@debug@
		local numButtons = 0
		--@end-debug@
		for button in pairs(dirtyButtons) do
			button:FullUpdate()
			--@debug@
			numButtons = numButtons + 1
			--@end-debug@
		end
		--@debug@
		self:Debug(numButtons, 'late button update(s)')
		--@end-debug@
		wipe(dirtyButtons)
	end

	return dirtyLayout
end

--------------------------------------------------------------------------------
-- Section layout
--------------------------------------------------------------------------------

local function CompareSections(a, b)
	if a.order == b.order then
		if a.total == b.total then
			return a.name < b.name
		else
			return b.total < a.total
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
	self:Debug('LayoutSections', forceLayout)

	for name, section in pairs(self.sections) do
		if section:LayoutButtons(forceLayout) then
			tinsert(orderedSections, section)
		else
			section:Release()
			self.sections[name] = nil
		end
	end

	table.sort(orderedSections, CompareSections)
	
	local BAG_WIDTH = addon.db.profile.columns
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
