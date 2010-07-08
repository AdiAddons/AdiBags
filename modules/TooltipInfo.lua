--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('TooltipInfo', 'AceEvent-3.0', 'AceHook-3.0')
mod.uiName = L['Tooltip information']
mod.uiDesc = L['Add more information in tooltips related to items in your bags.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.name, {profile={
		item = 'any',
		container = 'any',
		filter = 'any',
	}})
end

function mod:OnEnable()
	self:SecureHook('ContainerFrameItemButton_OnEnter')
	self:SecureHook('BankFrameItemButton_OnEnter', 'ContainerFrameItemButton_OnEnter')
end

function mod:GetOptions()
	local modMeta = { __index = {
		type = "select",
		width = "double",
		values = {
			never = L["Never"],
			shift = L["When shift is held down"],
			ctrl = L["When ctrl is held down"],
			alt = L["When alt is held down"],
			any = L["When any modifier key is held down"],
			always = L["Always"],
		},
	}}
	return {
		item = setmetatable({
			name = L["Show item information..."],
			order = 10,
		}, modMeta),
		container = setmetatable({
			name = L["Show container information..."],
			order = 20,
		}, modMeta),
		filter = setmetatable({
			name = L["Show filtering information..."],
			order = 30,
		}, modMeta),
	}, addon:GetOptionHandler(self)
end

local function TestModifier(name)
	local setting = mod.db.profile[name]
	if setting == "never" then
		return false
	end
	return (setting == "always")
		or (setting == "any" and IsModifierKeyDown())
		or (setting == "shift" and IsShiftKeyDown())
		or (setting == "ctrl" and IsCtrlKeyDown())
		or (setting == "alt" and IsAltKeyDown())
end

function mod:ContainerFrameItemButton_OnEnter(button)
	local bag, slot, container = button.bag, button.slot, button.container
	if not (bag and slot and container) then return end
	local slotData = container.content[bag][slot]
	local tt = GameTooltip

	if slotData.link and TestModifier("item") then
		tt:AddLine(" ")
		tt:AddLine(L["Item information"], 1, 1, 1)
		tt:AddDoubleLine(L["Maximum stack size"], slotData.maxStack)
		tt:AddDoubleLine(L["AH category"], slotData.class)
		tt:AddDoubleLine(L["AH subcategory"], slotData.subclass)
	end

	if TestModifier("container") then
		tt:AddLine(" ")
		tt:AddLine(L["Container information"], 1, 1, 1)
		tt:AddDoubleLine(L["Bag number"], bag)
		tt:AddDoubleLine(L["Slot number"], slot)
	end

	if TestModifier("filter") then
		tt:AddLine(" ")
		tt:AddLine(L["Filtering information"], 1, 1, 1)
		tt:AddDoubleLine(L["Filter"], button.filterName or "-")
		local section = button:GetSection()
		tt:AddDoubleLine(L["Section"], section and section.name or "-")
		tt:AddDoubleLine(L["Category"], section and section.category or "-")
	end

	tt:Show()
end
