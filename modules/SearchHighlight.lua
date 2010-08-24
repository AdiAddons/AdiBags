--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('SearchHighlight', 'AceEvent-3.0')
mod.uiName = L['Item search']
mod.uiDesc = L['Provides a text widget at top of the backpack where you can type (part of) an item name to locate it in your bags.']

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.widget then
		self.widget:Show()
		self:SendMessage('AdiBags_UpdateAllButtons')
	end
	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')
	self:RegisterMessage('AdiBags_UpdateLock', 'UpdateButton')
	self:RegisterMessage('AdiBags_UpdateBorder', 'UpdateButton')
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
		self:SendMessage('AdiBags_UpdateAllButtons')
	end
end

local function SearchEditBox_OnTextChanged(editBox)
	local text = editBox:GetText()
	if not text or text:trim() == "" then
		editBox.clearButton:Hide()
	else
		editBox.clearButton:Show()
	end
	mod:SendMessage('AdiBags_UpdateAllButtons')
end

local function SearchEditBox_OnEnterPressed(editBox)
	editBox:ClearFocus()
	return SearchEditBox_OnTextChanged(editBox)
end

local function SearchEditBox_OnEscapePressed(editBox)
	editBox:ClearFocus()
	editBox:SetText('')
	return SearchEditBox_OnTextChanged(editBox)
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()

	local searchBox = CreateFrame("Frame", addonName.."SearchFrame", frame)
	searchBox:SetSize(100, 18)
	self.widget = searchBox

	local searchEditBox = CreateFrame("EditBox", nil, searchBox, "InputBoxTemplate")
	searchEditBox:SetAutoFocus(false)
	searchEditBox:SetPoint("TOPLEFT")
	searchEditBox:SetPoint("TOPRIGHT")
	searchEditBox:SetHeight(18)
	searchEditBox:SetScript("OnEnterPressed", SearchEditBox_OnEnterPressed)
	searchEditBox:SetScript("OnEscapePressed", SearchEditBox_OnEscapePressed)
	searchEditBox:SetScript("OnTextChanged", SearchEditBox_OnTextChanged)

	self.widget.editBox = searchEditBox
	self.widget.GetText = function() return searchEditBox:GetText() end

	local searchLabel = searchEditBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	searchLabel:SetPoint("TOPRIGHT", searchEditBox, "TOPLEFT", -4, 0)
	searchLabel:SetText(L["Search:"].." ")
	searchLabel:SetHeight(18)

	local searchClearButton = CreateFrame("Button", nil, searchBox, "UIPanelButtonTemplate")
	searchClearButton:SetPoint("TOPRIGHT", searchBox)
	searchClearButton:SetSize(20, 20)
	searchClearButton:SetText("X")
	searchClearButton:Hide()
	searchClearButton:SetScript('OnClick', function() SearchEditBox_OnEscapePressed(searchEditBox) end)
	searchClearButton:SetScript('OnHide', function() searchEditBox:SetPoint("TOPRIGHT", searchBox, "TOPRIGHT", 0, 0) end)
	searchClearButton:SetScript('OnShow', function() searchEditBox:SetPoint("TOPRIGHT", searchClearButton, "TOPLEFT", -4, 0) end)

	searchEditBox.clearButton = searchClearButton

	addon.SetupTooltip(searchEditBox, {
		L["Item search"],
		L["Enter a text to search in item names."]
	}, "ANCHOR_TOPLEFT", 0, 8)

	frame:AddHeaderWidget(searchBox, -10, 104 + searchLabel:GetStringWidth(), -1)
end

function mod:UpdateButton(event, button)
	if not self.widget then return end
	local text = self.widget:GetText()
	if not text or text:trim() == "" then return end
	text = text:lower():trim()
	local name = button.itemId and GetItemInfo(button.itemId)
	if name and not name:lower():match(text) then
		button.IconTexture:SetVertexColor(0.2, 0.2, 0.2)
		button.IconQuestTexture:Hide()
		button.Count:Hide()
		button.Stock:Hide()
	end
end


