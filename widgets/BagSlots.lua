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
	local timeout = 0
	local currentBag, currentSlot, numSlots

	function swapFrame:Done()
		self:UnregisterAllEvents()
		self:Hide()
		currentBag = nil
		wipe(locked)
		addon:SetGlobalLock(false)
	end

	local CanPutItemInContainer = addon.CanPutItemInContainer

	function swapFrame:ProcessInner()
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
			for i, destBag in ipairs(otherBags) do
				if CanPutItemInContainer(item, destBag) then
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
		self:Done()
	end

	function swapFrame:Process()
		local ok, msg = pcall(self.ProcessInner, self)
		if not ok then
			self:Done()
			geterrorhandler()(msg)
		else
			timeout = 2
			self:Show()
		end
	end

	swapFrame:Hide()
	swapFrame:SetScript('OnUpdate', function(self, elapsed)
		if elapsed > timeout then
			self:Done()
		else
			timeout = timeout - elapsed
		end
	end)

	swapFrame:SetScript('OnEvent', function(self, event, bag)
		addon:Debug(event, bag)
		locked[bag] = nil
		if not next(locked) then
			self:Process()
		end
	end)

	function EmptyBag(bag)
		ClearCursor()
		wipe(otherBags)
		local bags = addon.BAG_IDS.BANK[bag] and addon.BAG_IDS.BANK or addon.BAG_IDS.BAGS
		for otherBag in pairs(bags) do
			if otherBag ~= bag and GetContainerNumSlots(otherBag) > 0 and GetContainerNumFreeSlots(otherBag) > 0 then
				tinsert(otherBags, otherBag)
			end
		end
		if #otherBags > 0 then
			table.sort(otherBags)
			currentBag, currentSlot, numSlots = bag, 0, GetContainerNumSlots(bag)
			addon:SetGlobalLock(true)
			swapFrame:RegisterEvent('BAG_UPDATE')
			swapFrame:Process()
		end
	end
end

--------------------------------------------------------------------------------
-- Regular bag buttons
--------------------------------------------------------------------------------

local bagButtonClass, bagButtonProto = addon:NewClass("BagSlotButton", "Button", "ItemButtonTemplate", "AceEvent-3.0")

function bagButtonProto:OnCreate(bag)
	self.bag = bag
	self.invSlot = ContainerIDToInventoryID(bag)

	self:GetNormalTexture():SetSize(64 * 37 / ITEM_SIZE, 64 * 37 / ITEM_SIZE)
	self:SetSize(ITEM_SIZE, ITEM_SIZE)

	self:EnableMouse(true)
	self:RegisterForDrag("LeftButton")
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)
	self:SetScript('OnEnter', self.OnEnter)
	self:SetScript('OnLeave', self.OnLeave)
	self:SetScript('OnDragStart', self.OnDragStart)
	self:SetScript('OnReceiveDrag', self.OnClick)
	self:SetScript('OnClick', self.OnClick)
	self.UpdateTooltip = self.OnEnter

	self.Count = _G[self:GetName().."Count"]
end

function bagButtonProto:UpdateLock()
	if addon.globalLock then
		self:Disable()
		SetItemButtonDesaturated(self, true)
	else
		self:Enable()
		SetItemButtonDesaturated(self, IsInventoryItemLocked(self.invSlot))
	end
end

function bagButtonProto:Update()
	local icon = GetInventoryItemTexture("player", self.invSlot)
	self.hasItem = not not icon
	if self.hasItem then
		local total, free = GetContainerNumSlots(self.bag), GetContainerNumFreeSlots(self.bag)
		if total > 0 then
			self.isEmpty = (total == free)
			self.Count:SetFormattedText("%d", total-free)
			if free == 0 then
				self.Count:SetTextColor(1, 0, 0)
			else
				self.Count:SetTextColor(1, 1, 1)
			end
			self.Count:Show()
		else
			self.Count:Hide()
		end
	else
		icon = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]
		self.Count:Hide()
	end
	SetItemButtonTexture(self, icon)
	self:UpdateLock()
end

function bagButtonProto:OnShow()
	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("ITEM_LOCK_CHANGED")
	self:RegisterMessage("AdiBags_GlobalLockChanged", "Update")
	self:Update()
end

function bagButtonProto:OnHide()
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()
end

function bagButtonProto:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if not GameTooltip:SetInventoryItem("player", self.invSlot) then
		if self.tooltipText then
			GameTooltip:SetText(self.tooltipText)
		end
	elseif not self.isEmpty then
		GameTooltip:AddLine(L['Right-click to try to empty this bag.'])
		GameTooltip:Show()
	end
	CursorUpdate(self)
end

function bagButtonProto:OnLeave()
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

local pendingUpdate = {}

