--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2021 Adirelle (adirelle@gmail.com)
All rights reserved.

This file is part of AdiBags.

AdiBags is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

AdiBags is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdiBags.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addonName, addon = ...
local L = addon.L

-- Constants for detecting WoW version.
addon.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
addon.isBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
addon.isWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

--<GLOBALS
local _G = _G
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local BANK_CONTAINER = _G.BANK_CONTAINER
local REAGENTBANK_CONTAINER = _G.REAGENTBANK_CONTAINER
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS
local NUM_BANKBAGSLOTS = _G.NUM_BANKBAGSLOTS
local pairs = _G.pairs
--GLOBALS>

addon.itemQuality = {}
addon.itemClass = {}
addon.itemSubClass = {}

--<GLOBALS Item Quality
if addon.isRetail then
	
	addon.itemQuality.Poor  			= _G.Enum.ItemQuality.Poor
	addon.itemQuality.Uncommon 			= _G.Enum.ItemQuality.Uncommon
	addon.itemQuality.Common 			= _G.Enum.ItemQuality.common
	addon.itemQuality.Rare	 			= _G.Enum.ItemQuality.Rare
	addon.itemQuality.Epic	 			= _G.Enum.ItemQuality.Epic
	addon.itemQuality.Legendary			= _G.Enum.ItemQuality.Legendary
	addon.itemQuality.Artifact			= _G.Enum.ItemQuality.Artifact
	addon.itemQuality.Heirloom			= _G.Enum.ItemQuality.Heirloom
	addon.itemQuality.WoWToken			= _G.Enum.ItemQuality.WoWToken
else
	addon.itemQuality.Poor  			= _G.LE_ITEM_QUALITY_POOR
	addon.itemQuality.Uncommon 			= _G.LE_ITEM_QUALITY_UNCOMMON
	addon.itemQuality.Common 			= _G.LE_ITEM_QUALITY_COMMON
	addon.itemQuality.Rare	 			= _G.LE_ITEM_QUALITY_RARE
	addon.itemQuality.Epic	 			= _G.LE_ITEM_QUALITY_EPIC
	addon.itemQuality.Legendary			= _G.LE_ITEM_QUALITY_LEGENDARY
end
--GLOBALS Item Quality>


--<GLOBALS Item Class
if addon.isRetail then
	addon.itemClass.Consumable			= _G.Enum.ItemClass.Consumable
	addon.itemClass.Container			= _G.Enum.ItemClass.Container
	addon.itemClass.Weapon				= _G.Enum.ItemClass.Weapon
	addon.itemClass.Gem					= _G.Enum.ItemClass.Gem
	addon.itemClass.Armor				= _G.Enum.ItemClass.Armor
	addon.itemClass.Reagent				= _G.Enum.ItemClass.Reagent
	addon.itemClass.Projectile			= _G.Enum.ItemClass.Projectile
	addon.itemClass.Tradegoods			= _G.Enum.ItemClass.Tradegoods
	addon.itemClass.ItemEnhancement		= _G.Enum.ItemClass.ItemEnhancement
	addon.itemClass.Recipe				= _G.Enum.ItemClass.Recipe
	addon.itemClass.CurrencyToken 		= _G.Enum.ItemClass.CurrencyTokenObsolete
	addon.itemClass.Quiver				= _G.Enum.ItemClass.Quiver
	addon.itemClass.Questitem			= _G.Enum.ItemClass.Questitem
	addon.itemClass.Key					= _G.Enum.ItemClass.Key
	addon.itemClass.Permanent 			= _G.Enum.ItemClass.PermanentObsolete
	addon.itemClass.Miscellaneous		= _G.Enum.ItemClass.Miscellaneous
	addon.itemClass.Glyph				= _G.Enum.ItemClass.Glyph
	addon.itemClass.Battlepet			= _G.Enum.ItemClass.Battlepet
	addon.itemClass.WoWToken			= _G.Enum.ItemClass.WoWToken
