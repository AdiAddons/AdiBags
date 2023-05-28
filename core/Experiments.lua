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

---@class Experiments
local Experiments = addon:NewModule('Experiments')

---@cast addon +AdiBags

function Experiments:OnInitialize()
  self:CreateAllExperiments()
end

---CreateExperiment creates a new experiment.
---@param exp Experiment
function Experiments:CreateExperiment(exp)
  assert(exp.Name, "Experiment must have a name")
  assert(exp.Percent ~= nil and exp.Percent >= 0 and exp.Percent <= 100, "Experiment percent must be between 0 and 100")

  -- Don't create the experiment if it already exists with the same percentage, as this was loaded from disk.
  if addon.db.profile.experiments[exp.Name] ~= nil and addon.db.profile.experiments[exp.Name].Percent == exp.Percent then
    return
  end

  -- Don't recalculate already enabled experiements, recalculation can only add users to the cohort, not remove them.
  if addon.db.profile.experiments[exp.Name] ~= nil and addon.db.profile.experiments[exp.Name].Enabled then
    return
  end

  -- Figure out if this user should be in the experiment.
  if math.random(100) <= exp.Percent then
    exp.Enabled = true
  else
    exp.Enabled = false
  end

  addon.db.profile.experiments[exp.Name] = exp
end

-- Enabled returns whether or not any experiment is enabled for this user.
---@param name string
---@return boolean
function Experiments:Enabled(name)
  assert(addon.db.profile.experiments[name] ~= nil, "Experiment with name " .. name .. " does not exist")
  return addon.db.profile.experiments[name].Enabled
end

function Experiments:CreateAllExperiments()
  Experiments:CreateExperiment({
    Name = "Bag Lag Fix",
    Description = "This experiment will fix the lag when opening bags via per-item change draws instead of full redraws.",
    Percent = 1,
  })
end

function Experiments:GetOptions()
  local options = {}
  for name, experiment in pairs(addon.db.profile.experiments) do
    options[name] = {
      type = "toggle",
      name = experiment.Name,
      desc = experiment.Description,
      get = function()
        return addon.db.profile.experiments[name].Enabled
      end,
      set = function(_, value)
        addon.db.profile.experiments[name].Enabled = value
      end,
    }
  end
  return options
end

---@class Experiment
---@field Name string The name of the experiment.
---@field Description string The description of the experiment.
---@field Percent integer The percentage of players that should be in the experiment.
---@field Enabled boolean Whether or not the experiment is enabled.
