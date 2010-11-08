--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0', 'AceBucket-3.0', 'AceHook-3.0')
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
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local DEFAULT_SETTINGS = {
	profile = {
		enabled = true,
		positionMode = "anchored",
		positions = {
			anchor = { point = "BOTTOMRIGHT", xOffset = -32, yOffset = 200 },
			Backpack = { point = "BOTTOMRIGHT", xOffset = -32, yOffset = 200 },
			Bank = { point = "TOPLEFT", xOffset = 32, yOffset = -104 },
		},
		scale = 0.8,
		rowWidth = 9,
		maxHeight = 0.60,
		laxOrdering = 1,
		qualityHighlight = true,
		qualityOpacity = 1.0,
		dimJunk = true,
		questIndicator = true,
		showBagType = true,
		filters = { ['*'] = true },
		filterPriorities = {},
		sortingOrder = 'default',
		modules = { ['*'] = true },
		backgroundColors = {
			Backpack = { 0, 0, 0, 1 },
			Bank = { 0, 0, 0.5, 1 },
		},
		virtualStacks = {
			['*'] = false,
			freeSpace = true,
		},
	},
	char = {
		collapsedSections = {
			['*'] = false,
		},
	}
}

--------------------------------------------------------------------------------
-- Addon initialization and enabling
--------------------------------------------------------------------------------

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", DEFAULT_SETTINGS, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Reconfigure")
	self.db.RegisterCallback(self, "OnProfileCopied", "Reconfigure")
	self.db.RegisterCallback(self, "OnProfileReset", "Reconfigure")

	self.itemParentFrames = {}

	self:InitializeFilters()
	self:CreateBagAnchor()
	addon:InitializeOptions()

	self:SetEnabledState(self.db.profile.enabled)

	-- Persistent handler
	self.RegisterBucketMessage(addonName, 'AdiBags_ConfigChanged', 0.2, function(...) addon:ConfigChanged(...) end)
end

local function NOOP() end

function addon:OnEnable()
	-- Convert old ordering setting
	if self.db.profile.laxOrdering == true then
		self.db.profile.laxOrdering = 1
	end

	-- Convert old anchor settings
	local oldData = self.db.profile.anchor
	if oldData then
		local scale = oldData.scale or 0.8
		self.db.profile.scale = scale 
		
		local newData = self.db.profile.positions.anchor
		newData.point = oldData.pointFrom or "BOTTOMRIGHT"
		newData.xOffset = (oldData.xOffset or -32) / scale
		newData.yOffset = (oldData.yOffset or 200) / scale
		
		self.db.profile.anchor = nil
	end

	self.globalLock = false

	self:RegisterEvent('BAG_UPDATE')
	self:RegisterBucketEvent('PLAYERBANKSLOTS_CHANGED', 0, 'BankUpdated')

	self:RegisterMessage('AdiBags_BagOpened', 'LayoutBags')
	self:RegisterMessage('AdiBags_BagClosed', 'LayoutBags')

	self:RawHook("OpenAllBags", true)
	self:RawHook("CloseAllBags", true)
	self:RawHook('CloseSpecialWindows', true)
	
	-- Track most windows involving items
	self:RegisterEvent('BANKFRAME_OPENED', 'UpdateInteractingWindow')
	self:RegisterEvent('BANKFRAME_CLOSED', 'UpdateInteractingWindow')
	self:RegisterEvent('MAIL_SHOW', 'UpdateInteractingWindow')
	self:RegisterEvent('MAIL_CLOSED', 'UpdateInteractingWindow')
	self:RegisterEvent('MERCHANT_SHOW', 'UpdateInteractingWindow')
	self:RegisterEvent('MERCHANT_CLOSED', 'UpdateInteractingWindow')
	self:RegisterEvent('AUCTION_HOUSE_SHOW', 'UpdateInteractingWindow')
	self:RegisterEvent('AUCTION_HOUSE_CLOSED', 'UpdateInteractingWindow')
	self:RegisterEvent('TRADE_SHOW', 'UpdateInteractingWindow')
	self:RegisterEvent('TRADE_CLOSED', 'UpdateInteractingWindow')
	self:RegisterEvent('GUILDBANKFRAME_OPENED', 'UpdateInteractingWindow')
	self:RegisterEvent('GUILDBANKFRAME_CLOSED', 'UpdateInteractingWindow')

	self:SetSortingOrder(self.db.profile.sortingOrder)

	for name, module in self:IterateModules() do
		if module.isFilter then
			module:SetEnabledState(self.db.profile.filters[module.moduleName])
		else
			module:SetEnabledState(self.db.profile.modules[module.moduleName])
		end
	end

	 self:UpdatePositionMode()
