--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local safecall = addon.safecall

-- GLOBALS: SLASH_ADIBAGSOODEBUG1 SlashCmdList LibStub
local _G = _G
local assert = _G.assert
local CreateFrame = _G.CreateFrame
local next = _G.next
local pairs = _G.pairs
local print = _G.print
local select = _G.select
local setmetatable = _G.setmetatable
local string = _G.string
local tostring = _G.tostring

--------------------------------------------------------------------------------
-- Classes
--------------------------------------------------------------------------------

local classes = {}

local function Meta_ToString(self)
	return self:ToString()
end

local function Class_Create(class, ...)
	class.serial = class.serial + 1
	local self = CreateFrame(class.frameType, addonName..class.name..class.serial, nil, class.frameTemplate)
	setmetatable(self, class.metatable)
	self:ClearAllPoints()
	self:Hide()
	safecall(self, "OnCreate", ...)
	return self
end

local function NewClass(name, parent, ...)
	local prototype, mixins = {}, {}

	local class = {
		name = name,
		prototype = prototype,
		parent = parent,
		mixins = mixins,
		serial = 0,
		metatable = {
			__index = prototype,
			__tostring = Meta_ToString
		},
		Create = Class_Create,
	}

	if parent.mixins then
		setmetatable(mixins, { __index = parent.mixins })
	end
	for i = 1, select('#', ...) do
		local name = select(i, ...)
		if not mixins[name] then
			local mixin = LibStub(name)
			mixins[name] = mixin
			safecall(mixin, "Embed", prototype)
		end
	end

	prototype.class = class
	prototype.Debug = addon.Debug
	if parent.prototype then
		setmetatable(class, { __index = parent })
		setmetatable(prototype, { __index = parent.prototype })
		return class, prototype, parent.prototype
	else
		setmetatable(prototype, { __index = parent })
		return class, prototype, parent
	end
end

local function NewRootClass(name, frameType, frameTemplate, ...)
	local class, prototype, parent
	if frameTemplate and LibStub(frameTemplate, true) then
		class, prototype, parent = NewClass(name, CreateFrame(frameType), frameTemplate, ...)
		frameTemplate = nil
	else
		class, prototype, parent = NewClass(name, CreateFrame(frameType), ...)
	end
	class.frameType = frameType
	class.frameTemplate = frameTemplate
	prototype.ToString = parent.GetName
	return class, prototype, parent
end

function addon:NewClass(name, frameType, ...)
	local class, prototype, parent
	if classes[frameType] then
		class, prototype, parent = NewClass(name, classes[frameType], ...)
	else
		class, prototype, parent = NewRootClass(name, frameType, ...)
	end
	classes[name] = class
	return class, prototype, parent
end

function addon:GetClass(name)
	return name and classes[name]
end

--------------------------------------------------------------------------------
-- Object pools
--------------------------------------------------------------------------------

local pools = {}

local poolProto = {}
local poolMeta = { __index = poolProto }

function poolProto:Acquire(...)
	local object = next(self.heap)
	if object then
		assert(not object.acquired, "Found an acquired object in the pool")
		self.heap[object] = nil
	else
		object = self.class:Create()
	end
	self.actives[object] = true
	object.acquired = true
	for name, mixin in pairs(self.class.mixins) do
		safecall(mixin, "OnEmbedEnable", object)
	end
	safecall(object, "OnAcquire", ...)
	return object
end

function poolProto:Release(object)
	assert(object.acquired, "Trying to release an object that wasn't acquired")
	object:Hide()
	object:ClearAllPoints()
	object:SetParent(nil)
	safecall(object, "OnRelease")
	for name, mixin in pairs(self.class.mixins) do
		safecall(mixin, "OnEmbedDisable", object)
	end
	object.acquired = nil
	self.actives[object] = nil
	self.heap[object] = true
end

local function PoolIterator(data, current)
	current = next(data.pool[data.attribute], current)
	if current == nil and data.attribute == "heap" then
		data.attribute = "actives"
		return next(data.pool.actives)
	end
	return current
end

function poolProto:IterateAllObjects()
	return PoolIterator, { pool = self, attribute = "heap" }
end

function poolProto:IterateHeap()
	return pairs(self.heap)
end

function poolProto:IterateActiveObjects()
	return pairs(self.actives)
end

local function Instance_Release(self)
	return self.class.pool:Release(self)
end

function addon:CreatePool(class, acquireMethod)
	local pool = setmetatable({
		heap = {},
		actives = {},
		class = class,
	}, poolMeta)
	class.pool = pool
	class.prototype.Release = Instance_Release
	pools[class.name] = pool
	if acquireMethod then
		self[acquireMethod] = function(self, ...) return pool:Acquire(...) end
	end
	return pool
end

function addon:GetPool(name)
	return name and pools[name]
end

--@debug@
SLASH_ADIBAGSOODEBUG1 = "/aboo"
function SlashCmdList.ADIBAGSOODEBUG()
	print('Classes:')
	for name, class in pairs(classes) do
		print(string.format("- %s: type: %s, template: %s, serial: %d", name, class.frameType, tostring(class.frameTemplate), class.serial))
	end
	print('Pools:')
	for name, pool in pairs(pools) do
		local heapSize, numActives = 0, 0
		for k in pairs(pool.activtes) do
			numActives = numActives + 1
		end
		for k in pairs(pool.heap) do
			heapSize = heapSize + 1
		end
		print(string.format("- %s: heap size: %d, number of active objects: %d", name, heapSize, numActives))
	end
end
--@end-debug@
