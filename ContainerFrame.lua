--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local containerProto = setmetatable({}, { __index = CreateFrame("Frame") })
local containerMeta = { __index = containerProto }
local containerCount = 1
LibStub('AceEvent-3.0'):Embed(containerProto)
LibStub('AceBucket-3.0'):Embed(containerProto)

containerProto.Debug = addon.Debug

local ITEM_SIZE = 37
local ITEM_SPACING = 4
local SECTION_SPACING = ITEM_SIZE / 3 + ITEM_SPACING
local BAG_WIDTH = 12
local BAG_INSET = 8
local TOP_PADDING = 32

local BACKDROP = {
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
}

function addon:CreateContainerFrame(name, bags, isBank)
	local container = setmetatable(CreateFrame("Frame", addonName..name, UIParent), containerMeta)
	container:Debug('Created')
	container:ClearAllPoints()
	container:EnableMouse(true)
	container:Hide()
	container:OnCreate(name, bags, isBank)
	return container
end

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

local bagSlots = {}
function containerProto:OnCreate(name, bags, isBank)
	self:SetScale(0.8)
	self:SetFrameStrata("HIGH")

	self:SetBackdrop(BACKDROP)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)

	self.bags = bags
	self.isBank = isBank
	self.buttons = {}
	self.content = {}
	self.stacks = {}
	self.sections = {}
	for bag in pairs(self.bags) do
		self.content[bag] = {}
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
	--bagSlotButton:GetCheckedTexture():SetBlendMode("ADD")
	bagSlotButton:SetScript('OnClick', BagSlotButton_OnClick)
	bagSlotButton.panel = bagSlotPanel
	bagSlotButton:SetWidth(18)
	bagSlotButton:SetHeight(18)
	bagSlotButton:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)

	local title = self:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
	title:SetText(name)
	title:SetTextColor(1, 1, 1)
	title:SetHeight(18)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", bagSlotButton, "TOPRIGHT", 4, 0)
	title:SetPoint("RIGHT", closeButton, "LEFT", -4, 0)
end

function containerProto:OnShow()
	self:Debug('OnShow')
	if self.isBank then
		self:RegisterEvent('BANKFRAME_CLOSED', "Hide")
	end
	self:RegisterBucketEvent('BAG_UPDATE', 0.1, "BagsUpdated")
	for bag in pairs(self.bags) do
		self:UpdateContent("OnShow", bag)
	end
	return self:FullUpdate('OnShow', true)
end

function containerProto:OnHide()
	self:UnregisterAllEvents()
	self:UnregisterAllBuckets()
end

function containerProto:UpdateContent(event, bag)
	self:Debug('UpdateContent', event, bag)
	local bagContent = self.content[bag]
	bagContent.size = GetContainerNumSlots(bag)
	for slot = 1, bagContent.size do
		local link = GetContainerItemLink(bag, slot)
		if link ~= bagContent[slot] then
			bagContent[slot] = link
			self.dirty = true
		end
	end
	if #bagContent > bagContent.size then
		self.dirty = true
		for slot = bagContent.size+1, #bagContent do
			bagContent[slot] = nil
		end
	end
end

local EQUIP_LOCS = {
	INVTYPE_AMMO = 0,
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_BODY = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13,
	INVTYPE_CLOAK = 15,
	INVTYPE_WEAPON = 16,
	INVTYPE_SHIELD = 17,
	INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16,
	INVTYPE_WEAPONOFFHAND = 17,
	INVTYPE_HOLDABLE = 17,
	INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18,
	INVTYPE_RANGEDRIGHT = 18,
	INVTYPE_RELIC = 18,
	INVTYPE_TABARD = 19,
	INVTYPE_BAG = 20,
}

