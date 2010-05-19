--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0', 'AceBucket-3.0', 'AceHook-3.0', 'LibMovable-1.0')
--@debug@
_G[addonName] = addon
--@end-debug@

--------------------------------------------------------------------------------
-- Debug stuff
--------------------------------------------------------------------------------

if tekDebug then
	local type, tostring, select, unpack, strjoin = type, tostring, select, unpack, string.join
	local function TableToString(t)
		return (t == addon and 'Core')
			or (type(t.ToString) == "function" and t:ToString())
			or (type(t.GetName) == "function" and t:GetName())
			or t.moduleName
			or t.name
			or tostring(t)
	end
	local t = {}
	local function MyToStringAll(...)
		local n = select('#', ...)
		if n > 0 then
			for i = 1, n do
				local value = select(i, ...)
				t[i] = type(value) == "table" and TableToString(value) or tostring(value)
			end
			return unpack(t, 1, n)
		end
	end

	local frame = tekDebug:GetFrame(addonName)
	function addon:Debug(...)
		frame:AddMessage(strjoin(" ", "|cffff7700["..TableToString(self).."]|r", MyToStringAll(...)))
	end
else
	function addon.Debug() end
end

addon:SetDefaultModulePrototype{Debug = addon.Debug}

--------------------------------------------------------------------------------
-- Helpful constants
--------------------------------------------------------------------------------

do
	-- Backpack and bags
	local BAGS = { [BACKPACK_CONTAINER] = BACKPACK_CONTAINER }
	for i = 1, NUM_BAG_SLOTS do BAGS[i] = i end

	-- Bank bags
	local BANK = { [BANK_CONTAINER] = BANK_CONTAINER }
	for i = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do BANK[i] = i end
	
	-- All bags
	local ALL = {}
	for id in pairs(BAGS) do ALL[id] = id end
	for id in pairs(BANK) do ALL[id] = id end

	addon.BAG_IDS = { BAGS = BAGS, BANK = BANK, ALL = ALL }
end

local FAMILY_TAGS = {
--@noloc[[
	[0x0001] = L["QUIVER_TAG"], -- Quiver
  [0x0002] = L["AMMO_TAG"], -- Ammo Pouch
  [0x0004] = L["SOUL_BAG_TAG"], -- Soul Bag
  [0x0008] = L["LEATHERWORKING_BAG_TAG"], -- Leatherworking Bag
  [0x0010] = L["INSCRIPTION_BAG_TAG"], -- Inscription Bag
  [0x0020] = L["HERB_BAG_TAG"], -- Herb Bag
  [0x0040] = L["ENCHANTING_BAG_TAG"] , -- Enchanting Bag
  [0x0080] = L["ENGINEERING_BAG_TAG"], -- Engineering Bag
  [0x0100] = L["KEYRING_TAG"], -- Keyring
  [0x0200] = L["GEM_BAG_TAG"], -- Gem Bag
  [0x0400] = L["MINING_BAG_TAG"], -- Mining Bag
--@noloc]]
}

local FAMILY_ICONS = {
	[0x0001] = [[Interface\Icons\INV_Misc_Ammo_Arrow_01]], -- Quiver
  [0x0002] = [[Interface\Icons\INV_Misc_Ammo_Bullet_05]], -- Ammo Pouch
  [0x0004] = [[Interface\Icons\INV_Misc_Gem_Amethyst_02]], -- Soul Bag
  [0x0008] = [[Interface\Icons\Trade_LeatherWorking]], -- Leatherworking Bag
  [0x0010] = [[Interface\Icons\INV_Inscription_Tradeskill01]], -- Inscription Bag
  [0x0020] = [[Interface\Icons\Trade_Herbalism]], -- Herb Bag
  [0x0040] = [[Interface\Icons\Trade_Engraving]], -- Enchanting Bag
  [0x0080] = [[Interface\Icons\Trade_Engineering]], -- Engineering Bag
  [0x0100] = [[Interface\Icons\INV_Misc_Key_14]], -- Keyring
  [0x0200] = [[Interface\Icons\INV_Misc_Gem_BloodGem_01]], -- Gem Bag
  [0x0400] = [[Interface\Icons\Trade_Mining]], -- Mining Bag
}

