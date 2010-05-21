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
local SECTION_SPACING = addon.SECTION_SPACING
local BAG_INSET = addon.BAG_INSET

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

local containerClass, containerProto, containerParentProto = addon:NewClass("Container", "LayeredRegion", "AceEvent-3.0", "AceBucket-3.0")

function addon:CreateContainerFrame(...) return containerClass:Create(...) end

local SimpleLayeredRegion = addon:GetClass("SimpleLayeredRegion")

local bagSlots = {}
function containerProto:OnCreate(name, bagIds, isBank, anchor)
	containerParentProto.OnCreate(self, anchor)

	--self:EnableMouse(true)
	self:SetFrameStrata("HIGH")

	self:SetBackdrop(addon.BACKDROP)

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

	local button = CreateFrame("Button", nil, self)
	button:SetAllPoints(self)
	button:RegisterForClicks("AnyUp")
	button:SetScript('OnClick', function(_, ...) return self:OnClick(...) end)
	button:SetScript('OnReceiveDrag', function() return self:OnClick("LeftButton") end)
	self.ClickReceiver = button
	local minFrameLevel = button:GetFrameLevel() + 1

	local headerLeftRegion = SimpleLayeredRegion:Create(self, "TOPLEFT", "RIGHT", 4)
	headerLeftRegion:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)
	self.HeaderLeftRegion = headerLeftRegion
	self:AddWidget(headerLeftRegion)
	headerLeftRegion:SetFrameLevel(minFrameLevel)

	local headerRightRegion = SimpleLayeredRegion:Create(self, "TOPRIGHT", "LEFT", 4)
	headerRightRegion:SetPoint("TOPRIGHT", -32, -BAG_INSET)
	self.HeaderRightRegion = headerRightRegion
	self:AddWidget(headerRightRegion)
	headerRightRegion:SetFrameLevel(minFrameLevel)

	local bottomLeftRegion = SimpleLayeredRegion:Create(self, "BOTTOMLEFT", "UP", 4)
	bottomLeftRegion:SetPoint("BOTTOMLEFT", BAG_INSET, BAG_INSET)
	self.BottomLeftRegion = bottomLeftRegion
	self:AddWidget(bottomLeftRegion)
	bottomLeftRegion:SetFrameLevel(minFrameLevel)

	local bottomRightRegion = SimpleLayeredRegion:Create(self, "BOTTOMRIGHT", "UP", 4)
	bottomRightRegion:SetPoint("BOTTOMRIGHT", -BAG_INSET, BAG_INSET)
	self.BottomRightRegion = bottomRightRegion
	self:AddWidget(bottomRightRegion)
	bottomRightRegion:SetFrameLevel(minFrameLevel)

	local bagSlotPanel = addon:CreateBagSlotPanel(self, name, bagSlots, isBank)
	bagSlotPanel:Hide()
	self.BagSlotPanel = bagSlotPanel
	wipe(bagSlots)

	local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	self.CloseButton = closeButton
	closeButton:SetPoint("TOPRIGHT", -2, -2)
	addon.SetupTooltip(closeButton, L["Close"])
	closeButton:SetFrameLevel(minFrameLevel)

	local bagSlotButton = CreateFrame("CheckButton", nil, self)
	bagSlotButton:SetNormalTexture([[Interface\Buttons\Button-Backpack-Up]])
	bagSlotButton:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	bagSlotButton:GetCheckedTexture():SetBlendMode("ADD")
	bagSlotButton:SetScript('OnClick', BagSlotButton_OnClick)
	bagSlotButton.panel = bagSlotPanel
	bagSlotButton:SetWidth(18)
	bagSlotButton:SetHeight(18)
	addon.SetupTooltip(bagSlotButton, {
		L["Equipped bags"],
		L["Click to toggle the equipped bag panel, so you can change them."]
	}, "ANCHOR_BOTTOMLEFT", -8, 0)
	headerLeftRegion:AddWidget(bagSlotButton, 50)

	local title = self:CreateFontString(self:GetName().."Title","OVERLAY","GameFontHighlightLarge")
	self.Title = title
	title:SetText(L[name])
	title:SetTextColor(1, 1, 1)
	title:SetHeight(18)
	title:SetJustifyH("LEFT")
	title:SetPoint("LEFT", headerLeftRegion, "RIGHT", 4, 0)
	title:SetPoint("RIGHT", headerRightRegion, "LEFT", -4, 0)

	local content = CreateFrame("Frame", nil, self)
	content:SetPoint("TOPLEFT", BAG_INSET, -addon.TOP_PADDING)
	self.Content = content
	self:AddWidget(content)

	self:UpdateBackgroundColor()
	self:RegisterPersistentListeners()
