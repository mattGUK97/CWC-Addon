local ADDON, CWC = ...
local button

local FRAME_NAME = "CWCMinimapButton"

local function placeButton()
  local angle = math.rad(CWC_Account.settings.minimapAngle or 220)
  -- Sit just outside the minimap's edge, whatever size the minimap is set to.
  local half = (Minimap:GetWidth() or 0) / 2
  local radius = half > 0 and (half + 12) or 80
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function CWC.SetMinimapShown(shown)
  if not button then return end
  if shown then button:Show() else button:Hide() end
end

function CWC.CreateMinimapButton()
  if button then return end
  button = CreateFrame("Button", FRAME_NAME, Minimap)
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(CWC.logoPath)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      CWC.ShowSetup("full")
    else
      CWC.ToggleRoster()
    end
  end)

  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      CWC_Account.settings.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
      placeButton()
    end)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Coping with Caffeine")
    GameTooltip:AddLine("Left-click: roster. Right-click: setup.", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)

  placeButton()
  CWC.SetMinimapShown(CWC_Account.settings.minimapShown)
  C_Timer.After(5, CWC.ReclaimMinimapButton)
  C_Timer.After(15, CWC.ReclaimMinimapButton)
end

-- /cwc minimap: prints where the button is, to help track down a missing icon.
function CWC.MinimapStatus()
  if not button then
    CWC.Print("Minimap button: not created yet.")
    return
  end
  local shown = button:IsShown() and "shown" or "hidden"
  local x, y = button:GetCenter()
  local parent = button:GetParent() and button:GetParent():GetName() or "unknown"
  CWC.Print(string.format("Minimap button: %s, setting=%s, parent=%s, screen position=%s,%s",
    shown, tostring(CWC_Account.settings.minimapShown), parent,
    x and tostring(math.floor(x)) or "none", y and tostring(math.floor(y)) or "none"))
end

-- /cwc minimap reset: puts the button back at its default place and makes it visible.
function CWC.MinimapReset()
  if not button then return end
  CWC_Account.settings.minimapAngle = 220
  CWC_Account.settings.minimapShown = true
  placeButton()
  CWC.SetMinimapShown(true)
  CWC.Print("Minimap button reset to its default place.")
end

-- Some collector addons move minimap buttons after login, so put this one back on the minimap a few times.
function CWC.ReclaimMinimapButton()
  if not button then return end
  if button:GetParent() ~= Minimap then button:SetParent(Minimap) end
  placeButton()
  CWC.SetMinimapShown(CWC_Account.settings.minimapShown)
end