else
	addon.itemClass.Consumable			= _G.LE_ITEM_CLASS_CONSUMABLE
	addon.itemClass.Container			= _G.LE_ITEM_CLASS_CONTAINER
	addon.itemClass.Weapon				= _G.LE_ITEM_CLASS_WEAPON
	addon.itemClass.Gem					= _G.LE_ITEM_CLASS_GEM
	addon.itemClass.Armor				= _G.LE_ITEM_CLASS_ARMOR
	addon.itemClass.Reagent				= _G.LE_ITEM_CLASS_REAGENT
	addon.itemClass.Projectile			= _G.LE_ITEM_CLASS_PROJECTILE
	addon.itemClass.Tradegoods			= _G.LE_ITEM_CLASS_TRADEGOODS
	addon.itemClass.ItemEnhancement		= _G.LE_ITEM_CLASS_ITEMENHANCEMENT
	addon.itemClass.Recipe				= _G.LE_ITEM_CLASS_RECIPE
	addon.itemClass.CurrencyToken		= _G.LE_ITEM_CLASS_CURRENCYTOKEN
	addon.itemClass.Quiver				= _G.LE_ITEM_CLASS_QUIVER
	addon.itemClass.Questitem			= _G.LE_ITEM_CLASS_QUESTITEM
	addon.itemClass.Key					= _G.LE_ITEM_CLASS_CLASSKEY
	addon.itemClass.Permanent			= _G.LE_ITEM_CLASS_PERMANENT
	addon.itemClass.Miscellaneous		= _G.LE_ITEM_CLASS_MISCELLANEOUS
	addon.itemClass.Glyph				= _G.LE_ITEM_CLASS_GLYPH
	addon.itemClass.Battlepet			= _G.LE_ITEM_CLASS_BATTLEPET
	addon.itemClass.WoWToken			= _G.LE_ITEM_CLASS_WOWTOKEN
end
--GLOBALS Item  Class>

--<GLOBALS Item Sub Class
addon.itemSubClass.Misc = {}
addon.itemSubClass.Gem = {}
if addon.isRetail then
	-- addon.itemSublass		= _G.Enum.
	-- Miscellaneous
	addon.itemSubClass.Misc.Pet			= _G.Enum.ItemMiscellaneousSubclass.CompanionPet
	-- Gem
	addon.itemSubClass.Gem.Artifactrelic	= _G.Enum.ItemGemSubclass.Artifactrelic
else
	-- Miscellaneous
	addon.itemSubClass.Misc.Pet			= _G.LE_ITEM_MISCELLANEOUS_COMPANION_PET
	-- Gem
	addon.itemSubClass.Gem.Artifactrelic	= _G.LE_ITEM_GEM_ARTIFACTRELIC
end
--GLOBALS Item  Class>





-- Backpack and bags
local BAGS = { [BACKPACK_CONTAINER] = BACKPACK_CONTAINER }
for i = 1, NUM_BAG_SLOTS do BAGS[i] = i end

local BANK = {}
local BANK_ONLY = {}
local REAGENTBANK_ONLY = {}

if addon.isRetail then
	-- Base nank bags
	BANK_ONLY = { [BANK_CONTAINER] = BANK_CONTAINER }
	for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do BANK_ONLY[i] = i end

	--- Reagent bank bags
	REAGENTBANK_ONLY = { [REAGENTBANK_CONTAINER] = REAGENTBANK_CONTAINER }

	-- All bank bags
	for _, bags in ipairs { BANK_ONLY, REAGENTBANK_ONLY } do
		for id in pairs(bags) do BANK[id] = id end
	end
else
	BANK = { [BANK_CONTAINER] = BANK_CONTAINER }
	for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do BANK[i] = i end
end

-- All bags
local ALL = {}
for _, bags in ipairs { BAGS, BANK } do
	for id in pairs(bags) do ALL[id] = id end
end

addon.BAG_IDS = {
	BAGS = BAGS,
	BANK = BANK,
	BANK_ONLY = BANK_ONLY,
	REAGENTBANK_ONLY = REAGENTBANK_ONLY,
	ALL = ALL
}

