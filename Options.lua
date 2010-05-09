--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--------------------------------------------------------------------------------
-- Option handler prototype
--------------------------------------------------------------------------------

local handlerProto = {}
local handlerMeta = { __index = handlerProto }

function handlerProto:ResolvePath(info)
	local db = self.dbHolder.db.profile
	local path = info.arg or info[#info]
	if type(path) == "string" then
		return db, path, path
	elseif type(path) == "table" then
		local n = #path
		for i = 1, n-1 do
			db = db[path[i]]
		end
		return db, path[n], strjoin('.', unpack(path))
	end
end

function handlerProto:Get(info, ...)
	local db, key = self:ResolvePath(info)
	if info.type == "multiselect" then
		local subKey = ...
		return db[key] and db[key][subKey]
	else
		return db[key]
	end
end

function handlerProto:Set(info, value, ...)
	local db, key, path = self:ResolvePath(info)
	if info.type == 'multiselect' then
		local subKey, value = value, ...
		db[key][subKey] = value
		path = strjoin('.', path, subKey)
	else
		db[key] = value
	end
	self.dbHolder:Debug('ConfigSet', path, value)
	self.dbHolder:SendMessage('AdiBags_ConfigChanged', path)
end

function handlerProto:IsDisabled(info)
	if self.dbHolder == addon then
		return info.type ~= "group" and not addon:IsEnabled()
	else
		return info.type ~= "group" and (not addon:IsEnabled() or not self.dbHolder:IsEnabled())
	end
end

function addon.GetOptionHandler(dbHolder)
	return setmetatable({dbHolder = dbHolder}, handlerMeta)
end

--------------------------------------------------------------------------------
-- Core options
--------------------------------------------------------------------------------

local options

local function AddFilterOptions(filter)
	
end

local function AddModuleOptions(module)
end

local function OnModuleCreated(self, module)
	if module.isFilter then
		AddFilterOptions(module)
	elseif not module.isBag then
		AddModuleOptions(module)
	end
end

function addon.GetOptions()
	if not options then
		options = {
			name = addonName,
			type = 'group',
			handler = addon:GetOptionHandler(),
			get = 'Get',
			set = 'Set',
			disabled = 'IsDisabled',
			args = {
				_bagHeader = {
					name = L['Bags'],
					type = 'header',
					order = 100,
				},
				toggleAnchor = {
					name = function() 
						return addon:AreMovablesLocked() and L["Unlock anchor"] or L["Lock anchor"]
					end,
					desc = L["Click to toggle the bag anchor."],
					type = 'execute',
					order = 110,
					func = function()
						if addon:AreMovablesLocked() then
							 addon:UnlockMovables()
						else
							addon:LockMovables()
						end
					end,
				},
				bagScale = {
					name = L['Scale'],
					desc = L['Use this to adjust the bag sizes.'],
					type = 'range',
					order = 120,					
					arg = { 'anchor', 'scale' },
					isPercent = true,
					min = 0.1,
					max = 3.0,
					step = 0.1,
					set = function(info, value) info.handler:Set(info, value) addon:UpdateMovableLayout() end,
				},
				reset = {
					name = L['Reset'],
					desc = L['Click there to reset the bag positions and sizes.'],
					type = 'execute',
					order = 130,
					func = function() addon:ResetMovableLayout() end,
				},
				_itemsHeader = {
					name = L['Items'],
					type = 'header',
					order = 200,
				},
				qualityHighlight = {
					name = L['Quality highlight'],
					desc = L['Check this to display a colored border around items, based on item quality.'],
					type = 'toggle',
					order = 210,
				},
				qualityOpacity = {
					name = L['Quality opacity'],
					desc = L['Use this to adjust the quality-based border opacity. 100% means fully opaque.'],
					type = 'range',
					order = 220,
					isPercent = true,
					min = 0.05,
					max = 1.0,
					step = 0.05,
					disabled = function(info)
						return info.handler:IsDisabled(info) or not addon.db.profile.qualityHighlight
					end,
				},
				questIndicator = {
					name = L['Quest indicator'],
					desc = L['Check this to display an indicator on quest items.'],
					type = 'toggle',
					order = 230,
				},
				_stackHeader = {
					name = L['Virtual stacks'],
					type = 'header',
					order = 300,
				},
				_stackDesc = {
					name = L['Virtual stacks display in one place items that actually spread over several bag slots.'],
					type = 'description',
					order = 301,
				},
				stackFreeSpace = {
					name = L['Free space'],
					order = 310,
					type = 'toggle',
				},
				stackAmmunition = {
					name = L['Ammunition and soul shards'],
					order = 320,
					type = 'toggle',
				},
			},
			plugins = {}
		}
		addon.OnModuleCreated = OnModuleCreated
		for name, module in addon:IterateModules() do
			addon:OnModuleCreated(module)
		end
	end
	return options
end

