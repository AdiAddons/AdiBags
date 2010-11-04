--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local BAG_INSET = addon.BAG_INSET
local TOP_PADDING = addon.TOP_PADDING

--------------------------------------------------------------------------------
-- Swaping process
--------------------------------------------------------------------------------

local EmptyBag
do
	local swapFrame = CreateFrame("Frame")
	local otherBags = {}
	local locked = {}
	local currentBag, currentSlot, numSlots

	local function Done()
		swapFrame:UnregisterAllEvents()
		currentBag = nil
		wipe(locked)
		addon:SetGlobalLock(false)		
	end

	local function ProcessInner()
		if not CursorHasItem() then
			while currentSlot < numSlots do
				currentSlot = currentSlot + 1
				if GetContainerItemID(currentBag, currentSlot) then
					PickupContainerItem(currentBag, currentSlot)
					if CursorHasItem() then
						locked[currentBag] = true
						break
					end
				end
			end
		end
		if CursorHasItem() then
			local item = select(3, GetCursorInfo())
			local itemFamily = GetItemFamily(item)
			if select(9, GetItemInfo(item)) == 'INVTYPE_BAG' then
				itemFamily = 0
			end
			for destBag in pairs(otherBags) do
				local freeSlots, bagFamily = GetContainerNumFreeSlots(destBag)
				if freeSlots > 0 and (bagFamily == 0 or bit.band(bagFamily, itemFamily) ~= 0) then
					for destSlot = 1, GetContainerNumSlots(destBag) do
						if not GetContainerItemID(destBag, destSlot) then
							PickupContainerItem(destBag, destSlot)
							if not CursorHasItem() then
								locked[destBag] = true
								return
							end
						end
					end
				end
			end
			ClearCursor()
		end
		Done()
	end

	local function Process()
		local ok, msg = pcall(ProcessInner)
		if not ok then
			Done()
			geterrorhandler()(msg)
		end
	end

	swapFrame:SetScript('OnEvent', function(_, event, bag)
		addon:Debug(event, bag)
		locked[bag] = nil
		if not next(locked) then
			Process()
		end
	end)

	function EmptyBag(bag)
		ClearCursor()
		wipe(otherBags)
		local bags = addon.BAG_IDS.BANK[bag] and addon.BAG_IDS.BANK or addon.BAG_IDS.BAGS
		for otherBag in pairs(bags) do
			if otherBag ~= bag and GetContainerNumSlots(otherBag) > 0 and GetContainerNumFreeSlots(otherBag) > 0 then
				otherBags[otherBag] = true
			end
		end
		if next(otherBags) then
			currentBag, currentSlot, numSlots = bag, 0, GetContainerNumSlots(bag)
			swapFrame:RegisterEvent('BAG_UPDATE')
			addon:SetGlobalLock(true)
			Process()
		end
	end
end

--------------------------------------------------------------------------------
-- Widget scripts
--------------------------------------------------------------------------------

local function Button_OnClick(self, id, button)
	addon:Debug("Button_OnClick", id, self.bag, button)
	if button == "RightButton" then
		if GetContainerNumSlots(self.bag) > 0 then
			return EmptyBag(self.bag)
		end
	elseif not PutItemInBag(id) then
		return PickupBagFromSlot(id)
	end
end

local function BagSlotButton_OnClick(self, button)
	return Button_OnClick(self, self:GetID(), button)
end

local function BankBagButton_OnClick(self, button)
	if self.toPurchase then
		PlaySound("igMainMenuOption")
		StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
	else
		return Button_OnClick(self, self:GetInventorySlot(), button)
	end
end

local function BankBagPanel_UpdateStatus(self)
	local numSlots = GetNumBankSlots()
	for i, button in pairs(self.buttons) do
		button.canPurchase = nil
		if i <= numSlots then
			SetItemButtonTextureVertexColor(button, 1, 1, 1)
			button.tooltipText = BANK_BAG
			button.toPurchase = false
		else
			SetItemButtonTextureVertexColor(button, 1, 0.1, 0.1)
			local cost = GetBankSlotCost(i)
			if i == numSlots + 1 then
				BankFrame.nextSlotCost = cost
				button.tooltipText = strjoin("",
					BANK_BAG_PURCHASE, "\n",
					COSTS_LABEL, " ", GetCoinTextureString(cost), "\n",
					L["Click to purchase"]
				)
				button.toPurchase = true
			else
				button.tooltipText = strjoin("", BANK_BAG_PURCHASE, "\n", COSTS_LABEL, " ", GetCoinTextureString(cost))
				button.toPurchase = false
			end
		end
	end
end

local function RefreshCount(self, onShow)
	if not self:IsVisible() and not onShow then return end
	for i, button in pairs(self.buttons) do
		local total, free = GetContainerNumSlots(button.bag), GetContainerNumFreeSlots(button.bag)
		if total > 0 then
			button.CountText:SetFormattedText("%d", total-free)
			button.CountText:Show()
		else
			button.CountText:Hide()
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
	elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
		BankBagPanel_UpdateStatus(self)
	elseif event == 'PLAYERBANKSLOTS_CHANGED' then
		local slot = ...
		if slot <= NUM_BANKGENERIC_SLOTS then
			return
		end
		for i, button in pairs(self.buttons) do
			BankFrameItemButton_Update(button)
		end
	else
		RefreshCount(self)
	end
end

local function BagPanel_OnShow(self)
	PlaySound("igBackPackOpen")
	self:RegisterEvent('BAG_UPDATE')
	RefreshCount(self, true)
end

local function BagPanel_OnHide(self)
	PlaySound("igBackPackClose")
	self:UnregisterAllEvents()
end

local function BankBagPanel_OnShow(self)
	PlaySound("igMainMenuOpen")
	BagPanel_OnShow(self)
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
	BankBagPanel_UpdateStatus(self)
	for i, button in pairs(self.buttons) do
		BankFrameItemButton_Update(button)
	end
end

local function BankBagPanel_OnHide(self)
	PlaySound("igMainMenuClose")
	self:UnregisterAllEvents()
end

--------------------------------------------------------------------------------
-- Panel creation
--------------------------------------------------------------------------------

function addon:CreateBagSlotPanel(container, name, bags, isBank)
	local self = CreateFrame("Frame", container:GetName().."Bags", container)
	self:SetBackdrop(addon.BACKDROP)
	self:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 4)

	if isBank then
		self:SetScript('OnShow', BankBagPanel_OnShow)
		self:SetScript('OnHide', BankBagPanel_OnHide)
		self:SetScript('OnEvent', BankBagPanel_OnEvent)
	else
		self:SetScript('OnShow', BagPanel_OnShow)
		self:SetScript('OnHide', BagPanel_OnHide)
		self:SetScript('OnEvent', RefreshCount)
	end

	local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetText(L["Equipped bags"])
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
				button:SetScript('OnClick', BankBagButton_OnClick)
			else
				button = CreateFrame("Button", string.format("AdiBag___Bag%dSlot", bag - 1), self, "BagSlotButtonTemplate")
				button.isBag = true
				button:SetScript('OnClick', BagSlotButton_OnClick)
				local normalTexture = button:GetNormalTexture()
				normalTexture:SetWidth(64 * 37 / ITEM_SIZE)
				normalTexture:SetHeight(64 * 37 / ITEM_SIZE)
			end
			button:RegisterForClicks("AnyUp")
			button.bag = bag
			button.isBank = isBank
			button.CountText = _G[button:GetName().."Count"]
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
