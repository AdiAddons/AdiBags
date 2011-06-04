--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local ClearCursor = _G.ClearCursor
local GetCursorInfo = _G.GetCursorInfo
local GetItemInfo = _G.GetItemInfo
local gsub = _G.gsub
local pairs = _G.pairs
local select = _G.select
local setmetatable = _G.setmetatable
local strsplit = _G.strsplit
local strtrim = _G.strtrim
local tinsert = _G.tinsert
local tonumber = _G.tonumber
local tostring = _G.tostring
local tremove = _G.tremove
local type = _G.type
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local mod = addon:RegisterFilter("FilterOverride", 95, "AceEvent-3.0")
mod.uiName = L['Manual filtering']
mod.uiDesc = L['Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title.']

local buttons = {}

function mod:OnInitialize()

	-- This module was named "mod" for quite a while, retrieve the old data if they exists
	if addon.db.sv.namespaces and addon.db.sv.namespaces.mod ~= nil then
		addon.db.sv.namespaces[self.moduleName] = addon.db.sv.namespaces.mod
		addon.db.sv.namespaces.mod = nil
	end

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

function mod:AssignItems(section, category, ...)
	local key = section and category and (section..'#'..category) or nil
	for i = 1, select('#', ...) do
		local itemId = select(i, ...)
		mod.db.profile.overrides[itemId] = key
	end
	self:SendMessage('AdiBags_OverrideFilter', section, category, ...)
	self:SendMessage('AdiBags_FiltersChanged')
	local acr = LibStub('AceConfigRegistry-3.0', true)
	if acr then
		acr:NotifyChange(addonName)
	end
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local categoryValues

local function GetItemId(str)
	local link = str and select(2, GetItemInfo(str))
	return link and tonumber(link:match("item:(%d+)"))
end

local AceConfigRegistry = LibStub('AceConfigRegistry-3.0')

local options
function mod:GetOptions()
	if not options then
		categoryValues = {}
		for name in addon:IterateCategories() do
			categoryValues[name] = name
		end
		local newItemId, newSection, newCategory
		options = {
			newAssoc = {
				type = 'group',
				name = L["New Override"],
				desc = L["Use this section to define any item-section association."],
				order = 10,
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
							mod:AssignItems(newSection, newCategory, newItemId)
							mod:UpdateOptions(newCategory)
							newItemId, newCategory, newSection = nil, nil, nil
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
	local AceConfigDialog = LibStub('AceConfigDialog-3.0')

	local t = {}
	local handlerProto = {
		SetItemAssoc = function(self, section, category)
			wipe(t)
			for itemId in pairs(self.values) do
				tinsert(t, itemId)
			end
			if #t > 0 then
				mod:AssignItems(section, category, unpack(t))
				wipe(t)
				mod:UpdateOptions(self.category, category)
			end
		end,
		GetName = function(self) return self.name end,
		SetName = function(self, info, input) return self:SetItemAssoc(input, self.category) end,
		ValidateName = function(self, info, input) return type(input) == "string" and strtrim(input) ~= "" end,
		GetCategory = function(self) return self.category end,
		SetCategory = function(self, info, input) return self:SetItemAssoc(self.name, input) end,
		ListCategories = function() return categoryValues end,
		Remove = function(self) return self:SetItemAssoc() end,
		ValidateItem = function(self, info, input) return not not GetItemId(input) end,
		AddItem = function(self, info, input, ...)
			mod:AssignItems(self.name, self.category, GetItemId(input))
			mod:UpdateOptions()
		end,
		SetItem = function(self, info, itemId, value)
			if value then
				mod:AssignItems(self.name, self.category, itemId)
			else
				mod:AssignItems(nil, nil, itemId)
			end
			mod:UpdateOptions(self.category)
		end,
		ListItems = function(self)
			wipe(self.values)
			for itemId, key in pairs(mod.db.profile.overrides) do
				if key == self.key then
					self.values[itemId] = true
				end
			end
			return self.values
		end,
	}
	local handlerMeta = { __index = handlerProto }
	local optionProto = {
		type = 'group',
		inline = true,
		args = {
			name = {
				name = L['Section'],
				type = 'input',
				order = 10,
				get = 'GetName',
				set = 'SetName',
				validate = 'ValidateName',
			},
			category = {
				name = L['Category'],
				type = 'select',
				order = 20,
				get = 'GetCategory',
				set = 'SetCategory',
				values = 'ListCategories',
			},
			remove = {
				name = L['Remove'],
				type = 'execute',
				order = 30,
				confirm = true,
				confirmText = L['Are you sure you want to remove this section ?'],
				func = 'Remove',
			},
			items = {
				name = L['Items'],
				desc = L['Click on a item to remove it from the list. You can drop an item on the empty slot to add it to the list.'],
				type = 'multiselect',
				dialogControl = 'ItemList',
				order = 40,
				get = function() return true end,
				set = 'SetItem',
				values = 'ListItems',
			},
		},
	}
	local optionMeta = { __index = optionProto }
	local sectionHeap = {}
	local categories = {}
	local categoryHeap = {}

	function mod:UpdateOptions(selectCategory, fallbackSelectCategory)
		if not options then return end
		setmetatable(handlerProto, { __index = addon:GetOptionHandler(self) })
		for category, categoryGroup in pairs(categories) do
			options[category] = nil
			for _, sectionGroup in pairs(categoryGroup.args) do
				wipe(sectionGroup.handler.values)
				tinsert(sectionHeap, sectionGroup)
			end
			wipe(categoryGroup.args)
			tinsert(categoryHeap, categoryGroup)
		end
		wipe(categories)
		for itemId, override in pairs(self.db.profile.overrides) do
			local section, category = strsplit('#', tostring(override))
			local categoryGroup = categories[category]
			if not categoryGroup then
				categoryGroup = tremove(categoryHeap)
				if not categoryGroup then
					categoryGroup = { name = category, type = 'group', args = {} }
				end
				categoryGroup.name, categoryGroup.order = category, addon:GetCategoryOrder(category)
				categories[category] = categoryGroup
				options[category] = categoryGroup
			end
			local key = gsub(section, "%W", "")
			local sectionGroup = categoryGroup.args[key]
			if not sectionGroup then
				sectionGroup = tremove(sectionHeap)
				if not sectionGroup then
					sectionGroup = setmetatable({handler = setmetatable({values = {}}, handlerMeta)}, optionMeta)
				end
				sectionGroup.name = section
				sectionGroup.handler.key = override
				sectionGroup.handler.name = section
				sectionGroup.handler.category = category
				categoryGroup.args[key] = sectionGroup
			end
		end
		if selectCategory or fallbackSelectCategory then
			if options[selectCategory] then
				AceConfigDialog:SelectGroup(addonName, "filters", mod.filterName, selectCategory)
			elseif options[fallbackSelectCategory] then
				AceConfigDialog:SelectGroup(addonName, "filters", mod.filterName, fallbackSelectCategory)
			else
				AceConfigDialog:SelectGroup(addonName, "filters", mod.filterName)
			end
		end
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
	ClearCursor()
	mod:AssignItems(self.section.name, self.section.category, itemId)
	mod:UpdateOptions()
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
