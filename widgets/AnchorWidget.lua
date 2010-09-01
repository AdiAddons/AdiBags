--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local anchorClass, anchorProto, anchorParentProto = addon:NewClass("Anchor", "Frame")

function addon:CreateAnchorWidget(...) return anchorClass:Create(...) end

local function Corner_OnUpdate(self)
	local x, y = self.anchor:GetCenter()
	if x ~= self.anchorX or y ~= self.anchorY then
		self.anchorX, self.anchorY = x, y
		local point = self.anchor:GetPosition()
		if point ~= self:GetPoint() then
			self:ClearAllPoints()
			self:SetPoint(point, self.anchor.target, 0, 0)
		end
	end
end

local BACKDROP = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16
}
addon.ANCHOR_BACKDROP = BACKDROP

function anchorProto:OnCreate(parent, name, label, target)
	self:SetParent(parent or UIParent)
	target = target or self

	self.name = name
	self.label = label
	self.target = target

	self:SetScript('OnHide', self.StopMoving)

	local corner = CreateFrame("Frame", nil, self)
	corner:SetFrameStrata("TOOLTIP")
	corner:SetBackdrop(BACKDROP)
	corner:SetBackdropColor(0, 1, 1, 1)
	corner:SetBackdropBorderColor(0, 0, 0, 0)
	corner:SetSize(12, 12)
	corner:Hide()
	corner:SetScript('OnUpdate', Corner_OnUpdate)
	corner.anchor = self
	self.corner = corner
end

local abs = math.abs
function anchorProto:GetPosition()
	local target = self.target
	local scale = target:GetScale()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()

	local x, y = target:GetCenter()
	x, y = x * scale, y * scale

	local vPos, hPos
	if x > w/2 then
		hPos, x = "RIGHT", target:GetRight()*scale - w
	else
		hPos, x = "LEFT", target:GetLeft()*scale
	end
	if y > h/2 then
		vPos, y = "TOP", target:GetTop()*scale - h
	else
		vPos, y = "BOTTOM", target:GetBottom()*scale
	end

	return vPos .. hPos, x, y
end

function anchorProto:ApplySettings()
	local db = addon.db.profile.positions[self.name]
	if db then
		local target = self.target
		local scale = target:GetScale()
		target:ClearAllPoints()
		target:SetPoint(db.point, db.xOffset / scale, db.yOffset / scale)
	end
end

function anchorProto:SaveSettings()
	local db = addon.db.profile.positions[self.name]
	db.point, db.xOffset, db.yOffset = self:GetPosition()
end

function anchorProto:StartMoving()
	if self.moving then return end
	self.moving = true
	local target = self.target
	if not target:IsMovable() then
		self.toggleMovable = true
		target:SetMovable(true)
	end
	if target == self then
		anchorParentProto.StartMoving(self)
	else
		target:StartMoving()
	end
	self.corner:Show()
	if self.OnMovingStarted then
		self:OnMovingStarted()
	end
end

function anchorProto:StopMoving()
	if not self.moving then return end
	self.moving = nil
	local target = self.target
	if self.toggleMovable then
		self.toggleMovable = nil
		target:SetMovable(false)
	end
	self.corner:Hide()
	if target == self then
		anchorParentProto.StopMovingOrSizing(self)
	else
		target:StopMovingOrSizing()
	end
	self:SaveSettings()
	if self.OnMovingStopped then
		self:OnMovingStopped()
	end
end
