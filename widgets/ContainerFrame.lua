--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2014 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local assert = _G.assert
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local band = _G.bit.band
local BANK_CONTAINER = _G.BANK_CONTAINER
local ceil = _G.ceil
local CreateFrame = _G.CreateFrame
local format = _G.format
local GetContainerFreeSlots = _G.GetContainerFreeSlots
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetCursorInfo = _G.GetCursorInfo
local GetItemInfo = _G.GetItemInfo
local GetMerchantItemLink = _G.GetMerchantItemLink
local ipairs = _G.ipairs
local max = _G.max
local min = _G.min
local next = _G.next
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local pairs = _G.pairs
local PlaySound = _G.PlaySound
local select = _G.select
local strjoin = _G.strjoin
local strsplit = _G.strsplit
local tinsert = _G.tinsert
local tostring = _G.tostring
local tremove = _G.tremove
local tsort = _G.table.sort
local UIParent = _G.UIParent
local wipe = _G.wipe
--GLOBALS>

local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId
local GetItemFamily = addon.GetItemFamily
local BuildSectionKey = addon.BuildSectionKey
local SplitSectionKey = addon.SplitSectionKey

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local SECTION_SPACING = addon.SECTION_SPACING
local BAG_INSET = addon.BAG_INSET
local HEADER_SIZE = addon.HEADER_SIZE

local BAG_IDS = addon.BAG_IDS

--------------------------------------------------------------------------------
-- Widget scripts
--------------------------------------------------------------------------------

local function BagSlotButton_OnClick(button)
	button.panel:SetShown(button:GetChecked())
end

--------------------------------------------------------------------------------
-- Bag creation
--------------------------------------------------------------------------------

local containerClass, containerProto, containerParentProto = addon:NewClass("Container", "LayeredRegion", "ABEvent-1.0")

function addon:CreateContainerFrame(...) return containerClass:Create(...) end

local SimpleLayeredRegion = addon:GetClass("SimpleLayeredRegion")