local function CompareItems(idA, idB)
	local nameA, _, qualityA, levelA, _, classA, subclassA, _, equipSlotA = GetItemInfo(idA)
	local nameB, _, qualityB, levelB, _, classB, subclassB, _, equipSlotB = GetItemInfo(idB)
	local equipLocA = EQUIP_LOCS[equipSlotA or ""]
	local equipLocB = EQUIP_LOCS[equipSlotB or ""]
	if equipLocA and equipLocB and equipLocA ~= equipLocB then
		return equipLocA < equipLocB
	elseif classA ~= classB then
		return classA < classB
	elseif subclassA ~= subclassB then
		return subclassA < subclassB
	elseif qualityA ~= qualityB then
		return qualityA > qualityB
	elseif levelA ~= levelB then
		return levelA > levelB
	else
		return nameA < nameB
	end
end

local itemCompareCache = setmetatable({}, { 
	__index = function(t, key)
		local result = CompareItems(strsplit(':', key, 2))
		t[key] = result
		return result
	end
})

local GetContainerItemID = GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local strformat = string.format

local function CompareButtons(a, b)
	local idA = GetContainerItemID(a.bag, a.slot)
	local idB = GetContainerItemID(b.bag, b.slot)
	if idA and idB then
		if idA ~= idB then
			return itemCompareCache[strformat("%d:%d", idA, idB)]
		else
			local _, countA = GetContainerItemInfo(a.bag, a.slot)
			local _, countB = GetContainerItemInfo(b.bag, b.slot)
			return countA > countB
		end
	elseif not idA and not idB then
		local _, famA = GetContainerNumFreeSlots(a.bag)
		local _, famB = GetContainerNumFreeSlots(b.bag)
		if famA and famB and famA ~= famB then
			return famA < famB
		end
	end
	return (idA and 1 or 0) > (idB and 1 or 0)
end

function containerProto:SetupItemButton(index)
	local button = self.buttons[index]
	if not button then
		button = addon:AcquireItemButton()
		button:SetWidth(ITEM_SIZE)
		button:SetHeight(ITEM_SIZE)
		self.buttons[index] = button
	end
	return button
end

function containerProto:ReleaseItemButton(index)
	local button = self.buttons[index]
	if not button then return end
	self.buttons[index] = nil
	button:Release()
	return true
end

function containerProto:FullUpdate(event, forceUpdate)
	if not self.dirty and not forceUpdate then return end
	self:Debug('Updating on', event)
	self.dirty = nil
	wipe(self.stacks)

	local dirtyLayout = forceUpdate
	for name, section in pairs(self.sections) do
		for i in ipairs(section) do
			section[i] = nil
		end
	end
	
	local index = 0
	addon:PreFilter(event, self)
	for bag, content in pairs(self.content) do
		local _, bagFamily = GetContainerNumFreeSlots(bag)
		for slot = 1, content.size do
			local link = content[slot]
			local sectionName, stackType, stackData
			if link then
				local itemId = tonumber(link:match('item:(%d+)'))			
				sectionName, stackType, stackData = addon:Filter(bag, slot, itemId, link)
				self:Debug('Filtering:', link, '=>', section, stackType, stackData)
			else
				sectionName, stackType, stackData = "Free", 'free', bagFamily
			end
			local stackKey = stackType and strjoin(':', tostringall(stackType, stackData))
			if not stackKey or not self.stacks[stackKey] then
				index = index + 1
				local button = self:SetupItemButton(index)
				if button:SetBagSlot(bag, slot) then
					dirtyLayout = true
				end
				if button:SetStackable(stackType, stackData) then
					dirtyLayout = true
				end
				if stackKey then
					self.stacks[stackKey] = button
				end
				if not self.sections[sectionName] then
					self.sections[sectionName] = { name = sectionName }
					dirtyLayout = true
				end
				tinsert(self.sections[sectionName], button)
			end
		end
	end
	
	addon:PostFilter(event, self)
	
	for unused = index+1, #self.buttons do
		if self:ReleaseItemButton(unused) then
			dirtyLayout = true
		end
	end
	
	if dirtyLayout then 
		self:Layout()
	end
