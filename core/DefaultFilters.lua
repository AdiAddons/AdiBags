--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2014 Adirelle (adirelle@gmail.com)
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

function addon:SetupDefaultFilters()
	-- Globals: GetEquipmentSetLocations
	--<GLOBALS
	local _G = _G
	local BANK_CONTAINER = _G.BANK_CONTAINER
	local BANK_CONTAINER_INVENTORY_OFFSET = _G.BANK_CONTAINER_INVENTORY_OFFSET
	local EquipmentManager_UnpackLocation = _G.EquipmentManager_UnpackLocation
	local format = _G.format
	local pairs = _G.pairs
	local wipe = _G.wipe
	--GLOBALS>

	local L = addon.L

	-- Make some strings local to speed things
	local CONSUMMABLE = GetItemClassInfo(LE_ITEM_CLASS_CONSUMABLE)
	local JUNK = GetItemSubClassInfo(LE_ITEM_CLASS_MISCELLANEOUS, 0)
	local MISCELLANEOUS = GetItemClassInfo(LE_ITEM_CLASS_MISCELLANEOUS)
	local QUEST = GetItemClassInfo(LE_ITEM_CLASS_QUESTITEM)
	local RECIPE = GetItemClassInfo(LE_ITEM_CLASS_RECIPE)
	local TRADE_GOODS = GetItemClassInfo(LE_ITEM_CLASS_TRADEGOODS)
	local WEAPON = GetItemClassInfo(LE_ITEM_CLASS_WEAPON)
	local ARMOR = GetItemClassInfo(LE_ITEM_CLASS_ARMOR)
	local JEWELRY = L['Jewelry']
	local EQUIPMENT = L['Equipment']
	local AMMUNITION = L['Ammunition']

	-- Define global ordering
	self:SetCategoryOrders{
		[QUEST] = 30,
		[TRADE_GOODS] = 20,
		[EQUIPMENT] = 10,
		[CONSUMMABLE] = -10,
		[MISCELLANEOUS] = -20,
		[AMMUNITION] = -30,
		[JUNK] = -40,
	}

	-- [75] Quest Items
	do
		local questItemFilter = addon:RegisterFilter('Quest', 75, function(self, slotData)
			if slotData.class == QUEST or slotData.subclass == QUEST then
				return QUEST
			else
				return false
			end
		end)
		questItemFilter.uiName = L['Quest Items']
		questItemFilter.uiDesc = L['Put quest-related items in their own section.']
	end

	-- [60] Equipment
	do
		local equipCategories = {
			INVTYPE_2HWEAPON = WEAPON,
			INVTYPE_AMMO = MISCELLANEOUS,
			INVTYPE_BAG = MISCELLANEOUS,
			INVTYPE_BODY = MISCELLANEOUS,
			INVTYPE_CHEST = ARMOR,
			INVTYPE_CLOAK = ARMOR,
			INVTYPE_FEET = ARMOR,
			INVTYPE_FINGER = JEWELRY,
			INVTYPE_HAND = ARMOR,
			INVTYPE_HEAD = ARMOR,
			INVTYPE_HOLDABLE = WEAPON,
			INVTYPE_LEGS = ARMOR,
			INVTYPE_NECK = JEWELRY,
			INVTYPE_QUIVER = MISCELLANEOUS,
			INVTYPE_RANGED = WEAPON,
			INVTYPE_RANGEDRIGHT = WEAPON,
			INVTYPE_RELIC = JEWELRY,
			INVTYPE_ROBE = ARMOR,
			INVTYPE_SHIELD = WEAPON,
			INVTYPE_SHOULDER = ARMOR,
			INVTYPE_TABARD = MISCELLANEOUS,
			INVTYPE_THROWN = WEAPON,
			INVTYPE_TRINKET = JEWELRY,
			INVTYPE_WAIST = ARMOR,
			INVTYPE_WEAPON = WEAPON,
			INVTYPE_WEAPONMAINHAND = WEAPON,
			INVTYPE_WEAPONMAINHAND_PET = WEAPON,
			INVTYPE_WEAPONOFFHAND = WEAPON,
			INVTYPE_WRIST = ARMOR,
		}

		local equipmentFilter = addon:RegisterFilter('Equipment', 60, function(self, slotData)
			local equipSlot = slotData.equipSlot
			if equipSlot and equipSlot ~= "" then
				local rule = self.db.profile.dispatchRule
				local category
				if rule == 'category' then
					category = equipCategories[equipSlot] or _G[equipSlot]
				elseif rule == 'slot' then
					category = _G[equipSlot]
				end
				if category == ARMOR and self.db.profile.armorTypes and slotData.subclass then
					category = slotData.subclass
				end
				return category or EQUIPMENT, EQUIPMENT
			end
		end)
		equipmentFilter.uiName = EQUIPMENT
		equipmentFilter.uiDesc = L['Put any item that can be equipped (including bags) into the "Equipment" section.']

		function equipmentFilter:OnInitialize()
			self.db = addon.db:RegisterNamespace('Equipment', { profile = { dispatchRule = 'category', armorTypes = false } })
		end

		function equipmentFilter:GetOptions()
			return {
				dispatchRule = {
					name = L['Section setup'],
					desc = L['Select the sections in which the items should be dispatched.'],
					type = 'select',
					width = 'double',
					order = 10,
					values = {
						one = L['Only one section.'],
						category = L['Four general sections.'],
						slot = L['One section per item slot.'],
					},
				},
				armorTypes = {
					name = L['Split armors by types'],
					desc = L['Check this so armors are dispatched in four sections by type.'],
					type = 'toggle',
					order = 20,
					disabled = function() return self.db.profile.dispatchRule ~= 'category' end,
				},
			}, addon:GetOptionHandler(self, true)
		end
	end

	-- [10] Item classes
	do
		local itemCat = addon:RegisterFilter('ItemCategory', 10)
		itemCat.uiName = L['Item category']
		itemCat.uiDesc = L['Put items in sections depending on their first-level category at the Auction House.']
			..'\n|cffff7700'..L['Please note this filter matchs every item. Any filter with lower priority than this one will have no effect.']..'|r'

		function itemCat:OnInitialize(slotData)
			self.db = addon.db:RegisterNamespace(self.moduleName, {
				profile = {
					splitBySubclass = { false }
				}
			})
		end

		function itemCat:GetOptions()
			return {
				splitBySubclass = {
					name = L['Split by subcategories'],
					desc = L['Select which first-level categories should be split by sub-categories.'],
					type = 'multiselect',
					order = 10,
					values = {
						[TRADE_GOODS] = TRADE_GOODS,
						[CONSUMMABLE] = CONSUMMABLE,
						[MISCELLANEOUS] = MISCELLANEOUS,
						[RECIPE] = RECIPE,
					}
				}
			}, addon:GetOptionHandler(self, true)
		end

		function itemCat:Filter(slotData)
			local class, subclass = slotData.class, slotData.subclass
			if self.db.profile.splitBySubclass[class] then
				return subclass, class
			else
				return class
			end
		end

	end

end