local bagSlots = {}
function containerProto:OnCreate(name, isBank, bagObject)
	self:SetParent(UIParent)
	containerParentProto.OnCreate(self)

	--self:EnableMouse(true)
	self:SetFrameStrata("HIGH")
	local frameLevel = 2 + (isBank and 5 or 0)
	self:SetFrameLevel(frameLevel - 2)

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)

	self.name = name
	self.bagObject = bagObject
	self.isBank = isBank
	self.isReagentBank = false

	self.buttons = {}
	self.dirtyButtons = {}
	self.content = {}
	self.stacks = {}
	self.sections = {}

	self.added = {}
	self.removed = {}
	self.changed = {}

	local ids
	for bagId in pairs(BAG_IDS[isBank and "BANK" or "BAGS"]) do
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
	button:SetFrameLevel(frameLevel - 1)

	local headerLeftRegion = SimpleLayeredRegion:Create(self, "TOPLEFT", "RIGHT", 4)
	headerLeftRegion:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)
	self.HeaderLeftRegion = headerLeftRegion
	self:AddWidget(headerLeftRegion)
	headerLeftRegion:SetFrameLevel(frameLevel)

	local headerRightRegion = SimpleLayeredRegion:Create(self, "TOPRIGHT", "LEFT", 4)
	headerRightRegion:SetPoint("TOPRIGHT", -32, -BAG_INSET)
	self.HeaderRightRegion = headerRightRegion
	self:AddWidget(headerRightRegion)
	headerRightRegion:SetFrameLevel(frameLevel)

	local bottomLeftRegion = SimpleLayeredRegion:Create(self, "BOTTOMLEFT", "UP", 4)
	bottomLeftRegion:SetPoint("BOTTOMLEFT", BAG_INSET, BAG_INSET)
	self.BottomLeftRegion = bottomLeftRegion
	self:AddWidget(bottomLeftRegion)
	bottomLeftRegion:SetFrameLevel(frameLevel)

	local bottomRightRegion = SimpleLayeredRegion:Create(self, "BOTTOMRIGHT", "UP", 4)
	bottomRightRegion:SetPoint("BOTTOMRIGHT", -BAG_INSET, BAG_INSET)
	self.BottomRightRegion = bottomRightRegion
	self:AddWidget(bottomRightRegion)
	bottomRightRegion:SetFrameLevel(frameLevel)

	local bagSlotPanel = addon:CreateBagSlotPanel(self, name, bagSlots, isBank)
	bagSlotPanel:Hide()
	self.BagSlotPanel = bagSlotPanel
	wipe(bagSlots)

	local closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	self.CloseButton = closeButton
	closeButton:SetPoint("TOPRIGHT", -2, -2)
	addon.SetupTooltip(closeButton, L["Close"])
	closeButton:SetFrameLevel(frameLevel)

	local bagSlotButton = CreateFrame("CheckButton", nil, self)
	bagSlotButton:SetNormalTexture([[Interface\Buttons\Button-Backpack-Up]])
	bagSlotButton:SetCheckedTexture([[Interface\Buttons\CheckButtonHilight]])
	bagSlotButton:GetCheckedTexture():SetBlendMode("ADD")
	bagSlotButton:SetScript('OnClick', BagSlotButton_OnClick)
	bagSlotButton.panel = bagSlotPanel
	bagSlotButton:SetWidth(18)
	bagSlotButton:SetHeight(18)
	self.BagSlotButton = bagSlotButton
	addon.SetupTooltip(bagSlotButton, {
		L["Equipped bags"],
		L["Click to toggle the equipped bag panel, so you can change them."]
	}, "ANCHOR_BOTTOMLEFT", -8, 0)
	headerLeftRegion:AddWidget(bagSlotButton, 50)

	local searchBox = CreateFrame("EditBox", self:GetName().."SearchBox", self, "BagSearchBoxTemplate")
	searchBox:SetSize(130, 20)
	searchBox:SetFrameLevel(frameLevel)
	headerRightRegion:AddWidget(searchBox, -10, 130, 0, -1)
	tinsert(_G.ITEM_SEARCHBAR_LIST, searchBox:GetName())

	local title = self:CreateFontString(self:GetName().."Title","OVERLAY")
	self.Title = title
	title:SetFontObject(addon.bagFont)
	title:SetText(L[name])
	title:SetHeight(18)
	title:SetJustifyH("LEFT")
	title:SetPoint("LEFT", headerLeftRegion, "RIGHT", 4, 0)
	title:SetPoint("RIGHT", headerRightRegion, "LEFT", -4, 0)

	local anchor = addon:CreateBagAnchorWidget(self, name, L[name])
	anchor:SetAllPoints(title)
	anchor:SetFrameLevel(self:GetFrameLevel() + 10)
	self.Anchor = anchor

	if self.isBank then
		self:CreateReagentTabButton()
		self:CreateDepositButton()
	end
	self:CreateSortButton()

	local content = CreateFrame("Frame", nil, self)
	content:SetPoint("TOPLEFT", BAG_INSET, -addon.TOP_PADDING)
	self.Content = content
	self:AddWidget(content)

	self:UpdateSkin()
	self.dirtyLayout = false
	self.paused = true
	self.forceLayout = true

	-- Register persitent listeners
	local name = self:GetName()
	local RegisterMessage = LibStub('ABEvent-1.0').RegisterMessage
	RegisterMessage(name, 'AdiBags_FiltersChanged', self.FiltersChanged, self)
	RegisterMessage(name, 'AdiBags_LayoutChanged', self.LayoutChanged, self)
	RegisterMessage(name, 'AdiBags_ConfigChanged', self.ConfigChanged, self)
end

function containerProto:ToString() return self.name or self:GetName() end

function containerProto:CreateModuleButton(letter, order, onClick, tooltip)
	local button = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	button:SetText(letter)
	button:SetSize(20, 20)
	button:SetScript("OnClick", onClick)
	button:RegisterForClicks("AnyUp")
	if order then
		self:AddHeaderWidget(button, order)
	end
	if tooltip then
		addon.SetupTooltip(button, tooltip, "ANCHOR_TOPLEFT", 0, 8)
	end
	return button
