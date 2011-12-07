--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
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
	local GetContainerItemQuestInfo = _G.GetContainerItemQuestInfo
	local GetEquipmentSetInfo = _G.GetEquipmentSetInfo
	local GetNumEquipmentSets = _G.GetNumEquipmentSets
	local pairs = _G.pairs
	local wipe = _G.wipe
	--GLOBALS>

	local L, BI = addon.L, addon.BI

	-- Make some strings local to speed things
	local CONSUMMABLE = BI['Consumable']
	local GEM = BI['Gem']
	local GLYPH = BI['Glyph']
	local JUNK = BI['Junk']
	local MISCELLANEOUS = BI['Miscellaneous']
	local QUEST = BI['Quest']
	local RECIPE = BI['Recipe']
	local TRADE_GOODS = BI['Trade Goods']
	local WEAPON = BI["Weapon"]
	local ARMOR =  BI["Armor"]
	local JEWELRY = L["Jewelry"]
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

	-- [90] Parts of an equipment set
	do
		local setFilter = addon:RegisterFilter("ItemSets", 90, "AceEvent-3.0", "AceBucket-3.0")
		setFilter.uiName = L['Gear manager item sets']
		setFilter.uiDesc = L['Put items belonging to one or more sets of the built-in gear manager in specific sections.']

		function setFilter:OnInitialize()
			self.db = addon.db:RegisterNamespace('ItemSets', {
				profile = { oneSectionPerSet = true },
				char = { mergedSets = { ['*'] = false } },
			})
			self.names = {}
			self.slots = {}
		end

		function setFilter:OnEnable()
			self:RegisterEvent('EQUIPMENT_SETS_CHANGED')
			self:RegisterMessage("AdiBags_PreFilter")
			self:RegisterMessage("AdiBags_PreContentUpdate")
			self:UpdateNames()
		end

		local GetSlotId = addon.GetSlotId

		function setFilter:UpdateNames()
			self:Debug('Updating names')
			wipe(self.names)
			for i = 1, GetNumEquipmentSets() do
				local name = GetEquipmentSetInfo(i)
				self.names[name] = name
			end
			self.dirty = true
		end

		function setFilter:UpdateSlots()
			self:Debug('Updating slots')
			wipe(self.slots)
			local missing = false
			for i = 1, GetNumEquipmentSets() do
				local name = GetEquipmentSetInfo(i)
				local ids = GetEquipmentSetItemIDs(name)
				local locations = GetEquipmentSetLocations(name)
				if ids and locations then
					for invId, location in pairs(locations) do
						if location ~= 0 and location ~= 1 and ids[invId] ~= 0 then
							local player, bank, bags, slot, container = EquipmentManager_UnpackLocation(location)
							local slotId
							if bags and slot and container then
								slotId = GetSlotId(container, slot)
							elseif bank and slot then
								slotId = GetSlotId(BANK_CONTAINER, slot - BANK_CONTAINER_INVENTORY_OFFSET)
							elseif not player or not slot then
								missing = true
							end
							if slotId and not self.slots[slotId] then
								self.slots[slotId] = name
							end
						end
					end
				else
					missing = true
				end
			end
			self.dirty = not missing
		end

		function setFilter:EQUIPMENT_SETS_CHANGED(event)
			self:UpdateNames()
			self:SendMessage('AdiBags_FiltersChanged', true)
		end

		function setFilter:AdiBags_PreContentUpdate(event)
			self.dirty = true
		end

		function setFilter:AdiBags_PreFilter(event)
			if self.dirty then
				self:UpdateSlots()
			end
		end

		local SETS, SET_NAME =  L['Sets'], L["Set: %s"]
		function setFilter:Filter(slotData)
			local name = self.slots[slotData.slotId]
			if name then
				if not self.db.profile.oneSectionPerSet or self.db.char.mergedSets[name] then
					return SETS, EQUIPMENT
				else
					return format(SET_NAME, name), EQUIPMENT
				end
			end
		end

		function setFilter:GetFilterOptions()
			return {
				oneSectionPerSet = {
					name = L['One section per set'],
					desc = L['Check this to display one individual section per set. If this is disabled, there will be one big "Sets" section.'],
					type = 'toggle',
					order = 10,
				},
				mergedSets = {
					name = L['Merged sets'],
					desc = L['Check sets that should be merged into a unique "Sets" section. This is obviously a per-character setting.'],
					type = 'multiselect',
					order = 20,
					values = self.names,
					get = function(info, name)
						return self.db.char.mergedSets[name]
					end,
					set = function(info, name, value)
						self.db.char.mergedSets[name] = value
						self:SendMessage('AdiBags_FiltersChanged')
					end,
					disabled = function() return not self.db.profile.oneSectionPerSet end,
				},
			}, addon:GetOptionHandler(self, true)
		end

	end

	-- [75] Quest Items
	do
		local questItemFilter = addon:RegisterFilter('Quest', 75, function(self, slotData)
			if slotData.class == QUEST or slotData.subclass == QUEST then
				return QUEST
			else
				local isQuestItem, questId = GetContainerItemQuestInfo(slotData.bag, slotData.slot)
				return (questId or isQuestItem) and QUEST
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

		function equipmentFilter:GetFilterOptions()
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
					splitBySubclass = { false },
					mergeGems = true,
					mergeGlyphs = true,
				}
			})
		end

		function itemCat:GetFilterOptions()
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
						[GEM] = GEM,
						[GLYPH] = GLYPH,
						[RECIPE] = RECIPE,
					}
				},
				mergeGems = {
					name = L['Gems are trade goods'],
					desc = L['Consider gems as a subcategory of trade goods'],
					type = 'toggle',
					width = 'double',
					order = 20,
				},
				mergeGlyphs = {
					name = L['Glyphs are trade goods'],
					desc = L['Consider glyphs as a subcategory of trade goods'],
					type = 'toggle',
					width = 'double',
					order = 30,
				},
			}, addon:GetOptionHandler(self, true)
		end

		function itemCat:Filter(slotData)
			local class, subclass = slotData.class, slotData.subclass
			if class == GEM and self.db.profile.mergeGems then
				class, subclass = TRADE_GOODS, class
			elseif class == GLYPH and self.db.profile.mergeGlyphs then
				class, subclass = TRADE_GOODS, class
			end
			if self.db.profile.splitBySubclass[class] then
				return subclass, class
			else
				return class
			end
		end

	end

end
