--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local SLOT_OFFSET = ITEM_SIZE + ITEM_SPACING
local HEADER_SIZE = 14 + ITEM_SPACING

local SECTION_ORDER = {
	[L["New"]] = 10,
	[L["Free space"]] = -10,
}

--------------------------------------------------------------------------------
-- Initialization and release
--------------------------------------------------------------------------------

local sectionClass, sectionProto = addon:NewClass("Section", "Frame")
addon:CreatePool(sectionClass, "AcquireSection")

function sectionProto:OnCreate()
	self.buttons = {}
	self.slots = {}
	self.freeSlots = {}

	self.width = 0
	self.height = 0
	self.count = 0

	local header = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_SIZE)
	header:SetJustifyH("LEFT")
	header:SetJustifyV("TOP")
	self.header = header
end

function sectionProto:OnAcquire(container, name)
	self:SetParent(container)
	self.header:SetText(name)
	self.name = name
	self.order = SECTION_ORDER[name] or 0
	self.container = container
end

function sectionProto:ToString()
	return string.format("Section-%s", tostring(self.name))
end

function sectionProto:OnRelease()
	wipe(self.freeSlots)
	wipe(self.slots)
	wipe(self.buttons)
	self.width = 0
	self.height = 0
	self.count = 0
	self.container = nil
end

--------------------------------------------------------------------------------
-- Button handling
--------------------------------------------------------------------------------

function sectionProto:AddItemButton(slotId, button)
	if not self.buttons[button] then
		button:SetSection(self)
		self.buttons[button] = slotId
		if self.slots[button] then
			return
		end
		local freeSlots = self.freeSlots
		for index = 1, self.width * self.height do
			if freeSlots[index] then
				self:PutButtonAt(button, index)
				return
			end
		end
		self.dirtyLayout = true
	end
end

function sectionProto:RemoveItemButton(button)
	if self.buttons[button] then
		local index = self.slots[button]
		if index then
			self.freeSlots[index] = true
			self.slots[button] = nil
		end
		self.buttons[button] = nil
	end
end

function sectionProto:DispatchDone()
	local slots, freeSlots, buttons = self.slots, self.freeSlots, self.buttons
	local count = 0
	for button in pairs(buttons) do
		count = count + 1
	end
	if (count == 0 and self.count > 0) or count > self.width * self.height then
		self.dirtyLayout = true
	end
	self.count = count
	self:Debug(count, 'buttons')
	return self.dirtyLayout
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

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

function sectionProto:PutButtonAt(button, index)
	self.slots[button] = index
	if index and self.width > 0 then
		self.freeSlots[index] = nil
		if not self.dirtyLayout then
			local row, col = math.floor((index-1) / self.width), (index-1) % self.width
			button:SetPoint("TOPLEFT", self, "TOPLEFT", col * SLOT_OFFSET, - HEADER_SIZE - row * SLOT_OFFSET)
			button:Show()
		end
	else
		self.dirtyLayout = true
	end
end

function sectionProto:SetSize(width, height)
	if self.width == width and self.height == height then return end
	self:Debug('Setting size to ', width, height)
	self.width = width
	self.height = height
	self:SetWidth(math.max(ITEM_SIZE * width + ITEM_SPACING * math.max(width - 1 ,0), self.header:GetStringWidth()))
	self:SetHeight(HEADER_SIZE + ITEM_SIZE * height + ITEM_SPACING * math.max(height - 1, 0))
	self.dirtyLayout = true
end

local buttonOrder = {}
function sectionProto:LayoutButtons(forceLayout)
	if self.count == 0 then
		return false
	elseif not forceLayout and not self.dirtyLayout then
		return true
	end

	local width = math.min(self.count, addon.BAG_WIDTH)
	local height = math.ceil(self.count / math.max(width, 1))
	self:SetSize(width, height)

	wipe(self.freeSlots)
	wipe(self.slots)
	for index = 1, width * height do
		self.freeSlots[index] = true
	end

	for button in pairs(self.buttons) do
		tinsert(buttonOrder, button)
	end
	table.sort(buttonOrder, CompareButtons)

	self.dirtyLayout = false
	for index, button in ipairs(buttonOrder) do
		self:PutButtonAt(button, index)
	end

	wipe(buttonOrder)
	return true
end

