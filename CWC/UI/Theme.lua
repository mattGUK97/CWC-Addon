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

-- WoW: Forever's Skyborne (High Order for the Alliance) are newer than CWC's bundled icons, so the
-- game's own race portrait is used when the client has one, and CWC's Skyborne icon otherwise.
local raceAtlasCache = {}
local function gameRaceAtlas(race)
  if raceAtlasCache[race] ~= nil then return raceAtlasCache[race] or nil end
  local found = false
  pcall(function()
    if not (C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_Texture and C_Texture.GetAtlasInfo) then return end
    local want = string.lower(race)
    local files = {}
    for id = 1, 200 do
      local info = C_CreatureInfo.GetRaceInfo(id)
      local rn = info and info.raceName and string.lower(info.raceName)
      if rn and info.clientFileString then
        if rn == want then
          table.insert(files, 1, info.clientFileString)
        elseif rn:find("skyborne", 1, true) and want:find("skyborne", 1, true) then
          table.insert(files, info.clientFileString)
        end
      end
    end
    table.insert(files, "Skyborne")
    table.insert(files, "HighOrderSkyborne")
    for _, f in ipairs(files) do
      local lf = string.lower(f)
      for _, name in ipairs({ "raceicon128-" .. lf .. "-male", "raceicon-" .. lf .. "-male", "raceicon128-" .. lf .. "-female", "raceicon-" .. lf .. "-female" }) do
        if C_Texture.GetAtlasInfo(name) then
          found = name
          return
        end
      end
    end
  end)
  raceAtlasCache[race] = found
  return found or nil
end
T.GameRaceAtlas = gameRaceAtlas

-- Returns a texture path, or { atlas = name } for a game atlas.
function T.RaceIcon(race)
  local key = slug(race)
  if RACES[key] then return MEDIA .. "race\\" .. key .. ".tga" end
  if key:find("skyborne", 1, true) or key == "high-order" then
    local atlas = gameRaceAtlas(race)
    if atlas then return { atlas = atlas } end
    return MEDIA .. "race\\skyborne.tga"
  end
  return T.fallbackIcon
end

-- Shows an icon from T.RaceIcon (or any texture path) on a texture.
function T.SetIcon(tex, icon)
  if type(icon) == "table" and icon.atlas then
    tex:SetAtlas(icon.atlas)
    tex.cwcAtlas = true
  else
    tex:SetTexture(icon)
    -- An atlas leaves its own texture coordinates behind, so they're reset for a plain texture.
    if tex.cwcAtlas then
      tex:SetTexCoord(0, 1, 0, 1)
      tex.cwcAtlas = nil
    end
  end
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