end

function addon:OnDisable()
	self.anchor:Hide()
	self:CloseAllBags()
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
	if vars.enabled then
		if self.db.profile.enabled then
			self:Enable()
		else
			self:Disable()
		end
		return
	elseif not self.db.profile.enabled then
		return
	elseif vars.filter then
		return self:SendMessage('AdiBags_FiltersChanged')
	else
		for name in pairs(vars) do
			if name:match('virtualStacks') then
				return self:SendMessage('AdiBags_FiltersChanged')
			end
		end
	end
	if vars.sortingOrder then
		return self:SetSortingOrder(self.db.profile.sortingOrder)
	elseif vars.rowWidth or vars.maxHeight or vars.laxOrdering then
		return self:SendMessage('AdiBags_LayoutChanged')
	elseif vars.scale then
		return self:LayoutBags()
	elseif vars.positionMode then
		return self:UpdatePositionMode()
	else
		self:SendMessage('AdiBags_UpdateAllButtons')
	end
end

function addon:SetGlobalLock(locked)
	locked = not not locked
	if locked ~= self.globalLock then
		self.globalLock = locked
		self:SendMessage('AdiBags_GlobalLockChanged', locked)
		if not locked then
			self:SendMessage('AdiBags_LayoutChanged')
		end
	end
end

--------------------------------------------------------------------------------
-- Track windows related to item interaction (merchant, mail, bank, ...)
--------------------------------------------------------------------------------

do
	local current
	function addon:UpdateInteractingWindow(event, ...)
		self:Debug('UpdateInteractingWindow', event, ...)
		local new = strmatch(event, '^(%w+)_OPENED$') or strmatch(event, '^(%w+)_SHOW$')
		self:Debug('UpdateInteractingWindow', event, current, '=>', new)
		if new ~= current then
			local old = current
			current = new
			self.atBank = (current == "BANKFRAME")
			if not current then
				self:CloseAllBags()
			end
			if self.db.profile.virtualStacks.notWhenTrading then
				self:SendMessage('AdiBags_FiltersChanged')
			end
			self:SendMessage('AdiBags_InteractingWindowChanged', new, old)
		end
	end

	function addon:GetInteractingWindow()
		return current
	end
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

local function safecall_return(success, ...)
	if success then
		return ...
	else
		geterrorhandler()((...))
	end
end

local function safecall(funcOrSelf, argOrMethod, ...)
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
addon.safecall = safecall

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
	safecall(self, "tooltipCallback", GameTooltip)
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
	return addon:CreateContainerFrame(self.bagName, self.bagIds, self.isBank)
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

		for i = 1, NUM_CONTAINER_FRAMES do
			local container = _G['ContainerFrame'..i]
			self:RawHook(container, "Show", 'ContainerShow', true)
			container:Hide()
		end
	end
	
	function backpack:ContainerShow(container, ...)
		if container:GetID() == KEYRING_CONTAINER then
			return self.hooks[container].Show(container)
		else
			return self:Open()
		end
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
		self:RawHook(BankFrame, "Show", "Open", true)
		BankFrame:Hide()

		if addon.atBank then
			self:BANKFRAME_OPENED()
		end
	end

	function bank:OnDisable()
		bagProto.OnDisable(self)
		if self.atBank then
			self.hooks[BankFrame].Show(BankFrame)
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

function addon:CreateBagAnchor()
	local anchor = self:CreateAnchorWidget(UIParent, "anchor", L["AdiBags Anchor"])
	anchor:SetSize(80, 80)
	anchor:SetFrameStrata("TOOLTIP")
	anchor:SetBackdrop(self.ANCHOR_BACKDROP)
	anchor:SetBackdropColor(0, 1, 0, 1)
	anchor:SetBackdropBorderColor(0, 0, 0, 0)
	anchor:EnableMouse(true)
	anchor:SetClampedToScreen(true)
	anchor:SetMovable(true)
	anchor.OnMovingStopped = function() addon:LayoutBags() end
	anchor:SetScript('OnMouseDown', anchor.StartMoving)
	anchor:SetScript('OnMouseUp', anchor.StopMoving)
	anchor:Hide()

	local text = anchor:CreateFontString(nil, "ARTWORK", "GameFontWhite")
	text:SetAllPoints(anchor)
	text:SetText(L["AdiBags Anchor"])
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	text:SetShadowColor(0,0,0,1)
	text:SetShadowOffset(1, -1)
	anchor.text = text

	self.anchor = anchor
end