function addon:GetFamilyTag(family)
	if family and family ~= 0 then
		for mask, tag in pairs(FAMILY_TAGS) do
			if bit.band(family, mask) ~= 0 then
				return tag, FAMILY_ICONS[mask]
			end
		end
	end
end

addon.ITEM_SIZE = 37
addon.ITEM_SPACING = 4
addon.SECTION_SPACING = addon.ITEM_SIZE / 3 + addon.ITEM_SPACING
addon.BAG_INSET = 8
addon.TOP_PADDING = 32

addon.BACKDROP = {
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

--------------------------------------------------------------------------------
-- Addon initialization and enabling
--------------------------------------------------------------------------------

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", {profile = {
		anchor = { scale = 0.8 },
		columns = 12,
		qualityHighlight = true,
		qualityOpacity = 1.0,
		questIndicator = true,
		stackFreeSpace = true,
		stackAmmunition = true,
		stackStackable = false,
		stackOthers = false,
		showBagType = true,
		filters = { ['*'] = true },
		filterPriorities = {},
		sortingOrder = 'default',
		modules = { ['*'] = true },
		backgroundColors = {
			Backpack = { 0, 0, 0, 1 },
			Bank = { 0, 0, 0.5, 1 },
		}
	},}, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Reconfigure")
	self.db.RegisterCallback(self, "OnProfileCopied", "Reconfigure")
	self.db.RegisterCallback(self, "OnProfileReset", "Reconfigure")
	
	self.itemParentFrames = {}

	self:InitializeFilters()
	self:CreateBagAnchor()
	addon:InitializeOptions()
end

function addon:OnEnable()
	self:RegisterEvent('BANKFRAME_OPENED')
	self:RegisterEvent('BANKFRAME_CLOSED')

	self:RegisterEvent('BAG_UPDATE')
	self:RegisterBucketEvent('PLAYERBANKSLOTS_CHANGED', 0, 'BankUpdated')

	self:RegisterBucketMessage('AdiBags_ConfigChanged', 0.2, 'ConfigChanged')

	self:RegisterMessage('AdiBags_BagOpened', 'LayoutBags')
	self:RegisterMessage('AdiBags_BagClosed', 'LayoutBags')

	self:RawHook("OpenAllBags", true)
	self:RawHook("CloseAllBags", true)
	self:RawHook('CloseSpecialWindows', true)

	self:RegisterEvent('MAIL_CLOSED', 'CloseAllBags')

	self:SetSortingOrder(self.db.profile.sortingOrder)
	
	for name, module in self:IterateModules() do
		if module.isFilter then
			module:SetEnabledState(self.db.profile.filters[module.moduleName])
		else
			module:SetEnabledState(self.db.profile.modules[module.moduleName])
		end
	end	
end

function addon:Reconfigure()
	self.holdYourBreath = true -- prevent tons*$% of useless updates
	self:Disable()
	self:Enable()
	self.holdYourBreath = nil
	self:UpdateFilters()
end

--------------------------------------------------------------------------------
-- Event handlers
--------------------------------------------------------------------------------

function addon:BANKFRAME_OPENED()
	self.atBank = true
end

function addon:BANKFRAME_CLOSED()
	self.atBank = false
end

function addon:BAG_UPDATE(event, bag)
	self:SendMessage('AdiBags_BagUpdated', bag)
end

function addon:BankUpdated(slots)
	-- Wrap several PLAYERBANKSLOTS_CHANGED into one AdiBags_BagUpdated message
	self:SendMessage('AdiBags_BagUpdated', BANK_CONTAINER)
end

function addon:CloseSpecialWindows()
	local bagWasOpen = self:CloseAllBags()
	return self.hooks.CloseSpecialWindows() or bagWasOpen
end

--@debug@
local function DebugTable(t, prevKey)
	local k, v = next(t, prevKey)
	if k ~= nil then
		return k, v, DebugTable(t, k)
	end
end
--@end-debug@

