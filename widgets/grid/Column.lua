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
--GLOBALS>

local columnClass, columnProto, columnParentProto = addon:NewClass("Column", "LayeredRegion", "ABEvent-1.0")

function addon:CreateColumnFrame(...) return columnClass:Create(...) end
local columnPool = addon:CreatePool(columnClass, "AcquireColumn")

-- OnCreate is called every time a new column is created via addon:CreateColumnFrame().
function columnProto:OnCreate(name)
  columnParentProto.OnCreate(self)
  Mixin(self, BackdropTemplateMixin)
  self.name = name
  self.cells = {}
  self.minimumWidth = 0
  --[[
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
  self:SetBackdropColor(1, 0, 0)
  --]]
  --self:SetScript("OnMouseDown", function()
  --  self:Debug("Clicked Column")
  --end)
  --self:EnableMouse(true)
  self:Show()
  self:Debug("Column Created ID: ", self:GetName())
end

-- SetMinimumWidth sets the minimum width for this column.
function columnProto:SetMinimumWidth(width)
  self.minimumWidth = width
  self:Update()
end

-- AddCell adds a cell to this column at the given position, or at the
-- end of the column if no position is given.
function columnProto:AddCell(cell, position)
  cell:ClearAllPoints()
  cell:SetParent(self)
  cell:Show()
  position = position or #self.cells + 1
  table.insert(self.cells, position, cell)
end

-- GetCellPosition returns the cell's position as an integer in this column.
function columnProto:GetCellPosition(cell)
  for i, c in ipairs(self.cells) do
    if cell == c then return i end
  end
end

-- RemoveCell removes a cell from this column and reanchors
-- the cell below it (if any) to the cell above it.
function columnProto:RemoveCell(cell)
  for i, c in ipairs(self.cells) do
    if cell == c then
      cell:ClearAllPoints()
      table.remove(self.cells, i)
      break
    end
  end
  self:Update()
end

-- Update will fully redraw a column and snap all cells into the correct
-- position.
-- TODO(lobato): Add animation for cell movement.
function columnProto:Update()
  local w = self.minimumWidth
  local h = 0
  for cellPos, cell in ipairs(self.cells) do
    h = h + cell:GetHeight()
    w = math.max(w, cell:GetWidth()+4)
    if cellPos == 1 then
      cell:SetPoint("TOPLEFT", self)
    else
      cell:SetPoint("TOPLEFT", self.cells[cellPos-1], "BOTTOMLEFT")
    end
  end
  self:SetSize(w, h)
end