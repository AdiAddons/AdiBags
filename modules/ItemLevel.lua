--[[
AdiBags - Adirelle's bag addon.
Copyright 2013-2014 Adirelle (adirelle@gmail.com)
All rights reserved.

This file is part of AdiBags.

AdiBags is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

AdiBags is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdiBags.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local abs = _G.math.abs
local GetItemInfo = _G.GetItemInfo
local QuestDifficultyColors = _G.QuestDifficultyColors
local UnitLevel = _G.UnitLevel
local modf = _G.math.modf
local max = _G.max
local min = _G.min
local pairs = _G.pairs
local select = _G.select
local unpack = _G.unpack
--GLOBALS>

local mod = addon:NewModule('ItemLevel', 'ABEvent-1.0')
mod.uiName = L['Item level']
mod.uiDesc = L['Display the level of equippable item in the top left corner of the button.']

local colorSchemes = {
	none = function() return 1, 1 ,1 end
}

local texts = {}

local SyLevel = _G.SyLevel
local SyLevelBypass
if SyLevel then
	function SyLevelBypass() return mod:IsEnabled() and mod.db.profile.useSyLevel end
else
	function SyLevelBypass() return false end
end

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			useSyLevel = false,
			equippableOnly = true,
			colorScheme = 'level',
			minLevel = 1,
			ignoreJunk = true,
			ignoreHeirloom = true,
		},
	})
	if self.db.profile.colored == true then
		self.db.profile.colorScheme = 'original'
		self.db.profile.colored = nil
	elseif self.db.profile.colored == false then
		self.db.profile.colorScheme = 'none'
		self.db.profile.colored = nil
	end
	if SyLevel then
		SyLevel:RegisterPipe(
			'Adibags',
			function() self.db.profile.useSyLevel = true end,
			function() self.db.profile.useSyLevel = false end,
			function() self:SendMessage('AdiBags_UpdateAllButtons') end,
			'AdiBags'
		)
		SyLevel:RegisterFilterOnPipe('Adibags', 'Item level text')
		SyLevelDB.EnabledFilters['Item level text']['Adibags'] = true
	end
end

function mod:OnEnable()
	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')
	if SyLevel and self.db.profile.useSyLevel and not SyLevel:IsPipeEnabled('Adibags') then
		SyLevel:EnablePipe('Adibags')
	end
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
	local link = button:GetItemLink()
	local text = texts[button]

	if link then
		local _, _, quality, _, reqLevel, _, _, _, loc = GetItemInfo(link)
		local item = Item:CreateFromBagAndSlot(button.bag, button.slot)
		local level = item and item:GetCurrentItemLevel() or 0
		if level >= settings.minLevel
			and (quality ~= LE_ITEM_QUALITY_POOR or not settings.ignoreJunk)
			and (loc ~= "" or not settings.equippableOnly)
			and (quality ~= LE_ITEM_QUALITY_HEIRLOOM or not settings.ignoreHeirloom)
		then
			if SyLevel then
				if settings.useSyLevel then
					if text then
						text:Hide()
					end
					SyLevel:CallFilters('Adibags', button, link)
					return
				else
					SyLevel:CallFilters('Adibags', button, nil)
				end
			end
			if not text then
				text = CreateText(button)
			end
			text:SetText(level)
			text:SetTextColor(colorSchemes[settings.colorScheme](level, quality, reqLevel, (loc ~= "")))
			return text:Show()
		end
	end
	if SyLevel then
		SyLevel:CallFilters('Adibags', button, nil)
	end
	if text then
		text:Hide()
	end
end


function mod:GetOptions()
	return {
		useSyLevel = SyLevel and {
			name = L['Use SyLevel'],
			desc = L['Let SyLevel handle the the display.'],
			type = 'toggle',
			order = 5,
		} or nil,
		equippableOnly = {
			name = L['Only equippable items'],
			desc = L['Do not show level of items that cannot be equipped.'],
			type = 'toggle',
			order = 10,
		},
		colorScheme = {
			name = L['Color scheme'],
			desc = L['Which color scheme should be used to display the item level ?'],
			type = 'select',
			hidden = SyLevelBypass,
			values = {
				none     = L['None'],
				original = L['Same as InventoryItemLevels'],
				level    = L['Related to player level'],
			},
			order = 20,
		},
		minLevel = {
			name = L['Mininum level'],
			desc = L['Do not show levels under this threshold.'],
			type = 'range',
			min = 1,
			max = 1000,
			step = 1,
			bigStep = 10,
			order = 30,
		},
		ignoreJunk = {
			name = L['Ignore low quality items'],
			desc = L['Do not show level of poor quality items.'],
			type = 'toggle',
			order = 40,
		},
		ignoreHeirloom = {
			name = L['Ignore heirloom items'],
			desc = L['Do not show level of heirloom items.'],
			type = 'toggle',
			order = 50,
		},
	}, addon:GetOptionHandler(self)
