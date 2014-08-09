--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
--GLOBALS>

local mod = addon:NewModule('MoneyFrame', 'AceEvent-3.0')
mod.uiName = L['Money']
mod.uiDesc = L['Display character money at bottom right of the backpack.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(
		self.moduleName,
		{
			profile = {
				small = false,
			}
		}
	)
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.widget then
		self.widget:Show()
	end
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

	frame:AddBottomWidget(self.widget, "RIGHT", 50, size, size, 0)
end

function mod:GetOptions()
	return {
		small = {
			name = L['Small'],
			desc = L['Display a smaller money frame. This setting will take effect on next reload.'],
			type = 'toggle',
			order = 10,
		},
	}, addon:GetOptionHandler(self, false)
end
