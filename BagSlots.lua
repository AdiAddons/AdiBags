--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local ITEM_SIZE = 37
local ITEM_SPACING = 4
local BAG_INSET = 8
local TOP_PADDING = 32

local BACKDROP = {
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
}

local function BankBagPanel_UpdateStatus(self)
	local numSlots = GetNumBankSlots()
	for i, button in pairs(self.buttons) do
		if i <= numSlots then
			SetItemButtonTextureVertexColor(button, 1.0,1.0,1.0);
			button.tooltipText = BANK_BAG;
		else
			SetItemButtonTextureVertexColor(button, 1.0,0.1,0.1);
			button.tooltipText = BANK_BAG_PURCHASE;
		end
	end
end

local function BankBagPanel_OnEvent(self, event, ...)
	if not self:IsVisible() then return end
	
	if event == "ITEM_LOCK_CHANGED" then
		local bag, slot = ...
		if bag ~= BANK_CONTAINER or slot <= NUM_BANKGENERIC_SLOTS then
			return
		end
		for i, button in pairs(self.buttons) do
			BankFrameItemButton_UpdateLocked(button)
		end		
	elseif event == 'PLAYERBANKSLOTS_CHANGED' then
		local slot = ...
		if slot <= NUM_BANKGENERIC_SLOTS then
			return
		end
		for i, button in pairs(self.buttons) do
			BankFrameItemButton_Update(button)
		end		
	end
end

local function BankBagPanel_OnShow(self)
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	BankBagPanel_UpdateStatus(self)
	for i, button in pairs(self.buttons) do
		BankFrameItemButton_Update(button)
	end
end

local function BankBagPanel_OnHide(self)
	self:UnregisterAllEvents()
end

function addon:CreateBagSlotPanel(container, name, bags, isBank)	
	local self = CreateFrame("Frame", container:GetName().."Bags", container)
	self:SetBackdrop(BACKDROP)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	self:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 4)
	
	if isBank then
		self:SetScript('OnShow', BankBagPanel_OnShow)
		self:SetScript('OnHide', BankBagPanel_OnHide)
		self:SetScript('OnEvent', BankBagPanel_OnEvent)
	end
	
	local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetText(name.." Bags")
	title:SetTextColor(1, 1, 1)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)
	
	table.sort(bags)
	self.buttons = {}
	local x = BAG_INSET
	local height = 0
	for i, bag in ipairs(bags) do
		if bag ~= BACKPACK_CONTAINER and bag ~= BANK_CONTAINER then
			local id, name, template
			if isBank then
				template = "BankItemButtonBagTemplate" 
				id = bag
				name = string.format("AdiBank__Bag%d", id - NUM_BAG_SLOTS)
			else
				template = "BagSlotButtonTemplate"
				id = bag - 1
				name = string.format("AdiBag___Bag%dSlot", id)
			end
			local button = CreateFrame("CheckButton", name, self, template)
			button:SetID(id)
			button:SetPoint("TOPLEFT", x, -TOP_PADDING)
			x = x + button:GetWidth() + ITEM_SPACING
			height = button:GetHeight()
			tinsert(self.buttons, button)
		end
	end
	
	self:SetWidth(x + BAG_INSET)
	self:SetHeight(BAG_INSET + TOP_PADDING + height)

	return self
end

