--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local GetSlotId = addon.GetSlotId
local GetBagSlotFromId = addon.GetBagSlotFromId

local ITEM_SIZE = addon.ITEM_SIZE

--------------------------------------------------------------------------------
-- Button initialization
--------------------------------------------------------------------------------

local buttonClass, buttonProto = addon:NewClass("ItemButton", "Button", "ContainerFrameItemButtonTemplate")

local childrenNames = { "Cooldown", "IconTexture", "IconQuestTexture", "Count", "Stock", "NormalTexture" }

function buttonProto:OnCreate()
	local name = self:GetName()
	for i, childName in pairs(childrenNames ) do
		self[childName] = _G[name..childName]
	end
	self:RegisterForDrag("LeftButton")
	self:RegisterForClicks("LeftButtonUp","RightButtonUp")
	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)
	self:SetScript('OnEvent', self.OnEvent)
	self:SetWidth(ITEM_SIZE)
	self:SetHeight(ITEM_SIZE)
end

function buttonProto:OnAcquire(container, bag, slot)
	self.container = container
	self:SetBagSlot(bag, slot)
end

function buttonProto:OnRelease()
	self.container = nil
	self:SetSection(nil)
	self:SetBagSlot(nil, nil)
end

function buttonProto:ToString()
	return string.format("Button-%s-%s", tostring(self.bag), tostring(self.slot))
end

--------------------------------------------------------------------------------
-- Generic bank button sub-type
--------------------------------------------------------------------------------

local bankButtonClass = addon:NewClass("BankItemButton", "ItemButton")
bankButtonClass.frameTemplate = "BankItemButtonGenericTemplate"

--------------------------------------------------------------------------------
-- Pools and acquistion
--------------------------------------------------------------------------------

local containerButtonPool = addon:CreatePool(buttonClass)
local bankButtonPool = addon:CreatePool(bankButtonClass)

function addon:AcquireItemButton(container, bag, slot)
	if bag == BANK_CONTAINER then
		return bankButtonPool:Acquire(container, bag, slot)
	else
		return containerButtonPool:Acquire(container, bag, slot)
	end
end

--------------------------------------------------------------------------------
-- Model data
--------------------------------------------------------------------------------

function buttonProto:SetBagSlot(bag, slot)
	local oldBag = self.bag
	local changed = bag ~= oldBag or slot ~= self.slot
	if changed then
		self.bag, self.slot = bag, slot
		self.slotId = addon.GetSlotId(bag, slot)
		self:SetParent(bag and addon.itemParentFrames[bag] or nil)
		if bag and slot then
			self:SetID(slot)
			local _, family = GetContainerNumFreeSlots(bag)
			local tag = addon:GetFamilyTag(family)
			if tag then
				self.Stock:SetText(tag)
				self.Stock:Show()
			else
				self.Stock:Hide()
			end
		end
	end
	if bag and slot then
		self:FullUpdate()
	end
	return changed
end

function buttonProto:GetBagSlot()
	return self.bag, self.slot
end

function buttonProto:GetSlotId()
	return self.slotId
end

function buttonProto:SetSection(section)
	local oldSection = self.section
	if oldSection ~= section then
		if oldSection then
			oldSection:RemoveItemButton(self)
		end
		self.section = section
		return true
	end
end

function buttonProto:GetSection()
	return self.section
end

function buttonProto:GetCount()
	return select(2, GetContainerItemInfo(self.bag, self.slot))
end

function buttonProto:IsBankItem()
	return not not addon.BAG_IDS.BANK[self.bag or ""]
end

function buttonProto:IsStack()
	return false
end

--------------------------------------------------------------------------------
-- Scripts & event handlers
--------------------------------------------------------------------------------

function buttonProto:OnShow()
	self:RegisterEvent('BAG_UPDATE_COOLDOWN')
	self:RegisterEvent('ITEM_LOCK_CHANGED')
	self:RegisterEvent('QUEST_ACCEPTED')
	self:RegisterEvent('UNIT_QUEST_LOG_CHANGED')
	self:FullUpdate()
end

function buttonProto:OnHide()
	self:UnregisterAllEvents()
	if self.hasStackSplit and self.hasStackSplit == 1 then
		StackSplitFrame:Hide()
	end
end

function buttonProto:OnEvent(event, ...)
	if not self:IsVisible() or not self.bag or not self.slot then return end
	return self[event](self, event, ...)
end

function buttonProto:BAG_UPDATE_COOLDOWN(event) return self:UpdateCooldown() end
function buttonProto:ITEM_LOCK_CHANGED(event) return self:UpdateLock() end
function buttonProto:QUEST_ACCEPTED(event) return self:UpdateBorder() end
function buttonProto:UNIT_QUEST_LOG_CHANGED(event, unit)	if unit == "player" then return self:UpdateBorder() end end

