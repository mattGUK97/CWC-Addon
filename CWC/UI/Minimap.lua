local ADDON, CWC = ...

-- Minimap button.
-- When another addon has loaded LibDBIcon (the shared minimap button system most addons use), CWC registers
-- through it. Collector addons such as Minimap Button Button then pick CWC up exactly like every other addon.
-- Without LibDBIcon, CWC draws its own button using the same layout, so the logo sits inside the gold ring.

local button      -- CWC's own button (fallback only)
local libIcon     -- LibDBIcon, when it is available
local NAME = "CWC"

local function onClick(mouseButton)
  if mouseButton == "RightButton" then
    CWC.ShowSetup("full")
  else
    CWC.ToggleRoster()
  end
end

local function addTooltip(tt)
  tt:AddLine("Coping with Caffeine")
  tt:AddLine("Left-click: roster. Right-click: setup.", 1, 1, 1)
  local v = CWC.UpdateAvailable and CWC.UpdateAvailable()
  if v then tt:AddLine("Update required: CWC " .. v .. " is available.", 1, 0.35, 0.3) end
end

-- LibDBIcon keeps its own settings table (position and hidden state) inside CWC's saved settings.
local function libSettings()
  local s = CWC_Account.settings
  s.ldbIcon = s.ldbIcon or { minimapPos = s.minimapAngle or 220 }
  s.ldbIcon.hide = not s.minimapShown
  return s.ldbIcon
end

local function tryLibDBIcon()
  local stub = _G.LibStub
  if not stub then return false end
  local ldb = stub("LibDataBroker-1.1", true)
  local icon = stub("LibDBIcon-1.0", true)
  if not ldb or not icon then return false end
  local obj = ldb:GetDataObjectByName(NAME) or ldb:NewDataObject(NAME, {
    type = "launcher",
    text = "CWC",
    label = "Coping with Caffeine",
    icon = CWC.logoPath,
    OnClick = function(_, mouseButton) onClick(mouseButton) end,
    OnTooltipShow = addTooltip,
  })
  if not obj then return false end
  local ok = pcall(icon.Register, icon, NAME, obj, libSettings())
  if not ok then return false end
  libIcon = icon
  return true
end

-- Fallback: CWC's own button, laid out like a standard minimap button (31px button, 53px gold ring,
-- 18px icon inside it), so the logo no longer spills outside the ring.
local function placeButton()
  local angle = math.rad(CWC_Account.settings.minimapAngle or 220)
  local half = (Minimap:GetWidth() or 0) / 2
  local radius = half > 0 and (half + 10) or 80
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function createOwnButton()
  button = CreateFrame("Button", "CWCMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", 7, -5)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture(CWC.logoPath)
  -- Round the logo's corners so it sits cleanly inside the ring.
  if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  button:SetScript("OnClick", function(_, mouseButton) onClick(mouseButton) end)
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
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    addTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  placeButton()
end

function CWC.SetMinimapShown(shown)
  if libIcon then
    libSettings().hide = not shown
    if shown then libIcon:Show(NAME) else libIcon:Hide(NAME) end
  elseif button then
    if shown then button:Show() else button:Hide() end
  end
end

function CWC.CreateMinimapButton()
  if libIcon or button then return end
  if not tryLibDBIcon() then createOwnButton() end
  CWC.SetMinimapShown(CWC_Account.settings.minimapShown)
end

-- Settings > Tools > Check minimap button.
function CWC.MinimapStatus()
  local frame = libIcon and libIcon.GetMinimapButton and libIcon:GetMinimapButton(NAME) or button
  if not frame then
    CWC.Print("Minimap button: not created yet.")
    return
  end
  local how = libIcon and "LibDBIcon (shared minimap system, visible to collector addons)" or "CWC's own button (LibDBIcon not loaded)"
  local parent = frame:GetParent() and frame:GetParent():GetName() or "unknown"
  CWC.Print(string.format("Minimap button: %s, %s, setting=%s, parent=%s",
    how, frame:IsShown() and "shown" or "hidden", tostring(CWC_Account.settings.minimapShown), parent))
end

-- Settings > Tools > Reset minimap button: back to its default place and visible.
function CWC.MinimapReset()
  CWC_Account.settings.minimapAngle = 220
  CWC_Account.settings.minimapShown = true
  if libIcon then
    local db = libSettings()
    db.minimapPos = 220
    db.hide = false
    if libIcon.Refresh then libIcon:Refresh(NAME, db) end
    libIcon:Show(NAME)
  elseif button then
    placeButton()
    button:Show()
  end
  CWC.Print("Minimap button reset to its default place.")
end
