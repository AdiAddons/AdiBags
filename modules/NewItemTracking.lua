--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:RegisterFilter('NewItem', 100, 'AceEvent-3.0')
mod.uiName = L['Track new items']
mod.uiDesc = L['Track new items in each bag, displaying a glowing aura over them and putting them in a special section. "New" status can be reset by clicking on the small "N" button at top left of bags.']

local data = {}
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

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	self:RegisterMessage('AgiBags_PreFilter')
	self:RegisterMessage('AdiBags_BagOpened')
	self:RegisterMessage('AdiBags_PreContentUpdate', 'UpdateCounts')
	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')
	for _, data in pairs(data) do
		data.button:Show()
	end
	addon.filterProto.OnEnable(self)
end

function mod:OnDisable()
	for _, data in pairs(data) do
		data.button:Hide()
	end
	addon.filterProto.OnDisable(self)
end

local function ResetButton_OnClick(button)
	mod:Reset(button.container)
end

function mod:OnBagFrameCreated(bag)
	local container = bag:GetFrame()

	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button.container = container
	button:SetText("N")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", ResetButton_OnClick)
	container:AddHeaderWidget(button, 10)
	addon.SetupTooltip(button, {
		L["Reset new items"],
		L["Click to reset item status."]
	}, "ANCHOR_TOPLEFT", 0, 8)

	data[container] = {
		firstUpdate = true,
		counts = {},
		new = {},
		isBank = bag.isBank,
		button = button,
	}

	self:ScanInventory(container)
end

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

function mod:AdiBags_BagOpened(event, name, bag)
	return self:ScanInventory(bag:GetFrame())
end

local function UpdateItem(data, id)
	if not id then return end
	local count
	if data.isBank then
		count = (GetItemCount(id, true) or 0) - (GetItemCount(id) or 0)
	else
		count = (GetItemCount(id) or 0)
	end
	local oldCount = data.counts[id] or 0
	data.counts[id] = count
	if data.firstUpdate or oldCount == count then return end
	local wasNew = data.new[id]
	local isNew = wasNew or (count > oldCount)
	if isNew ~= wasNew then
		data.new[id] = isNew or nil
		data.updated = true
	end
end

local function IdFromLink(link)
	return link and tonumber(link:match('item:(%d+)'))
end

function mod:ScanInventory(container)
	local data = data[container]
	if not data.firstUpdate then return end
	self:Debug('ScanInventory', container)
	for slot = 0, 20 do -- All equipped items and bags
		UpdateItem(data, IdFromLink(GetInventoryItemLink("player", slot)))
	end
	if addon.atBank then
		for slot = 68, 74 do -- Bank equipped bags
			UpdateItem(data, IdFromLink(GetInventoryItemLink("player", slot)))
		end
	end
end

local items = {}
function mod:UpdateCounts(event, container, added, removed, changed)
	-- Collect all links into one table
	for slotId, slotData in pairs(added) do
		if slotData.link then
			items[IdFromLink(slotData.link)] = true
		end
	end
	for slotId, slotData in pairs(changed) do
		if slotData.link then
			items[IdFromLink(slotData.link)] = true
		end
	end
	for slotId, link in pairs(removed) do
		if link then
			items[IdFromLink(link)] = true
		end
	end

	-- Update counts
	local data = data[container]
	for id in pairs(items) do
		UpdateItem(data, id)
	end
	wipe(items)

	-- Update display
	if data.updated then
		self:SendMessage('AdiBags_UpdateAllButtons')
		data.updated = nil
	end
	if next(data.new) then
		data.button:Enable()
	else
		data.button:Disable()
	end
	data.firstUpdate = nil
end

function mod:Reset(container)
	local data = data[container]
	data.updated = true
	data.firstUpdate = true
	wipe(data.counts)
	wipe(data.new)
	self:ScanInventory(container)
	addon:SendMessage('AdiBags_FiltersChanged')
end

do
	local newItems

	function mod:AgiBags_PreFilter(event, container)
		newItems = data[container].new
	end

	function mod:Filter(slotData)
		return newItems[slotData.itemId] and L["New"]
	end
end

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
	if button.itemId and data[button.container].new[button.itemId] and mod.db.profile.showGlow then
		local glow = button.NewGlow or CreateGlow(button)
		UpdateGlow(glow)
		glow:Show()
	elseif button.NewGlow then
		button.NewGlow:Hide()
	end
end
