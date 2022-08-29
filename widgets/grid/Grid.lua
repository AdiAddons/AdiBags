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
  self.cellToColumn = {}
  self.cellToHandle = {}
  self.cellToPosition = {}
  self.cellMoving = {}
  self.minimumColumnWidth = 0
  self.sideFrame = CreateFrame("Frame", name .. "SideFrame", self)
  self.sideFrame:SetFrameLevel(self:GetFrameLevel() + 1)
  self.sideFrame:SetPoint("RIGHT", self, "RIGHT", 0, 0)
  Mixin(self.sideFrame, BackdropTemplateMixin)
  self.sideFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  self.sideFrame:Hide()

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
  self:Update()
  self:Debug("Grid created", name)
end

-- AddColumn adds a new column to the grid on the right hand side.
function gridProto:AddColumn()
  local column = addon:CreateColumnFrame(self.name .. "Column" .. #self.columns + 1)
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

-- Cell_OnDragStart is called when a cell is dragged.
local function Cell_OnDragStart(self, button, frame)
  if button ~= "LeftButton" then return end
  local column = self.cellToColumn[frame]
  if #column.cells < 2 and self.columns[#self.columns] ~= column then return end
  self.cellMoving[frame] = true

  self.sideFrame:Show()
  self.cellToPosition[frame] = column:GetCellPosition(frame)
  column:RemoveCell(frame)
  frame:StartMoving()
  frame:ClearAllPoints()
end

-- Cell_OnDragStop is called when a cell stops being dragged.
local function Cell_OnDragStop(self, button, frame)
  if not self.cellMoving[frame] then return end
  self.cellMoving[frame] = nil

  frame:StopMovingOrSizing()
  if self.sideFrame:IsMouseOver() then
    self:DeferUpdate()
    self.sideFrame:Hide()
    local column = self:AddColumn()
    column:SetMinimumWidth(self.minimumColumnWidth)

    self.cellToColumn[frame] = column
    column:AddCell(frame)
    self:DoUpdate()
    self:Debug("New Column Rect:", column:GetRect())
    return
  end

  self.sideFrame:Hide()
  for _, column in ipairs(self.columns) do
    self:Debug("Column Drag Stop Check", column)
    if column:IsMouseOver() then
      self:Debug("Dropping Cell in Column", column)
      self.cellToColumn[frame] = column
      column:AddCell(frame)
      column:Update()
      self:Debug("Mouse Over Frame", column)
      return
    end
  end

  -- Cell did not drag onto a column, restore it's position.
  self.cellToColumn[frame]:AddCell(frame, self.cellToPosition[frame])
  self.cellToColumn[frame]:Update()
end

-- AddCell will take the given frame and add it as a cell in
-- the grid.
function gridProto:AddCell(frame, dragHandle)
  assert(frame and frame.SetMovable, "Invalid cell added to frame!")
  assert(not dragHandle or dragHandle.EnableMouse, "Invalid drag handle added to frame!")
  local column
  if #self.columns < 1 then
    column = self:AddColumn()
    column:SetMinimumWidth(self.minimumColumnWidth)
  else
    column = self.columns[1]
  end

  column:AddCell(frame)
  self.cellToColumn[frame] = column
  self.cellToHandle[frame] = dragHandle or frame

  self.cellToHandle[frame]:EnableMouse(true)
  frame:SetMovable(true)
  self.cellToHandle[frame]:RegisterForDrag("LeftButton")
  self.cellToHandle[frame]:SetScript("OnMouseDown", function(e, button) Cell_OnDragStart(self, button, frame) end)
  self.cellToHandle[frame]:SetScript("OnMouseUp", function(e, button) Cell_OnDragStop(self, button, frame) end)
  self:Update()
end

-- SetMinimumColumnWidth sets the minium column width for all
-- columns in this grid.
function gridProto:SetMinimumColumnWidth(width)
  self.minimumColumnWidth = width
  for _, column in ipairs(self.columns) do
    column:SetMinimumWidth(width)
  end
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
    column:Update()
    self:Debug("Column Rect:", column:GetRect())
  end
  self.sideFrame:SetSize(25, self:GetHeight())
end