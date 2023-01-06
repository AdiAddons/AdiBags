--[[
AdiBags - Adirelle's bag addon.
Copyright 2012-2021 Adirelle (adirelle@gmail.com)
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
local LSM = LibStub('LibSharedMedia-3.0')

local _G = _G

-- UpsertTheme will create a new theme if it doesn't exist, or update an existing one.
-- Updates are a deep copy, so partial theme updates are allowed.
function addon:UpsertTheme(name, theme)
  assert(type(theme) == 'table', 'Theme must be a table')
  if not self.db.profile.theme.themes[name] then
    self.db.profile.theme.themes[name] = {}
  end
  _G.MergeTable(self.db.profile.theme.themes[name], theme)
end

function addon:SetTheme(name)
  self.db.profile.theme.currentTheme = name
  addon:SendMessage('AdiBags_ThemeChanged')
end

function addon:GetCurrentTheme()
  return self.db.profile.theme.themes[self.db.profile.theme.currentTheme]
end