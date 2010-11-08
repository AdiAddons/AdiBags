--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local AceConfigDialog = LibStub('AceConfigDialog-3.0')

local options

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
	return (info.option ~= options and info.option ~= options.args.core and not addon.db.profile.enabled) or (self.dbHolder ~= addon and not self.dbHolder:IsEnabled())
end

local handlers = {}
function addon:GetOptionHandler(dbHolder, isFilter)
	if not handlers[dbHolder] then
		handlers[dbHolder] = setmetatable({dbHolder = dbHolder, isFilter = isFilter}, handlerMeta)
		dbHolder.SendMessage = LibStub('AceEvent-3.0').SendMessage
	end
	return handlers[dbHolder]
end

--------------------------------------------------------------------------------
-- Filter & plugin options
--------------------------------------------------------------------------------

local filterOptions, moduleOptions = {}, {}

local OnModuleCreated

do
	local filters = {
		options = filterOptions,
		count = 0,
		nameAttribute = "filterName",
		dbKey = "filters",
		optionPath = "filters",
	}
	local modules = {
		options = moduleOptions,
		count = 0,
		nameAttribute = "moduleName",
		dbKey = "modules",
		optionPath = "modules",
	}

	function OnModuleCreated(self, module)
		if module.isBag and not module.isFilter and not module.GetOptions then
			return
		end

		local data = module.isFilter and filters or modules
		local name = module[data.nameAttribute]

		local baseOptions = {
			name = module.uiName or L[name] or name,
			desc = module.uiDesc,
			type = 'group',
			inline = true,
			order = 100 + data.count,
			args = {
				enabled = {
					name = L['Enabled'],
					desc = L['Check to enable this module.'],
					type = 'toggle',
					order = 20,
					get = function(info) return addon.db.profile[data.dbKey][name] end,
					set = function(info, value)
						addon.db.profile[data.dbKey][name] = value
						if value then module:Enable() else module:Disable() end
					end,
				},
			}
		}
		local extendedOptions

		if module.cannotDisable then
			baseOptions.args.enabled.disabled = true
		end
		if module.uiDesc then
			baseOptions.args.description = {
				name = module.uiDesc,
				type = 'description',
				order = 10,
			}
		end
		if module.isFilter then
			baseOptions.args.priority = {
				name = L['Priority'],
				type = 'range',
				order = 30,
				min = 0,
				max = 100,
				step = 1,
				bigStep = 1,
				get = function(info) return module:GetPriority() end,
				set = function(info, value) module:SetPriority(value) end,
			}
		end

		if module.GetOptions then
			local opts, handler = module:GetOptions()
			extendedOptions = {
				handler = handler,
				args = opts,
			}
		elseif module.GetFilterOptions then
			local opts, handler = module:GetFilterOptions()
			extendedOptions = {
				handler = handler,
				args = opts,
			}
		end

		data.options[name..'Basic'] = baseOptions

		if extendedOptions then
			extendedOptions.name = module.uiName or L[name] or name
			extendedOptions.desc = module.uiDesc
			extendedOptions.type = "group"
			extendedOptions.order = 1000 + data.count
			data.options[name] = extendedOptions

			if module.uiDesc then
				extendedOptions.args.description = {
					name = module.uiDesc,
					type = 'description',
					order = 1,
				}
			end

			baseOptions.args.configure = {
				name = L["Configure"],
				type = 'execute',
				func = function() AceConfigDialog:SelectGroup(addonName, data.optionPath, name) end,
			}
		end
		data.count = data.count + 1
	end
end

local function UpdateFilterOrder()
	for index, filter in addon:IterateFilters() do
		filterOptions[filter.filterName .. 'Basic'].order = 100 + index
	end
end

--------------------------------------------------------------------------------
-- Core options
--------------------------------------------------------------------------------

local lockOption = {
	name = function()
		return addon.anchor:IsShown() and L["Lock anchor"] or L["Unlock anchor"]
	end,
	desc = L["Click to toggle the bag anchor."],
	type = 'execute',
	order = 110,
	func = function()
		addon:ToggleAnchor()
	end,
	disabled = function(info) return (info.handler and info.handler:IsDisabled(info)) or addon.db.profile.positionMode ~= 'anchored' end,
}

