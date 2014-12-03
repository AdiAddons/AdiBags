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

	local toSortSection = addon:AcquireSection(self, "To sort", self.name)
	toSortSection:SetPoint("TOPLEFT", BAG_INSET, -addon.TOP_PADDING)
	toSortSection:Show()
	self.ToSortSection = toSortSection
	self:AddWidget(toSortSection)

	local content = CreateFrame("Frame", nil, self)
	content:SetPoint("TOPLEFT", toSortSection, "BOTTOMLEFT", 0, -ITEM_SPACING)
	self.Content = content
	self:AddWidget(content)

	self:UpdateSkin()
	self.paused = true
	self.forceLayout = true

	-- Register persitent listeners
	local name = self:GetName()
	local RegisterMessage = LibStub('ABEvent-1.0').RegisterMessage
	RegisterMessage(name, 'AdiBags_FiltersChanged', self.FullUpdate, self)
	RegisterMessage(name, 'AdiBags_LayoutChanged', self.FullUpdate, self)
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
			self:ShowReagentTab(not self.isReagentBank)
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
	self:Debug('BagsUpdated')
	local showBag = self:GetBagIds()
	for bag in pairs(bagIds) do
		if showBag[bag] then
			self:UpdateContent(bag)
		end
	end
	self:UpdateButtons()
end

function containerProto:CanUpdate()
	return not addon.holdYourBreath and not addon.globalLock and not self.paused and self:IsVisible()
end

function containerProto:ConfigChanged(event, name)
	if strsplit('.', name) == 'skin' then
		self:UpdateSkin()
	end
end

function containerProto:OnShow()
	self:Debug('OnShow')
	PlaySound(self.isBank and "igMainMenuOpen" or "igBackPackOpen")
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING', "PauseUpdates")
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED', "ResumeUpdates")
	self:RegisterEvent('AUCTION_MULTISELL_START', "PauseUpdates")
	self:RegisterEvent('AUCTION_MULTISELL_UPDATE')
	self:RegisterEvent('AUCTION_MULTISELL_FAILURE', "ResumeUpdates")
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
	self:RefreshContents()
end

function containerProto:PauseUpdates()
	if self.paused then return end
	self:Debug('PauseUpdates')
	self:UnregisterMessage('AdiBags_BagUpdated')
	self.paused = true
end

function containerProto:RefreshContents()
	self:Debug('RefreshContents')
	for bag in pairs(self:GetBagIds()) do
		self:UpdateContent(bag)
	end
	if self.forceLayout then
		self:FullUpdate()
	else
		self:UpdateButtons()
	end
end

function containerProto:ShowReagentTab(show)
	self:Debug('ShowReagentTab', show)

	self.Title:SetText(show and REAGENT_BANK or L["Bank"])
	self.BagSlotButton:SetEnabled(not show)
	if show and self.BagSlotPanel:IsShown() then
		self.BagSlotPanel:Hide()
		self.BagSlotButton:SetChecked(false)
	end
	BankFrame.selectedTab = show and 2 or 1

	local previousBags = self:GetBagIds()
	self.isReagentBank = show

	for bag in pairs(previousBags) do
		self:UpdateContent(bag)
	end
	self.forceLayout = true
	self:RefreshContents()
end

function containerProto:AUCTION_MULTISELL_UPDATE(event, current, total)
	if current == total then
		self:ResumeUpdates()
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
	self.minWidth = minWidth
	if self.forceLayout then
		self:FullUpdate()
	end
	self:Debug('OnLayout', self.ToSortSection:GetHeight())
	self:SetSize(
		BAG_INSET * 2 + max(minWidth, self.Content:GetWidth()),
		addon.TOP_PADDING + BAG_INSET + bottomHeight + self.Content:GetHeight() + self.ToSortSection:GetHeight() + ITEM_SPACING
	)
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

function containerProto:FindExistingButton(slotId, stackKey)
	local button = self.buttons[slotId]

	if not button then
		return
	elseif stackKey then
		if not button:IsStack() or button:GetKey() ~= stackKey then
			return self:RemoveSlot(slotId)
		end
	elseif button:IsStack() then
		return self:RemoveSlot(slotId)
	end

	return button
end

function containerProto:CreateItemButton(stackKey, slotData)
	if not stackKey then
		return addon:AcquireItemButton(self, slotData.bag, slotData.slot)
	end
	local stack = self:GetStackButton(stackKey)
	stack:AddSlot(slotData.slotId)
	return stack
end

function containerProto:DispatchItem(slotData, fullUpdate)
	local slotId = slotData.slotId
	local sectionName, category, filterName, shouldStack, stackHint = self:FilterSlot(slotData)
	assert(sectionName, "sectionName is nil, item: "..(slotData.link or "none"))
	local stackKey = shouldStack and stackHint or nil

	local button = self:FindExistingButton(slotId, stackKey)
	if button then
		button:FullUpdate()
	else
		button = self:CreateItemButton(stackKey, slotData)
	end
	button.filterName = filterName
	self.buttons[slotId] = button

	if button:GetSection() and not fullUpdate then
		return
	end

	local section = fullUpdate and self:GetSection(sectionName, category or sectionName) or self.ToSortSection
	if button:GetSection() ~= section then
		section:AddItemButton(slotId, button)
	end
end

function containerProto:RemoveSlot(slotId)
	local button = self.buttons[slotId]
	if not button then return end
	self.buttons[slotId] = nil

	if button:IsStack() then
		button:RemoveSlot(slotId)
		if not button:IsEmpty() then
			return
		end
		self.stacks[button:GetKey()] = nil
	end

	button:Release()
