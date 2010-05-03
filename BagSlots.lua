--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local BAG_INSET = addon.BAG_INSET
local TOP_PADDING = addon.TOP_PADDING

local function BankBagPanel_UpdateStatus(self)
	local numSlots = GetNumBankSlots()
	for i, button in pairs(self.buttons) do
		if i <= numSlots then
			SetItemButtonTextureVertexColor(button, 1, 1, 1)
			button.tooltipText = BANK_BAG
		else
			SetItemButtonTextureVertexColor(button, 1, 0.1, 0.1)
			button.tooltipText = BANK_BAG_PURCHASE
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
	self:SetBackdrop(addon.BACKDROP)
	self:SetBackdropColor(0, 0, 0, 1)
	self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	self:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 4)
	
	if isBank then
		self:SetScript('OnShow', BankBagPanel_OnShow)
		self:SetScript('OnHide', BankBagPanel_OnHide)
		self:SetScript('OnEvent', BankBagPanel_OnEvent)
	end
	
	local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetText("Equipped bags")
	title:SetTextColor(1, 1, 1)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)
	
	table.sort(bags)
	self.buttons = {}
	local x = BAG_INSET
	local height = 0
	for i, bag in ipairs(bags) do
		if bag ~= BACKPACK_CONTAINER and bag ~= BANK_CONTAINER then
			local button
			local id, name, template
			if isBank then
				button = CreateFrame("Button", string.format("AdiBank__Bag%d", bag - NUM_BAG_SLOTS), self, "BankItemButtonBagTemplate")
				button:SetID(bag)
			else
				button = CreateFrame("CheckButton", string.format("AdiBag___Bag%dSlot", bag - 1), self, "BagSlotButtonTemplate")
				local normalTexture = button:GetNormalTexture()
				normalTexture:SetWidth(64 * 37 / ITEM_SIZE)
				normalTexture:SetHeight(64 * 37 / ITEM_SIZE)
			end
			button:SetWidth(ITEM_SIZE)
			button:SetHeight(ITEM_SIZE)
			button:SetPoint("TOPLEFT", x, -TOP_PADDING)
			x = x + ITEM_SIZE + ITEM_SPACING
			tinsert(self.buttons, button)
		end
	end
	
	self:SetWidth(x + BAG_INSET)
	self:SetHeight(BAG_INSET + TOP_PADDING + ITEM_SIZE)

	return self
end

