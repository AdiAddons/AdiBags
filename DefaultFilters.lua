--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

function addon:SetupDefaultFilters()

	-- [90] Parts of an equipment set
	do
		local setFilter = addon:RegisterFilter("ItemSets", 90, "AceEvent-3.0")
		setFilter.uiName = L['Gear manager item sets']
		setFilter.uiDesc = L['Put items belonging to one or more sets of the built-in gear manager in specific sections.']

		function setFilter:OnInitialize()
			self.db = addon.db:RegisterNamespace('ItemSets', { profile = { oneSectionPerSet = true } })
		end

		function setFilter:OnEnable()
			self:RegisterEvent('EQUIPMENT_SETS_CHANGED')
			self:UpdateSets()
			addon:UpdateFilters()
		end

		local sets = {}

		function setFilter:UpdateSets()
			wipe(sets)
			for i = 1, GetNumEquipmentSets() do
				local name = GetEquipmentSetInfo(i)
				local section = L["Set: %s"]:format(name)
				local items = GetEquipmentSetItemIDs(name)
				for loc, id in pairs(items) do
					if id and not sets[id] then
						sets[id] = section
					end
				end
			end
		end

		function setFilter:EQUIPMENT_SETS_CHANGED()
			self:UpdateSets()
			self:SendMessage('AdiBags_FiltersChanged')
		end

		function setFilter:Filter(slotData)
			local set = sets[slotData.itemId]
			if set then
				return self.db.profile.oneSectionPerSet and set or L['Sets'], L["Equipment"]
			end
		end
		
		function setFilter:GetFilterOptions()
			return {
				oneSectionPerSet = {
					name = L['One section per set'],
					desc = L['Check this to display one individual section per set. If this is disabled, there will be one big "Sets" section.'],
					type = 'toggle',
					order = 10,
				}
			}, addon:GetOptionHandler(self, true)
		end

	end

	-- [80] Ammo and shards
	local ammoFilter = addon:RegisterFilter('AmmoShards', 80, function(filter, slotData) -- L["AmmoShards"]
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
		local lowQualityPattern = string.format('%s|Hitem:%%d+:0:0:0:0', ITEM_QUALITY_COLORS[ITEM_QUALITY_POOR].hex)
		local junkFilter = addon:RegisterFilter('Junk', 70, function(filter, slotData) -- L["Junk"]
			if slotData.class == L['Junk'] or slotData.subclass == L['Junk'] or slotData.link:match(lowQualityPattern) then
				return L['Junk']
			end
		end)
		junkFilter.uiName = L['Junk']
		junkFilter.uiDesc = L['Put items of poor quality or labeled as junk in the "Junk" section.']
	end

	-- [60] Equipment
	local equipmentFilter = addon:RegisterFilter('Equipment', 60, function(filter, slotData) -- L["Equipement"]
		if slotData.equipSlot and slotData.equipSlot ~= "" then
			return L['Equipment']
		end
	end)
	equipmentFilter.uiName = L['Equipment']
	equipmentFilter.uiDesc = L['Put any item that can be equipped (including bags) into the "Equipment" section.']

	-- [10] Item classes
	do
		local itemCat = addon:RegisterFilter('ItemCategory', 10) --L["ItemCategory"]
		itemCat.uiName = L['Item category']
		itemCat.uiDesc = L['Put items in sections depending on their first-level category at the Auction House.']

		function itemCat:OnInitialize(slotData)
			self.db = addon.db:RegisterNamespace(self.moduleName, {
				profile = {
					split = false,
					mergeGems = true,
					mergeGlyphs = true,
				}
			})
		end
		
		function itemCat:GetFilterOptions()
			return {
				split = {
					name = L['Split by second-level category'],
					type = 'toggle',
					order = 10,
				},
				mergeGems = {
					name = L['List gems as trade goods'],
					type = 'toggle',
					width = 'double',
					order = 20,
					disabled = function(info) return info.handler:IsDisabled(info) or self.db.profile.split end,
				},
				mergeGlyphs = {
					name = L['List glyphs as trade goods'],
					type = 'toggle',
					width = 'double',
					order = 30,
					disabled = function(info) return info.handler:IsDisabled(info) or self.db.profile.split end,
				},
			}, addon:GetOptionHandler(self, true)
		end
		
		function itemCat:Filter(slotData)
			local isGem = (slotData.class == L["Gem"])
			local isGlyph = (slotData.class == L["Glyph"])
			if self.db.profile.split then
				if isGem or isGlyph then
					return slotData.class
				else
					return slotData.subclass, slotData.class
				end
			elseif (isGem and self.db.profile.mergeGems) or (isGlyph and self.db.profile.mergeGlyphs) then
				return L["Trade Goods"]
			else
				return slotData.class
			end
		end
		
	end

end
