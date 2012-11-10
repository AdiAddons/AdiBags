--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local BreakUpLargeNumbers = _G.BreakUpLargeNumbers
local CreateFont = _G.CreateFont
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
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local mod = addon:NewModule('CurrencyFrame', 'AceEvent-3.0')
mod.uiName = L['Currency']
mod.uiDesc = L['Display character currency at bottom left of the backpack.']

local LSM = LibStub('LibSharedMedia-3.0')
local font = CreateFont(mod.name..'Font')
font:SetFontObject("NumberFontNormalLarge")

local DEFAULTS

function mod:OnInitialize()
	local fontFile, fontSize = font:GetFont()
	local fontName
	for name, file in pairs(LSM:HashTable(LSM.MediaType.FONT)) do
		if file == fontFile then
			fontName = name
			break
		end
	end
	DEFAULTS =  {
		shown = { ['*'] = true },
		hideZeroes = true,
		text = {
			name = fontName,
			size = floor(fontSize),
			color = { font:GetTextColor() }
		}
	}
	self.db = addon.db:RegisterNamespace(self.moduleName, { profile = DEFAULTS })
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

	local widget =CreateFrame("Button", addonName.."CurrencyFrame", frame)
	self.widget = widget
	widget:SetHeight(16)
	widget:RegisterForClicks("RightButtonUp")
	widget:SetScript('OnClick', function() self:OpenOptions() end)
	addon.SetupTooltip(widget, { L['Currency'], L['Right-click to configure.'] }, "ANCHOR_BOTTOMLEFT")

	local fs = widget:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(font)
	fs:SetPoint("BOTTOMLEFT", 0, 1)
	self.fontstring = fs

	self:Update()
	frame:AddBottomWidget(widget, "LEFT", 50, 19)
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

local ICON_STRING = "\124T%s:0:0:0:0:64:64:5:59:5:59\124t "

local values = {}
local updating
function mod:Update()
	if not self.widget or updating then return end
	updating = true

	local fontSkin = self.db.profile.text
	local fontName = LSM:Fetch(LSM.MediaType.FONT, fontSkin.name)
	font:SetFont(fontName, fontSkin.size, "OUTLINE")
	font:SetTextColor(unpack(fontSkin.color, 1, 3))

	local shown, hideZeroes = self.db.profile.shown, self.db.profile.hideZeroes
	for i, name, _, _, _, _, count, icon in IterateCurrencies() do
		if shown[name] and (count > 0 or not hideZeroes) then
			tinsert(values, BreakUpLargeNumbers(count))
			tinsert(values, format(ICON_STRING, icon))
		end
	end

	local widget, fs = self.widget, self.fontstring
	if #values > 0 then
		fs:SetText(tconcat(values, ""))
		widget:Show()
		widget:SetWidth(fs:GetStringWidth() + 4 * #values)
		wipe(values)
	else
		widget:Hide()
	end

	updating = false
end

function mod:GetOptions()
	local values = {}
	return {
		shown = {
			name = L['Currencies to show'],
			type = 'multiselect',
			order = 10,
			values = function()
				wipe(values)
				for i, name, _, _, _, _, _, icon in IterateCurrencies() do
					values[name] = format(ICON_STRING, icon)..name
				end
				return values
			end,
			width = 'double',
		},
		hideZeroes = {
			name = L['Hide zeroes'],
			desc = L['Ignore currencies with null amounts.'],
			type = 'toggle',
			order = 20,
		},
		text = addon:CreateFontOptions("text", 30, DEFAULTS.text.size, function()
			local text, def = self.db.profile.text, DEFAULTS.text
			text.name, text.size = def.name, def.size
			text.color[1], text.color[2], text.color[3] = unpack(def.color)
			return self:Update()
		end)
	}, addon:GetOptionHandler(self, false, function() return self:Update() end)
end