end

 function containerProto:CreateModuleAutoButton(letter, order, title, description, optionName, onClick, moreTooltip)
	local button
	local statusTexts = {
		[false] = '|cffff0000'..L["disabled"]..'|r',
		[true]  = '|cff00ff00'..L["enabled"]..'|r'
	}
	local Description = description:sub(1, 1):upper() .. description:sub(2)

	button = self:CreateModuleButton(
		letter,
		order,
		function(_, mouseButton)
			if mouseButton == "RightButton" then
				local enable = not addon.db.profile[optionName]
				addon.db.profile[optionName] = enable
				return PlaySound(enable and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
			end
			onClick()
		end,
		function(_, tooltip)
			tooltip:AddLine(title, 1, 1, 1)
			tooltip:AddLine(format(L["%s is: %s."], Description, statusTexts[not not addon.db.profile[optionName]]))
			if moreTooltip then
				tooltip:AddLine(moreTooltip)
			end
			tooltip:AddLine(format(L["Right-click to toggle %s."], description))
		end
	)

	return button
end

function containerProto:CreateDepositButton()
	local button = self:CreateModuleAutoButton(
		"D",
		0,
		REAGENTBANK_DEPOSIT,
		L["auto-deposit"],
		"autoDeposit",
		DepositReagentBank,
		L["You can block auto-deposit ponctually by pressing a modified key while talking to the banker."]
	)

	if not IsReagentBankUnlocked() then
		button:Hide()
		button:SetScript('OnEvent', button.Show)
		button:RegisterEvent('REAGENTBANK_PURCHASED')
	end
end

function containerProto:CreateSortButton()
	self:CreateModuleAutoButton(
		"S",
		10,
		BAG_CLEANUP_BAGS,
		L["auto-sort"],
		"autoSort",
		function() self.bagObject:Sort() end,
		'|cffff7700'..L["Auto-sort can cause freeze when the bag is closed."]..'|r'
	)
end

function containerProto:CreateReagentTabButton()
	local button
	button = self:CreateModuleButton(
		"R",
		0,
		function()
			if not IsReagentBankUnlocked() then
				PlaySound("igMainMenuOption")
				return StaticPopup_Show("CONFIRM_BUY_REAGENTBANK_TAB")
			end
			local previousBags = self:GetBagIds()
			self.isReagentBank = not self.isReagentBank
			BankFrame.selectedTab = self.isReagentBank and 2 or 1
			self.BagSlotButton:SetEnabled(not self.isReagentBank)
			if self.isReagentBank and self.BagSlotPanel:IsShown() then
				self.BagSlotPanel:Hide()
				self.BagSlotButton:SetChecked(False)
			end
			self.Title:SetText(self.isReagentBank and REAGENT_BANK or L["Bank"])
			addon:SendMessage('AdiBags_BagSetupChanged')
		end,
		function(_, tooltip)
			if not IsReagentBankUnlocked() then
				tooltip:AddLine(BANKSLOTPURCHASE, 1, 1, 1)
				tooltip:AddLine(REAGENTBANK_PURCHASE_TEXT)
				SetTooltipMoney(tooltip, GetReagentBankCost(), nil, COSTS_LABEL)
				return
			end
			tooltip:AddLine(
				format(
					L['Click to swap between %s and %s.'],
					REAGENT_BANK:lower(),
					L["Bank"]:lower()
				)
			)
		end
	)
end

--------------------------------------------------------------------------------
-- Scripts & event handlers
--------------------------------------------------------------------------------

function containerProto:GetBagIds()
	return BAG_IDS[
		self.isReagentBank and "REAGENTBANK_ONLY" or
		self.isBank and "BANK_ONLY" or
		"BAGS"
	]
end

function containerProto:BagsUpdated(event, bagIds)
	local showBag = self:GetBagIds()
	for bag in pairs(bagIds) do
		if showBag[bag] then
			self:UpdateContent(bag)
		end
	end
	self:UpdateButtons()
	self:LayoutSections()
end

function containerProto:CanUpdate()
	return not addon.holdYourBreath and not addon.globalLock and not self.paused and self:IsVisible()
end

function containerProto:FiltersChanged(event, forceLayout)
	self.filtersChanged = true
	if self:CanUpdate() then
		self:RedispatchAllItems()
		self:LayoutSections(forceLayout)
	elseif forceLayout then
		self.forceLayout = forceLayout
	end
end

function containerProto:LayoutChanged()
	if self:CanUpdate() then
		self:LayoutSections(true)
	else
		self.forceLayout = true
	end
end

function containerProto:ConfigChanged(event, name)
	if strsplit('.', name) == 'skin' then
		return self:UpdateSkin()
	end
end

function containerProto:OnShow()
	PlaySound(self.isBank and "igMainMenuOpen" or "igBackPackOpen")
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING', "PauseUpdates")
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED', "ResumeUpdates")
	self:RegisterEvent('AUCTION_MULTISELL_START', "PauseUpdates")
	self:RegisterEvent('AUCTION_MULTISELL_UPDATE')
	self:RegisterEvent('AUCTION_MULTISELL_FAILURE', "ResumeUpdates")
	self:RegisterMessage('AdiBags_SpellIsTargetingChanged')
	self:RegisterMessage('AdiBags_BagSetupChanged')
	self:ResumeUpdates()
	containerParentProto.OnShow(self)
end

function containerProto:OnHide()
	containerParentProto.OnHide(self)
	PlaySound(self.isBank and "igMainMenuClose" or "igBackPackClose")
	self:PauseUpdates()
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
end

function containerProto:ResumeUpdates()
	if not self.paused then return end
	self.paused = false
	self:RegisterMessage('AdiBags_BagUpdated', 'BagsUpdated')
	self:Debug('ResumeUpdates')
	return self:AdiBags_BagSetupChanged()
end

function containerProto:PauseUpdates()
	if self.paused then return end
	self:Debug('PauseUpdates')
	self:UnregisterMessage('AdiBags_BagUpdated')
	self.paused = true
end

function containerProto:AdiBags_BagSetupChanged()
	self:Debug('BagSetupChanged')
	for bag in pairs(self.content) do
		self:UpdateContent(bag)
	end
	if self.filtersChanged  then
		self:RedispatchAllItems()
	else
		self:UpdateButtons()
	end
	self:LayoutSections(true)
end

function containerProto:AUCTION_MULTISELL_UPDATE(event, current, total)
	if current == total then
		self:ResumeUpdates()
	end
end

function containerProto:AdiBags_SpellIsTargetingChanged(event, isTargeting)
	if not isTargeting and self:CanUpdate() then
		self:LayoutSections()
	end
end

--------------------------------------------------------------------------------
-- Backdrop click handler
--------------------------------------------------------------------------------

local function FindBagWithRoom(self, itemFamily)
	local fallback
	for bag in pairs(self:GetBagIds()) do
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
	elseif ... == "RightButton" and addon.db.profile.rightClickConfig then
		return addon:OpenOptions('bags')
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

function containerProto:OnLayout()
	self:Debug('OnLayout')
	local hlr, hrr = self.HeaderLeftRegion, self.HeaderRightRegion
	local blr, brr = self.BottomLeftRegion, self.BottomRightRegion
	local minWidth = max(
		self.Title:GetStringWidth() + 32 + (hlr:IsShown() and hlr:GetWidth() or 0) + (hrr:IsShown() and hrr:GetWidth() or 0),
		(blr:IsShown() and blr:GetWidth() or 0) + (brr:IsShown() and brr:GetWidth() or 0)
	)
	local bottomHeight = max(
		blr:IsShown() and (BAG_INSET + blr:GetHeight()) or 0,
		brr:IsShown() and (BAG_INSET + brr:GetHeight()) or 0
	)
	self:SetSize(
		BAG_INSET * 2 + max(minWidth, self.Content:GetWidth()),
		addon.TOP_PADDING + BAG_INSET + bottomHeight + self.Content:GetHeight()
	)
	local currentMinWidth = self.minWidth
	if ceil(currentMinWidth or 0) ~= ceil(minWidth) then
		self.minWidth = minWidth
		if not currentMinWidth or ceil(minWidth - currentMinWidth) > 2 * ITEM_SIZE + ITEM_SPACING then
			return self:LayoutSections(true)
		end
	end
end

--------------------------------------------------------------------------------
-- Miscellaneous
--------------------------------------------------------------------------------

function containerProto:UpdateSkin()
	local backdrop, r, g, b, a = addon:GetContainerSkin(self.name)
	self:SetBackdrop(backdrop)
	self:SetBackdropColor(r, g, b, a)
	local m = max(r, g, b)
	if m == 0 then
		self:SetBackdropBorderColor(0.5, 0.5, 0.5, a)
	else
		self:SetBackdropBorderColor(0.5+(0.5*r/m), 0.5+(0.5*g/m), 0.5+(0.5*b/m), a)
	end
end

--------------------------------------------------------------------------------
-- Bag content scanning
--------------------------------------------------------------------------------

function containerProto:UpdateContent(bag)
	self:Debug('UpdateContent', bag)
	local added, removed, changed = self.added, self.removed, self.changed
	local content = self.content[bag]
	local newSize = self:GetBagIds()[bag] and GetContainerNumSlots(bag) or 0
	local _, bagFamily = GetContainerNumFreeSlots(bag)
	content.family = bagFamily
	for slot = 1, newSize do
		local itemId = GetContainerItemID(bag, slot)
		local link = GetContainerItemLink(bag, slot)
		if not itemId or (link and addon.IsValidItemLink(link)) then
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

			local name, count, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice
			if link then
				name, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(link)
				count = select(2, GetContainerItemInfo(bag, slot)) or 0
			else
				link, count = false, 0
			end

			if slotData.link ~= link then
				removed[slotData.slotId] = slotData.link
				slotData.count = count
				slotData.link = link
				slotData.itemId = itemId
				slotData.name, slotData.quality, slotData.iLevel, slotData.reqLevel, slotData.class, slotData.subclass, slotData.equipSlot, slotData.texture, slotData.vendorPrice = name, quality, iLevel, reqLevel, class, subclass, equipSlot, texture, vendorPrice
				slotData.maxStack = maxStack or (link and 1 or 0)
				added[slotData.slotId] = slotData
			elseif slotData.count ~= count then
				slotData.count = count
				changed[slotData.slotId] = slotData
			end
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
	local key = BuildSectionKey(name, category)
	local section = self.sections[key]
	if not section then
		section = addon:AcquireSection(self, name, category)
		self.sections[key] = section
	end
	return section
end

local function FilterByBag(slotData)
	local bag = slotData.bag
	local name
	if bag == BACKPACK_CONTAINER then
		name = L['Backpack']
	elseif bag == BANK_CONTAINER then
		name = L['Bank']
	elseif bag == REAGENTBANK_CONTAINER then
		name = REAGENT_BANK
	elseif bag <= NUM_BAG_SLOTS then
		name = format(L["Bag #%d"], bag)
	else
		name = format(L["Bank bag #%d"], bag - NUM_BAG_SLOTS)
	end
	if slotData.link then
		local shouldStack, stackHint = addon:ShouldStack(slotData)
		return name, nil, nil, shouldStack, stackHint and strjoin('#', tostring(stackHint), name)
	else
		return name, nil, nil, addon.db.profile.virtualStacks.freeSpace, name
	end
end

local MISCELLANEOUS = addon.BI['Miscellaneous']
local FREE_SPACE = L["Free space"]
function containerProto:FilterSlot(slotData)
	if self.BagSlotPanel:IsShown() then
		return FilterByBag(slotData)
	elseif slotData.link then
		local section, category, filterName = addon:Filter(slotData, MISCELLANEOUS)
		return section, category, filterName, addon:ShouldStack(slotData)
	else
		return FREE_SPACE, nil, nil, addon:ShouldStack(slotData)
	end
end

function containerProto:DispatchItem(slotData)
	local slotId = slotData.slotId
	local sectionName, category, filterName, shouldStack, stackHint = self:FilterSlot(slotData)
	assert(sectionName, "sectionName is nil, item: "..(slotData.link or "none"))
	local stackKey = shouldStack and stackHint or nil
	local button = self.buttons[slotId]
	if button then
		if shouldStack then
			if not button:IsStack() or button:GetKey() ~= stackKey then
				self:RemoveSlot(slotId)
				button = nil
			end
		elseif button:IsStack() then
			self:RemoveSlot(slotId)
			button = nil
		end
	end
	if not button then
		if shouldStack then
			button = self:GetStackButton(stackKey)
			button:AddSlot(slotId)
		else
			button = addon:AcquireItemButton(self, slotData.bag, slotData.slot)
		end
	else
		button:FullUpdate()
	end
	local section = self:GetSection(sectionName, category or sectionName)
	if button:GetSection() ~= section then
		section:AddItemButton(slotId, button)
	end
	button.filterName = filterName
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

	local added, removed, changed = self.added, self.removed, self.changed
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
		buttons[slotId]:FullUpdate()
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
end

function containerProto:RedispatchAllItems()
	self:UpdateButtons()
	if self.filtersChanged then
		self:Debug('RedispatchAllItems')
		self:SendMessage('AdiBags_PreFilter', self)
		for bag, content in pairs(self.content) do
			for slotId, slotData in ipairs(content) do
				self:DispatchItem(slotData)
			end
		end
		self:SendMessage('AdiBags_PostFilter', self)
		self.filtersChanged = nil
	end
end

--------------------------------------------------------------------------------
-- Section queries
--------------------------------------------------------------------------------

function containerProto:GetSectionKeys(hidden, t)
	t = t or {}
	for key, section in pairs(self.sections) do
		if hidden or not section:IsCollapsed() then
			if not t[key] then
				tinsert(t, key)
				t[key] = true
			end
		end
	end
	return t
end

function containerProto:GetOrdererSectionKeys(hidden, t)
	t = t or {}
	self:GetSectionKeys(hidden, t)
	tsort(t, addon.CompareSectionKeys)
	return t
end

function containerProto:GetSectionInfo(key)
	local name, category = SplitSectionKey(key)
	local title = (category == name) and name or (name .. " (" .. category .. ")")
	local section = self.sections[key]
	return key, section, name, category, title, section and (not section:IsCollapsed()) or false
end

do
	local t = {}
	function containerProto:IterateSections(hidden)
		wipe(t)
		self:GetOrdererSectionKeys(hidden, t)
		local i = 0
		return function()
			i = i + 1
			local key = t[i]
			if key then
				return self:GetSectionInfo(key)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Section layout
--------------------------------------------------------------------------------

local DoLayoutSections

do
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

	local function GetBestSection(maxWidth, maxHeight, xOffset, category)
		local bestIndex, leastWasted, bestWidth, bestHeight
		for index, section in ipairs(sections) do
			if category and section.category ~= category then
				break
			end
			local fit, width, height, wasted = section:FitInSpace(maxWidth, maxHeight, xOffset)
			if fit then
				if wasted == 0 then
					return index, width, height
				elseif not leastWasted or wasted < leastWasted then
					bestIndex, bestWidth, bestHeight, leastWasted = index, width, height, wasted
				end
			end
		end
		return bestIndex, bestWidth, bestHeight
	end

	local getNextSection = {
		-- 0: keep section of the same category together and in the same exact order
		[0] = function(maxWidth, maxHeight, xOffset)
			local fit, width, height, wasted = sections[1]:FitInSpace(maxWidth, maxHeight, xOffset)
			if fit then
				return 1, width, height
			end
		end,
		-- 1: keep categories together
		[1] = function(maxWidth, maxHeight, xOffset)
			return GetBestSection(maxWidth, maxHeight, xOffset, sections[1].category)
		end,
		-- 2: do not care about ordering
		[2] = GetBestSection,
	}

	local row = {}

	function DoLayoutSections(self, rowWidth, maxWidth)

		wipe(sections)
		for key, section in pairs(self.sections) do
			if not section:IsEmpty() and not section:IsCollapsed() then
				tinsert(sections, section)
			end
		end
		tsort(sections, CompareSections)

		local content = self.Content
		local getNext = getNextSection[addon.db.profile.laxOrdering]

		local contentWidth, y, minHeight = 0, 0, 0
		local y = 0
		while #sections > 0 do
			wipe(row)
			local rowHeight, x, curHeight = 0, 0, 1
			while #sections > 0 and x + ITEM_SIZE <= maxWidth do
				local index, width, height = getNext(min(rowWidth, maxWidth - x), rowHeight, x)
				if not index then
					break
				end
				if height <= curHeight then
					local section = tremove(sections, index)
					section:SetPoint("TOPLEFT", content, x, -y)
					local w, h = section:SetSizeInSlots(width, curHeight)
					x = x + w + SECTION_SPACING
					rowHeight = max(rowHeight, h)
					tinsert(row, section)
				else
					curHeight, x = height, 0
					for i, section in ipairs(row) do
						local newWidth = ceil(section.count / curHeight)
						section:SetPoint("TOPLEFT", content, x, -y)
						local w, h = section:SetSizeInSlots(newWidth, height)
						x = x + w + SECTION_SPACING
						rowHeight = max(rowHeight, h)
					end
				end
			end
			if x > 0 then
				minHeight = max(minHeight, rowHeight)
				local num = #row
				for i, section in ipairs(row) do
					section:SetHeaderOverflow(i < num)
				end
				contentWidth = max(contentWidth, x)
				y = y + rowHeight + ITEM_SPACING
			else
				break
			end
		end
		return contentWidth - SECTION_SPACING, max(0, y - ITEM_SPACING), minHeight
	end
end

function containerProto:SetDirtyLayout(dirtyLevel)
	local dirtyLayout = dirtyLevel > 0
	self:Debug('SetDirtyLayout, layout is', dirtyLayout and "dirty" or "clean")
	if self.dirtyLayout ~= dirtyLayout then
		self.dirtyLayout = dirtyLayout
		self:SendMessage('AdiBags_ContainerLayoutDirty', self, dirtyLayout)
	end
end

function containerProto:LayoutSections(forceLayout)
	self.forceLayout = self.forceLayout or forceLayout

	local numSections, dirtyLevel = 0, 0
	for key, section in pairs(self.sections) do
		if section:IsEmpty() or section:IsCollapsed() then
			if section:IsShown() and dirtyLevel < 1 then
				dirtyLevel = 1
			end
		else
			numSections = numSections + 1
			dirtyLevel = max(dirtyLevel, section:IsShown() and section:GetDirtyLevel() or 2)
		end
	end

	local doLayout = self.forceLayout
	if not doLayout then
		local setting = addon.db.profile.automaticLayout
		doLayout = (setting < 3 and dirtyLevel >= 2)
			or (setting == 0 and dirtyLevel > 0)
			or (setting == 1 and dirtyLevel > 0 and not addon:GetInteractingWindow())
	end

	if doLayout and self.minWidth and not addon.spellIsTargeting then

		if self.forceLayout or dirtyLevel >= 2 then

			if numSections == 0 then
				self.Content:SetSize(0.5, 0.5)

			else
				local rowWidth = (ITEM_SIZE + ITEM_SPACING) * addon.db.profile.rowWidth[self.name] - ITEM_SPACING
				local minWidth = max(rowWidth, self.minWidth)
				local uiScale, uiWidth, uiHeight = UIParent:GetEffectiveScale(), UIParent:GetSize()
				local selfScale = self:GetEffectiveScale()
				local maxWidth = addon.db.profile.maxWidth * uiWidth * uiScale / selfScale
				local maxHeight = addon.db.profile.maxHeight * uiHeight * uiScale / selfScale

				local numColumns = 0
				local contentWidth, contentHeight, minHeight
				repeat
					numColumns = numColumns + 1
					local tmpMaxWidth = max(minWidth, min(maxWidth, (rowWidth + SECTION_SPACING) * numColumns - SECTION_SPACING))
					contentWidth, contentHeight, minHeight = DoLayoutSections(self, rowWidth, tmpMaxWidth)
				until contentHeight <= max(minHeight, maxHeight) or numColumns == 4

				self.Content:SetSize(contentWidth, contentHeight)
			end

			dirtyLevel = 0
		end

		for key, section in pairs(self.sections) do
			if section:IsEmpty() then
				section:Release()
				self.sections[key] = nil
			elseif section:IsCollapsed() then
				section:Hide()
			else
				section:Show()
				section:Layout()
				dirtyLevel = max(dirtyLevel, section:GetDirtyLevel())
			end
		end

		self.forceLayout = nil
	end

	self:SetDirtyLayout(dirtyLevel)
end
