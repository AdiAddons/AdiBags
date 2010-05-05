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
addon:CreatePool(buttonClass, "AcquireItemButton")

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

function buttonProto:OnRelease()
	self:SetSection(nil)
	self:SetBagSlot(nil, nil)
end

function buttonProto:ToString()
	return string.format("Button-%s-%s", tostring(self.bag), tostring(self.slot))
end

--------------------------------------------------------------------------------
-- Button sub-types
--------------------------------------------------------------------------------

local scripts = {}
do
	local templates = {
		bank = CreateFrame("Button", addonName.."BankButtonRef", nil, "BankItemButtonGenericTemplate"),
		container = CreateFrame("Button", addonName.."ContainerButtonRef", nil, "ContainerFrameItemButtonTemplate"),
	}
	local scriptNames = { "OnClick", "OnEnter", "OnLeave", "OnReceiveDrag", "OnDragStart" }
	for name, button in pairs(templates) do
		scripts[name] = {}
		for _, scriptName in pairs(scriptNames) do
			scripts[name][scriptName] = button:GetScript(scriptName)
		end
	end
end

local function ContainerButton_SplitStack(button, split)
	SplitContainerItem(button:GetParent():GetID(), button:GetID(), split)
end

local function BankButton_SplitStack(button, split)
	SplitContainerItem(BANK_CONTAINER, button:GetID(), split)
end

function buttonProto:SetGenericBank(isGenericBank)
	if isGenericBank == self.isGenericBank then return end
	self.isGenericBank = isGenericBank

	local shown = self:IsShown()
	if shown then self:Hide() end

	local buttonScripts
	if isGenericBank then
		buttonScripts = scripts.bank
		self.SplitStack = BankButton_SplitStack
		self.GetInventorySlot = ButtonInventorySlot
	else
		buttonScripts = scripts.container
		self.SplitStack = ContainerButton_SplitStack
		self.GetInventorySlot = nil
	end
	for name, func in pairs(buttonScripts) do
		self:SetScript(name, func)
	end
	self.UpdateTooltip = buttonScripts.OnEnter

	if shown then self:Show() end
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
		self:SetGenericBank(bag == BANK_CONTAINER)
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
		self:FullUpdate('OnSetBagSlot')
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
	self:FullUpdate('OnShow')
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

function buttonProto:BAG_UPDATE_COOLDOWN(event) return self:UpdateCooldown(event) end
function buttonProto:ITEM_LOCK_CHANGED(event) return self:UpdateLock(event) end
function buttonProto:QUEST_ACCEPTED(event) return self:UpdateBorder(event) end
function buttonProto:UNIT_QUEST_LOG_CHANGED(event, unit)	if unit == "player" then return self:UpdateBorder(event) end end

--------------------------------------------------------------------------------
-- Display updating
--------------------------------------------------------------------------------

function buttonProto:FullUpdate(event)
	if not self:IsVisible() or not self.bag or not self.slot then return end
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
	self:UpdateCount(event)
	self:UpdateBorder(event)
	self:UpdateCooldown(event)
	self:UpdateLock(event)
	self:UpdateSearchStatus(event)
end

function buttonProto:UpdateCount(event)
	local count = self:GetCount()
	self.count = count or 0
	if count > 1 then
		self.Count:SetText(count)
		self.Count:Show()
	else
		self.Count:Hide()
	end	
end

function buttonProto:UpdateLock(event)
	if self.bag == BANK_CONTAINER then
		BankFrameItemButton_UpdateLocked(self)
	else
		SetItemButtonDesaturated(self, select(3, GetContainerItemInfo(self.bag, self.slot)) and true or false)		
	end
end

function buttonProto:UpdateCooldown(event)
	return ContainerFrame_UpdateCooldown(self.bag, self)
end

function buttonProto:UpdateBorder(event)
	local itemId = GetContainerItemID(self.bag, self.slot)
	local border = self.IconQuestTexture
	if itemId then
		local texture, r, g, b, a, x1, x2, y1, y2, blendMode = nil, 1, 1, 1, 1, 0, 1, 0, 1, "BLEND"
		local isQuestItem, questId, isActive = GetContainerItemQuestInfo(self.bag, self.slot)
		if questId and not isActive then
			texture = TEXTURE_ITEM_QUEST_BANG
		elseif questId or isQuestItem then
			texture = TEXTURE_ITEM_QUEST_BORDER
		else
			local _, _, quality = GetItemInfo(itemId)
			if quality >= ITEM_QUALITY_UNCOMMON then
				r, g, b = GetItemQualityColor(quality)
				texture, x1, x2, y1, y2, a, blendMode = [[Interface\Buttons\UI-ActionButton-Border]], 14/64, 49/64, 15/64, 50/64, 1, "ADD"
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

function buttonProto:UpdateSearchStatus(event)
	local text = addon:GetSearchText()
	local selected = true
	if text and self.hasItem then
		local name = GetItemInfo(self.itemId)
		if name and not name:lower():match(text:lower()) then
			selected = false
		end
	end
	if selected then
		self:SetAlpha(1)
	else
		self:SetAlpha(0.3)
	end
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

function stackProto:OnAcquire(key)
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
			self:UpdateCount('OnSlotAdded')
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
			self:UpdateCount('OnSlotRemoved')
		end
		return true
	end
end

function stackProto:IsEmpty()
	return not next(self.slots)
end