function addon:ConfigChanged(vars)
	--@debug@
	self:Debug('ConfigChanged', DebugTable(vars))
	--@end-debug@
	for name in pairs(vars) do
		if name:match('^stack') or name == 'filter' or name == 'columns' then
			return self:SendMessage('AdiBags_FiltersChanged')
		elseif name == 'sortingOrder' then
			return self:SetSortingOrder(self.db.profile.sortingOrder)
		end
	end
	self:SendMessage('AdiBags_UpdateAllButtons')
end

--------------------------------------------------------------------------------
-- Miscellaneous helpers
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

local function WidgetTooltip_OnEnter(self)
	GameTooltip:SetOwner(self, self.tooltipAnchor, self.tootlipAnchorXOffset, self.tootlipAnchorYOffset)
	self:UpdateTooltip(self)
end

local function WidgetTooltip_OnLeave(self)
	if GameTooltip:GetOwner() == self then
		GameTooltip:Hide()
	end
end

local function WidgetTooltip_Update(self)
	GameTooltip:ClearLines()
	self:tooltipCallback(GameTooltip)
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
-- Bag prototype
--------------------------------------------------------------------------------

local bagProto = {
	Debug = addon.Debug,
	isBag = true,
}
addon.bagProto = bagProto

function bagProto:OnDisable()
	self:Close()
end

function bagProto:Open()
	if not self:CanOpen() then return end
	local frame = self:GetFrame()
	if not frame:IsShown() then
		self:Debug('Open')
		frame:Show()
		addon:SendMessage('AdiBags_BagOpened', name, self)
		return true
	end
end

function bagProto:Close()
	if self.frame and self.frame:IsShown() then
		self:Debug('Close')
		self.frame:Hide()
		addon:SendMessage('AdiBags_BagClosed', name, self)
		return true
	end
end

function bagProto:IsOpen()
	return self.frame and self.frame:IsShown()
end

function bagProto:CanOpen()
	return self:IsEnabled()
end

function bagProto:HasFrame()
	return not not self.frame
end

function bagProto:GetFrame()
	if not self.frame then
		self.frame = self:CreateFrame()
		self.frame.CloseButton:SetScript('OnClick', function() self:Close() end)
		addon:SendMessage('AdiBags_BagFrameCreated', self)
	end
	return self.frame
end

function bagProto:CreateFrame()
	return addon:CreateContainerFrame(self.bagName, self.bagIds, self.isBank, addon.anchor)
end

--------------------------------------------------------------------------------
-- Bags methods
--------------------------------------------------------------------------------

local bags = {}

local function CompareBags(a, b)
	return a.order < b.order
end

function addon:NewBag(name, order, bagIds, isBank, ...)
	self:Debug('NewBag', name, order, bagIds, isBank, ...)
	local bag = addon:NewModule(name, bagProto, 'AceEvent-3.0', ...)
	bag.bagName = name
	bag.bagIds = bagIds
	bag.isBank = isBank
	bag.order = order
	tinsert(bags, bag)
	table.sort(bags, CompareBags)
	return bag
end

local function IterateOpenBags(bags, index)
	local bag
	repeat
		index = index + 1
		bag = bags[index]
	until not bag or bag:IsOpen()
	if bag then
		return index, bag
	end
end

function addon:IterateBags(onlyOpen)
	if onlyOpen then
		return IterateOpenBags, bags, 0
	else
		return ipairs(bags)
	end
end

function addon:AreAllBagsOpen()
	for i, bag in ipairs(bags) do
		if bag:CanOpen() and not bag:IsOpen() then
			return false
		end
	end
	return true
end

function addon:OpenAllBags(forceOpen)
	if not forceOpen and self:AreAllBagsOpen() then
		self:CloseAllBags()
		return
	end
	for i, bag in ipairs(bags) do
		bag:Open()
	end
end

function addon:CloseAllBags()
	local closed = false
	for i, bag in ipairs(bags) do
		closed = bag:Close() or closed
	end
	return closed
end

--------------------------------------------------------------------------------
-- Helper for modules
--------------------------------------------------------------------------------

local hooks = {}

