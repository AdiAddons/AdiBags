--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

function addon:SetupDefaultFilters()

	-- Define global ordering
	self:SetCategoryOrders{
		[L['Quest']] = 30,
		[L['Trade Goods']] = 20,
		[L['Equipment']] = 10,
		[L['Consumable']] = -10,
		[L['Miscellaneous']] = -20,
		[L['Ammunition']] = -30,
		[L['Junk']] = -40,
	}

	-- [90] Parts of an equipment set
	do
		local setFilter = addon:RegisterFilter("ItemSets", 90, "AceEvent-3.0")
		setFilter.uiName = L['Gear manager item sets']
		setFilter.uiDesc = L['Put items belonging to one or more sets of the built-in gear manager in specific sections.']

		function setFilter:OnInitialize()
			self.db = addon.db:RegisterNamespace('ItemSets', {
				profile = { oneSectionPerSet = true },
				char = { mergedSets = { ['*'] = false } },
			})
		end

		function setFilter:OnEnable()
			self:RegisterEvent('EQUIPMENT_SETS_CHANGED')
			self:UpdateSets()
			addon:UpdateFilters()
		end

		local sets = {}
		local setNames = {}

		function setFilter:UpdateSets()
			wipe(sets)
			wipe(setNames)
			for i = 1, GetNumEquipmentSets() do
				local name = GetEquipmentSetInfo(i)
				setNames[name] = name
				local items = GetEquipmentSetItemIDs(name)
				for loc, id in pairs(items) do
					if id and not sets[id] then
						sets[id] = name
					end
				end
			end
		end

		function setFilter:EQUIPMENT_SETS_CHANGED()
			self:UpdateSets()
			self:SendMessage('AdiBags_FiltersChanged')
		end

		function setFilter:Filter(slotData)
			local name = sets[slotData.itemId]
			if name then
				if not self.db.profile.oneSectionPerSet or self.db.char.mergedSets[name] then
					return L['Sets'], L["Equipment"]
				else
					return L["Set: %s"]:format(name), L["Equipment"]
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
					values = setNames,
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

	-- [80] Ammo and shards
	local ammoFilter = addon:RegisterFilter('AmmoShards', 80, function(filter, slotData)
		if slotData.itemId == 6265 then -- Soul Shard
			return L['Soul shards'], L['Ammunition']
		elseif slotData.equipSlot == 'INVTYPE_AMMO' then
			return L['Ammunition']
		end
	end)
	ammoFilter.uiName = L['Ammunition and soul shards']
	ammoFilter.uiDesc = L['Put ammunition and soul shards in their own sections.']

	-- [70] Low quality items
	do
		--@noloc[[
		local junkFilter = addon:RegisterFilter('Junk', 70, function(self, slotData)
			if (slotData.class == L['Junk'] or slotData.subclass == L['Junk']) and slotData.quality < ITEM_QUALITY_UNCOMMON or  slotData.quality == ITEM_QUALITY_POOR then
				return L['Junk']
			end
		end)
		junkFilter.uiName = L['Junk']
		--@noloc]]
		junkFilter.uiDesc = L['Put items of poor quality or labeled as junk in the "Junk" section.']
	end

	-- [75] Quest Items
	do
		--@noloc[[
		local questItemFilter = addon:RegisterFilter('Quest', 75, function(self, slotData)
			if slotData.class == L['Quest'] or slotData.subclass == L['Quest'] then
				return L['Quest']
			else
				local isQuestItem, questId = GetContainerItemQuestInfo(slotData.bag, slotData.slot)
				return (questId or isQuestItem) and L['Quest']
			end
		end)
		--@noloc]]
		questItemFilter.uiName = L['Quest Items']
		questItemFilter.uiDesc = L['Put quest-related items in their own section.']
	end

	-- [60] Equipment
	do
		local WEAPON, ARMOR, JEWELRY, MISC = L["Weapon"], L["Armor"], L["Jewelry"], L["Miscellaneous"]
		local equipCategories = {
			INVTYPE_2HWEAPON = WEAPON,
			INVTYPE_AMMO = MISC,
			INVTYPE_BAG = MISC,
			INVTYPE_BODY = MISC,
			INVTYPE_CHEST = ARMOR,
			INVTYPE_CLOAK = ARMOR,
			INVTYPE_FEET = ARMOR,
			INVTYPE_FINGER = JEWELRY,
			INVTYPE_HAND = ARMOR,
			INVTYPE_HEAD = ARMOR,
			INVTYPE_HOLDABLE = WEAPON,
			INVTYPE_LEGS = ARMOR,
			INVTYPE_NECK = JEWELRY,
			INVTYPE_QUIVER = MISC,
			INVTYPE_RANGED = WEAPON,
			INVTYPE_RANGEDRIGHT = WEAPON,
			INVTYPE_RELIC = JEWELRY,
			INVTYPE_ROBE = ARMOR,
			INVTYPE_SHIELD = WEAPON,
			INVTYPE_SHOULDER = ARMOR,
			INVTYPE_TABARD = MISC,
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
				return category or L['Equipment'], L['Equipment']
			end
		end)
		equipmentFilter.uiName = L['Equipment']
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
						[L['Trade Goods']] = L['Trade Goods'],
						[L['Consumable']] = L['Consumable'],
						[L['Miscellaneous']] = L['Miscellaneous'],
						[L['Gem']] = L['Gem'],
						[L['Glyph']] = L['Glyph'],
						[L['Recipe']] = L['Recipe'],
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
			if class == L['Gem'] and self.db.profile.mergeGems then
				class, subclass = L["Trade Goods"], class
			elseif class == L['Glyph'] and self.db.profile.mergeGlyphs then
				class, subclass = L["Trade Goods"], class
			end
			if self.db.profile.splitBySubclass[class] then
				return subclass, class
			else
				return class
			end
		end

	end

end
