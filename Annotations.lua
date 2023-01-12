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

---@meta

-- This file holds type annotations for various objects used in AdiBags. It is
-- never loaded by the addon, but is used as a reference for the lua linter.

-----------------------------------------
--
-- Constant definitions
--
-----------------------------------------

BACKPACK_CONTAINER = Enum.BagIndex.Backpack
BANK_CONTAINER = Enum.BagIndex.Bank
REAGENTBANK_CONTAINER = Enum.BagIndex.Reagentbank
NUM_BAG_SLOTS = Constants.InventoryConstants.NumBagSlots
NUM_REAGENTBAG_SLOTS = Constants.InventoryConstants.NumReagentBagSlots
NUM_BANKBAGSLOTS = Constants.InventoryConstants.NumBankBagSlots
NUM_TOTAL_EQUIPPED_BAG_SLOTS = NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS
REAGENTBANK_DEPOSIT = REAGENTBANK_DEPOSIT
REAGENT_BANK = REAGENT_BANK
BANKSLOTPURCHASE = BANKSLOTPURCHASE
REAGENTBANK_PURCHASE_TEXT = REAGENTBANK_PURCHASE_TEXT
COSTS_LABEL = COSTS_LABEL
ADDON_LOAD_FAILED = ADDON_LOAD_FAILED
WOW_PROJECT_WRATH_CLASSIC = 11
ITEM_SEARCHBAR_LIST = {
	"BagItemSearchBox",
	"GuildItemSearchBox",
	"VoidItemSearchBox",
	"BankItemSearchBox",
}

-----------------------------------------
--
-- Alias definitions
--
-----------------------------------------

---@alias slotId number A unique slotId for an item in a bag.

-----------------------------------------
--
-- Class definitions
--
-----------------------------------------

