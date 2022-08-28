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

local gridClass, gridProto, gridParentProto = addon:NewClass("Grid", "LayeredRegion", "ABEvent-1.0")

function addon:CreateGridFrame(...) return gridClass:Create(...) end

-- OnCreate is called every time a new grid is created via addon:CreateGridFrame().
function gridProto:OnCreate(name, cellCreateFn)
  self:SetParent(UIParent)
  gridParentProto.OnCreate(self)
  Mixin(self, BackdropTemplateMixin)

  self.name = name
  self.updateDeferred = false
  self.columns = {}
  self.minimumColumnWidth = 0

  self:SetSize(300,500)
  self:SetPoint("CENTER", UIParent, "CENTER")

  -- Debugging only, remove in prod
  local backdropInfo =
  {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
     tile = true,
     tileEdge = true,
     tileSize = 8,
     edgeSize = 8,
     insets = { left = 1, right = 1, top = 1, bottom = 1 },
  }
  self:SetBackdrop(backdropInfo)
  -- End Debugging
  self:Show()
  self:Debug("Grid created", name)
end

-- AddColumn adds a new column to the grid on the right hand side.
function gridProto:AddColumn()
  local column = addon:CreateColumnFrame("one")
  column:SetParent(self)
  if #self.columns < 1 then
    column:SetPoint("TOPLEFT", self, "TOPLEFT")
  else
    local p = self.columns[#self.columns]
    column:SetPoint("TOPLEFT", p, "TOPRIGHT")
  end
  table.insert(self.columns, column)
  self:Debug("Added Column")
  self:Update()
  return column
end

local function Cell_OnDragStart(self)
  self:StartMoving()
end

local function Cell_OnDragStop(self)
  self:StopMovingOrSizing()
end
-- AddCell will take the given frame and add it as a cell in
-- the grid.
function gridProto:AddCell(frame)
  local column
  if #self.columns < 1 then
    column = self:AddColumn()
  else
    column = self.columns[1]
  end
  column:AddCell(frame)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", Cell_OnDragStart)
  frame:SetScript("OnDragStop", Cell_OnDragStop)
  self:Update()
end

-- SetMinimumColumnWidth sets the minium column width for all
-- columns in this grid.
function gridProto:SetMinimumColumnWidth(width)
  self.minimumColumnWidth = width
  self:Update()
end

-- DeferUpdate prevents grid updates from triggering until
-- DoUpdate is called.
function gridProto:DeferUpdate()
  self.updateDeferred = true
end

-- DoUpdate undeferres update calls and triggers an update.
function gridProto:DoUpdate()
  self.updateDeferred = false
  self:Update()
end

-- Update does a full layout update of the grid, sizing all columns
-- based on the properties of the grid, and ensuring positions
-- are correct.
function gridProto:Update()
  self:Debug("Grid Update With Deferred Status", self.updateDeferred)
  if self.updateDeferred then return end
  for i, column in ipairs(self.columns) do
    local width = self.minimumColumnWidth
    for cellPos, cell in ipairs(column.cells) do
      if cell:GetWidth() > width then
        width = cell:GetWidth()
      end
      if cellPos == 1 then
        cell:SetPoint("TOPLEFT", column)
      else
        cell:SetPoint("TOPLEFT", column.cells[cellPos-1], "BOTTOMLEFT")
      end
    end
    column:SetWidth(width)
    column:SetHeight(self:GetHeight())
    self:Debug("Column Width and Height", column:GetWidth(), column:GetHeight())
  end
end