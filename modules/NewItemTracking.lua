--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2012 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local CreateFrame = _G.CreateFrame
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetInventoryItemID = _G.GetInventoryItemID
local GetInventoryItemLink = _G.GetInventoryItemLink
local next = _G.next
local pairs = _G.pairs
local PlaySound = _G.PlaySound
local strmatch = _G.strmatch
local tonumber = _G.tonumber
local type = _G.type
local unpack = _G.unpack
local wipe = _G.wipe
--GLOBALS>

local mod = addon:RegisterFilter('NewItem', 80, 'AceEvent-3.0')
mod.uiName = L['Track new items']
mod.uiDesc = L['Track new items in each bag, displaying a glowing aura over them and putting them in a special section. "New" status can be reset by clicking on the small "N" button at top left of bags.']

function mod:OnInitialize()
	self.db = addon.db:RegisterNamespace(self.moduleName, {
		profile = {
			highlight = "legacy",
			glowScale = 1.5,
			glowColor = { 0.3, 1, 0.3, 0.7 },
			ignoreJunk = false,
		},
	})

	-- Upgrade from previous version
	if self.db.profile.showGlow == false then
		self.db.profile.highlight = "none"
		self.db.profile.showGlow = nil
	end

	addon:SetCategoryOrder(L['New'], 100)
end

function mod:OnEnable()
	addon:HookBagFrameCreation(self, 'OnBagFrameCreated')
	if self.button then
		self.button:Show()
	end

	self:RegisterMessage('AdiBags_UpdateButton', 'UpdateButton')
	self:RegisterEvent('BAG_NEW_ITEMS_UPDATED')

	addon.filterProto.OnEnable(self)
end

function mod:OnDisable()
	if self.button then
		self.button:Hide()
	end
	addon.filterProto.OnDisable(self)
end

--------------------------------------------------------------------------------
-- Widget creation
--------------------------------------------------------------------------------

local function ResetButton_OnClick(widget, button)
	if button == "RightButton" then
		return mod:OpenOptions()
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	C_NewItems.ClearAll()
	mod.button:Disable()
	mod:SendMessage('AdiBags_FiltersChanged', true)
end

function mod:OnBagFrameCreated(bag)
	if bag.isBank then return end
	self.button = bag:GetFrame():CreateModuleButton("N", 10, ResetButton_OnClick, {
		L["Reset new items"],
		L["Click to reset item status."],
		L["Right-click to configure."]
	})
	self.button:Disable()
	self:SendMessage('AdiBags_FiltersChanged', true)
end

function mod:UpdateButton(event, button)
	if addon.BAG_IDS.BANK[button.bag] then return end
	local isNew = self:IsNew(button.bag, button.slot)
	if isNew then
		self.button:Enable()
	end
	self:ShowLegacyGlow(button, isNew and mod.db.profile.highlight == "legacy")
	self:ShowBlizzardGlow(button, isNew and mod.db.profile.highlight == "blizzard")
end

--------------------------------------------------------------------------------
-- Filtering
--------------------------------------------------------------------------------

function mod:IsNew(bag, slot)
	return not addon.BAG_IDS.BANK[bag]
		and C_NewItems.IsNewItem(bag, slot)
		and not IsBattlePayItem(bag, slot)
		and (not self.db.profile.ignoreJunk or select(4, GetContainerItemInfo(bag, slot)) ~= LE_ITEM_QUALITY_POOR)
end

function mod:BAG_NEW_ITEMS_UPDATED(event)
	if self.button and self.button:IsVisible() then
		self.button:Disable()
		self:SendMessage('AdiBags_FiltersChanged', true)
	end
end

function mod:Filter(slotData)
	if self:IsNew(slotData.bag, slotData.slot) then
		self.button:Enable()
		return L["New"]
	end
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

function mod:GetOptions()
	return {
		highlight = {
			name = L['Highlight style'],
			type = 'select',
			order = 10,
			width = 'double',
			values = {
				none = L["None"],
				legacy = L["Legacy"],
				blizzard = L["6.0"]
			}
		},
		glowScale = {
			name = L['Highlight scale'],
			type = 'range',
			min = 0.5,
			max = 3.0,
			step = 0.01,
			isPercent = true,
			bigStep = 0.05,
			order = 20,
		},
		glowColor = {
			name = L['Highlight color'],
			type = 'color',
			order = 30,
			hasAlpha = true,
		},
		ignoreJunk = {
			name = L['Ignore low quality items'],
			type = 'toggle',
			order = 40,
			set = function(info, ...)
				info.handler:Set(info, ...)
				self:UpdateBags()
			end,
			width = 'double',
		},
	}, addon:GetOptionHandler(self)
end

--------------------------------------------------------------------------------
-- Blizzard glow
--------------------------------------------------------------------------------

function mod:ShowBlizzardGlow(button, enable)
	if enable then
		if quality and NEW_ITEM_ATLAS_BY_QUALITY[quality] then
			button.NewItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[quality])
		else
			button.NewItemTexture:SetAtlas("bags-glow-white")
		end
		button.NewItemTexture:Show()
		if not button.flashAnim:IsPlaying() and not button.newitemglowAnim:IsPlaying() then
			button.flashAnim:Play()
			button.newitemglowAnim:Play()
		end
	else
		button.NewItemTexture:Hide()
		if button.flashAnim:IsPlaying() or button.newitemglowAnim:IsPlaying() then
			button.flashAnim:Stop()
			button.newitemglowAnim:Stop()
		end
	end
end

--------------------------------------------------------------------------------
-- Legacy glow
--------------------------------------------------------------------------------

local glows = {}

local function Glow_Update(glow)
	glow:SetScale(mod.db.profile.glowScale)
	glow.Texture:SetVertexColor(unpack(mod.db.profile.glowColor))
end

local function CreateGlow(button)
	local glow = CreateFrame("FRAME", nil, button)
	glow:SetFrameLevel(button:GetFrameLevel()+15)
	glow:SetPoint("CENTER")
	glow:SetWidth(addon.ITEM_SIZE)
	glow:SetHeight(addon.ITEM_SIZE)

	local tex = glow:CreateTexture("OVERLAY")
	tex:SetTexture([[Interface\Cooldown\starburst]])
	tex:SetBlendMode("ADD")
	tex:SetAllPoints(glow)
	glow.Texture = tex

	local group = glow:CreateAnimationGroup()
	group:SetLooping("REPEAT")

	local anim = group:CreateAnimation("Rotation")
	anim:SetOrder(1)
	anim:SetDuration(10)
	anim:SetDegrees(360)
	anim:SetOrigin("CENTER", 0, 0)

	group:Play()

	glow.Update = Glow_Update

	glows[button] = glow
	return glow
end

function mod:ShowLegacyGlow(button, enable)
	local glow = glows[button]
	if enable then
		if not glow then
			glow = CreateGlow(button)
		end
		glow:Update()
		glow:Show()
	elseif glow then
		glow:Hide()
	end
end
