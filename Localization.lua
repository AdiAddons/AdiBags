--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local L = setmetatable({}, {
	__index = function(self, key)
		if key ~= nil then
			self[key] = tostring(key)
		end
		return tostring(key)
	end,
	__newindex = function(self, key, value)
		if value == true then value = key end
		rawset(self, tostring(key), tostring(value))
	end
})
addon.L = L

L["QUIVER_TAG"] = "Qu"
L["AMMO_TAG"] = "Am"
L["SOUL_BAG_TAG"] = "So"
L["LEATHERWORKING_BAG_TAG"] = "Le"
L["INSCRIPTION_BAG_TAG"] = "In"
L["HERB_BAG_TAG"] = "He"
L["ENCHANTING_BAG_TAG"] = "En"
L["ENGINEERING_BAG_TAG"] = "Eg"
L["KEYRING_TAG"] = "Ke"
L["GEM_BAG_TAG"] = "Ge"
L["MINING_BAG_TAG"] = "Mi"

-- AH (sub)categories
L['Recipe'] = true
L["Consumable"] = true
L["Miscellaneous"] = true
L["Trade Goods"] = true
L["Gem"] = true
L['Glyph'] = true
L["Quest"] = true
L["Junk"] = true
-- End of AH (sub)categories

L["AdiBags anchor"] = true
L["Adjust the maximum number of items per row for each column."] = true
L["Adjust the maximum number of items per row."] = true
L["Adjust the maximum number of rows."] = true
L["Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title."] = true
L["Ammunition"] = true
L["Ammunition and soul shards"] = true
L["Are you sure you want to remove this association ?"] = true
L["Backpack"] = true
L["Backpack background color"] = true
L["Bag height"] = true
L["Bag type"] = true
L["Bag usage format"] = true
L["Bag width"] = true
L["Bags"] = true
L["Bank"] = true
L["Bank background color"] = true
L["Basic AdiBags configuration"] = true
L["By category, subcategory, quality and item level (default)"] = true
L["By name"] = true
L["By quality and item level"] = true
L["Check sets that should be merged into a unique \"Sets\" section. This is obviously a per-character setting."] = true
L["Check this to display a bag type tag in the top left corner of items."] = true
L["Check this to display a colored border around items, based on item quality."] = true
L["Check this to display an icon after usage of each type of bags."] = true
L["Check this to display an indicator on quest items."] = true
L["Check this to display an textual tag before usage of each type of bags."] = true
L["Check this to display one individual section per set. If this is disabled, there will be one big \"Sets\" section."] = true
L["Check this to display one section per inventory slot."] = true
L["Check this to display only one value counting all equipped bags, ignoring their type."] = true
L["Check this to have the bag content spread over several columns."] = true
L["Check this to show space at your bank in the plugin."] = true
L["Check to enable this module."] = true
L["Click there to reset the bag positions and sizes."] = true
L["Click to reset item status."] = true
L["Click to tidy bags."] = true
L["Click to toggle the bag anchor."] = true
L["Click to toggle the equipped bag panel, so you can change them."] = true
L["Close"] = true
L["Column width"] = true
L["Configure"] = true
L["Consumable"] = true
L["Core"] = true
L["Display character money at bottom right of the backpack."] = true
L["Display one slot for free space per bag type."] = true
L["Display virtual stacks of ammunition and soul shards."] = true
L["Display virtual stacks of item that normally do not stack, like equipment or cut gems."] = true
L["Display virtual stacks of items that normally stack, like clothes, ores, herbs, ..."] = true
L["Drop your item there to add it to this section."] = true
L["Enabled"] = true
L["Enter a text to search in item names."] = true
L["Equipment"] = true
L["Equipped bags"] = true
L["Filters"] = true
L["Filters are used to dispatch items in bag sections. One item can only appear in one section. If the same item is selected by several filters, the one with the highest priority wins."] = true
L["Free space"] = true
L["Free space / total space"] = true
L["Gear manager item sets"] = true
L["Highlight color"] = true
L["Highlight scale"] = true
L["Item category"] = true
L["Item search"] = true
L["Item-section associations"] = true
L["Items"] = true
L["Junk"] = true
L["LDB Plugin"] = true
L["List gems as trade goods"] = true
L["List glyphs as trade goods"] = true
L["Lock anchor"] = true
L["Manual filtering"] = true
L["Merge bag types"] = true
L["Merged sets"] = true
L["Miscellaneous"] = true
L["Money"] = true
L["Multi-column layout"] = true
L["New"] = true
L["New item highlight"] = true
L["One section per set"] = true
L["Other items"] = true
L["Please note this filter matchs every item. Any filter with lower priority than this one will have no effect."] = true
L["Plugins"] = true
L["Priority"] = true
L["Provides a LDB data source to be displayed by LDB display addons."] = true
L["Provides a text widget at top of the backpack where you can type (part of) an item name to locate it in your bags."] = true
L["Put ammunition and soul shards in their own sections."] = true
L["Put any item that can be equipped (including bags) into the \"Equipment\" section."] = true
L["Put items belonging to one or more sets of the built-in gear manager in specific sections."] = true
L["Put items in sections depending on their first-level category at the Auction House."] = true
L["Put items of poor quality or labeled as junk in the \"Junk\" section."] = true
L["Put quest-related items in their own section."] = true
L["Quality highlight"] = true
L["Quality opacity"] = true
L["Quest"] = true
L["Quest indicator"] = true
L["Quest Items"] = true
L["Reset new items"] = true
L["Reset position"] = true
L["Scale"] = true
L["Search:"] = true
L["Select how bag usage should be formatted in the plugin."] = true
L["Select how items should be sorted within each section."] = true
L["Set: %s"] = true
L["Sets"] = true
L["Show bag type icons"] = true
L["Show bag type tags"] = true
L["Show bank usage"] = true
L["Sorting order"] = true
L["Soul shards"] = true
L["Space in use"] = true
L["Space in use / total space"] = true
L["Split by inventory slot"] = true
L["Split by second-level category"] = true
L["Stackable items"] = true
L["Tidy bags"] = true
L["Tidy your bags by clicking on the small \"T\" button at the top left of bags. Special bags with free slots will be filled with macthing items and stackable items will be stacked to save space."] = true
L["Toggle and configure item filters."] = true
L["Toggle and configure plugins."] = true
L["Track new items"] = true
L["Track new items in each bag, displaying a glowing aura over them and putting them in a special section. \"New\" status can be reset by clicking on the small \"N\" button at top left of bags."] = true
L["Trade Goods"] = true
L["Uncheck this to remove this association."] = true
L["Unlock anchor"] = true
L["Use this to adjust the bag scale."] = true
L["Use this to adjust the quality-based border opacity. 100% means fully opaque."] = true
L["Virtual stacks"] = true
L["Virtual stacks display in one place items that actually spread over several bag slots."] = true

