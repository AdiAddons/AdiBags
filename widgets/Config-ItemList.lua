--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

-- GLOBALS: CreateFrame UIParent LibStub
local _G = _G
local frame = _G.frame
local GetItemInfo = _G.GetItemInfo
local pairs = _G.pairs
local PlaySound = _G.PlaySound
local self = _G.self
local table = _G.table
local text = _G.text
local tinsert = _G.tinsert
local wipe = _G.wipe

local AceGUI = LibStub("AceGUI-3.0")

--------------------------------------------------------------------------------
-- Item list element
--------------------------------------------------------------------------------

do
	local Type, Version = "ItemListElement", 1

	local function Button_OnClick(frame, ...)
		AceGUI:ClearFocus()
		local widget = frame.obj
		local listWidget = widget:GetUserData('listwidget')
		if not listWidget then return end
		PlaySound("igMainMenuOption")
		local previousId = widget.itemId
		if previousId then
			listWidget:Fire("OnValueChanged", previousId, false)
		end
		local kind, newId = GetCursorInfo()
		if kind == "item" and tonumber(newId) then
			listWidget:Fire("OnValueChanged", newId, true)
			if previousId then
				PickupItem(previousId)
			else
				ClearCursor()
			end
		end
	end
	
	local function Button_OnDragStart(frame)
		local widget = frame.obj
		local listWidget = widget:GetUserData('listwidget')
		if not listWidget or not widget.itemId then return end
		PickupItem(widget.itemId)
		listWidget:Fire("OnValueChanged", widget.itemId, false)
	end

	local function Button_OnEnter(frame)
		local listWidget = frame.obj:GetUserData('listwidget')
		if listWidget then
			listWidget:Fire("OnEnter")
		end
	end

	local function Button_OnLeave(frame)
		local listWidget = frame.obj:GetUserData('listwidget')
		if listWidget then
			listWidget:Fire("OnLeave")
		end
	end

	local methods = {}

	function methods:OnAcquire()
		self:SetWidth(24)
		self:SetHeight(24)
	end

	function methods:OnRelease()
		self:SetUserData('listwidget', nil)
	end

	function methods:SetDisabled(disabled)
		if disabled then
			self.frame:Disable()
		else
			self.frame:Enable()
		end
	end

	function methods:SetItemId(itemId)
		self.itemId = itemId
		if itemId then
			local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
			if name and texture then
				self.frame:SetNormalTexture(texture)
			end
			self.frame:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
		else
			self.frame:SetNormalTexture([[Interface\Buttons\UI-Slot-Background]])
			self.frame:GetNormalTexture():SetTexCoord(0, 41/64, 0, 41/64)
		end
	end

	local function Constructor()
		local name = "AceGUI30ItemListElement" .. AceGUI:GetNextWidgetNum(Type)
		local frame = CreateFrame("Button", name, UIParent)
		frame:Hide()

		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton", "RightButton")
		frame:SetScript("OnClick", Button_OnClick)
		frame:SetScript("OnReceiveDrag", Button_OnClick)
		frame:SetScript("OnDragStart", Button_OnDragStart)
		frame:SetScript("OnEnter", Button_OnEnter)
		frame:SetScript("OnLeave", Button_OnLeave)

		frame:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")

		local widget = {
			text  = text,
			frame = frame,
			type  = Type
		}
		for method, func in pairs(methods) do
			widget[method] = func
		end

		return AceGUI:RegisterAsWidget(widget)
	end

	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

--------------------------------------------------------------------------------
-- Item list
--------------------------------------------------------------------------------

do
	local Type, Version = "ItemList", 1

	local methods = {}

	function methods:SetMultiselect(flag)
		-- Do not care
	end

	function methods:SetLabel(name)
		self:SetTitle(name)
	end

	function methods:SetDisabled(disabled)
		for _, child in pairs(self.children) do
			child:SetDisabled(disabled)
		end
	end

	local function AddItem(self, itemId)
		local widget = AceGUI:Create('ItemListElement')
		widget:SetUserData('listwidget', self)
		widget:SetItemId(itemId)
		self:AddChild(widget)
		return widget
	end

	local t = {}
	function methods:SetList(values)
		self:PauseLayout()
		self:ReleaseChildren()
		wipe(t)
		for itemId in pairs(values) do
			tinsert(t, itemId)
		end
		table.sort(t)
		for _, itemId in pairs(t) do
			AddItem(self, itemId)
		end
		AddItem(self, nil)
		self:SetLayout("Flow")
		self:ResumeLayout()
		self:DoLayout()
	end

	function methods:SetItemValue(key, value)
		-- Do not care
	end

	local function Constructor()
		-- Create a InlineGroup widget an "promote" it to ItemList
		local widget = AceGUI.WidgetRegistry.InlineGroup()
		widget.type = Type
		for method, func in pairs(methods) do
			widget[method] = func
		end
		return widget
	end

	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

