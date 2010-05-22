--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:RegisterFilter('NewItem', 100, 'AceEvent-3.0', 'AceBucket-3.0')
mod.uiName = L['Track new items']
mod.uiDesc = L['Track new items in each bag, displaying a glowing aura over them and putting them in a special section. "New" status can be reset by clicking on the small "N" button at top left of bags.']

local allBagIds = {}

local bags = {}
local inventory = {}
local glows = {}
local frozen = false
local inventoryScanned = false

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			showGlow = true,
			glowScale = 1.5,
			glowColor = { 0.3, 1, 0.3, 0.7 },
		},
	})
	addon:SetCategoryOrder(L['New'], 100)
end

function mod:OnEnable()

	for i, bag in addon:IterateBags() do
		if not bags[bag.bagName] then
			self:Debug('Adding bag', bag, bag.bagIds)
			local data = {
				bagIds = bag.bagIds,
				isBank = bag.isBank,
				counts = {},
				newItems = {},
				first = true,
			}
			for id in pairs(bag.bagIds) do
				allBagIds[id] = id
			end
			if data.isBank then
				data.GetCount = function(item)
					return item and (GetItemCount(item, true) or 0) - (GetItemCount(item) or 0) or 0
				end
			else
				data.GetCount = function(item)
					return item and GetItemCount(item) or 0
				end
				data.available = true
			end
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

	self:RegisterEvent('UNIT_INVENTORY_CHANGED')
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('BANKFRAME_CLOSED')
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING')
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED')
	self:RegisterBucketMessage('AdiBags_BagUpdated', 0.2, 'UpdateBags')

	frozen = false
	inventoryScanned = false

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

local function ResetButton_OnClick(button)
	PlaySound("igMainMenuOptionCheckBoxOn")
	mod:Reset(button.bagName)
end

function mod:OnBagFrameCreated(bag)
	local container = bag:GetFrame()

	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.bagName = bag.bagName
	button:SetText("N")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", ResetButton_OnClick)
	container:AddHeaderWidget(button, 10)
	addon.SetupTooltip(button, {
		L["Reset new items"],
		L["Click to reset item status."]
	}, "ANCHOR_TOPLEFT", 0, 8)

	if not next(bags[bag.bagName].newItems) then
		button:Disable()
	end

	container:HookScript('OnShow', function()
		mod:UpdateBags(bag.bagIds, 'OnShow')
	end)

	bags[bag.bagName].button = button
	bags[bag.bagName].container = container
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
	}, addon:GetOptionHandler(self)
end

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------

function mod:UNIT_INVENTORY_CHANGED(event, unit)
	if unit == "player" then
		self:Debug(event, unit)
		inventoryScanned = false
	end
end

function mod:BANKFRAME_OPENED(event)
	self:Debug(event)
	self:UpdateInventory(event)
	for name, bag in pairs(bags) do
		if bag.isBank then
			bag.available = true
			self:UpdateBags(bag.bagIds, event)
		end
	end
end

function mod:BANKFRAME_CLOSED(event)
	self:Debug(event)
	for name, bag in pairs(bags) do
		if bag.isBank then
			bag.available = false
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
	self:UpdateBags(allBagIds, event)
end

function mod:UpdateBags(bagIds, event)
	if frozen then return end
	self:Debug('UpdateBags', event or "BAG_UPDATED")
	for name, bag in pairs(bags) do
		if bag.available and (bag.first or (bag.container and bag.container:IsVisible())) then
			local counts = bag.counts
			local bagUpdated = false
			local first = bag.first

			-- Gather every item id of every updated bag (or all bags on first update)
			for bagId in pairs(bag.bagIds) do
				if first or bagIds[bagId] then
					bagUpdated = true
					for slot = 1, GetContainerNumSlots(bagId) do
						local itemId = GetContainerItemID(bagId, slot)
						if itemId and not counts[itemId] then
							counts[itemId] = 0 -- Never seen before, assume we haven't any of it
						end
					end
				end
			end

			if bagUpdated then
				self:Debug(name, 'updated, checking items')

				-- Update inventory if need be
				if not inventoryScanned then
					self:UpdateInventory(event)
				end

				-- Merge items from inventory
				for slot, itemId in pairs(inventory) do
					if not counts[itemId] then
						counts[itemId] = 0 -- Never seen before, assume we haven't any of it
					end
				end

				-- Update counts and new statuses
				local newItems, GetCount = bag.newItems, bag.GetCount
				for itemId, oldCount in pairs(counts) do
					local newCount = GetCount(itemId)
					counts[itemId] = newCount
					if oldCount ~= newCount then
						if not bag.first and oldCount < newCount and not newItems[itemId] then
							self:Debug(itemId, GetItemInfo(itemId), ':', oldCount, '=>', newCount, 'NEW!')
							newItems[itemId] = true
							bag.updated = true
						end
					end
				end
				bag.first = nil
			end
		end
	end

	local filterChanged = false
	for name, bag in pairs(bags) do
		if bag.button then
			if next(bag.newItems) then
				bag.button:Enable()
			else
				bag.button:Disable()
			end
		end
		if bag.updated and bag.available then
			self:Debug(name, 'contains new new items')
			bag.updated = nil
			filterChanged  = true
		end
	end
	if filterChanged then
		self:Debug('Need to filter bags again')
		self:SendMessage('AdiBags_FiltersChanged')
	end
end

function mod:UpdateInventory(event)
	if frozen then return end
	self:Debug('UpdateInventory', event)

	-- All equipped items and bags
	for slot = 0, 20 do
		inventory[slot] = GetInventoryItemID("player", slot) or nil
	end
	-- Bank equipped bags
	for slot = 68, 74 do
		inventory[slot] = GetInventoryItemID("player", slot) or nil
	end

	inventoryScanned = true
end

function mod:Reset(name)
	local bag = bags[name]
	self:Debug('Reset', name)
	wipe(bag.counts)
	wipe(bag.newItems)
	bag.first = true
	bag.updated = true
	self:UpdateBags(bag.bagIds, event)
end

function mod:IsNew(itemId, bagName)
	if not itemId or not bagName then return false end
	local bag = bags[bagName]
	return not bag.first and bag.newItems[itemId]
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
		if self:IsNew(slotData.itemId, currentContainerName) then
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
	if mod.db.profile.showGlow and self:IsNew(button:GetItemId(), button.container.name) then
		if not glow then
			glow = CreateGlow(button)
		end
		glow:Update()
		glow:Show()
	elseif glow then
		glow:Hide()
	end
end
