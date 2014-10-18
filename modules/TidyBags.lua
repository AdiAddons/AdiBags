--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2014 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
--GLOBALS>

local mod = addon:NewModule('TidyBags', 'AceEvent-3.0', 'AceBucket-3.0')
mod.uiName = L['Tidy bags']
mod.uiDesc = L['Tidy your bags by clicking on the small "T" button at the top left of bags. Special bags with free slots will be filled with macthing items and stackable items will be stacked to save space.']

local buttons = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			autoTidy = false,
		},
	})
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')

	self:RegisterMessage('AdiBags_InteractingWindowChanged')
	self:RegisterEvent('LOOT_CLOSED', 'AutomaticTidy')
	self:RegisterEvent('PLAYER_REGEN_ENABLED')

	for _, button in pairs(buttons) do
		button:Show()
	end
end

function mod:OnDisable()
	for _, button in pairs(buttons) do
		button:Hide()
	end
end

function mod:GetOptions()
	return {
		autoTidy = {
			name = L['Semi-automated tidy'],
			desc = L['Check this so tidying is performed when you close the loot windows or you leave merchants, mailboxes, etc.'],
			width = 'double',
			type = 'toggle',
			order = 10,
		},
	}, addon:GetOptionHandler(self)
end

function mod:AdiBags_InteractingWindowChanged(event, new)
	if not new then
		return self:AutomaticTidy(event)
	end
end

function mod:AutomaticTidy(event)
	if not self.db.profile.autoTidy or InCombatLockdown() or addon.spellIsTargeting then return end
	self:Debug('AutomaticTidy on', event)
	for bag in pairs(buttons) do
		bag:AutoSort()
	end
end

function mod:PLAYER_REGEN_ENABLED(event)
	self:AutomaticTidy(event)
end

local function Button_OnClick(widget, button)
	if button == "RightButton" then
		return mod:OpenOptions()
	end
	return widget.bag:AutoSort()
end

function mod:OnBagFrameCreated(bag)
	button = bag:GetFrame():CreateModuleButton("T", 0, Button_OnClick, {
		BAG_CLEANUP_BAGS,
		L["Right-click to configure."]
	})
	button.bag = bag
	buttons[bag] = button
end
