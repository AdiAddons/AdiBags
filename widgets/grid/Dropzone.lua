--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2022 Adirelle (adirelle@gmail.com)
All rights reserved.

This file is part of AdiBags.

AdiBags is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

AdiBags is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdiBags.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addonName, addon = ...
local L = addon.L

--<GLOBALS
local _G = _G
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
--GLOBALS>

local dropzoneClass
---@class dropzone
local dropzoneProto
local dropzoneParentProto

dropzoneClass, dropzoneProto = addon:NewClass("Dropzone", "Frame", "ABEvent-1.0")

---@return dropzone
function addon:CreateDropzoneFrame(...) return dropzoneClass:Create(...) end
addon:CreatePool(dropzoneClass, "AcquireDropzone")

-- A dropzone is a frame that acts as a placeholder for where an item can be dropped.
-- It is used to display a visual feedback when an item is being dragged over a dropzone.
-- Dropzones will dynamically resize to match the size of the frame that is being dragged.

function dropzoneProto:OnCreate()
  Mixin(self, BackdropTemplateMixin)
  local marker = CreateFrame("Frame", nil, self)
  marker:SetPoint("LEFT")
  marker:SetHeight(1)

  local tex = marker:CreateTexture("OVERLAY")
  tex:SetAllPoints(marker)
  tex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  tex:SetBlendMode("ADD")
  marker.Texture = tex

  local group = marker:CreateAnimationGroup()
  group:SetLooping("BOUNCE")

  local anim = group:CreateAnimation("Alpha")
  anim:SetOrder(1)
  anim:SetDuration(0.5)
  anim:SetFromAlpha(0.1)
  anim:SetToAlpha(0.8)
  self.group = group
  self.marker = marker
  self:SetScript("OnShow", self.OnShow)
  self:SetScript("OnHide", self.OnHide)
end

function dropzoneProto:OnShow()
  self.marker:SetWidth(self:GetWidth())
  self.group:Play()
end

function dropzoneProto:OnHide()
 self.group:Stop()
end

---@param name string The name of the frame.
---@param parent Frame The parent frame.
function dropzoneProto:OnAcquire(name, parent)
  self.name = name
  self:SetParent(parent)
  self:Hide()
end

function dropzoneProto:OnRelease()
  self.name = nil
  self:Hide()
  self:SetParent(UIParent)
  self:ClearAllPoints()
end