function addon:HookBagFrameCreation(target, callback)
	local hook = hooks[target]
	if not hook then
		local target, callback, seen = target, callback, {}
		hook = function(event, bag)
			if seen[bag] then return end
			seen[bag] = true
			local res, msg
			if type(callback) == "string" then
				res, msg = pcall(target[callback], target, bag)
			else
				res, msg = pcall(callback, bag)
			end
			if not res then
				geterrorhandler()(msg)
			end
		end
		hooks[target] = hook
	end
	local listen = false
	for index, bag in pairs(bags) do
		if bag:HasFrame() then
			hook("HookBagFrameCreation", bag)
		else
			listen = true
		end
	end
	if listen then
		target:RegisterMessage("AdiBags_BagFrameCreated", hook)
	end
end

--------------------------------------------------------------------------------
-- Backpack
--------------------------------------------------------------------------------

do
	-- L["Backpack"]
	local backpack = addon:NewBag("Backpack", 10, addon.BAG_IDS.BAGS, false, 'AceHook-3.0')

	function backpack:OnEnable()
		self:RegisterEvent('BANKFRAME_OPENED', 'Open')
		self:RegisterEvent('BANKFRAME_CLOSED', 'Close')
		self:RawHook('OpenBackpack', 'Open', true)
		self:RawHook('CloseBackpack', 'Close', true)
		self:RawHook('ToggleBackpack', true)
	end

	function backpack:ToggleBackpack()
		if self:IsOpen() then self:Close() else self:Open() end
	end

end

--------------------------------------------------------------------------------
-- Bank
--------------------------------------------------------------------------------

do
	-- L["Bank"]
	local bank = addon:NewBag("Bank", 20, addon.BAG_IDS.BANK, true, 'AceHook-3.0')

	local function NOOP() end

	function bank:OnEnable()
		self:RegisterEvent('BANKFRAME_OPENED')
		self:RegisterEvent('BANKFRAME_CLOSED')

		self:RawHookScript(BankFrame, "OnEvent", NOOP, true)
		BankFrame:Hide()

		if addon.atBank then
			self:BANKFRAME_OPENED()
		end
	end

	function bank:OnDisable()
		bagProto.OnDisable(self)
		if self.atBank then
			BankFrame:Show()
		end
	end

	function bank:BANKFRAME_OPENED()
		self.atBank = true
		self:Open()
	end

	function bank:BANKFRAME_CLOSED()
		self.atBank = false
		self:Close()
	end

	function bank:CanOpen()
		return self:IsEnabled() and self.atBank
	end

	function bank:Close()
		if bagProto.Close(self) and self.atBank then
			CloseBankFrame()
		end
	end

end

--------------------------------------------------------------------------------
-- Bag anchor and layout
--------------------------------------------------------------------------------

local function Anchor_StartMoving(anchor)
	for _, bag in addon:IterateBags(true) do
		anchor.openBags[bag] = true
		bag:GetFrame():Hide()
	end
end

local function Anchor_StopMovingOrSizing(anchor)
	for	bag in pairs(anchor.openBags) do
		bag:GetFrame():Show()
	end
	wipe(anchor.openBags)
	addon:LayoutBags()
end

local AceConfigRegistry = LibStub('AceConfigRegistry-3.0')
function addon:CreateBagAnchor()
	local anchor = CreateFrame("Frame", addonName.."Anchor", UIParent)
	anchor:SetPoint("BOTTOMRIGHT", -32, 200)
	anchor:SetWidth(200)
	anchor:SetHeight(20)
	anchor.openBags = {}
	hooksecurefunc(anchor, "StartMoving", Anchor_StartMoving)
	hooksecurefunc(anchor, "StopMovingOrSizing", Anchor_StopMovingOrSizing)
	hooksecurefunc(anchor, "SetScale", function() AceConfigRegistry:NotifyChange(addonName) end)
	self.anchor = anchor
	self:RegisterMovable(anchor, self.db.profile.anchor, L["AdiBags anchor"])
end

