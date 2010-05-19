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

	self:EnableMouse(true)
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

	local headerLeftRegion = SimpleLayeredRegion:Create(self, "TOPLEFT", "RIGHT", 4)
	headerLeftRegion:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)
	self.HeaderLeftRegion = headerLeftRegion
	self:AddWidget(headerLeftRegion)

	local headerRightRegion = SimpleLayeredRegion:Create(self, "TOPRIGHT", "LEFT", 4)
	headerRightRegion:SetPoint("TOPRIGHT", -32, -BAG_INSET)
	self.HeaderRightRegion = headerRightRegion
	self:AddWidget(headerRightRegion)
	
	local bottomLeftRegion = SimpleLayeredRegion:Create(self, "BOTTOMLEFT", "UP", 4)
	bottomLeftRegion:SetPoint("BOTTOMLEFT", BAG_INSET, BAG_INSET)
	self.BottomLeftRegion = bottomLeftRegion
	self:AddWidget(bottomLeftRegion)

	local bottomRightRegion = SimpleLayeredRegion:Create(self, "BOTTOMRIGHT", "UP", 4)
	bottomRightRegion:SetPoint("BOTTOMRIGHT", -BAG_INSET, BAG_INSET)
	self.BottomRightRegion = bottomRightRegion
	self:AddWidget(bottomRightRegion)

	local bagSlotPanel = addon:CreateBagSlotPanel(self, name, bagSlots, isBank)
	bagSlotPanel:Hide()
	self.BagSlotPanel = bagSlotPanel
	wipe(bagSlots)

	local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	self.CloseButton = closeButton
	closeButton:SetPoint("TOPRIGHT", -2, -2)
	addon.SetupTooltip(closeButton, L["Close"])

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

function containerProto:OnLayout()
	local bottomHeight, bottomWidth = 0, 0
	if self.BottomLeftRegion:IsShown() then
		bottomHeight = self.BottomLeftRegion:GetHeight() + BAG_INSET
		bottomWidth = bottomWidth + self.BottomLeftRegion:GetWidth()
	end
	if self.BottomRightRegion:IsShown() then
		bottomHeight = math.max(bottomHeight, self.BottomRightRegion:GetHeight() + BAG_INSET)
		bottomWidth = bottomWidth + self.BottomRightRegion:GetWidth()
	end
	
	local headerWidth = self.Title:GetStringWidth() + 32
	if self.HeaderLeftRegion:IsShown() then
		headerWidth = headerWidth + self.HeaderLeftRegion:GetWidth() + 4
	end
	if self.HeaderRightRegion:IsShown() then
		headerWidth = headerWidth + self.HeaderRightRegion:GetWidth() + 4
	end
	
	self:SetWidth(BAG_INSET * 2 + math.max(headerWidth, bottomWidth, self.Content:GetWidth()))
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
	local key = strjoin('#', name, category or name)
	local section = self.sections[key]
	if not section then
		section = addon:AcquireSection(self, name, category)
		self.sections[key] = section
	end
	return section
end

function containerProto:DispatchItem(slotData)
	local filter, sectionName, category
	local bag, slotId, slot, link, itemId = slotData.bag, slotData.slotId, slotData.slot, slotData.link, slotData.itemId
	local isFull = false
	if link then
		filter, sectionName, category = addon:Filter(slotData)
		isFull = (slotData.count or 1) == (slotData.maxStack or 1)
	else
		filter, sectionName, category = "Free", L["Free space"], L["Free space"]
		isFull = true
	end
	local button = self.buttons[slotId]
	if isFull and addon:ShouldStack(slotData) then
		local key = strjoin(':', tostringall(itemId, slotData.bagFamily))
		button = self:GetStackButton(key)
		button:AddSlot(slotId)
	elseif not button then
		button = addon:AcquireItemButton(self, bag, slot)
	end
	local section = self:GetSection(sectionName or L['Miscellaneous'], category)
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
	if a.category == b.category then
		local secA, secB = a:GetOrder(), b:GetOrder()
		if secA == secB then
			return a.name < b.name
		else
			return secA > secB
		end
	else
		local catA, catB = a:GetCategoryOrder(), b:GetCategoryOrder()
		if catA == catB then
			return a.category < b.category
		else
			return catA > catB
		end
	end
end

local sections = {}

local function GetBestSection(remainingWidth, category, order)
	local bestIndex, leastWasted
	for index, section in ipairs(sections) do
		if section.category ~= category or section.order ~= order then
			break
		end
		local wasted = remainingWidth - section:GetWidth()
		if wasted >= 0 and (not leastWasted or wasted < leastWasted) then
			bestIndex, leastWasted = index, leastWasted
		end
	end
	if bestIndex then
		return bestIndex
	elseif sections[1]:GetWidth() <= remainingWidth then
		return 1
	end
end

function containerProto:LayoutSections(forceLayout)
	self:Debug('LayoutSections', forceLayout)

	for name, section in pairs(self.sections) do
		if section:LayoutButtons(forceLayout) then
			tinsert(sections, section)
		else
			section:Release()
			self.sections[name] = nil
		end
	end

	table.sort(sections, CompareSections)
	self:Debug('Ordered sections:', unpack(sections))

	local content = self.Content
	local columnX, contentWidth, contentHeight = 0, 0, 0
	local maxColumnHeight, bagWidth
	if addon.db.profile.multiColumn then
		maxColumnHeight = (ITEM_SIZE + SECTION_SPACING) * addon.db.profile.multiColumnHeight - SECTION_SPACING
		bagWidth = (ITEM_SIZE + ITEM_SPACING) * addon.db.profile.multiColumnWidth - ITEM_SPACING
	else
		maxColumnHeight = 0.9 * UIParent:GetHeight() * self:GetEffectiveScale() / UIParent:GetEffectiveScale()
		bagWidth = (ITEM_SIZE + ITEM_SPACING) * addon.db.profile.columns - ITEM_SPACING
	end
	local num = #sections
	
	while num > 0 do	
		local y, columnWidth = 0, 0

		while num > 0 and y < maxColumnHeight do
			local rowHeight, x, nextIndex = 0, 0, 1
			while nextIndex do
				local section = tremove(sections, nextIndex)
				num = num - 1
				
				section:SetPoint('TOPLEFT', content, "TOPLEFT", columnX + x, -y)
				section:Show()

				x = x + section:GetWidth() + SECTION_SPACING
				rowHeight = math.max(rowHeight, section:GetHeight())

				if num > 0 and x < bagWidth then
					nextIndex = GetBestSection(bagWidth - x, section.category, section.order)
				else
					break
				end
			end
			y = y + rowHeight + ITEM_SPACING
			columnWidth = math.max(columnWidth, x)
			contentHeight = math.max(contentHeight, y)
		end
		
		columnX = columnX + columnWidth
	end
	
	content:SetWidth(columnX - SECTION_SPACING)
	content:SetHeight(contentHeight - ITEM_SPACING)
end
