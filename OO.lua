--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

-- Classes

local function Meta_ToString(self)
	return self:ToString()
end

local function Class_Create(class, ...)
	class.serial = class.serial + 1
	local self = CreateFrame(class.frameType, addonName..class.name..class.serial, nil, class.frameTemplate)
	setmetatable(self, class.metatable)
	self:ClearAllPoints()
	self:Hide()
	if self.OnCreate then
		self:OnCreate(...)
	end
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
			mixin:Embed(prototype)
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
	if LibStub(frameTemplate, true) then		
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

local classes = {}

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

-- Object pools

local pools = {}

local function Pool_Acquire(pool, ...)
	local class = pool.class
	local self = next(pool.heap)
	if self then
		pool.heap[self] = nil
	else
		self = class:Create()
	end
	for name, mixin in pairs(class.mixins) do
		if mixin.OnEmbedEnable then
			mixin:OnEmbedEnable(self)
		end
	end
	if self.OnAcquire then
		self:OnAcquire(...)
	end
	return self
end

local function Pool_Release(pool, self)
	self:Hide()
	self:ClearAllPoints()
	self:SetParent(nil)
	if self.OnRelease then
		self:OnRelease()
	end
	local class = pool.class
	for name, mixin in pairs(class.mixins) do
		if mixin.OnEmbedDisable then
			mixin:OnEmbedDisable(self)
		end
	end
	pool.heap[self] = true
end

local function Instance_Release(self) 
	return Pool_Release(self.class.pool, self) 
end

function addon:CreatePool(class, acquireMethod)
	local pool = {
		heap = {},
		class = class,
		Acquire = Pool_Acquire,
		Release = Pool_Release,
	}
	class.pool = pool
	class.prototype.Release = Instance_Release
	pools[class.name] = pool
	if acquireMethod then
		self[acquireMethod] = function(self, ...) return pool:Acquire(...) end
	end
	return pool
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
		local heapSize = 0
		for k in pairs(pool.heap) do 
			heapSize = heapSize + 1
		end
		print(string.format("- %s: heap size: %d", name, heapSize))
	end
end
--@end-debug@
