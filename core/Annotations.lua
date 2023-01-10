--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2023 Adirelle (adirelle@gmail.com)
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

-- This file holds type annotations for various objects used in AdiBags. It also
-- contains some basic data structures for use where they don't exist in
-- Blizzard interface code.

---@enum ItemBindType The binding types for items.
Enum.ItemBindType = {
  LE_ITEM_BIND_NONE = 0,
  LE_ITEM_BIND_ON_ACQUIRE = 1,
  LE_ITEM_BIND_ON_EQUIP = 2,
  LE_ITEM_BIND_ON_USE = 3,
  LE_ITEM_BIND_QUEST = 4,
}

---@enum ExpansionType The expansion type for items.
Enum.ExpansionType = {
  LE_EXPANSION_CLASSIC = 0,
  LE_EXPANSION_BURNING_CRUSADE = 1,
  LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2,
  LE_EXPANSION_CATACLYSM = 3,
  LE_EXPANSION_MISTS_OF_PANDARIA = 4,
  LE_EXPANSION_WARLORDS_OF_DRAENOR = 5,
  LE_EXPANSION_LEGION = 6,
  LE_EXPANSION_BATTLE_FOR_AZEROTH = 7,
  LE_EXPANSION_SHADOWLANDS = 8,
  LE_EXPANSION_DRAGONFLIGHT = 9,
}

---@class ItemInfo ItemInfo is constructed by GetItemInfo()
---@field name string The localized name of the item.
---@field link string The localized link of the item.
---@field quality Enum.ItemQuality The item quality, i.e. 1 for common, 2 for uncommon, etc.
---@field itemLevel number The base item level, not including upgrades. See GetDetailedItemLevelInfo() for getting the actual item level.
---@field itemMinLevel number The minimum level required to use the item, or 0 if there is no level requirement.
---@field itemType string The localized type name of the item: Armor, Weapon, Quest, etc.
---@field itemSubType string The localized sub-type name of the item: Bows, Guns, Staves, etc.
---@field itemStackCount number The max amount of an item per stack, e.g. 200 for Runecloth.
---@field itemEquipLoc string The inventory equipment location in which the item may be equipped e.g. "INVTYPE_HEAD", or an empty string if it cannot be equipped.
---@field itemTexture number The texture for the item icon in FileID format.
---@field sellPrice number The vendor price in copper, or 0 for items that cannot be sold.
---@field classID Enum.ItemClass The numeric ID that matches the string field itemType. See: https://wowpedia.fandom.com/wiki/ItemType
---@field subclassID Enum.ItemConsumableSubclass|Enum.ItemWeaponSubclass|Enum.ItemGemSubclass|Enum.ItemArmorSubclass|Enum.ItemReagentSubclass|Enum.ItemRecipeSubclass|Enum.ItemMiscellaneousSubclass|Enum.BattlePetTypes|Enum.ItemProfessionSubclass|number The numeric ID that matches the string field itemSubType. See: https://wowpedia.fandom.com/wiki/ItemType
---@field bindType ItemBindType The binding type of the item: 0 for no binding, 1 for on pickup, 2 for on equip, 3 for on use.
---@field expacID ExpansionType The related Expansion, e.g. 8 for Shadowlands.
---@field setID number The ID of the item set to which this item belongs, or nil if it does not belong to a set.
---@field isCraftingReagent boolean Whether the item can be used as a crafting reagent.
