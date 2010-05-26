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
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
		self:SendMessage('AdiBags_UpdateAllButtons')
	end
end

local function SearchEditBox_OnTextChanged(editBox)
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

	local searchEditBox = CreateFrame("EditBox", addonName.."SearchEditBox", frame, "InputBoxTemplate")
	searchEditBox:SetAutoFocus(false)
	searchEditBox:SetWidth(100)
	searchEditBox:SetHeight(18)
	searchEditBox:SetScript("OnEnterPressed", SearchEditBox_OnEnterPressed)
	searchEditBox:SetScript("OnEscapePressed", SearchEditBox_OnEscapePressed)
	searchEditBox:SetScript("OnTextChanged", SearchEditBox_OnTextChanged)
	self.widget = searchEditBox

	local searchLabel = searchEditBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	searchLabel:SetPoint("TOPRIGHT", searchEditBox, "TOPLEFT", -4, 0)
	searchLabel:SetText(L["Search:"].." ")
	searchLabel:SetHeight(18)

	addon.SetupTooltip(searchEditBox, {
		L["Item search"],
		L["Enter a text to search in item names."]
	}, "ANCHOR_TOPLEFT", 0, 8)

	frame:AddHeaderWidget(searchEditBox, -10, 104 + searchLabel:GetStringWidth(), -1)
end

function mod:UpdateButton(event, button)
	if not self.widget then return end
	local text = self.widget:GetText()
	if text and button.hasItem and text:trim() ~= "" then
		local name = GetItemInfo(button.itemId)
		if name and not name:lower():match(text:lower()) then
			button.IconTexture:SetVertexColor(0.2, 0.2, 0.2)
			button.IconQuestTexture:Hide()
			button.Count:Hide()
			button.Stock:Hide()
		end
	end
end


