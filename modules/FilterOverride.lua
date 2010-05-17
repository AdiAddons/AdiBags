--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:RegisterFilter("mod", 95, "AceEvent-3.0")
mod.uiName = L['Manual filtering']
mod.uiDesc = L['Allow you ']

local buttons = {}

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, { profile = { overrides = {} } })
end

function mod:OnEnable()
	for section in addon:GetPool("Section"):IterateAllObjects() do
		self:HookSection("OnEnable", section)
	end
	self:RegisterMessage('AdiBags_SectionCreated', 'HookSection')
	for button in pairs(buttons) do
		button:Show()
	end
end

function mod:OnDisable()
	for section in addon:GetPool("Section"):IterateAllObjects() do
		self:HookSection("OnEnable", section)
	end
	self:RegisterMessage('AdiBags_SectionCreated', 'HookSection')
	for button in pairs(buttons) do
		button:Hide()
	end
end

local seen = {}
function mod:HookSection(event, section)
	if seen[section] then return end
	seen[section] = true
	local button = self:NewHeaderButton(section)
	button:Show()
	buttons[button] = true
end

function mod:Filter(slotData)
	local override = self.db.profile.overrides[slotData.itemId]
	if override then
		return strsplit('#', override)
	end
end

--------------------------------------------------------------------------------
-- Section header button class
--------------------------------------------------------------------------------

local headerButtonClass, headerButtonProto = addon:NewClass("SectionHeaderButton", "Button", "AceEvent-3.0")

function headerButtonProto:OnCreate(section)
	self:SetParent(section)
	self.section = section
	self:SetPoint("TOPLEFT")
	self:SetPoint("TOPRIGHT")
	self:SetPoint("BOTTOM", section.Header)
	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)
	self:SetScript('OnClick', self.OnClick)
	self:SetScript('OnReceiveDrag', self.OnClick)
	self:EnableMouse(true)
	self:RegisterForClicks("AnyUp")
	
	self:SetHighlightTexture([[Interface\BUTTONS\UI-Panel-Button-Highlight]], "ADD")
	self:GetHighlightTexture():SetTexCoord(4/128, 76/128, 4/32, 18/32)
	
	addon.SetupTooltip(self, L["Drop your item there to add it to this section."])
end

function headerButtonProto:GetOverride()
	return strjoin('#', self.section.name, self.section.category)
end

function headerButtonProto:CURSOR_UPDATE()
	local contentType, itemId = GetCursorInfo()
	if contentType == "item" then
		self:Enable()
	else
		self:Disable()
	end
end

function headerButtonProto:OnShow()
	self:RegisterEvent("CURSOR_UPDATE")
	self:CURSOR_UPDATE()
end

function headerButtonProto:OnHide()
	self:UnregisterEvent("CURSOR_UPDATE")
end

function headerButtonProto:OnClick()
	local contentType, itemId = GetCursorInfo()
	if contentType ~= "item" then return end
	mod.db.profile.overrides[itemId] = self:GetOverride()
	self:SendMessage('AdiBags_FiltersChanged')
	ClearCursor()
end

function mod:NewHeaderButton(...)
	return headerButtonClass:Create(...)
end