end

local function CompareSections(a, b)
	local numA, numB = math.min(#a, BAG_WIDTH), math.min(#b, BAG_WIDTH)
	if numA == numB then
		return a.name < b.name
	else
		return numA > numB
	end
end

local function GetNextSection(sections, remainingwidth, atLineStart)
	local bestIndex, leastWasted
	for index, section in ipairs(sections) do
		if atLineStart and section.count >= BAG_WIDTH then
			return tremove(sections, index)
		else
			local wasted = remainingwidth - section.width
			if wasted >= 0 and (not leastWasted or wasted < leastWasted) then
				bestIndex, leastWasted = index, wasted
			end
		end
	end
	if bestIndex then
		return tremove(sections, bestIndex)
	end
end

local sectionOrder = {}
function containerProto:Layout()

	for name, section in pairs(self.sections) do
		if #section > 0 then
			if not section.header then
				header = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
				section.header = header
				header:SetText(section.name)
				header:SetPoint("BOTTOMLEFT")
				header:Show()
				section.headerWidth = header:GetStringWidth() + 8
			end
			section.count = #section
			section.width = math.max(section.headerWidth, section.count * ITEM_SIZE + math.max(section.count-1, 0) * ITEM_SPACING)
			tinsert(sectionOrder, section)
		elseif section.header then
			section.header:Hide()
		end
	end
	table.sort(sectionOrder, CompareSections)
	
	local lastWasMultiline = false
	local maxWidth = ITEM_SIZE * BAG_WIDTH + ITEM_SPACING * (BAG_WIDTH - 1)
	local maxX = 0
	local x, y = 0, 0
	
	while next(sectionOrder) do
		local atLineStart = (lastWasMultiline or x == 0)
		local remainingWidth = atLineStart and maxWidth or (maxWidth - x - SECTION_SPACING)
		local section = GetNextSection(sectionOrder, remainingWidth, atLineStart)
		if not section then
			section = GetNextSection(sectionOrder, maxWidth, true)
		end
	
		if x > 0 then
			x = x + SECTION_SPACING
			if lastWasMultiline or x + section.width > maxWidth then
				y = y + ITEM_SIZE + 2 * ITEM_SPACING + section.header:GetStringHeight()
				x = 0
			end
		elseif y == 0 then
			y = section.header:GetStringHeight() + ITEM_SPACING
		end
		section.header:SetPoint('BOTTOMLEFT', self, 'TOPLEFT', BAG_INSET + x, - TOP_PADDING - y + ITEM_SPACING)
		lastWasMultiline = false
		
		table.sort(section, CompareButtons)
		for i, button in ipairs(section) do
			if x + ITEM_SIZE > maxWidth then
				x = 0
				y = y + ITEM_SIZE + ITEM_SPACING
				lastWasMultiline = true
			end
			button:SetPoint("TOPLEFT", self, "TOPLEFT", BAG_INSET + x, - TOP_PADDING - y)
			button:Show()
			maxX = math.max(x + ITEM_SIZE, maxX)
			x = x + ITEM_SIZE + ITEM_SPACING
		end
	end
	wipe(sectionOrder)

	self:SetWidth(BAG_INSET * 2 + maxX)
	self:SetHeight(BAG_INSET + TOP_PADDING + y + ITEM_SIZE)
end

function containerProto:BagsUpdated(bags)
	self:Debug('BagsUpdated', bags)
	for bag, x in pairs(bags) do
		self:Debug('-', bag ,x)
		if self.bags[bag] then
			self:UpdateContent(event, bag)
		end
	end
	if self.dirty then
		return self:FullUpdate("BagsUpdated")
	else
		for i, button in pairs(self.buttons) do
			if bags[button.bag] then
				button:FullUpdate("BagsUpdated")
			end
		end
	end
end
