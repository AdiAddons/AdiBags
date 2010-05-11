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
	elseif info.type == 'color' then
		return unpack(db[key], 1, 4)
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
	elseif info.type == 'color' then
		if db[key] then
			local color = db[key]
			color[1], color[2], color[3], color[4] = value, ...
		else
			db[key] = { value, ... }
		end
	else
		db[key] = value
	end
	self.dbHolder:Debug('ConfigSet', path, value, ...)
	if self.isFilter then
		self.dbHolder:SendMessage('AdiBags_ConfigChanged', 'filter')
	else
		self.dbHolder:SendMessage('AdiBags_ConfigChanged', path)
	end
end

function handlerProto:IsDisabled(info)
	if self.dbHolder == addon then
		return info.type ~= "group" and not addon:IsEnabled()
	else
		return info.type ~= "group" and (not addon:IsEnabled() or not self.dbHolder:IsEnabled())
	end
end

local handlers = {}
function addon:GetOptionHandler(dbHolder, isFilter)
	if not handlers[dbHolder] then
		handlers[dbHolder] = setmetatable({dbHolder = dbHolder, isFilter = isFilter}, handlerMeta)
	end
	return handlers[dbHolder]
end

--------------------------------------------------------------------------------
-- Filter & plugin options
--------------------------------------------------------------------------------

local options, filterOptions, moduleOptions

local function AddFilterOptions(filter)
	local name = filter.filterName
	local opts = {
		name = filter.uiName or L[name] or name,
		type = 'group',
		inline = true,
		args = {
			enabled = {
				name = L['Enabled'],
				type = 'toggle',
				order = 1,
				get = function(info) return addon.db.profile.filters[name] end,
				set = function(info, value)
					addon.db.profile.filters[name] = value
					if value then filter:Enable() else filter:Disable() end
				end,
			},
			priority = {
				name = L['Priority'],
				type = 'range',
				order = 2,
				min = 0,
				max = 100,
				step = 1,
				bigStep = 5,
				get = function(info) return filter:GetPriority() end,
				set = function(info, value) filter:SetPriority(value) end,
				disabled = function() return not filter:IsEnabled() end,
			},
		},
	}
	if filter.GetFilterOptions then
		local filterOpts, handler = filter:GetFilterOptions()
		handler.isFilter = true
		if filterOpts.type == 'group' then
			filterOpts.handler = handler
			filterOptions[name..'Options'] = filterOpts
		else
			opts.plugins = { [name] = filterOpts }
			opts.handler = handler
		end
	end
	filterOptions[name] = opts
end

local function AddModuleOptions(module)
	local name = module.moduleName
	local opts = {
		name = module.uiName or L[name] or name, 
		type = 'group',
		inline = true,
		args = {}
	}
	if not module.isFilter and not module.isBag and not module.cannotDisable then
		opts.args.enabled = {
			name = L['Enabled'],
			type = 'toggle',
			order = 1,
			get = function(info) return addon.db.profile.modules[name] end,
			set = function(info, value)
				addon.db.profile.modules[name] = value
				if value then module:Enable() else module:Disable() end
			end,
		}
	end
	if module.GetOptions then
		local moduleOpts, handler = module:GetOptions()
		if moduleOpts.type == 'group' then
			moduleOpts.handler = handler
			moduleOptions[name..'Options'] = moduleOpts
		else
			opts.plugins = { [name] = moduleOpts }
			opts.handler = handler
		end
	end
	moduleOptions[name] = opts
end

local function OnModuleCreated(self, module)
	if module.isFilter then
		AddFilterOptions(module)
	end
	if module.GetOptions or (not module.isFilter and not module.isBag and not module.cannotDisable) then
		AddModuleOptions(module)
	end
end

--------------------------------------------------------------------------------
-- Core options
--------------------------------------------------------------------------------

local lockOption = {
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
}

function addon:GetOptions()
	if options then return options end
	filterOptions = {}
	moduleOptions = {}
	local profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)
	profiles.order = 30
	options = {
		name = addonName,
		type = 'group',
		args = {
			core = {
				name = L['Core'],
				type = 'group',
				order = 1,
				handler = addon:GetOptionHandler(addon),
				get = 'Get',
				set = 'Set',
				disabled = 'IsDisabled',			
				args = {
					_bagHeader = {
						name = L['Bags'],
						type = 'header',
						order = 100,
					},
					toggleAnchor = lockOption,
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
					columns = {
						name = L['Number of columns'],
						desc = L['Adjust the number of columns to display in each bag.'],
						type = 'range',
						min = 6,
						max = 16,
						step = 1,
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
			},
			filters = {
				name = L['Filters'],
				type = 'group',
				order = 10,
				args = filterOptions,
				handler = addon:GetOptionHandler(addon),
				get = 'Get',
				set = 'Set',
				disabled = 'IsDisabled',						
			},
			modules = {
				name = L['Plugins'],
				type = 'group',
				order = 20,
				args = moduleOptions,
				handler = addon:GetOptionHandler(addon),
				get = 'Get',
				set = 'Set',
				disabled = 'IsDisabled',						
			},
			profiles = profiles,
		},
		plugins = {}
	}
	addon.OnModuleCreated = OnModuleCreated
	for name, module in addon:IterateModules() do
		addon:OnModuleCreated(module)
	end
	return options
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

local AceConfigDialog = LibStub('AceConfigDialog-3.0')

function addon:InitializeOptions()
	local AceConfig = LibStub('AceConfig-3.0')

	AceConfig:RegisterOptionsTable(addonName.."BlizzOptions", {
		name = addonName,
		type = 'group',
		args = {
			configure = {
				name = L['Configure'],
				type = 'execute',
				order = 100,
				func = addon.OpenOptions,
			},
			lock = lockOption,
		},
	})	
	AceConfigDialog:AddToBlizOptions(addonName.."BlizzOptions", addonName)
	
	AceConfig:RegisterOptionsTable(addonName, function() return self:GetOptions() end)
end

function addon.OpenOptions()
	InterfaceOptionsFrame:Hide()
	AceConfigDialog:Open(addonName)
end
