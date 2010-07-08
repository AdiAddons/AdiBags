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

function mod:Filter(slotData)
	local override = self.db.profile.overrides[slotData.itemId]
	if override then
		return strsplit('#', override)
	end
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local options
function mod:GetOptions()
	if not options then
		local categoryValues = {}
		for name in addon:IterateCategories() do
			categoryValues[name] = name
		end
		local function GetItemId(str)
			local link = str and select(2, GetItemInfo(str))
			return link and tonumber(link:match("item:(%d+)"))
		end
		local newItemId, newSection, newCategory
		options = {
			newAssoc = {
				type = 'group',
				name = L["New Override"],
				desc = L["Use this section to define any item-section association."],
				order = -10,
				inline = true,
				args = {
					item = {
						type = 'input',
						name = L['Item'],
						desc = L["Enter the name, link or itemid of the item to associate with the section. You can also drop an item into this box."],
						order = 10,
						get = function() return newItemId and select(2, GetItemInfo(newItemId)) end,
						set = function(_, value) newItemId = GetItemId(value) end,
						validate = function(_, value) return not not GetItemId(value) end,
					},
					section = {
						type = 'input',
						name = L['Section'],
						desc = L["Enter the name of the section to associate with the item."],
						order = 20,
						get = function() return newSection end,
						set = function(_, value) newSection = value end,
						validate = function(_, value) return value and value:trim() ~= "" end,
					},
					category = {
						type = 'select',
						name = L['Section category'],
						desc = L["Select the category of the section to associate. This is used to group sections together."],
						order = 30,
						get = function() return newCategory end,
						set = function(_, value) newCategory = value end,
						values = categoryValues,
					},
					add = {
						type = 'execute',
						name = L['Add association'],
						desc = L["Click on this button to create the new association."],
						order = 40,
						func = function()
							mod.db.profile.overrides[newItemId] = strjoin('#', newSection, newCategory)
							newItemId, newCategory, newSection = nil, nil, nil
							mod:UpdateOptions()
							mod:SendMessage('AdiBags_FiltersChanged')
						end,
						disabled = function()
							return not newItemId or not newSection or not newCategory
						end,
					},
				},
			},
		}
		mod:UpdateOptions()
	end

	return options
end

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

	local function CompareOptions(a, b)
		return a.arg < b.arg
	end

	local tmp = {}
	function mod:UpdateOptions()
		if not options then return end
		for option in pairs(ours) do
			wipe(option.values)
			option.hidden = true
		end
		wipe(tmp)
		for itemId, override in pairs(self.db.profile.overrides) do
			local section, category = strsplit('#', tostring(override))
			local key = strjoin('_', section, category)
			local option = options[key]
			if not option then
				option = setmetatable({
					name = format("[%s] %s", category, section),
					arg = format('%05d:%s', 1000+addon:GetCategoryOrder(category), section),
					width = 'double',
					values = {}
				}, meta)
				ours[option] = true
				options[key] = option
			end
			tinsert(tmp, option)
			option.hidden = false
			local name, _, quality, _, _, _, _,  _, _, icon = GetItemInfo(itemId)
			if not name then
				option.values[itemId] = format("#%d", itemId)
			else
				local color = ITEM_QUALITY_COLORS[quality or 1]
				local hex = color and color.hex or ''
				option.values[itemId] = format("|T%s:20:20|t %s%s|r", icon, (color and color.hex or ''), name)
			end
		end
		table.sort(tmp, CompareOptions)
		local order = 100
		for i, option in pairs(tmp) do
			option.order = order
			order = order + 1
		end
		AceConfigRegistry:NotifyChange(addonName)
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

local seen = {}
function mod:HookSection(event, section)
	if seen[section] then return end
	seen[section] = true
	local button = self:NewHeaderButton(section)
	button:Show()
	buttons[button] = true
end
