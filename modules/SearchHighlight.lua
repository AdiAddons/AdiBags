--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('SearchHighlight', 'AceEvent-3.0')

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
	searchEditBox:SetPoint("TOPRIGHT", frame.Title)
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
end

function mod:UpdateButton(event, button)
	if not self.widget then return end
	local text = self.widget:GetText()
	local selected = true
	if text and button.hasItem and text:trim() ~= "" then
		local name = GetItemInfo(button.itemId)
		if name and not name:lower():match(text:lower()) then
			selected = false
		end
	end
	if selected then
		button:SetAlpha(1)
	else
		button:SetAlpha(0.3)
	end
end


