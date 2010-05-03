--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local EQUIP_LOCS = {
	INVTYPE_AMMO = 0,
	INVTYPE_HEAD = 1,
	INVTYPE_NECK = 2,
	INVTYPE_SHOULDER = 3,
	INVTYPE_BODY = 4,
	INVTYPE_CHEST = 5,
	INVTYPE_ROBE = 5,
	INVTYPE_WAIST = 6,
	INVTYPE_LEGS = 7,
	INVTYPE_FEET = 8,
	INVTYPE_WRIST = 9,
	INVTYPE_HAND = 10,
	INVTYPE_FINGER = 11,
	INVTYPE_TRINKET = 13,
	INVTYPE_CLOAK = 15,
	INVTYPE_WEAPON = 16,
	INVTYPE_SHIELD = 17,
	INVTYPE_2HWEAPON = 16,
	INVTYPE_WEAPONMAINHAND = 16,
	INVTYPE_WEAPONOFFHAND = 17,
	INVTYPE_HOLDABLE = 17,
	INVTYPE_RANGED = 18,
	INVTYPE_THROWN = 18,
	INVTYPE_RANGEDRIGHT = 18,
	INVTYPE_RELIC = 18,
	INVTYPE_TABARD = 19,
	INVTYPE_BAG = 20,
}

local function CompareItems(idA, idB)
	local nameA, _, qualityA, levelA, _, classA, subclassA, _, equipSlotA = GetItemInfo(idA)
	local nameB, _, qualityB, levelB, _, classB, subclassB, _, equipSlotB = GetItemInfo(idB)
	local equipLocA = EQUIP_LOCS[equipSlotA or ""]
	local equipLocB = EQUIP_LOCS[equipSlotB or ""]
	if equipLocA and equipLocB and equipLocA ~= equipLocB then
		return equipLocA < equipLocB
	elseif classA ~= classB then
		return classA < classB
	elseif subclassA ~= subclassB then
		return subclassA < subclassB
	elseif qualityA ~= qualityB then
		return qualityA > qualityB
	elseif levelA ~= levelB then
		return levelA > levelB
	else
		return nameA < nameB
	end
end

local itemCompareCache = setmetatable({}, { 
	__index = function(t, key)
		local result = CompareItems(strsplit(':', key, 2))
		t[key] = result
		return result
	end
})

local GetContainerItemID = GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo
local GetContainerNumFreeSlots = GetContainerNumFreeSlots
local strformat = string.format

function addon.CompareButtons(a, b)
	local idA = GetContainerItemID(a.bag, a.slot)
	local idB = GetContainerItemID(b.bag, b.slot)
	if idA and idB then
		if idA ~= idB then
			return itemCompareCache[strformat("%d:%d", idA, idB)]
		else
			local _, countA = GetContainerItemInfo(a.bag, a.slot)
			local _, countB = GetContainerItemInfo(b.bag, b.slot)
			return countA > countB
		end
	elseif not idA and not idB then
		local _, famA = GetContainerNumFreeSlots(a.bag)
		local _, famB = GetContainerNumFreeSlots(b.bag)
		if famA and famB and famA ~= famB then
			return famA < famB
		end
	end
	return (idA and 1 or 0) > (idB and 1 or 0)
end

