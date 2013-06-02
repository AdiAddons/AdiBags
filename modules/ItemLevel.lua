--[[
AdiBags - Adirelle's bag addon.
Copyright 2013 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local GetItemInfo = _G.GetItemInfo
local pairs = _G.pairs
local unpack = _G.unpack
--GLOBALS>

local mod = addon:NewModule('ItemLevel', 'AceEvent-3.0')
mod.uiName = L['Item level']
mod.uiDesc = L['Display the level of equippable item in the top left corner of the button.']

local colorScheme = {
	-- { upper bound, r, g, b }
	{ 150, 0.55, 0.55, 0.55 }, -- gray
	{ 250, 1.00, 0.00, 0.00 }, -- red
	{ 300, 1.00, 0.70, 0.00 }, -- orange
	{ 350, 1.00, 1.00, 0.00 }, -- yellow
	{ 372, 0.00, 1.00, 0.00 }, -- green
	{ 385, 0.00, 1.00, 1.00 }, -- cyan
	{ 397, 0.00, 0.80, 1.00 }, -- blue
	{ 403, 1.00, 0.50, 1.00 }, -- purple,
	{ 410, 1.00, 0.75, 1.00 }, -- pink
	{ 999, 1.00, 1.00, 1.00 }, -- white
}

local texts = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			equippableOnly = true,
			colored = true,
			minLevel = 1,
			ignoreJunk = true,
		},
	})
end

function mod:OnEnable()
	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')
	self:SendMessage('AdiBags_UpdateAllButtons')
end

function mod:OnDisable()
	for _, text in pairs(texts) do
		text:Hide()
	end
end

local function CreateText(button)
	local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	text:SetPoint("TOPLEFT", button, 3, -1)
	text:Hide()
	texts[button] = text
	return text
end

function mod:UpdateButton(event, button)
	local settings = self.db.profile
	local text = texts[button]
	local id = button:GetItemId()
	if id then
		local _, _, quality, level, _, _, _, _, loc = GetItemInfo(id)
		if level >= settings.minLevel and (quality > 0 or not settings.ignoreJunk) and (loc ~= "" or not settings.equippableOnly) then
			if not text then
				text = CreateText(button)
			end
			text:SetText(level)
			if settings.colored then
				for i, tuple in pairs(colorScheme) do
					if level < tuple[1] then
						text:SetTextColor(unpack(tuple, 2, 4))
						break
					end
				end
			else
				text:SetTextColor(1, 1, 1)
			end
			return text:Show()
		end
	end
	if text then
		text:Hide()
	end
end

function mod:GetOptions()
	return {
		equippableOnly = {
			name = L['Only equippable items'],
			desc = L['Do not show level of items that cannot be equipped.'],
			type = 'toggle',
			order = 10,
		},
		colored = {
			name = L['Color-coded level'],
			desc = L['Use a color code based on item level.'],
			type = 'toggle',
			order = 20,
		},
		minLevel = {
			name = L['Mininum level'],
			desc = L['Do not show levels under this threshold.'],
			type = 'range',
			min = 1,
			max = 500,
			step = 1,
			bigStep = 5,
			order = 30,
		},
		ignoreJunk = {
			name = L['Ignore low quality items'],
			desc = L['Do not show level of poor quality items.'],
			type = 'toggle',
			order = 40,
		},
	}, addon:GetOptionHandler(self)
end