-- CWC's scroll bar: a thin dark track with a gold thumb, and small arrows at each end. Drag the thumb,
-- click the track to jump a page, use the arrows, or scroll with the mouse wheel. It hides itself when
-- everything fits. sf is a ScrollFrame and child its scroll child; step is how far one wheel notch moves.
T.SCROLLBAR_W = 10
function T.ScrollBar(parent, sf, child, step)
  step = step or 40
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetWidth(T.SCROLLBAR_W)
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, 0)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 0)
  bar:SetFrameLevel(sf:GetFrameLevel() + 5)

  local function arrow(up)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(T.SCROLLBAR_W, 12)
    b:SetPoint(up and "TOP" or "BOTTOM", bar, up and "TOP" or "BOTTOM", 0, 0)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetTexture(up and "Interface\\Buttons\\Arrow-Up-Up" or "Interface\\Buttons\\Arrow-Down-Up")
    t:SetSize(14, 14)
    t:SetPoint("CENTER", 0, up and -2 or 3)
    t:SetVertexColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.75)
    b:SetScript("OnEnter", function() t:SetVertexColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1) end)
    b:SetScript("OnLeave", function() t:SetVertexColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.75) end)
    return b
  end
  local up, down = arrow(true), arrow(false)

  local track = CreateFrame("Frame", nil, bar)
  track:SetPoint("TOPLEFT", up, "BOTTOMLEFT", 0, -2)
  track:SetPoint("BOTTOMRIGHT", down, "TOPRIGHT", 0, 2)
  track:EnableMouse(true)
  local tbg = track:CreateTexture(nil, "BACKGROUND")
  tbg:SetAllPoints()
  tbg:SetColorTexture(0, 0, 0, 0.45)
  local edge = track:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  edge:SetColorTexture(T.c.line[1], T.c.line[2], T.c.line[3], 0.6)
  local inner = track:CreateTexture(nil, "BORDER", nil, 1)
  inner:SetAllPoints()
  inner:SetColorTexture(0.03, 0.025, 0.02, 1)

  local thumb = CreateFrame("Frame", nil, track)
  thumb:SetWidth(T.SCROLLBAR_W - 2)
  thumb:EnableMouse(true)
  local tt = thumb:CreateTexture(nil, "ARTWORK")
  tt:SetAllPoints()
  local function tint(a) tt:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], a) end
  tint(0.6)

  local function range() return math.max(0, (child:GetHeight() or 0) - (sf:GetHeight() or 0)) end
  local updating = false
  function bar.Update()
    if updating then return end
    updating = true
    local r = range()
    local cur = sf:GetVerticalScroll() or 0
    if cur > r then sf:SetVerticalScroll(r); cur = r end
    if r < 1 then
      if cur ~= 0 then sf:SetVerticalScroll(0) end
      bar:Hide()
    else
      bar:Show()
      local trackH = track:GetHeight() or 0
      local viewH, total = sf:GetHeight() or 1, child:GetHeight() or 1
      local th = math.max(24, math.min(trackH, trackH * viewH / total))
      thumb:SetHeight(th)
      thumb:ClearAllPoints()
      thumb:SetPoint("TOP", track, "TOP", 0, -(trackH - th) * (cur / r))
    end
    updating = false
  end
  function bar.ScrollTo(v)
    sf:SetVerticalScroll(math.max(0, math.min(range(), v)))
    bar.Update()
  end
  function bar.ScrollBy(d) bar.ScrollTo((sf:GetVerticalScroll() or 0) + d) end

  up:SetScript("OnClick", function() bar.ScrollBy(-step) end)
  down:SetScript("OnClick", function() bar.ScrollBy(step) end)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(_, delta) bar.ScrollBy(-delta * step) end)

  -- Click above or below the thumb to move a page.
  track:SetScript("OnMouseDown", function()
    local _, y = GetCursorPosition()
    y = y / track:GetEffectiveScale()
    local mid = (thumb:GetTop() + thumb:GetBottom()) / 2
    bar.ScrollBy((y > mid and -1 or 1) * (sf:GetHeight() or 100) * 0.9)
  end)

  local dragY, dragStart
  thumb:SetScript("OnEnter", function() if not dragY then tint(0.85) end end)
  thumb:SetScript("OnLeave", function() if not dragY then tint(0.6) end end)
  thumb:SetScript("OnMouseDown", function(self)
    local _, y = GetCursorPosition()
    dragY, dragStart = y / self:GetEffectiveScale(), sf:GetVerticalScroll() or 0
    tint(1)
  end)
  thumb:SetScript("OnMouseUp", function(self)
    dragY = nil
    tint(self:IsMouseOver() and 0.85 or 0.6)
  end)
  thumb:SetScript("OnHide", function() dragY = nil; tint(0.6) end)
  thumb:SetScript("OnUpdate", function(self)
    if not dragY then return end
    local _, y = GetCursorPosition()
    y = y / self:GetEffectiveScale()
    local movable = (track:GetHeight() or 0) - (self:GetHeight() or 0)
    if movable <= 0 then return end
    bar.ScrollTo(dragStart + (dragY - y) * range() / movable)
  end)

  sf:HookScript("OnSizeChanged", function() bar.Update() end)
  sf:HookScript("OnScrollRangeChanged", function() bar.Update() end)
  child:HookScript("OnSizeChanged", function() bar.Update() end)
  track:SetScript("OnSizeChanged", function() bar.Update() end)
  bar:Hide()
  return bar
end

-- A scrolling area with a CWC scroll bar. Put content on area.child, laid out from its top; set the
-- child's height to the content height and the bar appears when it is taller than the area.
-- The bar sits inside the area's right edge, in a gutter the content leaves free.
function T.ScrollArea(parent, step)
  local holder = CreateFrame("Frame", nil, parent)
  local sf = CreateFrame("ScrollFrame", nil, holder)
  sf:SetPoint("TOPLEFT")
  sf:SetPoint("BOTTOMRIGHT", -(T.SCROLLBAR_W + 6), 0)
  sf:SetClipsChildren(true)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(1, 1)
  sf:SetScrollChild(child)
  local bar = T.ScrollBar(holder, sf, child, step)
  sf:HookScript("OnSizeChanged", function(self, w)
    child:SetWidth(math.max(1, w or self:GetWidth() or 1))
  end)
  holder.sf, holder.child, holder.bar = sf, child, bar
  -- The content width: the area's width less the scroll bar gutter.
  function holder.InnerWidth() return math.max(1, (holder:GetWidth() or 0) - (T.SCROLLBAR_W + 6)) end
  return holder
end
