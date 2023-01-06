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

function addon:AddTheme(name, theme)
  self.db.profile.theme.themes[name] = theme
end

function addon:SetTheme(name)
  -- TODO(lobato): Send message for theme change
  self.db.profile.theme.currentTheme = name
  addon:SendMessage('AdiBags_ThemeChanged')
end

function addon:GetCurrentTheme()
  return self.db.profile.theme.themes[self.db.profile.theme.currentTheme]
end