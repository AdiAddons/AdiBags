--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local CreateFrame = _G.CreateFrame
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetInventoryItemID = _G.GetInventoryItemID
local GetInventoryItemLink = _G.GetInventoryItemLink
local next = _G.next
local pairs = _G.pairs
local PlaySound = _G.PlaySound
local strmatch = _G.strmatch
local tonumber = _G.tonumber
local type = _G.type
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local mod = addon:RegisterFilter('NewItem', 80, 'AceEvent-3.0', 'AceBucket-3.0', 'AceTimer-3.0')
mod.uiName = L['Track new items']
mod.uiDesc = L['Track new items in each bag, displaying a glowing aura over them and putting them in a special section. "New" status can be reset by clicking on the small "N" button at top left of bags.']

local bags = {}
local inventory = {}
local glows = {}
local frozen = false
local inventoryScanned = false
local initializing = false
local bagUpdateBucket

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			showGlow = true,
			glowScale = 1.5,
			glowColor = { 0.3, 1, 0.3, 0.7 },
			ignoreJunk = false,
		},
	})
	addon:SetCategoryOrder(L['New'], 100)
end

function mod:OnEnable()

	for i, bag in addon:IterateDefinedBags() do
		if not bags[bag.bagName] then
			self:Debug('Adding bag', bag, bag.bagName, bag.bagIds)
			local data = {
				bagIds = bag.bagIds,
				isBank = bag.isBank,
				obj = bag,
				counts = {},
				newItems = {},
				first = true,
			}
			bags[bag.bagName] = data
		end
	end

	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	for name, bag in pairs(bags) do
		if bag.button then
			bag.button:Show()
		end
	end

	self:RegisterMessage('AdiBags_PreFilter')
	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')

	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING')
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED')
	self:RegisterEvent('UNIT_INVENTORY_CHANGED')

	initializing = true
	bagUpdateBucket = self:RegisterBucketEvent('BAG_UPDATE', 10, "UpdateBags")

	addon.filterProto.OnEnable(self)
end

function mod:OnDisable()
	for name, bag in pairs(bags) do
		if bag.button then
			bag.button:Hide()
		end
	end
	addon.filterProto.OnDisable(self)
end

--------------------------------------------------------------------------------
-- Widget creation
--------------------------------------------------------------------------------

local function ResetButton_OnClick(widget, button)
	if button == "RightButton" then
		return mod:OpenOptions()
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	mod:Reset(widget.bagName)
end

function mod:OnBagFrameCreated(bag)
	local container = bag:GetFrame()

	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.bagName = bag.bagName
	button:SetText("N")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", ResetButton_OnClick)
	button:RegisterForClicks("AnyUp")
	container:AddHeaderWidget(button, 10)
	addon.SetupTooltip(button, {
		L["Reset new items"],
		L["Click to reset item status."],
		L["Right-click to configure."]
	}, "ANCHOR_TOPLEFT", 0, 8)

	if not next(bags[bag.bagName].newItems) then
		button:Disable()
	end

	bags[bag.bagName].button = button
	bags[bag.bagName].container = container

	mod:UpdateBags()
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

function mod:GetOptions()
	return {
		showGlow = {
			name = L['New item highlight'],
			type = 'toggle',
			order = 10,
			width = 'double',
		},
		glowScale = {
			name = L['Highlight scale'],
			type = 'range',
			min = 0.5,
			max = 3.0,
			step = 0.01,
			isPercent = true,
			bigStep = 0.05,
			order = 20,
		},
		glowColor = {
			name = L['Highlight color'],
			type = 'color',
			order = 30,
			hasAlpha = true,
		},
		ignoreJunk = {
			name = L['Ignore low quality items'],
			type = 'toggle',
			order = 40,
			set = function(info, ...)
				info.handler:Set(info, ...)
				self:UpdateBags()
			end,
			width = 'double',
		},
	}, addon:GetOptionHandler(self)
end

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------

function mod:UNIT_INVENTORY_CHANGED(event, unit)
	if unit == "player" then
		inventoryScanned = false
	end
end

function mod:BANKFRAME_OPENED(event)
	self:Debug(event)
	self:UpdateInventory()
	if not initializing then
		for name, bag in pairs(bags) do
			self:UpdateBags()
		end
	end
end

function mod:EQUIPMENT_SWAP_PENDING(event)
	self:Debug(event)
	frozen = true
end

function mod:EQUIPMENT_SWAP_FINISHED(event)
	self:Debug(event)
	frozen = false
	inventoryScanned = false
	if not initializing then
		self:UpdateBags()
	end
end

local GetDistinctItemID = addon.GetDistinctItemID

local function IsIgnored(itemId)
	if mod.db.profile.ignoreJunk then
		if type(itemId) == "string" then
			if strmatch(itemId, "battlepet:") then
				itemId = 82800
			else
				itemId = tonumber(strmatch(itemId, "item:(%d+)") or itemId)
			end
		end
		return addon:IsJunk(itemId)
	end
end

