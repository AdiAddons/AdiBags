--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2023 Adirelle (adirelle@gmail.com)
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

local deferred = false
local updateTable = {}

function addon:DeferUpdates()
  addon:Debug("DeferUpdates")
  deferred = true
end

function addon:ScheduleUpdate(key, fn)
  addon:Debug("ScheduleUpdate", key)
  if deferred then
    updateTable[key] = fn
  else
    fn(key)
  end
end

function addon:ApplyUpdates()
  addon:Debug("ApplyUpdates")
  deferred = false
  for key, update in pairs(updateTable) do
    update(key)
  end
  wipe(updateTable)
end