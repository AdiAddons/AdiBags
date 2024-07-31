local addonName = ...
---@class AdiBags: ABEvent-1.0
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- This is a deprecation message for AdiBags. To remove this for whatever reason,
-- remove this call from Core.lua in OnInitialize.
function addon:Deprecation()
    print("AdiBags is discontinued and will get no new releases.")
    print("Please consider switching to AdiBags' successor, BetterBags.")
    print("BetterBags is available at Curse, Wago, and github.com/Cidan/BetterBags")
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 0, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetPoint("LEFT", 30, 0)
    frame:SetSize(440, 300)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetTextColor(1, 1, 1, 1)
    text:SetPoint("LEFT", 20, 0)
    text:SetJustifyH("LEFT")
    text:SetText([[
AdiBags is discontinued, will get no new releases or bug fixes. Please consider switching to AdiBags' successor, BetterBags. BetterBags is written by the same team that maintains AdiBags. BetterBags is available at Curse, Wago, and github.com/Cidan/BetterBags
      ]])
    text:SetWordWrap(true)
    text:SetWidth(400)
    --frame:SetSize(text:GetStringWidth()+ 40, 200)

    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(180, 25)
    button:SetPoint("BOTTOM", 0, 10)
    button:SetText("Close")
    button:SetScript("OnClick", function()
      frame:Hide()
    end)
    frame:Show()
end
