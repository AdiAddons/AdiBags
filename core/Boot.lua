--[[
AdiBags - Adirelle's bag addon.
Copyright 2010-2021 Adirelle (adirelle@gmail.com)
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

-- This file handles the core loading of the addon before any other
-- functions or embedding is done. Do not add any functions or logic
-- to this file that is not related to the loading of the addon.

local addonName, root = ...
---@class AdiBags: AceModule
local addon = LibStub('AceAddon-3.0'):NewAddon(root, addonName, 'ABEvent-1.0', 'ABBucket-1.0', 'AceHook-3.0', 'AceConsole-3.0')

--@debug@
_G[addonName] = addon
--@end-debug@

addon:SetDefaultModuleState(false)

--------------------------------------------------------------------------------
-- Debug stuff
--------------------------------------------------------------------------------

--@alpha@
---@type AdiDebug
AdiDebug = AdiDebug

if AdiDebug then
	AdiDebug:Embed(addon, addonName)
else
--@end-alpha@
	function addon.Debug(self, ...) end
--@alpha@
end
--@end-alpha@

--------------------------------------------------------------------------------
-- Module prototype
--------------------------------------------------------------------------------

local moduleProto = {
	Debug = addon.Debug,
	OpenOptions = function(self)
		return addon:OpenOptions("modules", self.moduleName)
	end,
}
addon.moduleProto = moduleProto
addon:SetDefaultModulePrototype(moduleProto)