addon.FAMILY_TAGS = {
--@noloc[[
	[0x00001] = L["QUIVER_TAG"], -- Quiver
	[0x00002] = L["AMMO_TAG"], -- Ammo Pouch
	[0x00004] = L["SOUL_BAG_TAG"], -- Soul Bag
	[0x00008] = L["LEATHERWORKING_BAG_TAG"], -- Leatherworking Bag
	[0x00010] = L["INSCRIPTION_BAG_TAG"], -- Inscription Bag
	[0x00020] = L["HERB_BAG_TAG"], -- Herb Bag
	[0x00040] = L["ENCHANTING_BAG_TAG"] , -- Enchanting Bag
	[0x00080] = L["ENGINEERING_BAG_TAG"], -- Engineering Bag
	[0x00100] = L["KEYRING_TAG"], -- Keyring
	[0x00200] = L["GEM_BAG_TAG"], -- Gem Bag
	[0x00400] = L["MINING_BAG_TAG"], -- Mining Bag
	[0x08000] = L["TACKLE_BOX_TAG"], -- Tackle Box
	[0x10000] = L["COOKING_BAR_TAG"], -- Refrigerator
--@noloc]]
}

addon.FAMILY_ICONS = {
	[0x00001] = [[Interface\Icons\INV_Misc_Ammo_Arrow_01]], -- Quiver
	[0x00002] = [[Interface\Icons\INV_Misc_Ammo_Bullet_05]], -- Ammo Pouch
	[0x00004] = [[Interface\Icons\INV_Misc_Gem_Amethyst_02]], -- Soul Bag
	[0x00008] = [[Interface\Icons\Trade_LeatherWorking]], -- Leatherworking Bag
	[0x00010] = [[Interface\Icons\INV_Inscription_Tradeskill01]], -- Inscription Bag
	[0x00020] = [[Interface\Icons\Trade_Herbalism]], -- Herb Bag
	[0x00040] = [[Interface\Icons\Trade_Engraving]], -- Enchanting Bag
	[0x00080] = [[Interface\Icons\Trade_Engineering]], -- Engineering Bag
	[0x00100] = [[Interface\Icons\INV_Misc_Key_14]], -- Keyring
	[0x00200] = [[Interface\Icons\INV_Misc_Gem_BloodGem_01]], -- Gem Bag
	[0x00400] = [[Interface\Icons\Trade_Mining]], -- Mining Bag
	[0x08000] = [[Interface\Icons\Trade_Fishing]], -- Tackle Box
	[0x10000] = [[Interface\Icons\INV_Misc_Bag_Cooking]], -- Refrigerator
}

addon.ITEM_SIZE = 37
addon.ITEM_SPACING = 4
addon.SECTION_SPACING = addon.ITEM_SIZE / 3 + addon.ITEM_SPACING
addon.BAG_INSET = 8
addon.TOP_PADDING = 32
addon.HEADER_SIZE = 14 + addon.ITEM_SPACING

addon.BACKDROP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	tile = false,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

addon.DEFAULT_SETTINGS = {
	profile = {
		enabled = true,
		bags = {
			["*"] = true,
		},
		positionMode = "anchored",
		positions = {
			anchor = { point = "BOTTOMRIGHT", xOffset = -32, yOffset = 200 },
			Backpack = { point = "BOTTOMRIGHT", xOffset = -32, yOffset = 200 },
			Bank = { point = "TOPLEFT", xOffset = 32, yOffset = -104 },
		},
		scale = 0.8,
		columnWidth = {
			Backpack = 4,
			Bank = 6,
		},
		maxHeight = 0.60,
		qualityHighlight = true,
		qualityOpacity = 1.0,
		dimJunk = true,
		questIndicator = true,
		showBagType = true,
		filters = { ['*'] = true },
		filterPriorities = {},
		sortingOrder = 'default',
		modules = { ['*'] = true },
		virtualStacks = {
			['*'] = false,
			freeSpace = true,
			notWhenTrading = 1,
		},
		skin = {
			background = "Blizzard Tooltip",
			border = "Blizzard Tooltip",
			borderWidth = 16,
			insets = 3,
			BackpackColor = { 0, 0, 0, 1 },
			BankColor = { 0, 0, 0.5, 1 },
			ReagentBankColor = { 0, 0.5, 0, 1 },
		},
		rightClickConfig = true,
		autoOpen = true,
		hideAnchor = false,
		autoDeposit = false,
		compactLayout = false,
		upgradeIconAnchor = "TOPLEFT",
		upgradeIconOffsetX = 0,
		upgradeIconOffsetY = 0,
		gridLayout = false,
	},
	char = {
		collapsedSections = {
			['*'] = false,
		},
	},
}
