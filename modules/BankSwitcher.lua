--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local GameTooltip = _G.GameTooltip
local UseContainerItem = _G.UseContainerItem
--GLOBALS>

local mod = addon:NewModule('BankSwitcher', 'AceEvent-3.0')
mod.uiName = L['Bank Switcher']
mod.uiDesc = L['Move items from and to the bank by right-clicking on section headers.']

function mod:OnEnable()
	self:RegisterMessage('AdiBags_InteractingWindowChanged')
	self:AdiBags_InteractingWindowChanged('OnEnable', addon:GetInteractingWindow())
end

function mod:OnDisable()
	addon.UnregisterAllSectionHeaderScripts(self)
end

function mod:OnEnterSectionHeader(_, header)
	GameTooltip:SetOwner(header, 'ANCHOR_RIGHT', 0, 0)
	GameTooltip:AddLine(L['Right-click to move these items.'])
	GameTooltip:Show()
end

function mod:OnLeaveSectionHeader(_, header)
	if GameTooltip:GetOwner() == header then
		GameTooltip:Hide()
	end
end

function mod:OnClickSectionHeader(_, header, button)
	if button == "RightButton" then
		for slotId, bag, slot in header.section:IterateContainerSlots() do
			UseContainerItem(bag, slot)
		end
	end
end

function mod:AdiBags_InteractingWindowChanged(_, new, old)
	if new == "BANKFRAME" then
		addon.RegisterSectionHeaderScript(self, 'OnEnter', 'OnEnterSectionHeader')
		addon.RegisterSectionHeaderScript(self, 'OnLeave', 'OnLeaveSectionHeader')
		addon.RegisterSectionHeaderScript(self, 'OnClick', 'OnClickSectionHeader')
	elseif old == "BANKFRAME" then
		addon.UnregisterAllSectionHeaderScripts(self)
	end
end