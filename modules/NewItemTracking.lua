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

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			showGlow = true,
			glowScale = 1.5,
			glowColor = { 0.3, 1, 0.3, 0.7 },
		},
	})
end

local firstEnable = true
function mod:OnEnable()

	if firstEnable then
		for i, bag in addon:IterateBags() do
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
		firstEnable = false
	end

	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	for name, bag in pairs(bags) do
		if bag.button then
			bag.button:Show()
		end
	end

	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')

	self:RegisterEvent('UNIT_INVENTORY_CHANGED')
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('BANKFRAME_CLOSED')
	self:RegisterEvent('EQUIPMENT_SWAP_PENDING')
	self:RegisterEvent('EQUIPMENT_SWAP_FINISHED')	
	self:RegisterBucketMessage('AdiBags_BagUpdated', 0.2, 'UpdateBags')
	
	self.frozen = false

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

	bags[bag.bagName].button = button	
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
		self:UpdateInventory(event)
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
	self.frozen = true
end

function mod:EQUIPMENT_SWAP_FINISHED(event)
	self:Debug(event)
	self.frozen = false
	self:UpdateAll(event)
end

function mod:UpdateBags(bagIds, event)
	if self.frozen then return end
	self:Debug('UpdateBags', event)
	for name, bag in pairs(bags) do
		if bag.available then
			local counts = bag.counts			
			local bagUpdated = false
			
			-- Gather every link of every bag
			for bagId in pairs(bag.bagIds) do
				if bag.first or bagIds[bagId] then
					bagUpdated = true
					for slot = 1, GetContainerNumSlots(bagId) do
						local link = GetContainerItemLink(bagId, slot)
						if link and not counts[link] then
							counts[link] = 0
						end
					end
				end
			end
			
			if bagUpdated then
				self:Debug(name, 'updated, checking items')
			
				-- Merge links from inventory
				for slot, link in pairs(inventory) do
					if not counts[link] then
						counts[link] = 0
					end
				end
			
				-- Update counts and new statuses
				local newItems, GetCount = bag.newItems, bag.GetCount
				for link, oldCount in pairs(counts) do
					local newCount = GetCount(link)
					counts[link] = newCount
					if oldCount ~= newCount then
						if not bag.first and oldCount < newCount and not newItems[link] then
							self:Debug(link, ':', oldCount, '=>', newCount, 'NEW!')
							newItems[link] = true
							bag.updated = true
						else
							self:Debug(link, ':', oldCount, '=>', newCount)
						end
					end
				end
				bag.first = nil
			end
		end
	end
	
	local sent = false
	for name, bag in pairs(bags) do
		if bag.button then
			if next(bag.newItems) then
				bag.button:Enable()
			else
				bag.button:Disable()
			end
		end
		if bag.updated and bag.available then
			if not sent then
				self:SendMessage('AdiBags_FiltersChanged')
				sent = true
			end
			bag.updated = nil
		end
	end
end

function mod:UpdateInventory(event)
	if self.frozen then return end
	self:Debug('UpdateInventory', event)

	-- All equipped items and bags
	for slot = 0, 20 do 
		inventory[slot] = GetInventoryItemLink("player", slot) or nil
	end
	-- Bank equipped bags
	if bags.Bank.available then
		for slot = 68, 74 do 
			inventory[slot] = GetInventoryItemLink("player", slot) or nil
		end
	end
end

function mod:UpdateAll(event)
	if self.frozen then return end
	self:Debug('UpdateAll', event)
	self:UpdateInventory(event)
	self:UpdateBags(allBagIds, event)
end

function mod:Reset(name)
	local bag = bags[name]
	self:Debug('Reset', name) 
	wipe(bag.counts)
	wipe(bag.newItems)
	bag.first = true
	bag.updated = true
	self:UpdateInventory(event)
	self:UpdateBags(bag.bagIds, event)
end

function mod:IsNew(link, isBank)
	return link and bags[isBank and "Bank" or "Backpack"].newItems[link]
end

--------------------------------------------------------------------------------
-- Filtering
--------------------------------------------------------------------------------

function mod:Filter(slotData)
	if self:IsNew(slotData.link, slotData.isBank) then
		return L["New"]
	end
end

--------------------------------------------------------------------------------
-- Item glows
--------------------------------------------------------------------------------

local function UpdateGlow(glow)
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

	button.NewGlow = glow
	glows[glow] = true
	return glow
end

function mod:UpdateButton(event, button)
	if mod.db.profile.showGlow and self:IsNew(button:GetItemLink(), button:IsBank()) then
		local glow = button.NewGlow or CreateGlow(button)
		UpdateGlow(glow)
		glow:Show()
	elseif button.NewGlow then
		button.NewGlow:Hide()
	end
end