local function AnchoredBagLayout(self)
	self.anchor:ApplySettings()

	local nextBag, data, index, bag = self:IterateBags(true)
	index, bag = nextBag(data, index)
	if not bag then return end

	local anchor = self.anchor
	local anchorPoint = anchor:GetPosition()

	local frame = bag:GetFrame()
	frame:ClearAllPoints()
	self:Debug('AnchoredBagLayout', anchorPoint)
	frame:SetPoint(anchorPoint, anchor, anchorPoint, 0, 0)

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
		frame:SetPoint(fromPoint, lastFrame, toPoint, x / frame:GetScale(), 0)
		lastFrame, index, bag = frame, nextBag(bag, index)
	end
end

local function ManualBagLayout(self)
	for index, bag in self:IterateBags(true) do
		bag:GetFrame().Anchor:ApplySettings()
	end
end

function addon:LayoutBags()
	local scale = self.db.profile.scale
	for index, bag in self:IterateBags() do
		if bag:HasFrame() then
			bag:GetFrame():SetScale(scale)
		end
	end
	if self.db.profile.positionMode == 'anchored' then
		AnchoredBagLayout(self)
	else
		ManualBagLayout(self)
	end
end

function addon:ToggleAnchor()
	if self.db.profile.positionMode == 'anchored' and not self.anchor:IsShown() then
		self.anchor:Show()
	else
		self.anchor:Hide()
	end
end

function addon:UpdatePositionMode()
	if self.db.profile.positionMode == 'anchored' then
		for index, bag in self:IterateBags() do
			if bag:HasFrame() then
				bag:GetFrame().Anchor:Hide()
			end
		end
	else
		for index, bag in self:IterateBags() do
			if bag:HasFrame() then
				bag:GetFrame().Anchor:Show()
			end
		end
		self.anchor:Hide()
	end
	self:LayoutBags()
end

local function copytable(dst, src)
	wipe(dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			copytable(dst[k], v)
		else
			dst[k] = v
		end
	end
end

function addon:ResetBagPositions()
	self.db.profile.scale = DEFAULT_SETTINGS.profile.scale
	copytable(self.db.profile.positions, DEFAULT_SETTINGS.profile.positions)
	self:LayoutBags()
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
-- Virtual stacks
--------------------------------------------------------------------------------

do
	local function GetDistinctItemID(link)
		if not link then return end
		local id = type(link) == "string" and tonumber(strmatch(link, 'item:(%d+)'))
		local equipSlot = id and select(9, GetItemInfo(id))
		if id and (not equipSlot or equipSlot == "") then
			return id
		end
		return strmatch(link, 'item:[-:%d]+') or link
	end

	local distinctIDs = setmetatable({}, {__index = function(t, link)
		local result = GetDistinctItemID(link)
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

	function addon:ShouldStack(slotData)
		local conf = self.db.profile.virtualStacks
		if not slotData.link then
			return conf.freeSpace, "*Free*"
		end
		local maxStack = slotData.maxStack or 1
		if maxStack > 1 then
			if conf.stackable then
				if (slotData.count or 1) == maxStack then
					return true, slotData.itemId
				elseif self:GetInteractingWindow() and conf.notWhenTrading then
					return false
				end
				return conf.incomplete, slotData.itemId
			end
		elseif conf.others then
			return true, distinctIDs[slotData.link]
		end
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
	local prioA, prioB = a:GetPriority(), b:GetPriority()
	if prioA == prioB then
		return a.filterName < b.filterName
	else
		return prioA > prioB
	end
end

local activeFilters = {}
local allFilters = {}
function addon:UpdateFilters()
	wipe(allFilters)
	for name, filter in self:IterateModules() do
		if filter.isFilter then
			tinsert(allFilters, filter)
		end
	end
	table.sort(allFilters, CompareFilters)
	wipe(activeFilters)
	for i, filter in ipairs(allFilters) do
		if filter:IsEnabled() then
			tinsert(activeFilters, filter)
		end
	end
	self:SendMessage('AdiBags_FiltersChanged')
end

function addon:IterateFilters()
	return ipairs(allFilters)
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

--------------------------------------------------------------------------------
-- Filtering process
--------------------------------------------------------------------------------

function addon:Filter(slotData, defaultSection, defaultCategory)
	for i, filter in ipairs(activeFilters) do
		local sectionName, category = safecall(filter.Filter, filter, slotData)
		if sectionName then
			--@alpha@
			assert(type(sectionName) == "string", "Filter "..filter.name.." returned "..type(sectionName).." as section name instead of a string")
			assert(category == nil or type(category) == "string", "Filter "..filter.name.." returned "..type(category).." as category instead of a string")
			--@end-alpha@
			return sectionName, category, filter.uiName
		end
	end
	return defaultSection, defaultCategory
end