---@class ItemInfo ItemInfo is constructed by GetItemInfo(), with some additional fields for use in AdiBags.
---@field itemName string The localized name of the item.
---@field itemLink string The localized link of the item.
---@field itemQuality Enum.ItemQuality The item quality, i.e. 1 for common, 2 for uncommon, etc.
---@field itemLevel number The base item level, not including upgrades. See GetDetailedItemLevelInfo() for getting the actual item level.
---@field itemMinLevel number The minimum level required to use the item, or 0 if there is no level requirement.
---@field itemType string The localized type name of the item: Armor, Weapon, Quest, etc.
---@field itemSubType string The localized sub-type name of the item: Bows, Guns, Staves, etc.
---@field itemStackCount number The max amount of an item per stack, e.g. 200 for Runecloth.
---@field itemEquipLoc string The inventory equipment location in which the item may be equipped e.g. "INVTYPE_HEAD", or an empty string if it cannot be equipped.
---@field itemTexture number The texture for the item icon in FileID format.
---@field sellPrice number The vendor price in copper, or 0 for items that cannot be sold.
---[Documentation](https://wowpedia.fandom.com/wiki/ItemType)
---@field classID Enum.ItemClass The numeric ID that matches the string field itemType.
---@field subclassID Enum.ItemConsumableSubclass|Enum.ItemWeaponSubclass|Enum.ItemGemSubclass|Enum.ItemArmorSubclass|Enum.ItemReagentSubclass|Enum.ItemRecipeSubclass|Enum.ItemMiscellaneousSubclass|Enum.BattlePetTypes|Enum.ItemProfessionSubclass|number The numeric ID that matches the string field itemSubType. See: https://wowpedia.fandom.com/wiki/ItemType
---@field bindType ItemBindType The binding type of the item: 0 for no binding, 1 for on pickup, 2 for on equip, 3 for on use.
---@field expacID ExpansionType The related Expansion, e.g. 8 for Shadowlands.
---@field setID number The ID of the item set to which this item belongs, or nil if it does not belong to a set.
---@field isCraftingReagent boolean Whether the item can be used as a crafting reagent.
---@field bag number The bag index of the bag the item is in.
---@field slot number The slot index of the item in the bag.
---@field slotId slotId The unique slotId of the item in the bag. 
---@field bagFamily number? The bag family as documented in [GetContainerNumFreeSlots](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerNumFreeSlots)
---@field isBank boolean Whether the item is in the player's bank.
---@field itemGUID string The GUID of the item as returned by GetItemGUID().
---@field itemLocation ItemLocationMixin The item location of the item as returned by ItemLocation:CreateFromBagAndSlot(bag, slot).

---@class BankFrame
---@field selectedTab number The tab that is currently selected, 1 for the main bank, 2 for the reagent bank.
---@type BankFrame
BankFrame = {}

-----------------------------------------
--
-- Function definitions
--
-----------------------------------------

-- Container Functions

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.ContainerIDToInventoryID)
---@param containerID number
---@return number inventoryID
function ContainerIDToInventoryID(containerID) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.ContainerRefundItemPurchase)
---@param containerIndex number
---@param slotIndex number
---@param isEquipped? boolean Default = false
function ContainerRefundItemPurchase(containerIndex, slotIndex, isEquipped) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetBackpackAutosortDisabled)
---@return boolean isDisabled
function GetBackpackAutosortDisabled() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetBagName)
---@param bagIndex number
---@return string name
function GetBagName(bagIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetBagSlotFlag)
---@param bagIndex number
---@param flag number|Enum.BagSlotFlags
---@return boolean isSet
function GetBagSlotFlag(bagIndex, flag) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetBankAutosortDisabled)
---@return boolean isDisabled
function GetBankAutosortDisabled() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerFreeSlots)
---@param containerIndex number
---@return number[] freeSlots
function GetContainerFreeSlots(containerIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemCooldown)
---@param containerIndex number
---@param slotIndex number
---@return number startTime
---@return number duration
---@return number enable
function GetContainerItemCooldown(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemDurability)
---@param containerIndex number
---@param slotIndex number
---@return number durability
---@return number maxDurability
function GetContainerItemDurability(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemEquipmentSetInfo)
---@param containerIndex number
---@param slotIndex number
---@return boolean inSet
---@return string setList
function GetContainerItemEquipmentSetInfo(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemID)
---@param containerIndex number
---@param slotIndex number
---@return number containerID
function GetContainerItemID(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemInfo)
---@param containerIndex number
---@param slotIndex number
---@return ContainerItemInfo containerInfo
function GetContainerItemInfo(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemLink)
---@param containerIndex number
---@param slotIndex number
---@return string itemLink
function GetContainerItemLink(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemPurchaseCurrency)
---@param containerIndex number
---@param slotIndex number
---@param itemIndex number
---@param isEquipped boolean
---@return ItemPurchaseCurrency currencyInfo
function GetContainerItemPurchaseCurrency(containerIndex, slotIndex, itemIndex, isEquipped) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemPurchaseInfo)
---@param containerIndex number
---@param slotIndex number
---@param isEquipped boolean
---@return ItemPurchaseInfo info
function GetContainerItemPurchaseInfo(containerIndex, slotIndex, isEquipped) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemPurchaseItem)
---@param containerIndex number
---@param slotIndex number
---@param itemIndex number
---@param isEquipped boolean
---@return ItemPurchaseItem itemInfo
function GetContainerItemPurchaseItem(containerIndex, slotIndex, itemIndex, isEquipped) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerItemQuestInfo)
---@param containerIndex number
---@param slotIndex number
---@return ItemQuestInfo questInfo
function GetContainerItemQuestInfo(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerNumFreeSlots)
---@param bagIndex number
---@return number numFreeSlots
---@return number? bagFamily
function GetContainerNumFreeSlots(bagIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetContainerNumSlots)
---@param containerIndex number
---@return number numSlots
function GetContainerNumSlots(containerIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetInsertItemsLeftToRight)
---@return boolean isEnabled
function GetInsertItemsLeftToRight() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetItemCooldown)
---@param itemID number
---@return number startTime
---@return number duration
---@return number enable
function GetItemCooldown(itemID) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetMaxArenaCurrency)
---@return number maxCurrency
function GetMaxArenaCurrency() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.GetSortBagsRightToLeft)
---@return boolean isEnabled
function GetSortBagsRightToLeft() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.IsBattlePayItem)
---@param containerIndex number
---@param slotIndex number
---@return boolean isBattlePayItem
function IsBattlePayItem(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.IsContainerFiltered)
---@param containerIndex number
---@return boolean isFiltered
function IsContainerFiltered(containerIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.PickupContainerItem)
---@param containerIndex number
---@param slotIndex number
function PickupContainerItem(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.PlayerHasHearthstone)
---@return number? itemID
function PlayerHasHearthstone() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SetBackpackAutosortDisabled)
---@param disable boolean
function SetBackpackAutosortDisabled(disable) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SetBagPortraitTexture)
---@param texture table
---@param bagIndex number
function SetBagPortraitTexture(texture, bagIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SetBagSlotFlag)
---@param bagIndex number
---@param flag number|Enum.BagSlotFlags
---@param isSet boolean
function SetBagSlotFlag(bagIndex, flag, isSet) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SetBankAutosortDisabled)
---@param disable boolean
function SetBankAutosortDisabled(disable) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SetInsertItemsLeftToRight)
---@param enable boolean
function SetInsertItemsLeftToRight(enable) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SetItemSearch)
---@param searchString string
function SetItemSearch(searchString) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SetSortBagsRightToLeft)
---@param enable boolean
function SetSortBagsRightToLeft(enable) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.ShowContainerSellCursor)
---@param containerIndex number
---@param slotIndex number
function ShowContainerSellCursor(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SocketContainerItem)
---@param containerIndex number
---@param slotIndex number
---@return boolean success
function SocketContainerItem(containerIndex, slotIndex) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SortBags)
function SortBags() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SortBankBags)
function SortBankBags() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SortReagentBankBags)
function SortReagentBankBags() end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.SplitContainerItem)
---@param containerIndex number
---@param slotIndex number
---@param amount number
function SplitContainerItem(containerIndex, slotIndex, amount) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.UseContainerItem)
---@param containerIndex number
---@param slotIndex number
---@param unitToken? string
---@param reagentBankOpen? boolean Default = false
function UseContainerItem(containerIndex, slotIndex, unitToken, reagentBankOpen) end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_Container.UseHearthstone)
---@return boolean used
function UseHearthstone() end


