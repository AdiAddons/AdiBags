--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
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
	self.widget = CreateFrame("Frame", addonName.."MoneyFrame", frame, "MoneyFrameTemplate")
	self.widget:SetHeight(19)
	frame:AddBottomWidget(self.widget, "RIGHT", 50, nil, 13, 0)
end

