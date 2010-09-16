--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local SECTION_SPACING = addon.SECTION_SPACING
local SLOT_OFFSET = ITEM_SIZE + ITEM_SPACING
local HEADER_SIZE = 14 + ITEM_SPACING
addon.HEADER_SIZE = HEADER_SIZE

--------------------------------------------------------------------------------
-- Section ordering
--------------------------------------------------------------------------------

local categoryOrder = {
	[L["Free space"]] = -100
}

function addon:SetCategoryOrder(name, order)
	categoryOrder[name] = order
end

function addon:SetCategoryOrders(t)
	for name, order in pairs(t) do
		categoryOrder[name] = order
	end
end

function addon:IterateCategories()
	return pairs(categoryOrder)
end

function addon:GetCategoryOrder(name)
	return categoryOrder[name] or 0
end

--------------------------------------------------------------------------------
-- Initialization and release
--------------------------------------------------------------------------------

local sectionClass, sectionProto = addon:NewClass("Section", "Frame", "AceEvent-3.0")
addon:CreatePool(sectionClass, "AcquireSection")

function sectionProto:OnCreate()
	self.buttons = {}
	self.slots = {}
	self.freeSlots = {}

	local header = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", SECTION_SPACING - ITEM_SPACING, 0)
	header:SetHeight(HEADER_SIZE)
	self.Header = header
	self:SendMessage('AdiBags_SectionCreated', self)

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)
end

function sectionProto:OnShow()
	for button in pairs(self.buttons) do
		button:Show()
	end
end

function sectionProto:OnHide()
	for button in pairs(self.buttons) do
		button:Hide()
	end
end

function sectionProto:ToString()
	return string.format("Section[%q,%q]", tostring(self.name), tostring(self.category))
end

function addon:BuildSectionKey(name, category)
	return strjoin('#', category or name, name)
end

function addon:SplitSectionKey(key)
	local category, name = strsplit('#', key)
	return name, category
end

function sectionProto:OnAcquire(container, name, category)
	self:SetParent(container)
	self.Header:SetText(name)
	self.name = name
	self.category = category or name
	self.key = addon:BuildSectionKey(name, category)
	self.width = 0
	self.height = 0
	self.count = 0
	self.total = 0
	self.dirty = true
	self.container = container
	self:RegisterMessage('AdiBags_OrderChanged')
end

function sectionProto:OnRelease()
	wipe(self.freeSlots)
	wipe(self.slots)
	wipe(self.buttons)
	self.name = nil
	self.category = nil
	self.container = nil
end

function sectionProto:AdiBags_OrderChanged()
	self:ReorderButtons()
end

function sectionProto:GetOrder()
	return self.category and categoryOrder[self.category] or 0
end

function sectionProto:GetKey()
	return self.key
end

function sectionProto:IsCollapsed()
	return addon.db.char.collapsedSections[self.key]
end

function sectionProto:SetCollapsed(collapsed)
	collapsed = not not collapsed
	if addon.db.char.collapsedSections[self.key] ~= collapsed then
		addon.db.char.collapsedSections[self.key] = collapsed
		if collapsed then
			self:Hide()
		else
			self:Show()
			self.dirty = true
		end
		self:SendMessage('AdiBags_LayoutChanged')
	end
end

--------------------------------------------------------------------------------
-- Button handling
--------------------------------------------------------------------------------

function sectionProto:AddItemButton(slotId, button)
	if not self.buttons[button] then
		button:SetSection(self)
		self.count = self.count + 1
		self.buttons[button] = slotId
		self.dirty = true
		if self:IsVisible() and self.count <= self.total then
			local freeSlots = self.freeSlots
			for index = 1, self.total do
				if freeSlots[index] then
					freeSlots[index] = nil
					self:PutButtonAt(button, index)
					break
				end
			end
		end
	end
end

function sectionProto:RemoveItemButton(button)
	if self.buttons[button] then
		local index = self.slots[button]
		if index and index <= self.total then
			self.freeSlots[index] = true
		end
		self.count = self.count - 1
		self.dirty = true
		self.slots[button] = nil
		self.buttons[button] = nil
	end
end

function sectionProto:IsEmpty()
	return self.count == 0
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

function sectionProto:PutButtonAt(button, index)
	self.slots[button] = index
	local row, col = math.floor((index-1) / self.width), (index-1) % self.width
	button:SetPoint("TOPLEFT", self, "TOPLEFT", col * SLOT_OFFSET, - HEADER_SIZE - row * SLOT_OFFSET)
	if self:IsCollapsed() then
		button:Hide()
	else
		button:Show()
	end
end

function sectionProto:NeedLayout(clean)
	return self.count > self.total or (self.dirty and clean)
end

local floor, ceil, max = math.floor, math.ceil, math.max

