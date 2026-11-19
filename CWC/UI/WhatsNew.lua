local ADDON, CWC = ...
local T = CWC.Theme

-- What's New window, laid out like FlareUI's: logo and title at the top, a scrolling panel of notes
-- with yellow headings and bullet points, and a "Don't Show on Login" box at the bottom. It opens once
-- after each update, unless that box is ticked.

local W, H = 780, 580
local GAME_FONT = "Fonts\\FRIZQT__.TTF"   -- the game's own font, as FlareUI uses
local YELLOW = { 1, 0.82, 0, 1 }
local WHITE = { 0.92, 0.92, 0.92, 1 }
local RING = "Interface\\AddOns\\CWC\\media\\art\\ring.tga"

local frame

local function gameText(parent, size, colour)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(GAME_FONT, size, "")
  local c = colour or WHITE
  fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(true)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.9)
  return fs
end

-- Height of a wrapped text block. The game's own font is always loaded, so the measured height can be
-- trusted; an estimate stands in if it ever comes back empty.
local function heightOf(fs, size)
  local h = fs:GetStringHeight() or 0
  if h <= 0 then h = size + 4 end
  return h
end

-- Lays the notes out top to bottom inside the scroll area and returns the total height.
local function buildNotes(child, width)
  local y = 0
  local function place(fs, x, size, gapAfter)
    fs:SetWidth(width - x)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
    y = y + heightOf(fs, size) + (gapAfter or 0)
  end

  for vi, release in ipairs(CWC.RELEASE_NOTES or {}) do
    if vi > 1 then
      y = y + 14
      local rule = child:CreateTexture(nil, "ARTWORK")
      rule:SetColorTexture(1, 0.82, 0, 0.25)
      rule:SetHeight(1)
      rule:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      rule:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
      y = y + 18
    end

    local head = gameText(child, vi == 1 and 22 or 18, YELLOW)
    head:SetText("CWC " .. release.version)
    place(head, 0, vi == 1 and 22 or 18, 10)

    if release.intro then
      local intro = gameText(child, 13, WHITE)
      intro:SetText(release.intro)
      place(intro, 0, 13, 12)
    end

    for _, section in ipairs(release.sections or {}) do
      local title = gameText(child, 15, YELLOW)
      title:SetText(section.title)
      place(title, 0, 15, 6)
      for _, item in ipairs(section.items or {}) do
        local text = type(item) == "table" and item.text or item
        local bullet = gameText(child, 13, WHITE)
        bullet:SetText("•")
        bullet:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
        local line = gameText(child, 13, WHITE)
        line:SetText(text)
        place(line, 18, 13, 4)
        if type(item) == "table" and item.sub then
          for _, subText in ipairs(item.sub) do
            local dash = gameText(child, 13, WHITE)
            dash:SetText("-")
            dash:SetPoint("TOPLEFT", child, "TOPLEFT", 34, -y)
            local subLine = gameText(child, 13, WHITE)
            subLine:SetText(subText)
            place(subLine, 46, 13, 4)
          end
        end
      end
      y = y + 10
    end
  end
  return y + 6
end

