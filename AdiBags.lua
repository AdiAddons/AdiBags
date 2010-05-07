--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0', 'AceBucket-3.0', 'AceHook-3.0')
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
	addon.itemParentFrames = {}
	addon.bags = { Bank = true, Backpack = true }
end

function addon:OnEnable()
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('BANKFRAME_CLOSED')

	self:RegisterEvent('BAG_UPDATE')
	self:RegisterBucketEvent('PLAYERBANKSLOTS_CHANGED', 0, 'BankUpdated')
	
	self:RawHook('ToggleBackpack', true)
	self:RawHook('OpenBackpack', true)
	self:RawHook('CloseBackpack', true)
	self:RawHook("OpenAllBags", true)
	self:RawHook("CloseAllBags", true)
	
	self:RegisterEvent('MAIL_CLOSED', 'CloseAllBags')
	self:SecureHook('CloseSpecialWindows', 'CloseAllBags')
	
	-- Disable the BankFrame
	BankFrame.Show = BankFrame.Hide
	BankFrame:UnregisterAllEvents()
	BankFrame:SetScript('OnEvent', BankFrame.Hide)
	BankFrame:Hide()
	--self:HookScript(BankFrame, "OnEvent", "BankFrame_OnEvent")
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
-- Search feature
--------------------------------------------------------------------------------

function addon:GetSearchText()
	local text = self.searchEditBox and self.searchEditBox:GetText()
	if text and text:trim() ~= "" then
		return text
	end
end

function addon:OnSearchTextChanged()
	for name, bag in pairs(self.bags) do
		if bag ~= true and bag:IsVisible() then
			for i, button in ipairs(bag.buttons) do
				button:UpdateSearchStatus("OnSearchTextChanged")
			end
		end
	end
end

local function SearchEditBox_OnTextChanged(editBox)
	return addon:OnSearchTextChanged()
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

--------------------------------------------------------------------------------
-- Bag handling
--------------------------------------------------------------------------------

function addon:CreateBag(name, bags, isBank)
	local container = self:CreateContainerFrame(name, bags, isBank)
	local cname = container:GetName()
	for id in pairs(bags) do
		local f = CreateFrame("Frame", cname..'Bag'..id, container)
		f.isBank = isBank
		f:SetID(id)
		addon.itemParentFrames[id] = f
	end
	self.bags[name] = container
	return container
end

function addon:GetBag(name, noCreate)
	local bag = self.bags[name]
	if bag and bag ~= true then
		return bag
	elseif noCreate then
		return
	end
	if name == "Backpack" then -- L["Backpack"]
		bag = self:CreateBag("Backpack", self.BAG_IDS.BAGS)
		bag:SetPoint("BOTTOMRIGHT", -20, 300)	
		
		local searchEditBox = CreateFrame("EditBox", addonName.."SearchEditBox", bag, "InputBoxTemplate")
		
		searchEditBox:SetAutoFocus(false)
		searchEditBox:SetPoint("TOPRIGHT", bag.Title)
		searchEditBox:SetWidth(100)
		searchEditBox:SetHeight(18)
		searchEditBox:SetScript("OnEnterPressed", SearchEditBox_OnEnterPressed)
		searchEditBox:SetScript("OnEscapePressed", SearchEditBox_OnEscapePressed)
		searchEditBox:SetScript("OnTextChanged", SearchEditBox_OnTextChanged)
		self.searchEditBox = searchEditBox

		local searchLabel = searchEditBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		searchLabel:SetPoint("TOPRIGHT", searchEditBox, "TOPLEFT", -4, 0)
		searchLabel:SetText(L["Search:"].." ")
		searchLabel:SetHeight(18)

	elseif name == "Bank" then -- L["Bank"]
		bag = self:CreateBag("Bank", self.BAG_IDS.BANK, true)
		bag:SetPoint("BOTTOMRIGHT", self:GetBag("Backpack"), "BOTTOMLEFT", -10, 0)
		bag:HookScript('OnHide', function() if addon.atBank then CloseBankFrame() end end)
	end
	self.bags[name] = bag
	return bag
end

function addon:CanOpenBag(name)
	return name ~= 'Bank' or self.atBank
end

function addon:OpenBag(name)
	if self:CanOpenBag(name) then
		local bag = self:GetBag(name)
		if not bag:IsShown() then
			bag:Show()
		else
			return true
		end
	end
end

function addon:CloseBag(name)
	if self:IsBagOpen(name) then
		self:GetBag(name):Hide()
	end
end

function addon:IsBagOpen(name)
	local bag = self:GetBag(name, true)
	return bag and bag:IsShown()
end

function addon:AreAllBagsOpen()
	for name in pairs(self.bags) do
		if self:CanOpenBag(name) and not self:IsBagOpen(name) then
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- Hooks of standard bag function
--------------------------------------------------------------------------------

function addon:OpenBackpack() 
	return self:OpenBag("Backpack") 
end

function addon:CloseBackpack() 
	self:CloseBag("Backpack")
end

function addon:ToggleBackpack()
	if self:IsBagOpen("Backpack") then
		self:CloseBag("Backpack")
	else
		self:OpenBag("Backpack")
	end
end

function addon:OpenAllBags(forceOpen)
	if not forceOpen and self:AreAllBagsOpen() then
		self:CloseAllBags()
	else
		for name in pairs(self.bags) do
			self:OpenBag(name)
		end
	end
end

function addon:CloseAllBags()
	for name in pairs(self.bags) do
		self:CloseBag(name)
	end
end