end

function containerProto:ToString() return self.name or self:GetName() end

--------------------------------------------------------------------------------
-- Scripts & event handlers
--------------------------------------------------------------------------------

function containerProto:RegisterPersistentListeners()
	self:RegisterMessage('AdiBags_FiltersChanged', 'FiltersChanged')
	self:RegisterMessage('AdiBags_LayoutChanged', 'LayoutChanged')
	self:RegisterMessage('AdiBags_ConfigChanged', 'ConfigChanged')
end

function containerProto:RegisterUpdateEvents()
	self.bagUpdateBucket = self:RegisterBucketMessage('AdiBags_BagUpdated', 0.2, "BagsUpdated")
	self:UpdateAllContent(self.postponedUpdate)
	self.postponedUpdate = nil
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
	if addon.holdYourBreath or not self.bagUpdateBucket then
		self:Debug('Postponing FiltersChanged')
		self.postponedUpdate = true
		return
	end
	self:Debug('FiltersChanged')
	return self:UpdateAllContent(true)
end

function containerProto:LayoutChanged()
	return self:LayoutSections(true)
end

function containerProto:ConfigChanged(event, name)
	if name:match('^backgroundColors%.') then
		self:UpdateBackgroundColor()
	end
end

function containerProto:OnShow()
	containerParentProto.OnShow(self)
	PlaySound(self.isBank and "igMainMenuOpen" or "igBackPackOpen")
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING', "UnregisterUpdateEvents")
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED', "RegisterUpdateEvents")
	self:RegisterUpdateEvents()
end

function containerProto:OnHide()
	containerParentProto.OnHide(self)
	PlaySound(self.isBank and "igMainMenuClose" or "igBackPackClose")
	self.bagUpdateBucket = nil
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
	self:UnregisterAllBuckets()
	self:RegisterPersistentListeners()
end

function containerProto:UpdateAllContent(forceUpdate)
	self:Debug('UpdateAllContent', forceUpdate)
	for bag in pairs(self.bagIds) do
		self:UpdateContent(bag, forceUpdate)
	end
	self:UpdateButtons()
	self:LayoutSections(true)
end

--------------------------------------------------------------------------------
-- Backdrop click handler
--------------------------------------------------------------------------------

local band = bit.band
local function FindBagWithRoom(self, itemFamily)
	local fallback
	for bag in pairs(self.bagIds) do
		local numFree, family = GetContainerNumFreeSlots(bag)
		if numFree and numFree > 0 then
			if band(family, itemFamily) ~= 0 then
				return bag
			elseif not fallback then
				fallback = bag
			end
		end
	end
	return fallback
end

local FindFreeSlot
do
	local slots = {}
	FindFreeSlot = function(self, item)
		local bag = FindBagWithRoom(self, GetItemFamily(item))
		if not bag then return end
		wipe(slots)
		GetContainerFreeSlots(bag, slots)
		return GetSlotId(bag, slots[1])
	end
end

