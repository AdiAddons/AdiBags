--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

function addon:SetupDefaultFilters()

	-- [110] New items
	do
		local newFilter =  addon:RegisterFilter("NewItems", 110, "AceEvent-3.0")

		local newItems = {}

		function newFilter:OnEnable()
			self:RegisterMessage('AgiBags_PreFilter')
		end

		function newFilter:AgiBags_PreFilter(event, container)
			self:Debug(event, container)
			newItems = container.newItems
		end

		function newFilter:Filter(slotData)
			return newItems[slotData.itemId] and L["New"]
		end
	end

	-- [100] Parts of an equipment set
	do
		local setFilter = addon:RegisterFilter("ItemSets", 100, "AceEvent-3.0")

		local sets = {}

		function setFilter:OnEnable()
			self:RegisterEvent('EQUIPMENT_SETS_CHANGED')
			self:UpdateSets()
		end

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
			return sets[slotData.itemId]
		end

	end

	-- [90] Ammo and shards
	addon:RegisterFilter('AmmoShards', 90, function(filter, slotData) -- L["AmmoShards"]
		if slotData.itemId == 6265 then -- Soul Shard
			return L['Soul shards'], true
		elseif slotData.equipSlot == 'INVTYPE_AMMO' then
			return L['Ammunition'], true
		end
	end)

	-- [80] Low quality items
	do
		local lowQualityPattern = string.format('%s|Hitem:%%d+:0:0:0:0', ITEM_QUALITY_COLORS[ITEM_QUALITY_POOR].hex)
		addon:RegisterFilter('Junk', 80, function(filter, slotData) -- L["Junk"]
			return slotData.link:match(lowQualityPattern) and L['Junk']
		end)
	end

	-- [70] Equipment
	addon:RegisterFilter('Equipment', 70, function(filter, slotData) -- L["Equipement"]
		if slotData.equipSlot and slotData.equipSlot ~= "" then
			return L['Equipment']
		end
	end)

	-- [60] Item classes
	addon:RegisterFilter('ItemCategory', 70, function(filter, slotData) --L["ItemCategory"]
		if slotData.class == L["Gem"] then
			return L["Trade Goods"]
		else
			return slotData.class
		end
	end)

end
