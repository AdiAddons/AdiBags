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
	local widget = CreateFrame("Button", addonName.."MoneyFrame", frame, "MoneyFrameTemplate")
	self.widget = widget
	widget:SetHeight(19)
	widget:RegisterForClicks("RightButtonUp")
	widget:SetScript('OnClick', function() self:OpenOptions() end)
	addon.SetupTooltip(widget, { L['Money'], L['Right-click to configure.'] }, "ANCHOR_BOTTOMRIGHT")
	
	frame:AddBottomWidget(self.widget, "RIGHT", 50, 19, 19, 0)
end