--------------------------------------------------------------------------------
-- Locales from localization system (not yet)
--------------------------------------------------------------------------------

-- %Localization: adibags
-- AUTOMATICALLY GENERATED BY UpdateLocalization.lua
-- ANY CHANGE BELOW THIS LINE WILL BE LOST ON NEXT UPDATE
-- CHANGES SHOULD BE MADE USING http://www.wowace.com/addons/adibags/localization/

local locale = GetLocale()
if locale == "frFR" then
L["AMMO_TAG"] = "Ba"
L["Ammunition"] = "Munitions"
L["Backpack"] = "Sac à dos"
L["Bank"] = "Banque"
L["Consumable"] = "Consommable"
L["ENCHANTING_BAG_TAG"] = "En"
L["ENGINEERING_BAG_TAG"] = "In"
L["Equipment"] = "Equipement"
L["Equipped bags"] = "Sacs équipés"
L["Free space"] = "Espace libre"
L["Gem"] = "Gemme"
L["GEM_BAG_TAG"] = "Jo"
L["HERB_BAG_TAG"] = "He"
L["INSCRIPTION_BAG_TAG"] = "Ca"
L["Junk"] = "Camelote"
L["KEYRING_TAG"] = "Cl"
L["LEATHERWORKING_BAG_TAG"] = "Cu"
L["MINING_BAG_TAG"] = "Mi"
L["Miscellaneous"] = "Divers"
L["New"] = "Nouveau"
L["Quest"] = "Quête"
L["QUIVER_TAG"] = "Fl"
L["Search:"] = "Recherche :"
L["SOUL_BAG_TAG"] = "Âm"
L["Soul shards"] = "Fragments d'âme"
L["Trade Goods"] = "Artisanat"
L['Recipe'] = "Recette"
L['Glyph'] = "Glyphe"
elseif locale == "koKR" then
L["AdiBags anchor"] = "AdiBags 앵커"
L["Ammunition"] = "탄약"
L["Ammunition and soul shards"] = "탄약과 영혼의 조각"
L["Bags"] = "가방"
L["Basic AdiBags configuration"] = "기본 AdiBags 설정"
L["Check to enable this module."] = "이 모듈을 사용하려면 체크하세요."
L["Configure"] = "설정"
L["Enter a text to search in item names."] = "찾을 아이템 이름을 입력하세요."
L["Gear manager item sets"] = "장비 관리창 아이템 세트"
L["Item category"] = "아이템 종류"
L["Items"] = "아이템"
L["LDB Plugin"] = "LDB 플러그인"
L["Money"] = "소지금"
L["Put quest-related items in their own section."] = "퀘스트와 관련된 아이템은 그들 자신의 섹션에 놓습니다."
L["Quest"] = "퀘스트"
L["Quest Items"] = "퀘스트 아이템"
L["Sets"] = "세트"
L["Set: %s"] = "세트 : %s"
L["Sorting order"] = "분류 순서"
L["Soul shards"] = "영혼의 조각"
L["Track new items"] = "새 아이템 추적"
L["Virtual stacks"] = "가상 스택"
end