-- Missing LibSharedMedia definitions

---@class LibSharedMedia-3.0
local LibSharedMedia = {}

---@param self table The object to register the callback on.
---@param eventname string The name of the event to register.
---@param method string|function The method on the object or the function to call when the event is fired.
---@param ... any Any additional arguments to pass to the method when it is called.
function LibSharedMedia.RegisterCallback(self, eventname, method, ...) end

-- ABEvent definitions

---@class ABEvent-1.0
local ABEvent = {}

---@param target string|table The target object to register the event on. If a string is passed, the event will be registered on the global object.
---@param eventname string The name of the event to register.
---@param method function The method to call when the event is fired.
---@param ... any Additional arguments to pass to the method when it is called.
function ABEvent.RegisterMessage(target, eventname, method, ...) end

---@param target string|table The target object to register the event on. If a string is passed, the event will be registered on the global object.
---@param eventname string The name of the event to register.
---@param method function|string The method to call when the event is fired.
---@param ... any Additional arguments to pass to the method when it is called.
function ABEvent.RegisterEvent(target, eventname, method, ...) end

-- AdiDebug definitions

---@class AdiDebug
local AdiDebug = {}

---@param target table
---@param name string
function AdiDebug:Embed(target, name) end

-- Global functions

---@param which string The name of the popup to show.
---@param text_arg1? string The first text argument to pass to the popup.
---@param text_arg2? string The second text argument to pass to the popup.
---@param data? table The data to pass for certain popups.
---@param insertedFrame? Frame The frame to insert into the popup.
function StaticPopup_Show(which, text_arg1, text_arg2, data, insertedFrame) end

---@param frame Frame The frame to set the tooltip on.
---@param money number|nil The amount of money to display, in copper.
---@param type? string Unknown/undocumented parameter.
---@param prefixText? string The text to display before the money.
---@param suffixText? string The text to display after the money.
function SetTooltipMoney(frame, money, type, prefixText, suffixText) end

-- Define the main AdiBags addon object
---@class AdiBags-Proto
---@field ItemDatabase ItemDatabase

---@alias AdiBags AdiBags-Proto|AceAddon
