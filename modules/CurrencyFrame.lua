--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('CurrencyFrame', 'AceEvent-3.0')
mod.uiName = L['Currency']
mod.uiDesc = L['Display character currency at bottom left of the backpack.']

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

local ICON_STRING = "\124T%s:16:16:0:0\124t"
local HONOR_ICON_STRING
local ARENA_ICON_STRING = ICON_STRING:format([[Interface\PVPFrame\PVP-ArenaPoints-Icon]])

local collapse = {}
local values = {}
local updating
function mod:Update()
	if not self.widget or updating then return end
	updating = true

	for index = 1, GetCurrencyListSize() do
		local name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon = GetCurrencyListInfo(index)
		if isHeader then
			if not isExpanded then
				tinsert(collapse, index)
				ExpandCurrencyList(index, true)
				self:Debug('Expanded', name)
			end
		elseif isWatched then
			local iconString
			if extraCurrencyType == 1 then
				-- Arena points
				iconString = ARENA_ICON_STRING
			elseif extraCurrencyType == 2 then
				-- Honor points
				if HONOR_ICON_STRING == nil then
					local factionGroup = UnitFactionGroup("player")
					if factionGroup then
						HONOR_ICON_STRING = ICON_STRING:format([[Interface\AddOns\Broker_SimpleCurrency\images\]]..factionGroup)
					end
				end
				iconString = HONOR_ICON_STRING or " "..HONOR
			else
				-- "Standard" token
				iconString = icon and ICON_STRING:format(icon) or ""
			end
			self:Debug('name', count, icon, iconString)
			tinsert(values, ("%d%s"):format(count, iconString))
		end
	end

	for i = #collapse, 1, -1 do
		ExpandCurrencyList(collapse[i], false)
		collapse[i] = nil
		self:Debug('Collapsed', collapse[i])
	end

	local widget, fs = self.widget, self.fontstring
	if #values > 0 then
		widget:Show()
		fs:SetText(table.concat(values, " "))
		widget:SetWidth(fs:GetStringWidth())
		widget:SetHeight(fs:GetStringHeight())
		wipe(values)
	else
		widget:Hide()
	end

	updating = false
end
