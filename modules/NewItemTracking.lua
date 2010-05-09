--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:RegisterFilter('NewItem', 1000, 'AceEvent-3.0')

local data = {}

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

	data[container] = {
		firstUpdate = true,
		counts = {},
		new = {},
		isBank = bag.isBank,
		button = button,
	}

	self:ScanInventory(container)
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
	local isNew = (count > oldCount) or (wasNew and (count >= oldCount))
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

local function CreateGlow(button)
	local glow = CreateFrame("FRAME", nil, button)
	glow:SetFrameLevel(button:GetFrameLevel()+15)
	glow:SetPoint("CENTER")
	glow:SetWidth(button:GetWidth()*1.5)
	glow:SetHeight(button:GetHeight()*1.5)

	local tex = glow:CreateTexture("OVERLAY")
	tex:SetTexture([[Interface\Cooldown\starburst]])
	tex:SetBlendMode("ADD")
	tex:SetAllPoints(glow)
	tex:SetVertexColor(0.3, 1, 0.3, 0.7)

	local group = glow:CreateAnimationGroup()
	group:SetLooping("REPEAT")

	local anim = group:CreateAnimation("Rotation")
	anim:SetOrder(1)
	anim:SetDuration(10)
	anim:SetDegrees(360)
	anim:SetOrigin("CENTER", 0, 0)

	group:Play()

	button.NewGlow = glow
	return glow
end

function mod:UpdateButton(event, button)
	local isNew = button.itemId and data[button.container].new[button.itemId]
	if button.isNew == isNew then return end
	button.isNew = isNew
	if isNew then
		local glow = button.NewGlow or CreateGlow(button)
		glow:Show()
	elseif button.NewGlow then
		button.NewGlow:Hide()
	end
end