--------------------------------------------------------------------------------
-- Display updating
--------------------------------------------------------------------------------

function buttonProto:FullUpdate()
	if not self:IsVisible() or not self.bag or not self.slot or addon.holdYourBreath then return end
	if self.container.inUpdate then
		self.container.dirtyButtons[self] = true
		return
	end
	local texture = GetContainerItemInfo(self.bag, self.slot)
	local icon = self.IconTexture
	if texture then
		self.hasItem, self.itemId = true, GetContainerItemID(self.bag, self.slot)
		icon:SetTexture(texture)
		icon:SetTexCoord(0,1,0,1)
	else
		self.hasItem, self.itemId = false, nil
		icon:SetTexture([[Interface\BUTTONS\UI-EmptySlot]])
		icon:SetTexCoord(12/64, 51/64, 12/64, 51/64)
		self.Count:Hide()
	end
	self:UpdateCount()
	self:UpdateBorder()
	self:UpdateCooldown()
	self:UpdateLock()
	addon:SendMessage('AdiBags_UpdateButton', self)
end

function buttonProto:UpdateCount()
	local count = self:GetCount() or 0
	self.count = count or 0
	if count > 1 then
		self.Count:SetText(count)
		self.Count:Show()
	else
		self.Count:Hide()
	end
end

function buttonProto:UpdateLock()
	if self.bag == BANK_CONTAINER then
		BankFrameItemButton_UpdateLocked(self)
	else
		SetItemButtonDesaturated(self, select(3, GetContainerItemInfo(self.bag, self.slot)) and true or false)
	end
end

function buttonProto:UpdateCooldown()
	return ContainerFrame_UpdateCooldown(self.bag, self)
end

function buttonProto:UpdateBorder()
	local itemId = GetContainerItemID(self.bag, self.slot)
	local border = self.IconQuestTexture
	if itemId then
		local texture, r, g, b, a, x1, x2, y1, y2, blendMode = nil, 1, 1, 1, 1, 0, 1, 0, 1, "BLEND"
		local isQuestItem, questId, isActive = GetContainerItemQuestInfo(self.bag, self.slot)
		if addon.db.profile.questIndicator and (questId and not isActive) then
			texture = TEXTURE_ITEM_QUEST_BANG
		elseif addon.db.profile.questIndicator and (questId or isQuestItem) then
			texture = TEXTURE_ITEM_QUEST_BORDER
		elseif addon.db.profile.qualityHighlight then
			local _, _, quality = GetItemInfo(itemId)
			if quality >= ITEM_QUALITY_UNCOMMON then
				r, g, b = GetItemQualityColor(quality)
				texture, x1, x2, y1, y2, blendMode = [[Interface\Buttons\UI-ActionButton-Border]], 14/64, 49/64, 15/64, 50/64, "ADD"
				a = addon.db.profile.qualityOpacity
			end
		end
		if texture then
			border:SetTexture(texture)
			border:SetTexCoord(x1, x2, y1, y2)
			border:SetVertexColor(r, g, b, a)
			border:SetBlendMode(blendMode)
			return border:Show()
		end
	end
	border:Hide()
end

--------------------------------------------------------------------------------
-- Item stack button
--------------------------------------------------------------------------------

local stackClass, stackProto = addon:NewClass("StackButton", "ItemButton")
addon:CreatePool(stackClass, "AcquireStackButton")

function stackProto:OnCreate()
	buttonProto.OnCreate(self)
	self.slots = {}
end

function stackProto:OnAcquire(container, key)
	self.container = container
	self.key = key
	self.count = 0
end

function stackProto:OnRelease()
	self.key = nil
	wipe(self.slots)
	return buttonProto.OnRelease(self)
end

function stackProto:GetCount()
	return self.count
end

function stackProto:IsStack()
	return true
end

function stackProto:GetKey()
	return self.key
end

local function GetSlotCount(slotId)
	local _, count = GetContainerItemInfo(GetBagSlotFromId(slotId))
	return count or 1
end

function stackProto:AddSlot(slotId)
	local slots = self.slots
	if not slots[slotId] then
		local count = GetSlotCount(slotId)
		self.count = self.count + count
		slots[slotId] = count
		if not self.slotId then
			self:SetBagSlot(GetBagSlotFromId(slotId))
		elseif self:IsVisible() then
			self:UpdateCount()
		end
		return true
	end
end

function stackProto:RemoveSlot(slotId)
	local slots = self.slots
	if slots[slotId] then
		self.count = self.count - slots[slotId]
		slots[slotId] = nil
		if slotId == self.slotId then
			local newSlotId = next(slots)
			self:SetBagSlot(GetBagSlotFromId(newSlotId))
		elseif self:IsVisible() then
			self:UpdateCount()
		end
		return true
	end
end

function stackProto:IsEmpty()
	return not next(self.slots)
end
