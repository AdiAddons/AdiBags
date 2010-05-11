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
				return self.db.profile.oneSectionPerSet and set or L['Sets']
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
	addon:RegisterFilter('AmmoShards', 80, function(filter, slotData) -- L["AmmoShards"]
		if slotData.itemId == 6265 then -- Soul Shard
			return L['Soul shards']
		elseif slotData.equipSlot == 'INVTYPE_AMMO' then
			return L['Ammunition']
		end
	end)

	-- [70] Low quality items
	do
		local lowQualityPattern = string.format('%s|Hitem:%%d+:0:0:0:0', ITEM_QUALITY_COLORS[ITEM_QUALITY_POOR].hex)
		addon:RegisterFilter('Junk', 70, function(filter, slotData) -- L["Junk"]
			if slotData.class == L['Junk'] or slotData.subclass == L['Junk'] or slotData.link:match(lowQualityPattern) then
				return L['Junk']
			end
		end)
	end

	-- [60] Equipment
	addon:RegisterFilter('Equipment', 60, function(filter, slotData) -- L["Equipement"]
		if slotData.equipSlot and slotData.equipSlot ~= "" then
			return L['Equipment']
		end
	end)

	-- [10] Item classes
	do
		local itemCat = addon:RegisterFilter('ItemCategory', 10) --L["ItemCategory"]

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
					name = L['Split by subcategory'],
					type = 'toggle',
					order = 10,
				},
				mergeGems = {
					name = L['Merge gems into Trade Goods'],
					type = 'toggle',
					width = 'double',
					order = 20,
					disabled = function(info) return info.handler:IsDisabled(info) or self.db.profile.split end,
				},
				mergeGlyphs = {
					name = L['Merge glyphs into Trade Goods'],
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
					return slotData.subclass
				end
			elseif isGem and self.db.profile.mergeGems then
				return L["Trade Goods"]
			elseif isGlyph and self.db.profile.mergeGlyphs then
				return L["Trade Goods"]
			else
				return slotData.class
			end
		end
		
		
		
	end

end
