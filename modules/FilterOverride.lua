--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:RegisterFilter("mod", 95, "AceEvent-3.0")
mod.uiName = L['Manual filtering']
mod.uiDesc = L['Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title.']

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
	self:UpdateOptions()	
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

local overrideOptionList = {}
do
	local proto = {
		type = 'multiselect',
		confirm = true,
		confirmText = L['Are you sure you want to remove this association ?'],
		get = function(info, itemId) return true end,
		set = function(info, itemId, value)
			if not value then
				 mod.db.profile.overrides[itemId] = nil
				 mod:UpdateOptions()
				 mod:SendMessage('AdiBags_FiltersChanged')
			end
		end,
	}
	local meta = { __index = proto }
	local AceConfigRegistry = LibStub('AceConfigRegistry-3.0')
	local ours = {}

	function mod:UpdateOptions()
		for option in pairs(ours) do
			wipe(option.values)
			option.hidden = true
		end
		for itemId, override in pairs(self.db.profile.overrides) do
			local section, category = strsplit('#', tostring(override))
			local key = strjoin('_', section, category)
			local option = overrideOptionList[key]
			if not option then
				option = setmetatable({ values = {} }, meta)
				if category ~= section then
					option.name = section.. ' ('..category..')'
				else
					option.name = section
				end
				ours[option] = true
				overrideOptionList[key] = option
			end
			option.hidden = false
			option.values[itemId] = GetItemInfo(itemId)
		end
		AceConfigRegistry:NotifyChange(addonName)	
	end
end

local strsplit, strformat = string.split, string.format
function mod:GetOptions()
	return overrideOptionList
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
	mod:UpdateOptions()
	self:SendMessage('AdiBags_FiltersChanged')
	ClearCursor()
end

function mod:NewHeaderButton(...)
	return headerButtonClass:Create(...)
end
