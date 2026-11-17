local ADDON, CWC = ...
local T = {}
CWC.Theme = T

local MEDIA = "Interface\\AddOns\\CWC\\media\\"

-- Fonts match the Coping with Caffeine site: Barlow for text, Cinzel for headings.
T.fonts = {
  body = MEDIA .. "fonts\\Barlow-Regular.ttf",
  bold = MEDIA .. "fonts\\Barlow-Bold.ttf",
  heading = MEDIA .. "fonts\\Cinzel-Bold.ttf",
}

-- Colours taken from the site's stylesheet.
T.c = {
  bg = { 0.07, 0.058, 0.046, 0.98 },
  panel = { 0.10, 0.085, 0.065, 1 },
  panelHi = { 0.14, 0.118, 0.09, 1 },
  line = { 0.34, 0.26, 0.14, 1 },
  gold = { 0.847, 0.651, 0.42, 1 },
  cream = { 0.902, 0.902, 0.918, 1 },
  muted = { 0.66, 0.66, 0.66, 1 },
  input = { 0.04, 0.04, 0.04, 1 },
}

T.fallbackIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

local function set(list)
  local t = {}
  for _, k in ipairs(list) do t[k] = true end
  return t
end
local CLASSES = set({ "warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid" })
local RACES = set({ "human", "dwarf", "gnome", "night-elf", "orc", "tauren", "troll", "undead" })
local PROFS = set({ "alchemy", "blacksmithing", "cooking", "enchanting", "engineering", "first-aid", "fishing", "herbalism", "leatherworking", "mining", "skinning", "tailoring" })

local function slug(s)
  local r = string.lower(s or ""):gsub("%s+", "-")
  return r
end

function T.ClassIcon(classFile)
  local key = string.lower(classFile or "")
  if CLASSES[key] then return MEDIA .. "class\\" .. key .. ".tga" end
  return T.fallbackIcon
end

function T.RaceIcon(race)
  local key = slug(race)
  if RACES[key] then return MEDIA .. "race\\" .. key .. ".tga" end
  return T.fallbackIcon
end

function T.ProfIcon(name)
  local key = slug(name)
  if PROFS[key] then return MEDIA .. "prof\\" .. key .. ".tga" end
  return T.fallbackIcon
end

function T.ClassColour(classFile)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[string.upper(classFile or "")]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

function T.Font(fs, which, size, flags)
  local path = T.fonts[which] or T.fonts.body
  fs:SetFont(path, size or 12, flags or "")
  -- Remembered, because GetFont can return nothing before the font has loaded.
  fs.cwcFont = { path, size or 12, flags or "" }
  return fs
end

function T.Text(parent, which, size, colour)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  T.Font(fs, which, size)
  local c = colour or T.c.cream
  fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
  fs:SetJustifyH("LEFT")
  return fs
end

-- Shortens text with "..." so it fits inside maxWidth.
local measure
local function getMeasure()
  if not measure then
    -- Measured on CWC's own invisible frame, so nothing is added to Blizzard's frames.
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:SetAlpha(0)
    measure = holder:CreateFontString(nil, "OVERLAY")
    measure:Show()
    measure:SetAlpha(0)
  end
  return measure
end

-- Width of a string in a font string's font, or 0 when the font is not known yet.
function T.Measure(fs, str)
  local m = getMeasure()
  local path, size, flags = fs:GetFont()
  if not path and fs.cwcFont then path, size, flags = unpack(fs.cwcFont) end
  if not path then return 0 end
  m:SetFont(path, size, flags)
  m:SetText(tostring(str or ""))
  return m:GetStringWidth() or 0
end

function T.Fit(fs, str, maxWidth)
  str = tostring(str or "")
  getMeasure()
  local path, size, flags = fs:GetFont()
  if not path and fs.cwcFont then path, size, flags = unpack(fs.cwcFont) end
  if not path then
    fs:SetText(str)
    return
  end
  measure:SetFont(path, size, flags)
  measure:SetText(str)
  if measure:GetStringWidth() <= maxWidth then
    fs:SetText(str)
    return
  end
  local s = str
  repeat
    s = string.sub(s, 1, -2)
    measure:SetText(s .. "...")
  until string.len(s) <= 1 or measure:GetStringWidth() <= maxWidth
  fs:SetText(s .. "...")
end

local EDGE = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  edgeSize = 1,
}

function T.Panel(parent, bg, border)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop(EDGE)
  local b = bg or T.c.panel
  local d = border or T.c.line
  f:SetBackdropColor(b[1], b[2], b[3], b[4] or 1)
  f:SetBackdropBorderColor(d[1], d[2], d[3], d[4] or 1)
  return f
