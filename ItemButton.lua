--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local parents = setmetatable({}, {
	__index = function(self, id)
		local frame = CreateFrame("Frame", addonName.."Bag"..id, UIParent)
		frame:SetID(id)
		self[id] = frame
		return frame
	end
})

local buttonProto = setmetatable({
	Debug = addon.Debug
}, { __index = CreateFrame("Button", nil, nil, "ContainerFrameItemButtonTemplate") })
local buttonMeta = { __index = buttonProto }
local buttonCount = 1
local heap = {}

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
	self.bag, self.slot = nil, nil
	self:UnregisterAllEvents()
	self:Hide()
	self:SetParent(nil)
	self:ClearAllPoints()
	heap[self] = true
end

local childrenNames = { "Cooldown", "IconTexture", "IconQuestTexture", "Count" } --, "NormalTexture" }

function buttonProto:OnCreate()
	local name = self:GetName()
	for i, childName in pairs(childrenNames ) do
		self[childName] = _G[name..childName]
	end
	_G[name.."Stock"]:Hide()
	self:SetScript('OnShow', self.FullUpdate)
	self:SetScript('OnEvent', self.OnEvent)
end

function buttonProto:OnAcquire()
	self:RegisterEvent('BAG_UPDATE')
	self:RegisterEvent('BAG_UPDATE_COOLDOWN')
	self:RegisterEvent('ITEM_LOCK_CHANGED')
	self:RegisterEvent('QUEST_ACCEPTED')
	self:RegisterEvent('UNIT_QUEST_LOG_CHANGED')
end

function buttonProto:SetBagSlot(bag, slot)
	if bag ~= self.bag or slot ~= self.slot then
		self.bag, self.slot = bag, slot
		self:SetParent(bag and parents[bag] or nil)
		self:SetID(slot)
		self:FullUpdate('OnSetSlot')
	end
end

function buttonProto:OnEvent(event, ...)
	if not self:IsVisible() or not self.bag or not self.slot then return end
	return self[event](self, event, ...)
end

function buttonProto:BAG_UPDATE(event, bag) if bag == self.bag then return self:FullUpdate(event) end end
function buttonProto:BAG_UPDATE_COOLDOWN(event) return self:UpdateCooldown(event) end
function buttonProto:ITEM_LOCK_CHANGED(event) return self:UpdateLock(event) end
function buttonProto:QUEST_ACCEPTED(event) return self:UpdateBorder(event) end
function buttonProto:UNIT_QUEST_LOG_CHANGED(event, unit)	if unit == "player" then return self:UpdateBorder(event) end end

function buttonProto:FullUpdate(event)
	if not self:IsVisible() or not self.bag or not self.slot then return end	
	local texture, count = GetContainerItemInfo(self.bag, self.slot)
	if texture then
		self.IconTexture:SetTexture(texture)
		self.IconTexture:Show()
		
		if count and count > 1 then
			self.Count:SetText(count)
			self.Count:Show()
		else
			self.Count:Hide()
		end
		
	else
		self.IconTexture:Hide()
		self.Count:Hide()
		self.IconQuestTexture:Hide()
	end
	
	self:UpdateLock(event)
	self:UpdateBorder(event)
	self:UpdateCooldown(event)
end

function buttonProto:UpdateLock(event)
	SetItemButtonDesaturated(self, select(3, GetContainerItemInfo(self.bag, self.slot)) and true or false)
end

function buttonProto:UpdateBorder(event)
	local icon, _, _, quality = GetContainerItemInfo(self.bag, self.slot)
	local border = self.IconQuestTexture
	if icon then
		local texture, r, g, b, a, x1, x2, y1, y2 = nil, 1, 1, 1, 1, 0, 0, 1, 1
		local isQuestItem, questId, isActive = GetContainerItemQuestInfo(self.bag, self.slot)
		if questId and not isActive then
			texture = TEXTURE_ITEM_QUEST_BANG
		elseif questId or isQuestItem then
			texture = TEXTURE_ITEM_QUEST_BORDER
		elseif quality >= ITEM_QUALITY_UNCOMMON then
			local color = ITEM_QUALITY_COLORS[quality]
			if color then
				texture, x1, x2, y1, y2 = [[Interface\Buttons\UI-ActionButton-Border]], 14/64, 15/64, 48/64, 49/64
				r, g, b, a = color.r, color.g, color.b, 0.5
			end
		end
		if texture then
			border:SetTexture(texture)
			border:SetTexCoord(x1, x2, y1, y2)
			border:SetVertexColor(r, g, b, a)
			return border:Show()
		end
	end
	border:Hide()
end

function buttonProto:UpdateCooldown(event)
	local start, duration, enable =  GetContainerItemCooldown(self.bag, self.slot)
	if enable == 1 and start and start > 0 then
		self.Cooldown:SetCooldown(start, duration)
		self.Cooldown:Show()
	else
		self.Cooldown:Hide()
	end
end