function containerProto:OnClick(...)
	local kind, data1, data2 = GetCursorInfo()
	local itemLink
	if kind == "item" then
		itemLink = data2
	elseif kind == "merchant" then
		itemLink = GetMerchantItemLink(data1)
	else
		return
	end
	self:Debug('OnClick', kind, data1, data2, '=>', itemLink)
	if itemLink then
		local slotId = FindFreeSlot(self, itemLink)
		if slotId then
			local button = self.buttons[slotId]
			if button then
				local button = button:GetRealButton()
				self:Debug('Redirecting click to', button)
				return button:GetScript('OnClick')(button, ...)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Regions and global layout
--------------------------------------------------------------------------------

function containerProto:AddHeaderWidget(widget, order, width, yOffset, side)
	local region = (side == "LEFT") and self.HeaderLeftRegion or self.HeaderRightRegion
	region:AddWidget(widget, order, width, 0, yOffset)
end

function containerProto:AddBottomWidget(widget, side, order, height, xOffset, yOffset)
	local region = (side == "RIGHT") and self.BottomRightRegion or self.BottomLeftRegion
	region:AddWidget(widget, order, height, xOffset, yOffset)
end

function containerProto:GetContentMinWidth()
	return math.max(
		(self.BottomLeftRegion:IsShown() and self.BottomLeftRegion:GetWidth() or 0) +
			(self.BottomRightRegion:IsShown() and self.BottomRightRegion:GetWidth() or 0),
		self.Title:GetStringWidth() + 32 + 
			(self.HeaderLeftRegion:IsShown() and (self.HeaderLeftRegion:GetWidth() + 4) or 0) +
			(self.HeaderRightRegion:IsShown() and (self.HeaderRightRegion:GetWidth() + 4) or 0)
	)
end

function containerProto:OnLayout()
	local bottomHeight = 0
	if self.BottomLeftRegion:IsShown() then
		bottomHeight = self.BottomLeftRegion:GetHeight() + BAG_INSET
	end
	if self.BottomRightRegion:IsShown() then
		bottomHeight = math.max(bottomHeight, self.BottomRightRegion:GetHeight() + BAG_INSET)
	end
	self:SetWidth(BAG_INSET * 2 + math.max(self:GetContentMinWidth(), self.Content:GetWidth()))
	self:SetHeight(addon.TOP_PADDING + BAG_INSET + bottomHeight + self.Content:GetHeight())
end

--------------------------------------------------------------------------------
-- Miscellaneous
--------------------------------------------------------------------------------

function containerProto:UpdateBackgroundColor()
	local r, g, b, a = unpack(addon.db.profile.backgroundColors[self.name], 1, 4)
	self:SetBackdropColor(r, g, b, a)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, a)
	self.BagSlotPanel:SetBackdropColor(r, g, b, a)
	self.BagSlotPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, a)
end

--------------------------------------------------------------------------------
-- Bag content scanning
--------------------------------------------------------------------------------

