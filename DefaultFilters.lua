--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

function addon:SetupDefaultFilters()

	-- [100] Parts of an equipment set
	do
		local itemSets = {}
		
		local function PreFilter()
			wipe(itemSets)
			for i = 1, GetNumEquipmentSets() do
				local name = GetEquipmentSetInfo(i)
				local section = 'Set: '..name
				local items = GetEquipmentSetItemIDs(name)
				for loc, id in pairs(items) do
					if id and not itemSets[id] then
						itemSets[id] = section
					end
				end
			end
		end
		
		local function Filter(bag, slot, itemId, link)
			return itemSets[itemId]
		end

		addon:RegisterFilter('Item sets', 100, Filter, PreFilter)
	end

	-- [90] Ammo and shards
	addon:RegisterFilter('Ammo and shards', 90, function(bag, slot, itemId, link)
		if itemId == 6265 then -- Soul Shard
			return 'Shards', 'item', itemId
		elseif select(9, GetItemInfo(itemId)) == 'INVTYPE_AMMO' then
			return 'Ammo', 'item', itemId
		end
	end)

	-- [80] Low quality items
	do
		local lowQualityPattern = string.format('%s|Hitem:%%d+:0:0:0:0', ITEM_QUALITY_COLORS[ITEM_QUALITY_POOR].hex)
		addon:RegisterFilter('Crap', 80, function(bag, slot, itemId, link)
			return link:match(lowQualityPattern) and 'Crap'
		end)
	end

	-- [70] Equipment
	addon:RegisterFilter('Equipment', 70, function(bag, slot, itemId, link)
		local invType = select(9, GetItemInfo(itemId))
		if invType and invType ~= "" then
			return 'Equipment'
		end
	end)
	
	-- [60] Item classes
	addon:RegisterFilter('Per item class', 70, function(bag, slot, itemId, link)
		return select(6, GetItemInfo(itemId)) or nil
	end)

end