function addon:LayoutBags()
	local nextBag, data, index, bag = self:IterateBags(true)
	index, bag = nextBag(data, index)
	if not bag then return end

	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local x, y = self.anchor:GetCenter()
	local scale = self.anchor:GetScale()
	x, y = x * scale, y * scale
	local anchorPoint =
		((y > 0.6 * h) and "TOP" or (y < 0.4 * h) and "BOTTOM" or "") ..
		((x < 0.4 * w) and "LEFT" or (x > 0.6 * w) and "RIGHT" or "")
	if anchorPoint == "" then anchorPoint = "CENTER" end

	local frame = bag:GetFrame()
	frame:ClearAllPoints()
	frame:SetPoint(anchorPoint, 0, 0)

	local lastFrame = frame
	index, bag = nextBag(data, index)
	if not bag then return end

	local vPart = anchorPoint:match("TOP") or anchorPoint:match("BOTTOM") or ""
	local hFrom, hTo, x = "LEFT", "RIGHT", 10
	if anchorPoint:match("RIGHT") then
		hFrom, hTo, x = "RIGHT", "LEFT", -10
	end
	local fromPoint = vPart..hFrom
	local toPoint = vPart..hTo

	while bag do
		local frame = bag:GetFrame()
		frame:ClearAllPoints()
		frame:SetPoint(fromPoint, lastFrame, toPoint, x, 0)
		lastFrame, index, bag = frame, nextBag(bag, index)
	end
end

--------------------------------------------------------------------------------
-- Filter prototype
--------------------------------------------------------------------------------

local filterProto = {
	isFilter = true,
	priority = 0,
	Debug = addon.Debug,
}
addon.filterProto = filterProto

function filterProto:OnEnable()
	addon:UpdateFilters()
end

function filterProto:OnDisable()
	addon:UpdateFilters()
end

function filterProto:GetPriority()
	return addon.db.profile.filterPriorities[self.filterName] or self.priority or 0
end

function filterProto:SetPriority(value)
	if value ~= self:GetPriority() then
		addon.db.profile.filterPriorities[self.filterName] = (value ~= self.priority) and value or nil
		addon:UpdateFilters()
	end
end

--------------------------------------------------------------------------------
-- Filter handling
--------------------------------------------------------------------------------

function addon:InitializeFilters()
	self:SetupDefaultFilters()
	self:UpdateFilters()
end

local function CompareFilters(a, b)
	return a:GetPriority() > b:GetPriority() 
end

local filters = {}
function addon:UpdateFilters()
	wipe(filters)
	for name, filter in self:IterateModules() do
		if filter.isFilter and filter:IsEnabled() then
			tinsert(filters, filter)
		end
	end
	table.sort(filters, CompareFilters)
	self:SendMessage('AdiBags_FiltersChanged')
end

function addon:IterateFilters()
	return ipairs(filters)
end

function addon:RegisterFilter(name, priority, Filter, ...)
	local filter
	if type(Filter) == "function" then
		filter = addon:NewModule(name, filterProto, ...)
		filter.Filter = Filter
	elseif Filter then
		filter = addon:NewModule(name, filterProto, Filter, ...)
	else
		filter = addon:NewModule(name, filterProto)
	end
	filter.filterName = name
	filter.priority = priority
	return filter
end

function addon:ShouldStack(slotData)
	if not slotData.link then
		return self.db.profile.stackFreeSpace
	elseif slotData.itemId == 6265 or slotData.equipSlot == "INVTYPE_AMMO" then
		return self.db.profile.stackAmmunition
	elseif slotData.maxStack > 1 then
		return self.db.profile.stackStackable
	else
		return self.db.profile.stackOthers
	end
end

--------------------------------------------------------------------------------
-- Filtering process
--------------------------------------------------------------------------------

local function safecall_return(success, ...)
	if success then
		return ...
	else
		geterrorhandler()((...))
	end
end

local function safecall(func, ...)
	if type(func) == "function" then
		return safecall_return(pcall(func, ...))
	end
end

function addon:Filter(slotData)
	for i, filter in ipairs(filters) do
		local sectionName, category = safecall(filter.Filter, filter, slotData)
		if sectionName then
			return filter.name, sectionName, (category or sectionName)
		end
	end
end