--[[ Make some global locals to avoid issues with hooking
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetItemInfo = _G.GetItemInfo
--]]

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
		-- Try to catch weird link values (see ticket #2)
		if link ~= nil and type(link) ~= "string" then
			local secure, tainter = issecurevariable("GetContainerItemInfo")
			if tainter then
				print(strjoin("\n",
					"AdiBags: GetContainerItemInfo returned a weird link value where a string is expected.",
					"It seems has been hooked by "..tainter..", please disable this addon to see if it fixes this error.",
					"If it does, please report the bug to the author of "..tainter.."."
				))
				error("GetContainerItemInfo returned a "..type(link).." for the link, where a string is expected. Check your chat window for details.")
			else
				error("GetContainerItemInfo returned a "..type(link).." for the link, where a string is expected. No more information available.")
			end
		end
		link, count = link or false, count or 0

		if slotData.link ~= link or forceUpdate then
			removed[slotData.slotId] = slotData.link
			slotData.count = count
			slotData.link = link
			slotData.itemId = link and tonumber(link:match("item:(%d+)"))
			slotData.name, _, slotData.quality, slotData.iLevel, slotData.reqLevel, slotData.class, slotData.subclass, slotData.maxStack, slotData.equipSlot, slotData.texture, slotData.vendorPrice = GetItemInfo(link or "")
			added[slotData.slotId] = slotData
		elseif slotData.count ~= count then
			slotData.count = count
			changed[slotData.slotId] = slotData
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

function containerProto:GetSection(name, category)
	local key = strjoin('#', name, category)
	local section = self.sections[key]
	if not section then
		section = addon:AcquireSection(self, name, category)
		self.sections[key] = section
	end
	return section
end

local function FilterSlot(slotData)
	if slotData.link then
		local section, category = addon:Filter(slotData, L['Miscellaneous'])
		return section, category, addon:ShouldStack(slotData)
	else
		return L["Free space"], nil, addon:ShouldStack(slotData)
	end
end

function containerProto:DispatchItem(slotData)
	local sectionName, category, shouldStack, stackKey = FilterSlot(slotData)
	local slotId = slotData.slotId
	local button = self.buttons[slotId]
	if shouldStack then
		local fullKey = strjoin('#', stackKey, tostring(slotData.bagFamily))
		button = self:GetStackButton(fullKey)
		button:AddSlot(slotId)
	elseif not button then
		button = addon:AcquireItemButton(self, slotData.bag, slotData.slot)
	end
	local section = self:GetSection(sectionName, category or sectionName)
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
				self.stacks[button:GetKey()] = nil
				button:Release()
			end
		else
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
		self:SendMessage('AdiBags_PreFilter', self)
		for slotId, slotData in pairs(added) do
			self:DispatchItem(slotData)
			--@debug@
			numAdded = numAdded + 1
			--@end-debug@
		end
		self:SendMessage('AdiBags_PostFilter', self)
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
		local buttons = self.buttons
		for button in pairs(dirtyButtons) do
			if button.container == self then -- sanity check
				button:FullUpdate()
			end
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
	local orderA, orderB = a:GetOrder(), b:GetOrder()
	if orderA == orderB then
		if a.category == b.category then
			return a.name < b.name
		else
			return a.category < b.category
		end
	else
		return orderA > orderB
	end
end

local sections = {}
local max, floor = math.max, math.floor

local getNextSection = {
	-- 0: keep section of the same category together and in the right order 
	[0] = function(maxWidth, maxHeight, category)
		if floor(sections[1]:GetWidth()) <= maxWidth and floor(sections[1]:GetHeight()) <= maxHeight then
			return 1 
		end
	end,
	-- 1: keep categories together
	[1] = function(maxWidth, maxHeight, category)
		local bestIndex, leastWasted
		for index, section in ipairs(sections) do
			if category and section.category ~= category then break end
			local w, h = floor(section:GetWidth()), floor(section:GetHeight())
			if w <= maxWidth and h <= maxHeight then
				local wasted = (maxWidth - w) * (maxHeight - h)
				if not leastWasted or wasted < leastWasted then
					bestIndex, leastWasted = index, wasted
				end
			end
		end
		return bestIndex
	end,
	-- 2: do not care about ordering
	[2] = function(maxWidth, maxHeight, category)
		local bestIndex, leastWasted
		for index, section in ipairs(sections) do
			local w, h = floor(section:GetWidth()), floor(section:GetHeight())
			if w <= maxWidth and h <= maxHeight then
				local wasted = (maxWidth - w) * (maxHeight - h)
				if not leastWasted or wasted < leastWasted then
					bestIndex, leastWasted = index, wasted
				end
			end
		end
		return bestIndex
	end
}

local function DoLayoutSections(self, rowWidth, maxHeight)
	if not next(self.sections) then
		return 0, 0, 0, 0
	end
	for name, section in pairs(self.sections) do
		tinsert(sections, section)
	end
	table.sort(sections, CompareSections)

	local content = self.Content
	local getNext = getNextSection[addon.db.profile.laxOrdering]
	
	local wasted = 0
	local contentWidth, contentHeight = 0, 0
	local columnX, numColumns = 0, 0	
	local num = #sections
	local category = sections[1].category
	self:Debug('rowWidth, maxHeight:', rowWidth, maxHeight)
	while num > 0 do
		self:Debug('Start of column', numColumns)
		local columnWidth, y = 0, 0
		while num > 0 and y < maxHeight do
			self:Debug('Start of row at', y)
			local rowHeight, x = 0, 0
			while num > 0 and x < rowWidth do
				local index = getNext(rowWidth - x, maxHeight - y, category)
				if not index then
					if sections[1].category ~= category then
						category = sections[1].category
						index = getNext(rowWidth - x, maxHeight - y, category)
					end
					index = index or getNextSection[0](rowWidth - x, maxHeight - y)
					if not index then
						self:Debug('No section to fit in ', rowWidth - x, maxHeight - y, 'first section:', sections[1]:GetWidth(), sections[1]:GetHeight())
						break
					end
					self:Debug('Found any section for space', rowWidth - x, maxHeight - y, ':', sections[index])
				else
					self:Debug('Found section in category', category, 'for space', rowWidth - x, maxHeight - y, ':', sections[index])
				end
				local section = tremove(sections, index)
				category = section.category
				num = num - 1
				section:SetPoint("TOPLEFT", content, columnX + x, -y)
				section:Show()
				x = x + section:GetWidth() + SECTION_SPACING
				rowHeight = math.max(rowHeight, section:GetHeight())
			end
			if x > 0 then
				y = y + rowHeight + ITEM_SPACING
				columnWidth = math.max(columnWidth, x)
				contentHeight = math.max(contentHeight, y)
			else
				self:Debug('Empty row, start new column')
				break
			end
		end
		if y > 0 then
			numColumns = numColumns + 1
			columnX = columnX + columnWidth
			contentWidth = math.max(contentWidth, columnX)
			wasted = maxHeight - y
		else
			self:Debug('Empty column ??')
			break
		end
	end
	return contentWidth - SECTION_SPACING, contentHeight - ITEM_SPACING, numColumns, wasted 
end

function containerProto:LayoutSections(forceLayout)
	self:Debug('LayoutSections', forceLayout)

	for name, section in pairs(self.sections) do
		if not section:LayoutButtons(forceLayout) then
			section:Release()
			self.sections[name] = nil
		end
	end

	local rowWidth, maxHeight
	if addon.db.profile.multiColumn then
		maxHeight = (ITEM_SIZE + SECTION_SPACING) * addon.db.profile.multiColumnHeight - SECTION_SPACING
		rowWidth = (ITEM_SIZE + ITEM_SPACING) * addon.db.profile.multiColumnWidth - ITEM_SPACING
	else
		maxHeight = 0.9 * UIParent:GetHeight() * self:GetEffectiveScale() / UIParent:GetEffectiveScale()
		rowWidth = (ITEM_SIZE + ITEM_SPACING) * addon.db.profile.columns - ITEM_SPACING
	end	
	
	local contentWidth, contentHeight, numColumns, wastedHeight = DoLayoutSections(self, rowWidth, maxHeight)
	local step = ITEM_SIZE + ITEM_SPACING + addon.HEADER_SIZE
	if numColumns > 1 and wastedHeight / contentHeight > 0.1 then
		local totalHeight = contentHeight * numColumns - wastedHeight
		maxHeight = totalHeight / numColumns
		self:Debug('LayoutSections, height=', contentHeight, 'numColumns=', numColumns, 'wasted=', wastedHeight, '=> maxHeight=', maxHeight)
		contentWidth, contentHeight, numColumns, wastedHeight = DoLayoutSections(self, rowWidth, maxHeight)
	elseif numColumns == 1 and contentWidth < self:GetContentMinWidth()  then
		contentWidth, contentHeight, numColumns, wastedHeight = DoLayoutSections(self, self:GetContentMinWidth(), maxHeight)
	end
	self:Debug('LayoutSections, at final: width=', contentWidth, 'height=', contentHeight, 'numColumns=', numColumns, 'wasted=', wastedHeight)
	self.Content:SetWidth(contentWidth)
	self.Content:SetHeight(contentHeight)
end
