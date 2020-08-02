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
	self.BackpackGroup:SetCallback(self.OnMasqueGroupChange, self)
	self.BankGroup = Masque:Group(addonName, "Bank")
	self.BankGroup:SetCallback(self.OnMasqueGroupChange, self)

	self.BackpackButtonPool = addon:GetPool("ItemButton")
	self.BankButtonPool = addon:GetPool("BankItemButton")

	self:RegisterMessage("AdiBags_AcquireButton", "OnAcquireButton")
	self:RegisterMessage("AdiBags_ReleaseButton", "OnReleaseButton")
	self:RegisterMessage("AdiBags_UpdateButton", "OnUpdateButton")
	self:RegisterMessage("AdiBags_UpdateBorder", "OnUpdateButton")

	self:AddAllActiveButtonsToGroup(self.BackpackButtonPool, self.BackpackGroup)
	self:AddAllActiveButtonsToGroup(self.BankButtonPool, self.BankGroup)
end

function mod:OnDisable()
	self:UnregisterMessage("AdiBags_AcquireButton")
	self:UnregisterMessage("AdiBags_ReleaseButton")
	self:UnregisterMessage("AdiBags_UpdateButton")
	self:UnregisterMessage("AdiBags_UpdateBorder")

	if self.BackpackGroup and self.BackpackButtonPool then
		self:RemoveAllActiveButtonsFromGroup(self.BackpackButtonPool, self.BackpackGroup, true)
		self.BackpackGroup:Delete()
	end
	if self.BankGroup and self.BankButtonPool then
		self.RemoveAllActiveButtonsFromGroup(self.BankButtonPool, self.BankGroup, true)
		self.BankGroup:Delete()
	end
end

function mod:OnMasqueGroupChange(masqueGroupName, skinId, backdrop, shadow, gloss, colors, disabled)
	local pool, group
	if masqueGroupName == "Backpack" then
		pool = self.BackpackButtonPool
		group = self.BackpackGroup
	elseif masqueGroupName == "Bank" then
		pool = self.BankButtonPool
		group = self.BankGroup
	end
	if pool and group then
		self:RemoveAllActiveButtonsFromGroup(pool, group, disabled)
		if not disabled then
			self:AddAllActiveButtonsToGroup(pool, group)
		end
	end
end

function mod:AddAllActiveButtonsToGroup(pool, group)
	for button in pool:IterateActiveObjects() do
		self:AddButtonToMasqueGroup(group, button)
	end
end

function mod:RemoveAllActiveButtonsFromGroup(pool, group, update)
	if pool.IterateActiveObjects then
		for button in pool:IterateActiveObjects() do
			self:RemoveButtonFromMasqueGroup(group, button, update)
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
	button.EmptySlotTextureFile = nil
	group:AddButton(button, {
		Border = button.IconQuestTexture,
		Icon = button.IconTexture,
	})
	button.masqueGroup = group
	button:UpdateIcon()
end

function mod:RemoveButtonFromMasqueGroup(group, button, update)
	button.masqueGroup = nil
	button.EmptySlotTextureFile = addon.EMPTY_SLOT_FILE
	group:RemoveButton(button)
	if update then
		button:UpdateIcon()
	end
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