function bagButtonProto:OnClick(button)
	if self.hasItem and button == "RightButton" then
		if not self.isEmpty then
			EmptyBag(self.bag)
		end
	else
		if not PutItemInBag(self.invSlot) then
			PickupBagFromSlot(self.invSlot)
		end
		pendingUpdate[self.invSlot] = true
	end
end

function bagButtonProto:OnDragStart()
	if self.hasItem then
		PickupBagFromSlot(self.invSlot)
		pendingUpdate[self.invSlot] = true
	end
end

function bagButtonProto:BAG_UPDATE(event, bag, ...)
	if bag == self.bag then
		return self:Update()
	end
end

function bagButtonProto:ITEM_LOCK_CHANGED(event, invSlot, containerSlot)
	if not (containerSlot and invSlot == self.invSlot) or pendingUpdates[self.invSlot] then
		return self:Update()
	end
end

--------------------------------------------------------------------------------
-- Bank bag buttons
--------------------------------------------------------------------------------

local bankButtonClass, bankButtonProto = addon:NewClass("BankSlotButton", "BagSlotButton")

function bankButtonProto:OnClick(button)
	if self.toPurchase then
		PlaySound("igMainMenuOption")
		StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
	else
		return bagButtonProto.OnClick(self, button)
	end
end

function bankButtonProto:UpdateStatus()
	local numSlots = GetNumBankSlots()
	local bankSlot = self.bag - NUM_BAG_SLOTS
	self.toPurchase = nil
	if bankSlot <= numSlots then
		SetItemButtonTextureVertexColor(self, 1, 1, 1)
		self.tooltipText = BANK_BAG
	else
		SetItemButtonTextureVertexColor(self, 1, 0.1, 0.1)
		local cost = GetBankSlotCost(bankSlot)
		if bankSlot == numSlots + 1 then
			BankFrame.nextSlotCost = cost
			self.tooltipText = strjoin("",
				BANK_BAG_PURCHASE, "\n",
				COSTS_LABEL, " ", GetCoinTextureString(cost), "\n",
				L["Click to purchase"]
			)
			self.toPurchase = true
		else
			self.tooltipText = strjoin("", BANK_BAG_PURCHASE, "\n", COSTS_LABEL, " ", GetCoinTextureString(cost))
		end
	end
end

function bankButtonProto:Update()
	bagButtonProto.Update(self)
	self:UpdateStatus()
end

function bankButtonProto:PLAYERBANKSLOTS_CHANGED(event, bankSlot)
	if bankSlot - NUM_BANKGENERIC_SLOTS == self.bag - NUM_BAG_SLOTS then
		self:Update()
	end
end

function bankButtonProto:OnShow()
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED", "UpdateStatus")
	self:RegisterEvent("PLAYER_MONEY", "UpdateStatus")
	bagButtonProto.OnShow(self)
end

--------------------------------------------------------------------------------
-- Backpack bag panel scripts
--------------------------------------------------------------------------------

local function Panel_OnShow(self)
	PlaySound(self.openSound)
	addon:SendMessage('AdiBags_FiltersChanged')
end

local function Panel_OnHide(self)
	PlaySound(self.closeSound)
	addon:SendMessage('AdiBags_FiltersChanged')
end

--------------------------------------------------------------------------------
-- Panel creation
--------------------------------------------------------------------------------

function addon:CreateBagSlotPanel(container, name, bags, isBank)
	local self = CreateFrame("Frame", container:GetName().."Bags", container)
	self:SetBackdrop(addon.BACKDROP)
	self:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, 4)

	self.openSound = isBank and "igMainMenuOpen" or "igBackPackOpen"
	self.closeSound = isBank and "igMainMenuClose" or "igBackPackClose"
	self:SetScript('OnShow', Panel_OnShow)
	self:SetScript('OnHide', Panel_OnHide)

	local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetText(L["Equipped bags"])
	title:SetTextColor(1, 1, 1)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOPLEFT", BAG_INSET, -BAG_INSET)

	table.sort(bags)
	self.buttons = {}
	local buttonClass = isBank and bankButtonClass or bagButtonClass
	local x = BAG_INSET
	local height = 0
	for i, bag in ipairs(bags) do
		if bag ~= BACKPACK_CONTAINER and bag ~= BANK_CONTAINER then
			local button = buttonClass:Create(bag)
			button:SetParent(self)
			button:SetPoint("TOPLEFT", x, -TOP_PADDING)
			button:Show()
			x = x + ITEM_SIZE + ITEM_SPACING
			tinsert(self.buttons, button)
		end
	end

	self:SetWidth(x + BAG_INSET)
	self:SetHeight(BAG_INSET + TOP_PADDING + ITEM_SIZE)

	return self
end