end

function T.Button(parent, label, width, onClick, primary)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width or 110, 28)
  b:SetBackdrop(EDGE)
  local bg = primary and T.c.gold or T.c.panelHi
  local line = primary and T.c.gold or T.c.line
  b:SetBackdropColor(bg[1], bg[2], bg[3], 1)
  b:SetBackdropBorderColor(line[1], line[2], line[3], 1)
  b.text = T.Text(b, "bold", 12, primary and T.c.bg or T.c.cream)
  b.text:SetPoint("CENTER")
  b.text:SetText(label or "")
  b:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1)
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(line[1], line[2], line[3], 1)
  end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function T.Input(parent, width, maxLetters)
  local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  eb:SetSize(width or 200, 26)
  eb:SetBackdrop(EDGE)
  eb:SetBackdropColor(T.c.input[1], T.c.input[2], T.c.input[3], 1)
  eb:SetBackdropBorderColor(T.c.line[1], T.c.line[2], T.c.line[3], 1)
  T.Font(eb, "body", 13)
  eb:SetTextColor(T.c.cream[1], T.c.cream[2], T.c.cream[3], 1)
  eb:SetTextInsets(8, 8, 0, 0)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(maxLetters or 64)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEditFocusGained", function(self)
    self:SetBackdropBorderColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1)
  end)
  eb:SetScript("OnEditFocusLost", function(self)
    self:SetBackdropBorderColor(T.c.line[1], T.c.line[2], T.c.line[3], 1)
  end)
  return eb
end

function T.Check(parent, label, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb.label = T.Text(parent, "body", 13)
  cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cb.label:SetText(label or "")
  if onClick then cb:SetScript("OnClick", onClick) end
  return cb
end

-- Layout helpers for the redesigned window (inspired by FlareUI's layout; no code or artwork copied).
T.banner = MEDIA .. "art\\banner.tga"
T.portrait = MEDIA .. "art\\portrait.tga"

T.g = {
  bgTop = { 0.105, 0.105, 0.105, 1 },
  bgBottom = { 0.03, 0.03, 0.03, 1 },
  panelTop = { 0.125, 0.10, 0.075, 1 },
  panelBottom = { 0.075, 0.062, 0.048, 1 },
}

function T.Gradient(parent, top, bottom, layer)
  local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
  tex:SetAllPoints()
  tex:SetColorTexture(1, 1, 1, 1)
  tex:SetGradient("VERTICAL",
    CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
    CreateColor(top[1], top[2], top[3], top[4] or 1))
  return tex
end

function T.Card(parent)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop(EDGE)
  f:SetBackdropColor(0, 0, 0, 0)
  f:SetBackdropBorderColor(T.c.line[1], T.c.line[2], T.c.line[3], 1)
  T.Gradient(f, T.g.panelTop, T.g.panelBottom, "BACKGROUND")
  return f
end

function T.Rule(parent, alpha)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], alpha or 0.45)
  t:SetHeight(1)
  return t
end

function T.Badge(parent, colour)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetSize(78, 20)
  f:SetBackdrop(EDGE)
  f.text = T.Text(f, "bold", 11, colour)
  f.text:SetPoint("CENTER")
  f.text:SetJustifyH("CENTER")
  function f:SetLabel(text, c)
    self.text:SetText(text)
    self.text:SetTextColor(c[1], c[2], c[3], 1)
    self:SetBackdropColor(c[1] * 0.12, c[2] * 0.12, c[3] * 0.12, 0.9)
    self:SetBackdropBorderColor(c[1], c[2], c[3], 0.8)
  end
  f:SetLabel("", colour)
  return f
end

function T.NavItem(parent, label, icon, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(38)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(1, 1, 1, 0)
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1)
  b.bar:SetWidth(3)
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(22, 22)
  b.icon:SetPoint("LEFT", 16, 0)
  b.icon:SetTexture(icon or T.fallbackIcon)
  b.text = T.Text(b, "bold", 13, T.c.muted)
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
  b.text:SetText(label)
  b.active = false
  function b:SetActive(on)
    self.active = on
    self.bar:SetShown(on)
    if on then
      self.bg:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.10)
      self.text:SetTextColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1)
    else
      self.bg:SetColorTexture(1, 1, 1, 0)
      self.text:SetTextColor(T.c.cream[1], T.c.cream[2], T.c.cream[3], 1)
    end
  end
  b:SetScript("OnEnter", function(self)
    if not self.active then self.bg:SetColorTexture(1, 1, 1, 0.04) end
  end)
  b:SetScript("OnLeave", function(self)
    if not self.active then self.bg:SetColorTexture(1, 1, 1, 0) end
  end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end