end

function containerProto:UpdateButtons()
	if not self:HasContentChanged() then return end
	self:Debug('UpdateButtons')

	local added, removed, changed = self.added, self.removed, self.changed
	self:SendMessage('AdiBags_PreContentUpdate', self, added, removed, changed)

	for slotId in pairs(removed) do
		self:RemoveSlot(slotId)
	end

	if next(added) then
		self:SendMessage('AdiBags_PreFilter', self)
		for slotId, slotData in pairs(added) do
			self:DispatchItem(slotData)
		end
		self:SendMessage('AdiBags_PostFilter', self)
	end

	local buttons = self.buttons
	for slotId in pairs(changed) do
		buttons[slotId]:FullUpdate()
	end

	self:SendMessage('AdiBags_PostContentUpdate', self, added, removed, changed)

	wipe(added)
	wipe(removed)
	wipe(changed)
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
-- Full Layout
--------------------------------------------------------------------------------

function containerProto:RedispatchAllItems()
	self:Debug('RedispatchAllItems')
	self:UpdateButtons()
	self:SendMessage('AdiBags_PreFilter', self)
	for bag, content in pairs(self.content) do
		for slotId, slotData in ipairs(content) do
			self:DispatchItem(slotData, true)
		end
	end
	self:SendMessage('AdiBags_PostFilter', self)
end

local sections = {}

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

function containerProto:PrepareSections(rowWidth)
	wipe(sections)
	local halfWidth = floor(rowWidth / 2)
	for key, section in pairs(self.sections) do
		if section:IsEmpty() or section:IsCollapsed() then
			section:Hide()
		else
			tinsert(sections, section)
			local w, h = halfWidth, 1
			if section.count > w then
				w, h = rowWidth, ceil(section.count / rowWidth)
			end
			section:SetSizeInSlots(w, h)
			section:Show()
			section:FullLayout()
		end
	end
	tsort(sections, CompareSections)
	self:Debug('PrepareSections', rowWidth, '=>', #sections)
end

local heights, rows = { 0 }, {}

local COLUMN_SPACING = ceil((ITEM_SIZE + ITEM_SPACING) / 2)

function containerProto:LayoutSections(maxHeight, rowWidth, minWidth)
	self:Debug('LayoutSections', maxHeight, rowWidth, minWidth)

	local content = self.Content
	local columnWidth = (ITEM_SIZE + ITEM_SPACING) * rowWidth + COLUMN_SPACING - ITEM_SPACING

	local numRows, x, y = 0, 0, 0
	for index, section in ipairs(sections) do
		if x > 0 then
			if x + section:GetWidth() <= columnWidth then
				section:SetPoint('TOPLEFT', sections[index-1], 'TOPRIGHT', ITEM_SPACING*2, 0)
			else
				x, y = 0, heights[numRows + 1]
			end
		end
		if x == 0 then
			numRows = numRows + 1
			rows[numRows] = section
			if numRows > 1 then
				section:SetPoint('TOPLEFT', rows[numRows-1], 'BOTTOMLEFT', 0, -ITEM_SPACING)
			end
		end
		heights[numRows + 1] = y + section:GetHeight() + ITEM_SPACING
		x = x + section:GetWidth() + ITEM_SPACING * 2
	end

	local totalHeight = (heights[numRows + 1] - ITEM_SPACING)
	local numColumns = max(floor(minWidth / (columnWidth - COLUMN_SPACING)), ceil(totalHeight / maxHeight))
	local maxColumnHeight = ceil(totalHeight / numColumns)

	local row, x, contentHeight = 1, 0, 0
	for col = 1, numColumns do
		local yOffset, section = heights[row], rows[row]
		section:SetPoint('TOPLEFT', content, x, 0)
		local maxY = yOffset + maxColumnHeight
		repeat
			row = row + 1
		until row > numRows or (col < numColumns and heights[row] > maxY)
		contentHeight = max(contentHeight, heights[row] - yOffset)
		x = x + columnWidth
	end

	return x - COLUMN_SPACING, contentHeight - ITEM_SPACING
end

function containerProto:FullUpdate()
	self:Debug('FullUpdate', self:CanUpdate(), self.minWidth)
	if not self:CanUpdate() or not self.minWidth then
		self.forceLayout = true
		return
	end
	self.forceLayout = false
	self:Debug('Do FullUpdate')

	local settings = addon.db.profile
	local rowWidth = settings.rowWidth[self.name]

	self:RedispatchAllItems()
	self:PrepareSections(rowWidth)

	if #sections == 0 then
		self.Content:SetSize(self.minWidth, 0.5)
		return
	end

	local uiScale, uiWidth, uiHeight = UIParent:GetEffectiveScale(), UIParent:GetSize()
	local selfScale = self:GetEffectiveScale()
	local maxHeight = settings.maxHeight * uiHeight * uiScale / selfScale - (ITEM_SIZE + ITEM_SPACING + HEADER_SIZE)

	local contentWidth, contentHeight = self:LayoutSections(maxHeight, rowWidth, self.minWidth)
	self:Debug('LayoutSections =>', contentWidth, contentHeight)

	self.ToSortSection:SetSizeInSlots(floor((contentWidth + ITEM_SPACING) / (ITEM_SIZE + ITEM_SPACING)), 1)
	self.ToSortSection:FullLayout()

	self.Content:SetSize(contentWidth, contentHeight)
end
