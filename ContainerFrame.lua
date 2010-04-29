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
local BAG_WIDTH = 10
local BAG_INSET = 8

local BACKDROP = {
		bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
		tile = true, tileSize = 16, edgeSize = 16, 
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
}

function addon:CreateContainerFrame(name, bags, isBank)
	local container = setmetatable(CreateFrame("Frame", addonName..name, UIParent), containerMeta)
	container:ClearAllPoints()
	container:Hide()
	
	container:SetBackdrop(BACKDROP)
	container:SetBackdropColor(0, 0, 0, 1)
	container:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	
	container:SetScript('OnShow', container.OnShow)
	container:SetScript('OnHide', container.OnHide)
	container.bags = bags
	container.isBank = isBank
	
	container.content = {}
	for bag in pairs(bags) do
		container.content[bag] = {}
	end
	
	container.buttons = {}
	container:Debug('Created')
	return container
end

function containerProto:OnShow()
	self:Debug('OnShow')
	if self.isBank then
		self:RegisterEvent('BANKFRAME_CLOSED', "Hide")
	end
	self:RegisterBucketEvent('BAG_UPDATE', 0.5, "BagsUpdated")
	for bag in pairs(self.bags) do
		self:UpdateContent("OnShow", bag)
	end
	if self.dirty then
		return self:FullUpdate('OnShow')
	end
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

function containerProto:SetupItemButton(index, bag, slot)
	local button = self.buttons[index]
	if not button then
		button = addon:AcquireItemButton()
		button:SetWidth(ITEM_SIZE)
		button:SetHeight(ITEM_SIZE)
		self.buttons[index] = button
	end
	local col, row = (index-1) % BAG_WIDTH, math.floor((index-1) / BAG_WIDTH)
	button:SetPoint('TOPLEFT', self, 'TOPLEFT',
		BAG_INSET + col * (ITEM_SIZE + ITEM_SPACING),
		- (BAG_INSET + row * (ITEM_SIZE + ITEM_SPACING))
	)
	button:SetBagSlot(bag, slot)
	button:Show()
end

function containerProto:ReleaseItemButton(index)
	local button = self.buttons[index]
	if not button then return end
	self.buttons[index] = nil
	return button:Release()
end

local empties = {}
function containerProto:FullUpdate(event)
	if not self.dirty then return end
	self:Debug('Updating on', event)
	self.dirty = nil
	local count = 0
	wipe(empties)
	for bag, content in pairs(self.content) do
		for slot = 1, content.size do
			local data = content[slot]
			if data then
				count = count + 1
				self:SetupItemButton(count, bag, slot)
			else
				tinsert(empties, bag..':'..slot)
			end
		end
	end
	for i, data in ipairs(empties) do	
		local bag, slot = strsplit(':', data)
		bag, slot = tonumber(bag), tonumber(slot)
		count = count + 1
		self:SetupItemButton(count, bag, slot)
	end
	for unused = count+1, #self.buttons do
		self:ReleaseItemButton(unused)
	end
	self:Debug(count, 'items')
	local cols = math.min(BAG_WIDTH, count)
	local rows = math.ceil(count / BAG_WIDTH)
	self:SetWidth(BAG_INSET * 2 + cols * ITEM_SIZE + math.max(0, cols-1) * ITEM_SPACING)
	self:SetHeight(BAG_INSET * 2 + rows * ITEM_SIZE + math.max(0, rows-1) * ITEM_SPACING)
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
		return self:FullUpdate(event)
	else
		for i, button in pairs(self.buttons) do
			button:BAG_UPDATE(event, bags)
		end
	end
end
