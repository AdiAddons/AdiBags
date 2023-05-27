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

---@cast addon +AdiBags

local Experiments = addon:NewModule('Experiments')
---@cast Experiments +Experiments

---@diagnostic disable-next-line: duplicate-set-field
function Experiments:OnInitialize()
  self.experiments = {}
end

---@param exp Experiment
function Experiments:CreateExperiment(exp)
  assert(exp.Name, "Experiment must have a name")
  assert(self.experiments[exp.Name] == nil, "Experiment with name " .. exp.Name .. " already exists")
  self.experiments[exp.Name] = exp
end

---@class Experiment
---@field Name string
---@field Description string

---@class Experiments
---@field experiments table<string, Experiment>