local newCounts, equipped = {}, {}
function mod:UpdateBag(bag)
	if not bag.obj:CanOpen() then return end

	wipe(newCounts)
	wipe(equipped)

	-- Gather every item id of every bags
	for bagId in pairs(bag.bagIds) do
		for slot = 1, GetContainerNumSlots(bagId) do
			local _, count, _, _, _, _, link = GetContainerItemInfo(bagId, slot)
			local itemId = GetDistinctItemID(link)
			if itemId then
				newCounts[itemId] = (newCounts[itemId] or 0) + (count or 1)
			end
		end
	end

	-- Merge items from inventory
	for slot, link in pairs(inventory) do
		local itemId = GetDistinctItemID(link)
		if itemId then
			newCounts[itemId] = (newCounts[itemId] or 0) + 1
			equipped[itemId] = (equipped[itemId] or 0) + 1
		end
	end

	local counts, newItems = bag.counts, bag.newItems

	-- Items that were in the bags
	for itemId, oldCount in pairs(counts) do
		local newCount = newCounts[itemId]
		counts[itemId], newCounts[itemId] = newCount, nil
		if newCount and equipped[itemId] then -- Ignore equipped item count
			newCount = newCount - equipped[itemId]
		end
		if not newCount or IsIgnored(itemId) then
			if newItems[itemId] then
				self:Debug('Not new anymore', itemId)
				newItems[itemId] = nil
				if newCount and newCount > 0 then
					bag.removed = true
				end
			end
		elseif not bag.first and newCount > oldCount and not newItems[itemId] then
			self:Debug('Got more of', itemId)
			newItems[itemId] = true
			bag.updated = true
		end
	end

	-- Brand new items
	for itemId, newCount in pairs(newCounts) do
		counts[itemId] = newCount
		if newCount and equipped[itemId] then -- Ignore equipped item count
			newCount = newCount - equipped[itemId]
		end
		if not bag.first and not newItems[itemId] and (newCount > 0) and not IsIgnored(itemId) then
			self:Debug('Brand new item:', itemId)
			newItems[itemId] = true
			bag.updated = true
		end
	end

	bag.first = nil
end

function mod:UpdateBags()
	self:Debug('UpdateBags')

	if GetContainerNumSlots(BACKPACK_CONTAINER) == 0 then
		-- No bag data at all
		self:Debug('Aborting, no bag data')
		return
	end

	-- Update inventory if need be
	if not self:UpdateInventory() then
		self:Debug('Aborting, incomplete inventory')
		-- Missing links in inventory
		return
	end

	-- Update all bags
	for name, bag in pairs(bags) do
		self:UpdateBag(bag)
	end

	if initializing then
		-- Do not go further if we're still initializing
		self:UnregisterBucket(bagUpdateBucket)
		bagUpdateBucket = self:RegisterBucketEvent('BAG_UPDATE', 0.1, "UpdateBags")
		initializing = false
		return
	end

	-- Update feedback
	for name, bag in pairs(bags) do
		if bag.button then
			if next(bag.newItems) then
				bag.button:Enable()
			else
				bag.button:Disable()
			end
		end
		if bag.updated and bag.container and bag.obj:CanOpen() then
			self:Debug(name, 'contains new new items')
			bag.updated = nil
			bag.container:FiltersChanged("OnNewItems")
		end
	end

end

do
	local incomplete

	local function ScanInventorySlot(slot)
		local id = GetInventoryItemID("player", slot)
		if id then
			local link = GetInventoryItemLink("player", slot)
			inventory[slot] = link
			if not link then
				incomplete = true
			end
		else
			inventory[slot] = nil
		end
	end

	function mod:UpdateInventory()
		if not inventoryScanned then
			self:Debug('UpdateInventory')
			incomplete = false

			-- All equipped items and bags
			for slot = 0, 20 do
				ScanInventorySlot(slot)
			end
			-- Bank equipped bags
			for slot = 68, 74 do
				ScanInventorySlot(slot)
			end

			inventoryScanned = not incomplete
		end
		return inventoryScanned
	end
end

function mod:Reset(name)
	local bag = bags[name]
	self:Debug('Reset', name)
	wipe(bag.counts)
	wipe(bag.newItems)
	bag.first = true
	bag.updated = true
	self:UpdateBags()
	bag.container:LayoutSections(true)
end

function mod:IsNew(itemLink, bagName)
	if not itemLink or not bagName then return false end
	local bag = bags[bagName]
	return not bag.first and bag.newItems[GetDistinctItemID(itemLink)]
end

--------------------------------------------------------------------------------
-- Filtering
--------------------------------------------------------------------------------

do
	local currentContainerName

	function mod:AdiBags_PreFilter(event, container)
		currentContainerName = container.name
	end

	function mod:Filter(slotData)
		if self:IsNew(slotData.link, currentContainerName) then
			return L["New"]
		end
	end
end

--------------------------------------------------------------------------------
-- Item glows
--------------------------------------------------------------------------------

local function Glow_Update(glow)
	glow:SetScale(mod.db.profile.glowScale)
	glow.Texture:SetVertexColor(unpack(mod.db.profile.glowColor))
end

local function CreateGlow(button)
	local glow = CreateFrame("FRAME", nil, button)
	glow:SetFrameLevel(button:GetFrameLevel()+15)
	glow:SetPoint("CENTER")
	glow:SetWidth(addon.ITEM_SIZE)
	glow:SetHeight(addon.ITEM_SIZE)

	local tex = glow:CreateTexture("OVERLAY")
	tex:SetTexture([[Interface\Cooldown\starburst]])
	tex:SetBlendMode("ADD")
	tex:SetAllPoints(glow)
	glow.Texture = tex

	local group = glow:CreateAnimationGroup()
	group:SetLooping("REPEAT")

	local anim = group:CreateAnimation("Rotation")
	anim:SetOrder(1)
	anim:SetDuration(10)
	anim:SetDegrees(360)
	anim:SetOrigin("CENTER", 0, 0)

	group:Play()

	glow.Update = Glow_Update

	glows[button] = glow
	return glow
end

function mod:UpdateButton(event, button)
	local glow = glows[button]
	if mod.db.profile.showGlow and self:IsNew(button.itemLink, button.container.name) then
		if not glow then
			glow = CreateGlow(button)
		end
		glow:Update()
		glow:Show()
	elseif glow then
		glow:Hide()
	end
end
