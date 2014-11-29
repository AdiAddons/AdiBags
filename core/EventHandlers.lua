--[[
AdiBags - Adirelle's bag addon.
Copyright 2014 Adirelle (adirelle@gmail.com)
All rights reserved.
--]]

local addonName, addon = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local geterrorhandler = _G.geterrorhandler
local ipairs = _G.ipairs
local next = _G.next
local pairs = _G.pairs
local type = _G.type
local wipe = _G.wipe
local xpcall = _G.xpcall

local CBH = LibStub('CallbackHandler-1.0')

-- Event dispatching and messagging

local eventLib = LibStub:NewLibrary("ABEvent-1.0", 1)

local events = CBH:New(eventLib, 'RegisterEvent', 'UnregisterEvent', 'UnregisterAllEvents')
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript('OnEvent', function(_, ...) return events:Fire(...) end)
function events:OnUsed(_, event) return eventFrame:RegisterEvent(event) end
function events:OnUnused(_, event) return eventFrame:UnregisterEvent(event) end

local messages = CBH:New(eventLib, 'RegisterMessage', 'UnregisterMessage', 'UnregisterAllMessages')
eventLib.SendMessage = messages.Fire

function eventLib:Embed(target)
	for _, name in ipairs{'RegisterEvent', 'UnregisterEvent', 'UnregisterAllEvents', 'RegisterMessage', 'UnregisterMessage', 'UnregisterAllMessages', 'SendMessage'} do
		target[name] = eventLib[name]
	end
end

function eventLib:OnEmbedDisable(target)
	target:UnregisterAllEvents()
	target:UnregisterAllMessages()
end

-- Event/message bucketing

local bucketLib = LibStub:NewLibrary("ABBucket-1.0", 1)
local buckets, bucketHeap = {}, {}

local function BucketFire(self)
	self.timer = nil
	if not self.cancelled and next(self.received) then
		xpcall(self.callback, geterrorhandler())
	end
	wipe(self.received)
end

local function BucketHandler(self, event, arg)
	if arg == nil then
		arg = "nil"
	end
	self.received[arg] = (self.received[arg] or 0) + 1
	if not self.timer and not self.cancelled then
		self.timer = true
		C_Timer.After(self.delay, function() return BucketFire(self) end)
	end
end

local function RegisterBucket(target, event, delay, callback, regFunc)
	local bucket = next(bucketHeap)
	if bucket then
		bucketHeap[bucket] = nil
	else
		bucket = { received = {}, handler = BucketHandler }
	end
	wipe(bucket.received)
	bucket.delay, bucket.cancelled, bucket.timer = delay

	if type(callback) == "string" then
		bucket.callback = function() return target[callback](target, bucket.received) end
	else
		bucket.callback = function() return callback(target, bucket.received) end
	end

	if type(event) == "table" then
		for _, e in ipairs(event) do
			regFunc(bucket, e, "handler")
		end
	else
		regFunc(bucket, event, "handler")
	end

	if buckets[target] then
		buckets[target][bucket] = true
	else
		buckets[target] = { [bucket] = true }
	end
	return bucket
end

function bucketLib:RegisterBucketEvent(event, delay, callback)
	return RegisterBucket(self, event, delay, callback, eventLib.RegisterEvent)
end

function bucketLib:RegisterBucketMessage(event, delay, callback)
	return RegisterBucket(self, event, delay, callback, eventLib.RegisterMessage)
end

function bucketLib:UnregisterBucket(bucket)
	if not buckets[self][bucket] then
		return
	end
	eventLib.UnregisterAllEvents(bucket)
	eventLib.UnregisterAllMessages(bucket)
	bucket.cancelled = true
	wipe(bucket.received)
	buckets[self][bucket] = nil
	bucketHeap[bucket] = true
end

function bucketLib:UnregisterAllBuckets()
	if buckets[self] then
		for bucket in pairs(buckets[self]) do
			self:UnregisterBucket(bucket)
		end
	end
end

function bucketLib:Embed(target)
	for _, name in ipairs{"RegisterBucketEvent", "RegisterBucketMessage", "UnregisterBucket", "UnregisterAllBuckets"} do
		target[name] = bucketLib[name]
	end
end

function bucketLib:OnEmbedDisable(target)
	target:UnregisterAllBuckets()
end
