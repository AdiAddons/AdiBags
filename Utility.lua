--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

-- Various utility functions

local addonName, addon = ...
local L = addon.L

--------------------------------------------------------------------------------
-- (bag,slot) <=> slotId conversion
--------------------------------------------------------------------------------

function addon.GetSlotId(bag, slot)
	if bag and slot then
		return bag * 100 + slot
	end
end

function addon.GetBagSlotFromId(slotId)
	if slotId then
		return math.floor(slotId / 100), slotId % 100
	end
end

--------------------------------------------------------------------------------
-- Safe call
--------------------------------------------------------------------------------

local function safecall_return(success, ...)
	if success then
		return ...
	else
		geterrorhandler()((...))
	end
end

function addon.safecall(funcOrSelf, argOrMethod, ...)
	local func, arg
	if type(funcOrSelf) == "table" and type(argOrMethod) == "string" then
		func, arg = funcOrSelf[argOrMethod], funcOrSelf
	else
		func, arg = funcOrSelf, argOrMethod
	end
	if type(func) == "function" then
		return safecall_return(pcall(func, arg, ...))
	end
end

--------------------------------------------------------------------------------
-- Attaching tooltip to widgets
--------------------------------------------------------------------------------

local function WidgetTooltip_OnEnter(self)
	GameTooltip:SetOwner(self, self.tooltipAnchor, self.tootlipAnchorXOffset, self.tootlipAnchorYOffset)
	self:UpdateTooltip()
end

local function WidgetTooltip_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

local function WidgetTooltip_Update(self)
	GameTooltip:ClearLines()
	addon.safecall(self, "tooltipCallback", GameTooltip)
	GameTooltip:Show()
end

function addon.SetupTooltip(widget, content, anchor, xOffset, yOffset)
	if type(content) == "string" then
		widget.tooltipCallback = function(self, tooltip)
			tooltip:AddLine(content)
		end
	elseif type(content) == "table" then
		widget.tooltipCallback = function(self, tooltip)
			tooltip:AddLine(tostring(content[1]), 1, 1, 1)
			for i = 2, #content do
				tooltip:AddLine(tostring(content[i]))
			end
		end
	elseif type(content) == "function" then
		widget.tooltipCallback = content
	else
		return
	end
	widget.tooltipAnchor = anchor or "ANCHOR_TOPLEFT"
	widget.tootlipAnchorXOffset = xOffset or 0
	widget.tootlipAnchorYOffset = yOffset or 0
	widget.UpdateTooltip = WidgetTooltip_Update
	widget:HookScript('OnEnter', WidgetTooltip_OnEnter)
	widget:HookScript('OnLeave', WidgetTooltip_OnLeave)
end

--------------------------------------------------------------------------------
-- Item link checking
--------------------------------------------------------------------------------

function addon.IsValidItemLink(link)
	if type(link) == "string" and strmatch(link, 'item:[-:%d]+') and not strmatch(link, 'item:%d+:0:0:0:0:0:0:0:0:0') then
		return true
	end
end

--------------------------------------------------------------------------------
-- Get distinct item IDs from item links
--------------------------------------------------------------------------------

local function __GetDistinctItemID(link)
	if not link or not addon.IsValidItemLink(link) then return end
	local itemString, id, enchant, gem1, gem2, gem3, gem4, suffix, reforge = strmatch(link, '(item:(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):%-?%d+:%-?%d+:(%-?%d+))')
	id = tonumber(id)
	local equipSlot = select(9, GetItemInfo(id))
	if equipSlot and equipSlot ~= "" and equipSlot ~= "INVTYPE_BAG" then
		-- Rebuild an item link without noise
		id = strjoin(':', 'item', id, enchant, gem1, gem2, gem3, gem4, suffix, "0", "0", reforge)
	end
	return id
end

local distinctIDs = setmetatable({}, {__index = function(t, link)
	local result = __GetDistinctItemID(link)
	if result then
		t[link] = result
		return result
	else
		return link
	end
end})

function addon.GetDistinctItemID(link)
	return link and distinctIDs[link]
end

--------------------------------------------------------------------------------
-- Detect junk items, with third-party addon support
--------------------------------------------------------------------------------

do
	local GetItemInfo, ITEM_QUALITY_POOR, ITEM_QUALITY_UNCOMMON = GetItemInfo, ITEM_QUALITY_POOR, ITEM_QUALITY_UNCOMMON
	
	local function IsJunk_Simple(itemId)
		local _, _, quality, _, _, class, subclass = GetItemInfo(itemId)
		--@noloc[[
		return quality == ITEM_QUALITY_POOR or quality < ITEM_QUALITY_UNCOMMON and (class == L['Junk'] or subclass == L['Junk'])
		--@noloc]]		
	end
	
	-- Scrap support, as suggest by xbeeps
	if Scrap and type(Scrap.IsJunk) == "function" then
		local Scrap = Scrap
		addon.IsJunk = function(itemId) return IsJunk_Simple(itemId) or Scrap:IsJunk(itemId) end
		Scrap:HookScript('OnReceiveDrag', function() addon:SendMessage("AdiBags_FiltersChanged") end)

	-- BrainDead support
	elseif LibStub('AceAddon-3.0'):GetAddon('BrainDead', true) then
		local SellJunk = LibStub('AceAddon-3.0'):GetAddon('BrainDead'):GetModule('SellJunk')
		addon.IsJunk = function(itemId)
			return IsJunk_Simple(itemId) or (SellJunk:IsEnabled() and SellJunk.db.profile.items[itemId])
		end
		
	-- no third-party addon
	else
		addon.IsJunk = IsJunk_Simple
	end
end

--------------------------------------------------------------------------------
-- Item and container family
--------------------------------------------------------------------------------

local GetItemFamily, GetItemInfo, GetContainerNumFreeSlots = GetItemFamily, GetItemInfo, GetContainerNumFreeSlots

function addon.GetItemFamily(item)
	return select(9, GetItemInfo(item)) == "INVTYPE_BAG" and 0 or GetItemFamily(item)
end

function addon.CanPutItemInContainer(item, container)
	local freeSlots, containerFamily = GetContainerNumFreeSlots(container)
	local itemFamily = addon.GetItemFamily(item)
	return freeSlots > 0 and (containerFamily == 0 or bit.band(itemFamily, containerFamily) ~= 0), freeSlots, itemFamily, containerFamily
end
