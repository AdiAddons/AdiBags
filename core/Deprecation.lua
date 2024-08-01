local addonName = ...
---@class AdiBags: ABEvent-1.0
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)

-- This is a deprecation message for AdiBags. To remove this for whatever reason,
-- remove this call from Core.lua in OnInitialize.
function addon:Deprecation()
  if addon.db.profile.deprecationPhase < 2 then
    local prefix = "|cFF8ADCFF"..addonName.."|r:"
    local msg = "This addon has been deprecated and is therefore unlikely to receive new features, nor timely bug fixes. Continued support will largely be left up to the community.\n\nPlease consider switching to AdiBags' successor, BetterBags, which is written by the same team that maintains AdiBags and is available to download from Curse, Wago, and GitHub.\n\nThanks! :)"
    print(prefix, msg)
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
    frame:SetSize(440, 250)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetTextColor(1, 1, 1, 1)
    text:SetPoint("LEFT", 20, 0)
    text:SetJustifyH("LEFT")
    text:SetText(prefix.."\n"..msg)
    text:SetWordWrap(true)
    text:SetWidth(400)
    --frame:SetSize(text:GetStringWidth()+ 40, 200)

    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(180, 25)
    button:SetPoint("BOTTOM", 0, 10)
    button:SetText("Do Not Show Again")
    button:SetScript("OnClick", function()
      addon.db.profile.deprecationPhase = 2
      frame:Hide()
    end)
    frame:Show()
  end
end
