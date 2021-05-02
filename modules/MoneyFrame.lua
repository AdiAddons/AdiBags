--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2021 Adirelle (adirelle@gmail.com)
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
local CreateFrame = _G.CreateFrame
--GLOBALS>

local mod = addon:NewModule('MoneyFrame', 'ABEvent-1.0')
mod.uiName = L['Money']
mod.uiDesc = L['Display character money at bottom right of the backpack.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(
		self.moduleName,
		{
			profile = {
				small = false,
				text = addon:GetFontDefaults(PriceFont)
			}
		}
	)
	self.font = addon:CreateFont(
		self.name..'Font',
		PriceFont,
		function() return self.db.profile.text end
	)
	self.font.SettingHook = function() return self:Update() end
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.widget then
		self.widget:Show()
	end
	self.font:ApplySettings()
	self:Update();
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
	end
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()
	local template, size = "MoneyFrameTemplate", 19
	if self.db.profile.small then
		template, size = "SmallMoneyFrameTemplate", 13
	end
	local widget = CreateFrame("Button", addonName.."MoneyFrame", frame, template)
	self.widget = widget
	widget:SetHeight(size)
	widget:RegisterForClicks("RightButtonUp")
	widget:SetScript('OnClick', function() self:OpenOptions() end)
	addon.SetupTooltip(widget, { L['Money'], L['Right-click to configure.'] }, "ANCHOR_BOTTOMRIGHT")

	self:Update()
	frame:AddBottomWidget(self.widget, "RIGHT", 50, size, size, 0)
end

local updating
local GOLD_BUTTON_FRAME_NAME = addonName.."MoneyFrameGoldButton"
local SILVER_BUTTON_FRAME_NAME = addonName.."MoneyFrameSilverButton"
local COPPER_BUTTON_FRAME_NAME = addonName.."MoneyFrameCopperButton"

function mod:Update()
	if not self.widget or updating then return end
	updating = true

	for _, child in ipairs({ self.widget:GetChildren() }) do
		local childName = child:GetName()
		if childName == GOLD_BUTTON_FRAME_NAME or childName == SILVER_BUTTON_FRAME_NAME or childName == COPPER_BUTTON_FRAME_NAME then
			child:SetNormalFontObject(self.font)
		end
	end

	updating = false
end

function mod:GetOptions()
	return {
		small = {
			name = L['Small'],
			desc = L['Display a smaller money frame. This setting will take effect on next reload.'],
			type = 'toggle',
			order = 10,
		},
		text = addon:CreateFontOptions(self.font, nil, 15)
	}, addon:GetOptionHandler(self, false, function() return self:Update() end)
end
