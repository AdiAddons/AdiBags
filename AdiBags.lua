--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0', 'AceBucket-3.0', 'AceHook-3.0', 'LibMovable-1.0')
--@debug@
_G[addonName] = addon
--@end-debug@

--------------------------------------------------------------------------------
-- Debug stuff
--------------------------------------------------------------------------------

if tekDebug then
	local frame = tekDebug:GetFrame(addonName)
	function addon:Debug(...)
		if self.ToString then
			self = self:ToString()
		elseif self.GetName then
			self = self:GetName()
		elseif self == addon then
			self = 'Core'
		else
			self = self.moduleName or self.name or tostring(self)
		end
		frame:AddMessage(string.join(" ", "|cffff7700["..self.."]|r", tostringall(...)))
	end
else
	function addon.Debug() end
end

addon:SetDefaultModulePrototype{Debug = addon.Debug}

--------------------------------------------------------------------------------
-- Helpful constants
--------------------------------------------------------------------------------

do
	-- Backpack and bags
	local BAGS = { [BACKPACK_CONTAINER] = BACKPACK_CONTAINER }
	for i = 1, NUM_BAG_SLOTS do BAGS[i] = i end

	-- Bank bags
	local BANK = { [BANK_CONTAINER] = BANK_CONTAINER }
	for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do BANK[i] = i end

	addon.BAG_IDS = { BAGS = BAGS, BANK = BANK }
end

local FAMILY_TAGS = {
	[0x0001] = L["QUIVER_TAG"], -- Quiver
  [0x0002] = L["AMMO_TAG"], -- Ammo Pouch
  [0x0004] = L["SOUL_BAG_TAG"], -- Soul Bag
  [0x0008] = L["LEATHERWORKING_BAG_TAG"], -- Leatherworking Bag
  [0x0010] = L["INSCRIPTION_BAG_TAG"], -- Inscription Bag
  [0x0020] = L["HERB_BAG_TAG"], -- Herb Bag
  [0x0040] = L["ENCHANTING_BAG_TAG"] , -- Enchanting Bag
  [0x0080] = L["ENGINEERING_BAG_TAG"], -- Engineering Bag
  [0x0100] = L["KEYRING_TAG"], -- Keyring
  [0x0200] = L["GEM_BAG_TAG"], -- Gem Bag
  [0x0400] = L["MINING_BAG_TAG"], -- Mining Bag
}

local FAMILY_ICONS = {
	[0x0001] = [[Interface\Icons\INV_Misc_Ammo_Arrow_01]], -- Quiver
  [0x0002] = [[Interface\Icons\INV_Misc_Ammo_Bullet_05]], -- Ammo Pouch
  [0x0004] = [[Interface\Icons\INV_Misc_Gem_Amethyst_02]], -- Soul Bag
  [0x0008] = [[Interface\Icons\Trade_LeatherWorking]], -- Leatherworking Bag
  [0x0010] = [[Interface\Icons\INV_Inscription_Tradeskill01]], -- Inscription Bag
  [0x0020] = [[Interface\Icons\Trade_Herbalism]], -- Herb Bag
  [0x0040] = [[Interface\Icons\Trade_Engraving]], -- Enchanting Bag
  [0x0080] = [[Interface\Icons\Trade_Engineering]], -- Engineering Bag
  [0x0100] = [[Interface\Icons\INV_Misc_Key_14]], -- Keyring
  [0x0200] = [[Interface\Icons\INV_Misc_Gem_BloodGem_01]], -- Gem Bag
  [0x0400] = [[Interface\Icons\Trade_Mining]], -- Mining Bag
}

function addon:GetFamilyTag(family)
	if family and family ~= 0 then
		for mask, tag in pairs(FAMILY_TAGS) do
			if bit.band(family, mask) ~= 0 then
				return tag, FAMILY_ICONS[mask]
			end
		end
	end
end

addon.ITEM_SIZE = 37
addon.ITEM_SPACING = 4
addon.SECTION_SPACING = addon.ITEM_SIZE / 3 + addon.ITEM_SPACING
addon.BAG_WIDTH = 12
addon.BAG_INSET = 8
addon.TOP_PADDING = 32

addon.BACKDROP = {
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
addon.BACKDROPCOLOR = {
	backpack = { 0, 0, 0, 1 },
	bank = { 0, 0, 0.5, 1 },
}

--------------------------------------------------------------------------------
-- Addon initialization and enabling
--------------------------------------------------------------------------------

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", {profile = {
		anchor = {},
	},}, true)
	self.itemParentFrames = {}
	self.bags = { Bank = true, Backpack = true }

	self:CreateBagAnchor()