end

-- Color scheme inspired from InventoryItemLevels
do
	local colors = {
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

	colorSchemes.original = function(level)
		for i, tuple in pairs(colors) do
			if level < tuple[1] then
				return unpack(tuple, 2, 4)
			end
		end
	end
end

-- Color scheme based on player Level
do
	-- Color gradient function taken from my customized oUF
	local colorGradient
	do
		local function GetY(r, g, b)
			return 0.3 * r + 0.59 * g + 0.11 * b
		end

		local function RGBToHCY(r, g, b)
			local min, max = min(r, g, b), max(r, g, b)
			local chroma = max - min
			local hue
			if chroma > 0 then
				if r == max then
					hue = ((g - b) / chroma) % 6
				elseif g == max then
					hue = (b - r) / chroma + 2
				elseif b == max then
					hue = (r - g) / chroma + 4
				end
				hue = hue / 6
			end
			return hue, chroma, GetY(r, g, b)
		end

		local function HCYtoRGB(hue, chroma, luma)
			local r, g, b = 0, 0, 0
			if hue then
				local h2 = hue * 6
				local x = chroma * (1 - abs(h2 % 2 - 1))
				if h2 < 1 then
					r, g, b = chroma, x, 0
				elseif h2 < 2 then
					r, g, b = x, chroma, 0
				elseif h2 < 3 then
					r, g, b = 0, chroma, x
				elseif h2 < 4 then
					r, g, b = 0, x, chroma
				elseif h2 < 5 then
					r, g, b = x, 0, chroma
				else
					r, g, b = chroma, 0, x
				end
			end
			local m = luma - GetY(r, g, b)
			return r + m, g + m, b + m
		end

		colorGradient = function(a, b, ...)
			local perc
			if(b == 0) then
				perc = 0
			else
				perc = a / b
			end

			if perc >= 1 then
				local r, g, b = select(select('#', ...) - 2, ...)
				return r, g, b
			elseif perc <= 0 then
				local r, g, b = ...
				return r, g, b
			end

			local num = select('#', ...) / 3
			local segment, relperc = modf(perc*(num-1))
			local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

			local h1, c1, y1 = RGBToHCY(r1, g1, b1)
			local h2, c2, y2 = RGBToHCY(r2, g2, b2)
			local c = c1 + (c2-c1) * relperc
			local	y = y1 + (y2-y1) * relperc
			if h1 and h2 then
				local dh = h2 - h1
				if dh < -0.5  then
					dh = dh + 1
				elseif dh > 0.5 then
					dh = dh - 1
				end
				return HCYtoRGB((h1 + dh * relperc) % 1, c, y)
			else
				return HCYtoRGB(h1 or h2, c, y)
			end

		end
	end

	local maxLevelRanges = {
		[ 60] = {  58,  65 }, -- Classic
		[ 70] = {  80,  94 }, -- The Burning Crusade
		[ 80] = { 100, 102 }, -- Wrath of the Lich King
		[ 85] = { 108, 114 }, -- Cataclysm
		[ 90] = { 116, 130 }, -- Mists of Pandaria
		[100] = { 136, 143 }, -- Warlords of Draenor
		[110] = { 164, 250 }, -- Legion
		[120] = { 370, 445 }, -- Battle for Azeroth
	}

	local maxLevelColors = {}
	do
		local t = maxLevelColors
		t[1], t[2], t[3] = GetItemQualityColor(2)
		t[4], t[5], t[6] = GetItemQualityColor(3)
		t[7], t[8], t[9] = GetItemQualityColor(4)
		t[10], t[11], t[12] = GetItemQualityColor(5)
	end

	colorSchemes.level = function(level, quality, reqLevel, equipabble)
		if not equipabble then return 1,1,1 end
		local playerLevel = UnitLevel('player')
		if playerLevel == _G.MAX_PLAYER_LEVEL then
			-- Use the item level range for that level
			local minLevel, maxLevel = unpack(maxLevelRanges[playerLevel])
			if level < minLevel then
				return GetItemQualityColor(0)
			else
				return colorGradient(level - minLevel, maxLevel - minLevel, unpack(maxLevelColors))
			end
		elseif reqLevel and reqLevel > 1 then
			-- Use the
			local delta, color = playerLevel - reqLevel
			if delta < 0 then
				color = QuestDifficultyColors.trivial
			elseif delta == 0 then
				color = QuestDifficultyColors.standard
			elseif delta == 1 then
				color = QuestDifficultyColors.difficult
			elseif delta == 2 then
				color = QuestDifficultyColors.verydifficult
			else
				color = QuestDifficultyColors.impossible
			end
			return color.r, color.g, color.b
		else
			-- Would this happen ?
			return 1, 1, 1
		end
	end
end
