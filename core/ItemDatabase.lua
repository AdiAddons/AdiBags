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

--<GLOBALS
local _G = _G
local TRADE_GOODS = _G.Enum.ItemClass.Tradegoods
local UNKNOWN = _G.UNKNOWN
--GLOBALS>

local addonName, addon = ...

---@cast addon +AdiBags

local GetSlotId = addon.GetSlotId
---@class ItemDatabase
local ItemDatabase = {
  ---@type table<string|number, ItemInfo>
  itemCache = {}
}

-- Get an AdiBags @ItemInfo table for the given item link or id.
---@param linkOrID string|number The link or item id to get @ItemInfo for.
---@param bagId number? If provided with slot, will populate the ItemLocation and guid field.
---@param slot number? If provided with bagId, will populate the ItemLocation and guid field.
---@return ItemInfo
function ItemDatabase:GetItem(linkOrID, bagId, slot)
  if linkOrID == nil then
    return {
      empty = true
    }
  end

  local itemLocation
  local guid
  if bagId and slot then
    itemLocation = ItemLocation:CreateFromBagAndSlot(bagId, slot)
    if addon.isRetail and itemLocation and itemLocation:IsValid() then
      guid = C_Item.GetItemGUID(itemLocation)
    end
  end

  if guid and self.itemCache[guid] then
    return self.itemCache[guid]
  elseif self.itemCache[linkOrID] then
    --TODO(lobato): Refresh the item link if needed, maybe remove link lookup?
    return self.itemCache[linkOrID]
  end

  local itemName, itemLink, itemQuality,
  itemLevel, itemMinLevel, itemType, itemSubType,
  itemStackCount, itemEquipLoc, itemTexture,
  sellPrice, classID, subclassID, bindType, expacID,
  setID, isCraftingReagent = GetItemInfo(linkOrID)

  local itemInfo = {
    itemName = itemName,
    itemLink = itemLink,
    itemQuality = itemQuality,
    itemLevel = itemLevel,
    itemMinLevel = itemMinLevel,
    itemType = itemType,
    itemSubType = itemSubType,
    itemStackCount = itemStackCount,
    itemEquipLoc = itemEquipLoc,
    itemTexture = itemTexture,
    sellPrice = sellPrice,
    classID = classID,
    subclassID = subclassID,
    bindType = bindType,
    expacID = expacID,
    setID = setID,
    isCraftingReagent = isCraftingReagent,
    itemLocation = itemLocation,
    itemGUID = guid,
    slot = slot,
  }
  if itemInfo.itemGUID then
    self.itemCache[guid] = itemInfo
  else
    self.itemCache[linkOrID] = itemInfo
  end

  return itemInfo
end

function ItemDatabase:ReagentData(slotData)
  if not slotData.isCraftingReagent then return false end
  if not slotData.classID == TRADE_GOODS then return false end
  return {
    expacName = addon.EXPANSION_MAP[slotData.expacID],
    subclassName = addon.TRADESKILL_MAP[slotData.subclassID] or UNKNOWN,
  }
end

---@param bagId number The bag id for the new container.
---@return ContainerInfo
function ItemDatabase:NewContainerInfo(bagId)
  ---@type ContainerInfo
  return {
    bagId = bagId,
    slots = {}
  }
end

---@param bagId number The bag id for the new slot.
---@param slot number The slot id for the new slot.
---@return SlotInfo
function ItemDatabase:NewSlotInfo(bagId, slot)
  ---@type SlotInfo
  return {
    slot = slot,
    bagId = bagId,
    slotId = GetSlotId(bagId, slot)
  }
end

---@param slot number The slot id for the new item.
---@return ItemInfo
function ItemDatabase:NewItemInfo(slot)
  return {
    slot = slot,
    empty = true,
  }
end

addon.ItemDatabase = ItemDatabase