local function build()
  frame = CreateFrame("Frame", "CWCWhatsNew", UIParent, "BackdropTemplate")
  frame:SetSize(W, H)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetBackdropColor(0.16, 0.13, 0.1, 0.97)
  frame:SetBackdropBorderColor(0.95, 0.8, 0.55, 1)
  frame:Hide()
  table.insert(UISpecialFrames, "CWCWhatsNew") -- Escape closes it

  -- Header: round logo in a gold ring, title and version, then the two buttons.
  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetSize(50, 50)
  logo:SetPoint("TOPLEFT", 26, -22)
  logo:SetTexture(CWC.logoPath)
  if logo.SetMask then pcall(logo.SetMask, logo, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  local logoBg = frame:CreateTexture(nil, "BORDER")
  logoBg:SetSize(52, 52)
  logoBg:SetPoint("CENTER", logo, "CENTER")
  logoBg:SetColorTexture(0.95, 0.92, 0.85, 1)
  if logoBg.SetMask then pcall(logoBg.SetMask, logoBg, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  local ring = frame:CreateTexture(nil, "OVERLAY")
  ring:SetSize(62, 62)
  ring:SetPoint("CENTER", logo, "CENTER")
  ring:SetTexture(RING)

  local title = T.Text(frame, "heading", 24, T.c.gold)
  title:SetPoint("LEFT", logo, "RIGHT", 14, 2)
  title:SetText("Coping with Caffeine")
  local ver = gameText(frame, 12, WHITE)
  ver:SetPoint("LEFT", title, "RIGHT", 10, -2)
  ver:SetText(CWC.version)

  local openBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  openBtn:SetSize(108, 26)
  openBtn:SetPoint("LEFT", ver, "RIGHT", 34, 0)
  openBtn:SetText("Open CWC")
  openBtn:SetScript("OnClick", function()
    frame:Hide()
    if CWC.OpenWindow then CWC.OpenWindow() end
  end)
  local newBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  newBtn:SetSize(108, 26)
  newBtn:SetPoint("LEFT", openBtn, "RIGHT", 8, 0)
  newBtn:SetText("What's New")
  newBtn:LockHighlight() -- this is the page being shown

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() frame:Hide() end)

  -- Notes panel with its own scroll bar.
  local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", 22, -88)
  panel:SetPoint("BOTTOMRIGHT", -22, 54)
  panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  panel:SetBackdropColor(0.05, 0.04, 0.035, 0.75)
  panel:SetBackdropBorderColor(0.45, 0.36, 0.22, 1)

  local scroll = CreateFrame("ScrollFrame", "CWCWhatsNewScroll", panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -14)
  scroll:SetPoint("BOTTOMRIGHT", -32, 12)
  local child = CreateFrame("Frame", nil, scroll)
  local width = W - 22 - 22 - 16 - 32
  child:SetSize(width, 10)
  scroll:SetScrollChild(child)
  child:SetHeight(buildNotes(child, width))

  -- Footer: the box that stops it opening by itself, and where to find the notes later.
  local dontShow = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  dontShow:SetSize(28, 28)
  dontShow:SetPoint("BOTTOMLEFT", 22, 16)
  dontShow:SetChecked(CWC_Account.settings.hideWhatsNew == true)
  dontShow:SetScript("OnClick", function(self)
    CWC_Account.settings.hideWhatsNew = self:GetChecked() and true or false
  end)
  local dontLabel = gameText(frame, 14, WHITE)
  dontLabel:SetWordWrap(false)
  dontLabel:SetPoint("LEFT", dontShow, "RIGHT", 6, 0)
  dontLabel:SetText("Don't Show on Login")
  local note = gameText(frame, 11, { 0.7, 0.68, 0.64, 1 })
  note:SetWordWrap(false)
  note:SetPoint("LEFT", dontLabel, "RIGHT", 14, 0)
  note:SetText("The notes stay here: Settings > Tools > What's New, or /cwc whatsnew.")
  frame.dontShow = dontShow
end

function CWC.ShowWhatsNew()
  if not frame then build() end
  frame.dontShow:SetChecked(CWC_Account.settings.hideWhatsNew == true)
  frame:Show()
  frame:Raise()
  CWC_Account.notesSeenVersion = CWC.version
end

-- Opens once after each update: only for guild members, not on top of the setup wizard, and never when
-- Don't Show on Login is ticked. Waits for the guild check and for the wizard to close.
local function maybeShowOnLogin(tries)
  tries = tries or 0
  if CWC_Account.settings.hideWhatsNew then return end
  if CWC_Account.notesSeenVersion == CWC.version then return end
  local st = CWC.GuildState and CWC.GuildState() or "member"
  if st == "outsider" then return end
  local wizardOpen = CWCSetupFrame and CWCSetupFrame:IsShown()
  if st == "checking" or wizardOpen then
    if tries < 24 then C_Timer.After(5, function() maybeShowOnLogin(tries + 1) end) end
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    C_Timer.After(5, function() maybeShowOnLogin(tries + 1) end)
    return
  end
  CWC.ShowWhatsNew()
end

CWC.On("PLAYER_LOGIN", function()
  C_Timer.After(6, function() maybeShowOnLogin(0) end)
end)