function sectionProto:FitInSpace(maxWidth, maxHeight, xOffset, rowHeight)
	local maxColumns = floor((ceil(maxWidth) + ITEM_SPACING) / SLOT_OFFSET)
	local maxRows = floor((ceil(maxHeight) - HEADER_SIZE + ITEM_SPACING) / SLOT_OFFSET)
	if maxColumns * maxRows < self.count then
		return false
	end
	local numColumns, numRows
	if maxColumns >= self.count then
		numColumns, numRows = self.count, 1
	else
		numColumns, numRows = maxColumns, ceil(self.count / maxColumns)
	end
	local height = HEADER_SIZE + ITEM_SIZE * numRows + ITEM_SPACING * max(numRows - 1, 0)
	local available = maxWidth * maxHeight
	local gap = max(0, height - rowHeight) * xOffset
	local occupation = self.count * SLOT_OFFSET * SLOT_OFFSET + numColumns * SLOT_OFFSET * HEADER_SIZE

	local wasted = available + gap - occupation
	if gap < occupation / 2 then
		return true, numColumns, numRows, wasted, height
	end
end

function sectionProto:Layout(width, height, clean, force)
	local sizeChanged = self.width ~= width or self.height ~= height
	local needReorder = sizeChanged or force or self:NeedLayout(clean)
	if sizeChanged then
		self:Debug('NewSize', width, height)
		self.width = width
		self.height = height
		self.total = width * height
		self:SetWidth(ITEM_SIZE * width + ITEM_SPACING * max(width - 1 ,0))
		self:SetHeight(HEADER_SIZE + ITEM_SIZE * height + ITEM_SPACING * max(height - 1, 0))
	end
	if needReorder then
		self:ReorderButtons()
	end
end

local CompareButtons
local buttonOrder = {}
function sectionProto:ReorderButtons()
	if not self:IsVisible() then return end
	self:Debug('ReorderButtons, count=', self.count)
	self.dirty = nil

	if self:IsCollapsed() then
		return self:Hide()
	end

	for button in pairs(self.buttons) do
		button:Show()
		tinsert(buttonOrder, button)
	end
	table.sort(buttonOrder, CompareButtons)

	local slots, freeSlots = self.slots, self.freeSlots
	wipe(freeSlots)
	wipe(slots)
	for index, button in ipairs(buttonOrder) do
		slots[button] = index
		self:PutButtonAt(button, index)
	end
	for index = self.count + 1, self.total do
		freeSlots[index] = true
	end

	wipe(buttonOrder)
end

--------------------------------------------------------------------------------
-- Item sorting
--------------------------------------------------------------------------------

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

local sortingFuncs = {

	default = function(idA, idB, nameA, nameB)
		local _, _, qualityA, levelA, _, classA, subclassA, _, equipSlotA = GetItemInfo(idA)
		local _, _, qualityB, levelB, _, classB, subclassB, _, equipSlotB = GetItemInfo(idB)
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
	end,

	byName = function(idA, idB, nameA, nameB)
		return nameA < nameB
	end,

	byQualityAndLevel = function(idA, idB, nameA, nameB)
		local _, _, qualityA, levelA = GetItemInfo(idA)
		local _, _, qualityB, levelB = GetItemInfo(idB)
		if qualityA ~= qualityB then
			return qualityA > qualityB
		elseif levelA ~= levelB then
			return levelA > levelB
		else
			return nameA < nameB
		end
	end,

}

local currentSortingFunc = sortingFuncs.default

local itemCompareCache = setmetatable({}, {
	__index = function(t, key)
		local idA, idB = strsplit(':', key, 2)
		local nameA, nameB = GetItemInfo(idA), GetItemInfo(idB)
		if nameA and nameB then
			local result = currentSortingFunc(idA, idB, nameA, nameB)
			t[key] = result
			return result
		else
			return idA < idB
		end
	end
})

function addon:SetSortingOrder(order)
	local func = sortingFuncs[order]
	if func and func ~= currentSortingFunc then
		self:Debug('SetSortingOrder', order, func)
		currentSortingFunc = func
		wipe(itemCompareCache)
		self:SendMessage('AdiBags_OrderChanged')
	end
end

function CompareButtons(a, b)
	local idA, idB = a:GetItemId(), b:GetItemId()
	if idA and idB then
		if idA ~= idB then
			return itemCompareCache[format("%d:%d", idA, idB)]
		else
			return a:GetCount() > b:GetCount()
		end
	elseif not idA and not idB then
		local famA, famB = a:GetBagFamily(), b:GetBagFamily()
		if famA and famB and famA ~= famB then
			return famA < famB
		end
	end
	return (idA and 1 or 0) > (idB and 1 or 0)
end
