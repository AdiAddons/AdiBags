--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local ExpandCurrencyList = _G.ExpandCurrencyList
local format = _G.format
local GetCurrencyListInfo = _G.GetCurrencyListInfo
local GetCurrencyListSize = _G.GetCurrencyListSize
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local IsAddOnLoaded = _G.IsAddOnLoaded
local tconcat = _G.table.concat
local tinsert = _G.tinsert
local wipe = _G.wipe
--GLOBALS>

local mod = addon:NewModule('CurrencyFrame', 'AceEvent-3.0')
mod.uiName = L['Currency']
mod.uiDesc = L['Display character currency at bottom left of the backpack.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			shown = { ['*'] = true },
		},
	})
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.widget then
		self.widget:Show()
	end
	self:RegisterEvent('KNOWN_CURRENCY_TYPES_UPDATE', "Update")
	self:RegisterEvent('CURRENCY_DISPLAY_UPDATE', "Update")
	self:RegisterEvent('HONOR_CURRENCY_UPDATE', "Update")
	if not self.hooked then
		if IsAddOnLoaded('Blizzard_TokenUI') then
			self:ADDON_LOADED('OnEnable', 'Blizzard_TokenUI')
		else
			self:RegisterEvent('ADDON_LOADED')
		end
	end
	self:Update()
end

function mod:ADDON_LOADED(_, name)
	if name ~= 'Blizzard_TokenUI' then return end
	self:UnregisterEvent('ADDON_LOADED')
	hooksecurefunc('TokenFrame_Update', function() self:Update() end)
	self.hooked = true
end

function mod:OnDisable()
	if self.widget then
		self.widget:Hide()
	end
end

function mod:OnBagFrameCreated(bag)
	if bag.bagName ~= "Backpack" then return end
	local frame = bag:GetFrame()
	self.widget = CreateFrame("Frame", addonName.."CurrencyFrame", frame)
	self.fontstring = self.widget:CreateFontString(nil, "OVERLAY","NumberFontNormalLarge")
	self.fontstring:SetPoint("BOTTOMLEFT", 0 ,1)
	--AddBottomWidget(widget, side, order, height, xOffset, yOffset)
	frame:AddBottomWidget(self.widget, "LEFT", 50, 13)
	self:Update()
end

local IterateCurrencies
do
	local function iterator(collapse, index)
		if not index then return end
		repeat
			index = index + 1
			local name, isHeader, isExpanded, isUnused, isWatched, count, icon = GetCurrencyListInfo(index)
			if name then
				if isHeader then
					if not isExpanded then
						tinsert(collapse, 1, index)
						ExpandCurrencyList(index, true)
					end
				else
					return index, name, isHeader, isExpanded, isUnused, isWatched, count, icon
				end
			end
		until index > GetCurrencyListSize()
		for i, index in ipairs(collapse) do
			ExpandCurrencyList(index, false)
		end
	end

	local collapse = {}
	function IterateCurrencies()
		wipe(collapse)
		return iterator, collapse, 0
	end
end

local ICON_STRING = "%d\124T%s:0:0:0:0:64:64:5:59:5:59\124t"

local values = {}
local updating
function mod:Update()
	if not self.widget or updating then return end
	updating = true

	for i, name, _, _, _, _, count, icon in IterateCurrencies() do
		if self.db.profile.shown[name] then
			tinsert(values, format(ICON_STRING, count, icon))
		end
	end

	local widget, fs = self.widget, self.fontstring
	if #values > 0 then
		widget:Show()
		fs:SetText(tconcat(values, " "))
		widget:SetWidth(fs:GetStringWidth())
		widget:SetHeight(fs:GetStringHeight())
		wipe(values)
	else
		widget:Hide()
	end

	updating = false
end

function mod:GetOptions()
	local values = {}
	local function GetValueList()
		wipe(values)
		for i, name in IterateCurrencies() do
			values[name] = name
		end
		return values
	end

	return {
		shown = {
			name = L['Currencies to show'],
			type = 'multiselect',
			order = 10,
			values = GetValueList,
			set = function(info, ...)
				info.handler:Set(info, ...)
				mod:Update()
			end
		},
	}, addon:GetOptionHandler(self)
end