function addon:GetOptions()
	if options then return options end
	filterOptions._desc = {
		name = L['Filters are used to dispatch items in bag sections. One item can only appear in one section. If the same item is selected by several filters, the one with the highest priority wins.'],
		type = 'description',
		order = 1,
	}
	local profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)
	profiles.order = 600
	profiles.disabled = false
	options = {
		--@debug@
		name = addonName..' DEV',
		--@end-debug@
		--[===[@non-debug@
		name = addonName..' @project-version@',
		--@end-non-debug@]===]
		type = 'group',
		handler = addon:GetOptionHandler(addon),
		get = 'Get',
		set = 'Set',
		disabled = 'IsDisabled',
		args = {
			enabled = {
				name = L['Enabled'],
				desc = L['Uncheck this to disable AdiBags.'],
				type = 'toggle',
				order = 100,
				disabled = false,
			},
			bags = {
				name = L['Bags'],
				type = 'group',
				order = 100,
				args = {
					positionMode = {
						name = L['Position mode'],
						desc = L['Select how the bag are positionned.'],
						type = 'select',
						order = 100,
						values = {
							anchored = L['Anchored'],
							manual = L['Manual'],
						}
					},
					toggleAnchor = lockOption,
					reset = {
						name = L['Reset position'],
						desc = L['Click there to reset the bag positions and sizes.'],
						type = 'execute',
						order = 120,
						func = function() addon:ResetBagPositions() end,
					},
					scale = {
						name = L['Scale'],
						desc = L['Use this to adjust the bag scale.'],
						type = 'range',
						order = 130,
						isPercent = true,
						min = 0.1,
						max = 3.0,
						step = 0.1,
						set = function(info, newScale)
							self.db.profile.scale = newScale
							self:LayoutBags()
							self:SendMessage('AdiBags_LayoutChanged')
						end,
					},
					rowWidth = {
						name = L['Maximum row width'],
						desc = L['Adjust the maximum number of items per row.'],
						type = 'range',
						order = 145,
						min = 4,
						max = 16,
						step = 1,
					},
					maxHeight = {
						name = L['Maximum bag height'],
						desc = L['Adjust the maximum height of the bags, relative to screen size.'],
						type = 'range',
						order = 145,
						isPercent = true,
						min = 0.30,
						max = 0.90,
						step = 0.01,
					},
					laxOrdering = {
						name = L['Layout priority'],
						type = 'select',
						width = 'double',
						order = 149,
						values = {
							[0] = L['Strictly keep ordering'],
							[1] = L['Group sections of same category'],
							[2] = L['Fill lines at most'],
						}
					},
					backgroundColors = {
						name = L['Background colors'],
						type = 'group',
						inline = true,
						order = 150,
						args = {
							backpackColor = {
								name = L['Backpack'],
								type = 'color',
								order = 150,
								hasAlpha = true,
								arg = { "backgroundColors", "Backpack" },
							},
							bankColor = {
								name = L['Bank'],
								type = 'color',
								order = 160,
								hasAlpha = true,
								arg = { "backgroundColors", "Bank" },
							},
						},
					}
				},
			},
			items = {
				name = L['Items'],
				type = 'group',
				order = 200,
				args = {
					sortingOrder = {
						name = L['Sorting order'],
						desc = L['Select how items should be sorted within each section.'],
						width = 'double',
						type = 'select',
						order = 100,
						values = {
							default = L['By category, subcategory, quality and item level (default)'],
							byName = L['By name'],
							byQualityAndLevel = L['By quality and item level'],
						}
					},
					quality = {
						name = L['Quality highlight'],
						type = 'group',
						inline = true,
						order = 100,
						args = {
							qualityHighlight = {
								name = L['Enabled'],
								desc = L['Check this to display a colored border around items, based on item quality.'],
								type = 'toggle',
								order = 210,
							},
							qualityOpacity = {
								name = L['Opacity'],
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
							dimJunk = {
								name = L['Dim junk'],
								desc = L['Check this to have poor quality items dimmed.'],
								type = 'toggle',
								order = 225,
								disabled = function(info)
									return info.handler:IsDisabled(info) or not addon.db.profile.qualityHighlight
								end,
							},
						},
					},
					questIndicator = {
						name = L['Quest indicator'],
						desc = L['Check this to display an indicator on quest items.'],
						type = 'toggle',
						order = 230,
					},
					showBagType = {
						name = L['Bag type'],
						desc = L['Check this to display a bag type tag in the top left corner of items.'],
						type = 'toggle',
						order = 240,
					},
					virtualStacks = {
						name = L['Virtual stacks'],
						type = 'group',
						inline = true,
						order = 300,
						args = {
							_desc = {
								name = L['Virtual stacks display in one place items that actually spread over several bag slots.'],
								type = 'description',
								order = 1,
							},
							freeSpace = {
								name = L['Free space'],
								desc = L['Show only one free slot for each kind of bags.'],
								order = 10,
								type = 'toggle',
								arg = {'virtualStacks', 'freeSpace'},
							},
							others = {
								name = L['Unstackable items'],
								desc = L['Show only one slot of items that cannot be stacked.'],
								order = 26,
								type = 'toggle',
								arg = {'virtualStacks', 'others'},
							},
							_stackableHeader = {
								type = 'header',
								name = L['Stackable items'],
								order = 19,
							},
							stackable = {
								name = L['Merge stackable items'],
								desc = L['Show only one slot of items that can be stacked.'],
								order = 20,
								width = 'full',
								type = 'toggle',
								arg = {'virtualStacks', 'stackable'},
							},
							incomplete = {
								name = L['... including incomplete stacks'],
								desc= L['Merge incomplete stacks with complete ones.'],
								order = 30,
								width = 'full',
								type = 'toggle',
								arg = {'virtualStacks', 'incomplete'},
								disabled = function(info)
									return info.handler:IsDisabled(info) or not addon.db.profile.virtualStacks.stackable
								end
							},
							notWhenTrading = {
								name = L['... but not when trading'],
								desc = L["Do not merge incomplete stack at merchants', auction house, bank, mailboxes or when trading."],
								order = 40,
								width = 'full',
								type = 'toggle',
								arg = {'virtualStacks', 'notWhenTrading'},
								disabled = function(info)
									return info.handler:IsDisabled(info) or not addon.db.profile.virtualStacks.stackable or not addon.db.profile.virtualStacks.incomplete
								end
							},
						}
					},
				},
			},
			filters = {
				name = L['Filters'],
				desc = L['Toggle and configure item filters.'],
				type = 'group',
				order = 400,
				args = filterOptions,
			},
			modules = {
				name = L['Plugins'],
				desc = L['Toggle and configure plugins.'],
				type = 'group',
				order = 500,
				args = moduleOptions,
			},
			profiles = profiles,
		},
		plugins = {}
	}
	addon.OnModuleCreated = OnModuleCreated
	for name, module in addon:IterateModules() do
		addon:OnModuleCreated(module)
	end
	UpdateFilterOrder()

	LibStub('AceEvent-3.0').RegisterMessage(addonName.."Options", 'AdiBags_FiltersChanged', UpdateFilterOrder)

	return options
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

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
				func = function()
					-- Close all UIPanels
					-- Doing InterfaceOptionsFrame.lastFrame = nil here taints the thing, causing weird issues
					local currentFrame = InterfaceOptionsFrame
					while currentFrame do
						local lastFrame = currentFrame.lastFrame
						HideUIPanel(currentFrame)
						currentFrame = lastFrame
					end
					-- Open the option pane on next update, hopefully after AceConfigDialog tried to close all its windows
					LibStub('AceTimer-3.0').ScheduleTimer(addonName, addon.OpenOptions, 0)
				end,
			},
			lock = lockOption,
		},
	})
	AceConfigDialog:AddToBlizOptions(addonName.."BlizzOptions", addonName)

	AceConfig:RegisterOptionsTable(addonName, function() return self:GetOptions() end)

	LibStub('AceConsole-3.0'):RegisterChatCommand("adibags", addon.OpenOptions, true)
end

function addon.OpenOptions()
	AceConfigDialog:SetDefaultSize(addonName, 800, 600)
	AceConfigDialog:Open(addonName)
end
