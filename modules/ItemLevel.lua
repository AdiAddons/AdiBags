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
local select = _G.select
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
	local text = texts[button]
	local id = button:GetItemId()
	local ilvl
	if id then
		local level, _, _, _, _, loc = select(4, GetItemInfo(id))
		ilvl = loc ~= ""  and level
	end
	if ilvl then
		if not text then
			text = CreateText(button)
		end
		text:SetText(ilvl)
		for i, tuple in pairs(colorScheme) do
			if ilvl < tuple[1] then
				text:SetTextColor(unpack(tuple, 2, 4))
				break
			end
		end
		text:Show()
	elseif text then
		text:Hide()
	end
end

