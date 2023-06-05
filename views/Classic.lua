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

local class
---@class ClassicView
local prototype
class, prototype = addon:NewClass('ClassicView')

local pool = addon:CreatePool(class)

---@type AceModule
local classicView = addon:NewModule('ClassicView')
classicView.Acquire = function(self, ...) return pool:Acquire(...) end

-- Local Variables
local ITEM_SIZE = addon.ITEM_SIZE
local ITEM_SPACING = addon.ITEM_SPACING
local COLUMN_SPACING = ceil((ITEM_SIZE + ITEM_SPACING) / 2)
local ROW_SPACING = ITEM_SPACING*2
local SECTION_SPACING = COLUMN_SPACING / 2
-- End Local Variables

-- Local functions
local function FindFittingSection(maxWidth, sections)
	local bestScore, bestIndex = math.huge, nil
	for index, section in ipairs(sections) do
		local wasted = maxWidth - section:GetWidth()
		if wasted >= 0 and wasted < bestScore then
			bestScore, bestIndex = wasted, index
		end
	end
	return bestIndex and tremove(sections, bestIndex)
end

local function GetNextSection(maxWidth, sections)
	if sections[1] and sections[1]:GetWidth() <= maxWidth then
		return tremove(sections, 1)
	end
end
-- End local functions

---@return Frame
function prototype:CreateContentFrame(parent, ...)
  return CreateFrame("Frame", nil, parent)
end

function prototype:AddContainerButtons(container)
end

function prototype:NewSection(key, section, content)
end

function prototype:SaveLayout(shouldWipe, content)
end

function prototype:LoadLayout(content)
end

function prototype:DoLayout(maxHeight, columnWidth, minWidth, sections, content)
  self:Debug('LayoutSections', maxHeight, columnWidth, minWidth)
	local heights, widths, rows = { 0 }, {}, {}
	local columnPixelWidth = (ITEM_SIZE + ITEM_SPACING) * columnWidth - ITEM_SPACING + SECTION_SPACING
	local getSection = addon.db.profile.compactLayout and FindFittingSection or GetNextSection

	local numRows, x, y, rowHeight, maxSectionHeight, previous = 0, 0, 0, 0, 0, nil
	while next(sections) do
		local section
		if x > 0 then
			section = getSection(columnPixelWidth - x, sections)
			if section and previous then
				-- Quick hack -- sometimes the same section is inserted twice for unknown reasons.
				if section ~= previous then
					section:SetPoint('TOPLEFT', previous, 'TOPRIGHT', SECTION_SPACING, 0)
				end
			else
				x = 0
				y = y + rowHeight + ROW_SPACING
			end
		end

		if x == 0 then
			section = tremove(sections, 1)
			rowHeight = section:GetHeight()
			numRows = numRows + 1
			heights[numRows] = y
			rows[numRows] = section
			if numRows > 1 then
				section:SetPoint('TOPLEFT', rows[numRows-1], 'BOTTOMLEFT', 0, -ROW_SPACING)
			end
		end

		if section ~= previous then
			x = x + section:GetWidth() + SECTION_SPACING
			widths[numRows] = x - SECTION_SPACING
			previous = section
			maxSectionHeight = max(maxSectionHeight, section:GetHeight())
			rowHeight = max(rowHeight, section:GetHeight())
		end
	end

	local totalHeight = y + rowHeight
	heights[numRows+1] = totalHeight
	local numColumns = max(floor(minWidth / (columnPixelWidth - COLUMN_SPACING)), ceil(totalHeight / maxHeight))
	local maxColumnHeight = max(ceil(totalHeight / numColumns), maxSectionHeight)

	local row, x, contentHeight = 1, 0, 0
	while row <= numRows do
		local yOffset, section = heights[row], rows[row]
		section:SetPoint('TOPLEFT', content, x, 0)
		local maxY, thisColumnWidth = yOffset + maxColumnHeight + ITEM_SIZE + ROW_SPACING, 0
		repeat
			thisColumnWidth = max(thisColumnWidth, widths[row])
			row = row + 1
		until row > numRows or heights[row+1] > maxY
		contentHeight = max(contentHeight, heights[row] - yOffset)
		x = x + thisColumnWidth + COLUMN_SPACING
	end
	return x - COLUMN_SPACING, contentHeight - ITEM_SPACING
end