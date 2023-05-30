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

-- This view is for the Classic rendering engine that originally shipped with AdiBags.

local addonName = ...
---@class AdiBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
local L = addon.L

---@class ClassicView: AceModule
local classicView = addon:NewModule('ClassicView')

---@return Frame
function classicView:CreateContentFrame(parent, ...)
  return CreateFrame("Frame", nil, parent)
end

function classicView:AddContainerButtons(container)
end

function classicView:NewSection(key, section)
end
