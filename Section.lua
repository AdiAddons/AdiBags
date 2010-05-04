--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local SLOT_OFFSET = ITEM_SIZE + ITEM_SPACING
local HEADER_SIZE = 14 + ITEM_SPACING

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

function sectionProto:DispatchDone(event)
	local slots, freeSlots, buttons = self.slots, self.freeSlots, self.buttons
	local count = 0
	for button in pairs(buttons) do
		count = count + 1 
	end
	self.count = count
	self:Debug(count, 'buttons')
	if count > self.width * self.height then
		self.dirtyLayout = true
	end
	return self.dirtyLayout
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
function sectionProto:LayoutButtons(event, forceLayout)
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
	table.sort(buttonOrder, addon.CompareButtons)
	
	self.dirtyLayout = false
	for index, button in ipairs(buttonOrder) do
		self:PutButtonAt(button, index)
	end
	
	wipe(buttonOrder)
	return true
end

