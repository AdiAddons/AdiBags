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

-- OnCreate is called every time a new column is created via addon:CreateColumnFrame().
function columnProto:OnCreate(name)
  columnParentProto.OnCreate(self)
  Mixin(self, BackdropTemplateMixin)

  self.name = name
  self.cells = {}
  self.minimumWidth = 0

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
  self:EnableMouse(true)
  self:Show()
end

function columnProto:SetMinimumWidth(width)
  self.minimumWidth = width
  self:Update()
end

function columnProto:AddCell(cell, position)
  cell:ClearAllPoints()
  cell:SetParent(self)
  cell:Show()
  position = position or #self.cells + 1
  table.insert(self.cells, position, cell)
end

-- RemoveCell removes a cell from this column and reanchors
-- the cell below it (if any) to the cell above it.
function columnProto:RemoveCell(cell)
  for i, c in ipairs(self.cells) do
    if cell == c then
      cell:ClearAllPoints()
      -- TODO(lobato): remember previous position setting in case we snap back due to invalid drop placement.
      table.remove(self.cells, i)
      break
    end
  end
  self:Update()
end

function columnProto:Update()
  local width = self.minimumWidth
  for cellPos, cell in ipairs(self.cells) do
    if cell:GetWidth() > width then
      width = cell:GetWidth()
    end
    if cellPos == 1 then
      cell:SetPoint("TOPLEFT", self)
    else
      cell:SetPoint("TOPLEFT", self.cells[cellPos-1], "BOTTOMLEFT")
    end
  end
  self:SetWidth(width)
  self:SetHeight(self:GetParent():GetHeight())
  self:Debug("Column Width and Height", self:GetWidth(), self:GetHeight())
end