end

function addon:OnEnable()
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('BANKFRAME_CLOSED')

	self:RegisterEvent('BAG_UPDATE')
	self:RegisterBucketEvent('PLAYERBANKSLOTS_CHANGED', 0, 'BankUpdated')
	self:RegisterBucketMessage({'AdiBags_BagOpened', 'AdiBags_BagClosed'}, 0, 'LayoutBags')
	
	self:RawHook("OpenAllBags", true)
	self:RawHook("CloseAllBags", true)
	
	self:RegisterEvent('MAIL_CLOSED', 'CloseAllBags')
	self:SecureHook('CloseSpecialWindows', 'CloseAllBags')
end

--------------------------------------------------------------------------------
-- Event handlers
--------------------------------------------------------------------------------

function addon:BANKFRAME_OPENED()
	self.atBank = true
	self:OpenAllBags(true)
end

function addon:BANKFRAME_CLOSED()
	self.atBank = false
	self:CloseAllBags()
end

function addon:BAG_UPDATE(event, bag)
	self:SendMessage('AdiBags_BagUpdated', bag)
end

function addon:BankUpdated(slots)
	-- Wrap several PLAYERBANKSLOTS_CHANGED into one AdiBags_BagUpdated message
	self:SendMessage('AdiBags_BagUpdated', BANK_CONTAINER)
end

-- No typo there, it is really addon.UpdateAllBags
function addon.UpdateAllBags()
	addon:SendMessage('AdiBags_UpdateAllBags')
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

function addon.GetSlotId(bag, slot)
	if bag and slot then
		return bag * 100 + slot
	end
end

function addon.GetBagSlotFromId(slotId)
	if slotId then
		return math.floor(slotId / 100), slotId % 100
	end
end

--------------------------------------------------------------------------------
-- Bag anchor and layout
--------------------------------------------------------------------------------

local function Anchor_StartMoving(anchor)
	for _, bag in addon:IterateBags(true) do
		anchor.openBags[bag] = true
		bag:GetFrame():Hide()
	end
end

local function Anchor_StopMovingOrSizing(anchor)
	for	bag in pairs(anchor.openBags) do
		bag:GetFrame():Show()
	end
	wipe(anchor.openBags)
	addon:LayoutBags()
end

function addon:CreateBagAnchor()
	local anchor = CreateFrame("Frame", addonName.."Anchor", UIParent)
	anchor:SetPoint("BOTTOMRIGHT", -32, 200)
	anchor:SetWidth(200)
	anchor:SetHeight(20)
	anchor.openBags = {}
	hooksecurefunc(anchor, "StartMoving", Anchor_StartMoving)
	hooksecurefunc(anchor, "StopMovingOrSizing", Anchor_StopMovingOrSizing)
	self.anchor = anchor
	self:RegisterMovable(anchor, self.db.profile.anchor, L["AdiBags anchor"])
end

function addon:LayoutBags()
	local nextBag, data, index, bag = self:IterateBags(true)
	index, bag = nextBag(data, index)
	if not bag then return end

	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local x, y = self.anchor:GetCenter()
	local anchorPoint =
		((y > 0.6 * h) and "TOP" or (y < 0.4 * h) and "BOTTOM" or "") ..
		((x < 0.4 * w) and "LEFT" or (x > 0.6 * w) and "RIGHT" or "")
	if anchorPoint == "" then anchorPoint = "CENTER" end

	local frame = bag:GetFrame()
	frame:ClearAllPoints()
	frame:SetPoint(anchorPoint, 0, 0)
	
	local lastBag = bag	
	index, bag = nextBag(data, index)
	if not bag then return end
	
	local vPart = anchorPoint:match("TOP") or anchorPoint:match("BOTTOM") or ""
	local hFrom, hTo, x = "LEFT", "RIGHT", 10
	if anchorPoint:match("RIGHT") then
		hFrom, hTo, x = "RIGHT", "LEFT", -10
	end
	local fromPoint = vPart..hFrom
	local toPoint = vPart.hTo
	
	while bag do
		local frame = bag:GetFrame()
		frame:ClearAllPoints()
		frame:SetPoint(fromPoint, lastBag, toPoint, x, 0)
		lastBag, index, bag = bag, nextBag(bag, index)
	end
end



