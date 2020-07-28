--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2014 Adirelle (adirelle@gmail.com)
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
local BANK_CONTAINER = _G.BANK_CONTAINER
--GLOBALS>

local mod = addon:NewModule('Masque', 'ABEvent-1.0')
mod.uiName = L['Masque']
mod.uiDesc = L['Support for skinning item buttons with Masque.']

function mod:OnEnable()
	local Masque = LibStub("Masque", true)

	if not Masque then return end

	self.Masque = Masque

	self.BackpackGroup = Masque:Group(addonName, "Backpack")
	self.BankGroup = Masque:Group(addonName, "Bank")

	self.BackpackButtonPool = addon:GetPool("ItemButton")
	self.BankButtonPool = addon:GetPool("BankItemButton")

	self:RegisterMessage("AdiBags_AcquireButton", "OnAcquireButton")
	self:RegisterMessage("AdiBags_ReleaseButton", "OnReleaseButton")
	self:RegisterMessage("AdiBags_UpdateButton", "OnUpdateButton")

	self:AddActiveButtonsToGroups()
end

function mod:OnDisable()
	self:UnregisterMessage("AdiBags_AcquireButton")
	self:UnregisterMessage("AdiBags_ReleaseButton")

	if self.BackpackGroup then
		self.BackpackGroup:Delete()
	end
	if self.BankGroup then
		self.BankGroup:Delete()
	end
end

function mod:AddActiveButtonsToGroups()
	if self.BackpackButtonPool then
		for button in self.BackpackButtonPool:IterateActiveObjects() do
			self:AddButtonToMasqueGroup(self.BackpackGroup, button)
		end
	end

	if self.BankButtonPool then
		for button in self.BankButtonPool:IterateActiveObjects() do
			self:AddButtonToMasqueGroup(self.BankGroup, button)
		end
	end
end

function mod:OnAcquireButton(event, button, bag)
	if bag == BANK_CONTAINER or bag == REAGENTBANK_CONTAINER then
		self:AddButtonToMasqueGroup(self.BankGroup, button)
	else
		self:AddButtonToMasqueGroup(self.BackpackGroup, button)
	end
end

function mod:OnReleaseButton(event, button, bag)
	if bag == BANK_CONTAINER or bag == REAGENTBANK_CONTAINER then
		self:RemoveButtonFromMasqueGroup(self.BankGroup, button)
	else
		self:RemoveButtonFromMasqueGroup(self.BackpackGroup, button)
	end
end

function mod:AddButtonToMasqueGroup(group, button)
	group:AddButton(button, {
		Border = button.IconQuestTexture
	})
	button.masqueGroup = group
end

function mod:RemoveButtonFromMasqueGroup(group, button)
	button.masqueGroup = nil
	group:RemoveButton(button)
end

function mod:OnUpdateButton(event, button)
	-- this effectively reskins the button
	if button.masqueGroup then
		local group = button.masqueGroup
		self:RemoveButtonFromMasqueGroup(group, button)
		self:AddButtonToMasqueGroup(group, button)
	end
end

function mod:GetOptions()
	local options = {}
	if SlashCmdList["MASQUE"] then
		options["reset"] = {
			name = L['/masque'],
			type = 'execute',
			order = 10,
			func = function() SlashCmdList["MASQUE"]("") end,
		}
	end
	return options, addon:GetOptionHandler(self, false)
end
