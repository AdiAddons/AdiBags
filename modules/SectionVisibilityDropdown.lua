--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CLOSE = _G.CLOSE
local CreateFrame = _G.CreateFrame
local format = _G.format
local ipairs = _G.ipairs
local pairs = _G.pairs
local tinsert = _G.tinsert
local ToggleDropDownMenu = _G.ToggleDropDownMenu
local tsort = _G.table.sort
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local wipe = _G.wipe
--GLOBALS>

local mod = addon:NewModule('SectionVisibilityDropdown', 'AceEvent-3.0')
mod.uiName = L['Section visibility button']
mod.uiDesc = L['Add a dropdown menu to bags that allow to hide the sections.']

local buttons = {}
local frame
local Button_OnClick

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	for button in pairs(buttons) do
		button:Show()
	end
end

function mod:OnDisable()
	for button in pairs(buttons) do
		button:Hide()
	end
end

function mod:OnBagFrameCreated(bag)
	local container = bag:GetFrame()
	local button = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	button:SetText("V")
	button:SetWidth(20)
	button:SetHeight(20)
	button:SetScript("OnClick", Button_OnClick)
	button.container = container
	container:AddHeaderWidget(button, 5)
	addon.SetupTooltip(button, {
		L["Section visibility"],
		L["Click to select which sections should be shown or hidden. Section visibility is common to all bags."]
	}, "ANCHOR_TOPLEFT", 0, 8)
	buttons[button] = true
end

local function CollapseDropDownMenu_ToggleSection(button, key, container)
	local section = container.sections[key]
	if section then
		section:SetCollapsed(not section:IsCollapsed())
	else
		addon.db.char.collapsedSections[key] = not addon.db.char.collapsedSections[key]
		mod:SendMessage('AdiBags_LayoutChanged')
	end
end

local info = {}
local entries = {}
local function CollapseDropDownMenu_Initialize(self, level)
	if not level then return end

	-- Title
	wipe(info)
	info.isTitle = true
	info.text = L['Section visibility']
	info.notCheckable = true
	UIDropDownMenu_AddButton(info, level)

	-- Now list all potential sections
	wipe(entries)
	for key, collapsed in pairs(addon.db.char.collapsedSections) do
		if collapsed and not entries[key] then
			entries[key] = true
			tinsert(entries, key)
		end
	end
	for key in pairs(self.container.sections) do
		if not entries[key] then
			entries[key] = true
			tinsert(entries, key)
		end
	end
	tsort(entries)

	-- Add an entry for each section
	local currentCat = nil
	wipe(info)
	for i, key in ipairs(entries) do
		local name, category = addon:SplitSectionKey(key)
		if category ~= currentCat then
			wipe(info)
			info.text = category
			info.disabled = true
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, level)
			currentCat = category
			wipe(info)
		end
		local section = self.container.sections[key]
		if section then
			info.text = format("%s (%d)", name, section.count)
		else
			info.text = name
		end
		info.isNotRadio = true
		info.tooltipTitle = format(L['Show %s'], name)
		info.tooltipText = L['Check this to show this section. Uncheck to hide it.']
		info.checked = not addon.db.char.collapsedSections[key]
		info.keepShownOnClick = true
		info.arg1 = key
		info.arg2 = self.container
		info.func = CollapseDropDownMenu_ToggleSection
		UIDropDownMenu_AddButton(info, level)
	end

	-- Add menu close entry
	wipe(info)
	info.text = CLOSE
	info.notCheckable = true
	UIDropDownMenu_AddButton(info, level)
end

function Button_OnClick(button)
	if not frame then
		frame = CreateFrame("Frame", addonName.."CollapseDropDownMenu")
		frame.displayMode = "MENU"
		frame.initialize = CollapseDropDownMenu_Initialize
		frame.point = "BOTTOMRIGHT"
		frame.relativePoint = "BOTTOMLEFT"
	end
	frame.container = button.container
	ToggleDropDownMenu(1, nil, frame, 'cursor')
end
