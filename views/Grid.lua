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

local addonName = ...
---@class AdiBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
local L = addon.L

---@class GridView: AceModule
local gridView = addon:NewModule('GridView')

---@return Grid
function gridView:CreateContentFrame(parent, key)
  return addon:CreateGridFrame(key, parent)
end

---@param container Container
function gridView:AddContainerButtons(container)
  container:CreateModuleButton(
		"L",
		20,
		function()
			container.Content:ToggleCovers()
		end,
		L["Lock/Unlock sections so they can be moved."]
	)
end

function gridView:NewSection(key, section, content)
  content:AddCell(key, section)
end

function gridView:SaveLayout(shouldWipe, content)
  content:SaveLayout(shouldWipe)
end

function gridView:LoadLayout(content)
  content:LoadLayout()
end

function gridView:DoLayout(maxHeight, columnWidth, minWidth, sections, content)
  content.Update()
  return 0, 0
end