--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local buttonProto = setmetatable({
	Debug = addon.Debug
}, { __index = CreateFrame("Button", nil, nil, "ContainerFrameItemButtonTemplate") })
local buttonMeta = { __index = buttonProto }
local buttonCount = 1
local heap = {}
LibStub('AceEvent-3.0'):Embed(buttonProto)
--LibStub('AceBucket-3.0'):Embed(buttonProto)

function addon:AcquireItemButton()
	local button = next(heap)
	if button then
		heap[button] = nil
	else
		button = setmetatable(CreateFrame("Button", addonName.."ItemButton"..buttonCount, nil, "ContainerFrameItemButtonTemplate"), buttonMeta)
		buttonCount = buttonCount + 1
		button:ClearAllPoints()
		button:Hide()
		button:OnCreate()
	end
	button:OnAcquire()
	return button
end

function buttonProto:Release()
	self:UnregisterAllEvents()
	--self:UnregisterAllBuckets()
	self:SetBagSlot(nil, nil)
	self:Hide()
	self:SetParent(nil)
	self:ClearAllPoints()
	heap[self] = true
end

local childrenNames = { "Cooldown", "IconTexture", "IconQuestTexture", "Count", "Stock", "NormalTexture" }

function buttonProto:OnCreate()
	local name = self:GetName()
	for i, childName in pairs(childrenNames ) do
		self[childName] = _G[name..childName]
	end
	self:SetScript('OnShow', function() self:FullUpdate('OnShow') end)
	self:SetScript('OnEvent', self.OnEvent)
end

function buttonProto:OnAcquire()
	self:RegisterEvent('BAG_UPDATE_COOLDOWN')
	self:RegisterEvent('ITEM_LOCK_CHANGED')
	self:RegisterEvent('QUEST_ACCEPTED')
	self:RegisterEvent('UNIT_QUEST_LOG_CHANGED')
end

function buttonProto:SetBagSlot(bag, slot)
	local changed = bag ~= self.bag or slot ~= self.slot
	if changed then
		self.bag, self.slot = bag, slot
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
		self:FullUpdate('OnSetBagSlot')
	end
	return changed
end

function buttonProto:SetStackable(stackType, stackData)
	local changed = self.stackType ~= stackType or self.stackData ~= stackData
	if changed then
		self.stackType, self.stackData = stackType, stackData
		self:FullUpdate('OnSetStackable')
	end
	return changed
end

function buttonProto:GetCount()
	local count, _ = 0
	if self.stackType == "free" then
		local bags = self:IsBankItem() and addon.BAG_IDS.BANK or addon.BAG_IDS.BAGS
		for bag in pairs(bags) do
			local free, family = GetContainerNumFreeSlots(bag)
			if family == self.stackData then
				count = count + free
			end
		end
	elseif self.stackType == "item" then
		if self:IsBankItem() then
			count = GetItemCount(self.stackData, true) - GetItemCount(self.stackData)
		else
			count = GetItemCount(self.stackData)
		end
	else
		_, count = GetContainerItemInfo(self.bag, self.slot)
	end
	return count
end

function buttonProto:IsBankItem()
	return not not addon.BAG_IDS.BANK[self.bag or ""]
end

--[[
function buttonProto:HasItem()
	return self.bag and self.slot and not not GetContainerItemID(self.bag, self.slot) or false
end
--]]

function buttonProto:OnEvent(event, ...)
	if not self:IsVisible() or not self.bag or not self.slot then return end
	return self[event](self, event, ...)
end

function buttonProto:BAG_UPDATE(event, bag)
	if bag == self.bag then return self:FullUpdate(event) end
end

function buttonProto:BAG_UPDATE_COOLDOWN(event) return self:UpdateCooldown(event) end
function buttonProto:ITEM_LOCK_CHANGED(event) return self:UpdateLock(event) end
function buttonProto:QUEST_ACCEPTED(event) return self:UpdateBorder(event) end
function buttonProto:UNIT_QUEST_LOG_CHANGED(event, unit)	if unit == "player" then return self:UpdateBorder(event) end end

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
	local count = self:GetCount()
	if count and count > 1 then
		self.Count:SetText(count)
		self.Count:Show()
	else
		self.Count:Hide()
	end	
	self:UpdateBorder(event)
	self:UpdateCooldown(event)
	self:UpdateLock(event)
	self:UpdateSearchStatus(event)
end

function buttonProto:UpdateLock(event)
	SetItemButtonDesaturated(self, select(3, GetContainerItemInfo(self.bag, self.slot)) and true or false)
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

function buttonProto:UpdateCooldown(event)
	return ContainerFrame_UpdateCooldown(self.bag, self)
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

