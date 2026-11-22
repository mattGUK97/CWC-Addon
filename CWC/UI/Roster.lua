local ADDON, CWC = ...
local T = CWC.Theme

local ROW_H = 44
local CARD_W = 224
local KV_VALUE_W = CARD_W - 28 - 84   -- room for a value beside its label; longer values wrap
local KV_STEP, KV_STEP_WRAPPED = 22, 36
local PROF_STEP = 32
local rosterBar
local GAP = 20 -- leaves room for the list's scroll bar between the list and the card
local HEAD_Y = -44
local MIN_LIST_W = 400

-- Roster columns: default width, the narrowest it may be made, and whether it can be hidden. Each
-- player chooses which columns show and how wide they are (Columns button, or drag a heading's edge);
-- that is saved on their own computer only and never shared with the guild.
local COLUMN_DEFS = {
  { key = "name", label = "Character", w = 200, min = 130, fixed = true },
  { key = "prof", label = "Professions", w = 128, min = 56 },
  { key = "race", label = "Race", w = 122, min = 80 },
  { key = "level", label = "Lvl", w = 44, min = 36 },
  { key = "role", label = "Role", w = 110, min = 84 },
  { key = "status", label = "Status", w = 160, min = 90 },
  { key = "experience", label = "Experience", w = 110, min = 90 },
}
local COLS, colByKey = {}, {}   -- the visible columns, with x and w, rebuilt by applyColumns()
local naturalW = 0              -- total width the visible columns ask for
-- No GUILD row: CWC is guild-only, so everyone on the roster is in Coping with Caffeine.
local CARD_KEYS = { "LEVEL", "ITEM LEVEL", "SPEC", "RANK", "ROLE", "STATUS", "EXPERIENCE" }

-- A race or class is only shown when it is real text. Anything missing reads "Unknown", never a number or "?".
local function knownText(v)
  return type(v) == "string" and v ~= "" and not string.find(v, "^%s*[%d%.%-]+%s*$")
end
local function raceText(rec)
  return knownText(rec.race) and rec.race or "Unknown"
end
local function setIcon(tex, path)
  if path and path ~= T.fallbackIcon then
    T.SetIcon(tex, path)
    tex:Show()
  else
    tex:Hide()
  end
end
-- Experience is set once per player, so this computer's own characters use the account setting.
local function experienceOf(rec)
  if rec.experience then return rec.experience end
  if CWC_Characters and rec.name and CWC_Characters[rec.name] then return CWC_Account.experience end
  return nil
end
local PROF_ROWS = 8

local page, scroll, child, searchBox, placeholder, countText, emptyText, card
local headerRule
local headers, rows = {}, {}
local sortKey, sortDir = "name", 1
local query = ""
local selectedName
local listW = 560

-- Crops a 2:1 banner so it fills a w x h area without stretching.
local function cropBanner(tex, w, h)
  local natH = w * 0.5
  local frac = math.min(1, h / natH)
  local v0 = (1 - frac) / 2
  tex:SetTexCoord(0, 1, v0, 1 - v0)
end

local function profList(rec)
  return rec.professions or {}
end

local function profNames(rec)
  local names = {}
  for _, p in ipairs(profList(rec)) do table.insert(names, p.name) end
  return table.concat(names, ", ")
end

local function statusRank(rec)
  if rec.isMain == true then return 0 end
  if rec.isMain == false then return 1 end
  return 2
end

local function statusText(rec)
  if rec.isMain == true then return "Main" end
  if rec.isMain == false then
    if rec.mainOf then return "Alt of " .. rec.mainOf end
    return "Alt"
  end
  return "Untagged"
end

local EXP_RANK = { Master = 1, Veteran = 2, Experienced = 3, Novice = 4, Newbie = 5 }

local ROLE_RANK = { ["Guild Master"] = 1, ["Officer"] = 2, ["Member"] = 3 }

local function sortValue(rec, key)
  if key == "experience" then return EXP_RANK[experienceOf(rec) or ""] or 9 end
  if key == "role" then return ROLE_RANK[rec.role or ""] or 9 end
  if key == "prof" then return profNames(rec) end
  if key == "race" then return rec.race or "" end
  if key == "level" then return rec.level or 0 end
  if key == "status" then return statusRank(rec) end
  return string.lower(rec.name or "")
end

local function matches(rec, q)
  if q == "" then return true end
  local hay = string.lower(table.concat({
    rec.name or "", rec.className or "", rec.race or "", rec.spec or "", profNames(rec),
  }, " "))
  return string.find(hay, q, 1, true) ~= nil
end

local function visibleList()
  local list = {}
  for _, rec in ipairs(CWC.AllRecords()) do
    if matches(rec, query) then table.insert(list, rec) end
  end
  table.sort(list, function(a, b)
    local va, vb = sortValue(a, sortKey), sortValue(b, sortKey)
    if va == vb then return string.lower(a.name or "") < string.lower(b.name or "") end
    if sortDir == 1 then return va < vb end
    return va > vb
  end)
  return list
end

-- The card shows the chosen character. Defaults to the current character, then the first row.
local function selectedRecord(list)
  if selectedName then
    for _, rec in ipairs(list) do
      if rec.name == selectedName then return rec end
    end
  end
  local me = CWC.PlayerName()
  for _, rec in ipairs(list) do
    if rec.name == me then
      selectedName = me
      return rec
    end
  end
  local first = list[1]
  selectedName = first and first.name or nil
  return first
end

local function showTooltip(row)
  local rec = row.rec
  if not rec or CWC_Account.settings.showTooltips == false then return end
  GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
  local r, g, b = T.ClassColour(rec.classFile)
  GameTooltip:AddLine(rec.name or "?", r, g, b)
  local line = raceText(rec) .. " " .. (knownText(rec.className) and rec.className or "")
  if rec.spec then line = line .. " · " .. rec.spec end
  GameTooltip:AddLine(line, 1, 1, 1)
  local lvl = "Level " .. tostring(rec.level or "unknown")
  if rec.itemLevel then lvl = lvl .. " · item level " .. rec.itemLevel end
  GameTooltip:AddLine(lvl, 0.8, 0.8, 0.8)
  if rec.guild then
    local rank = rec.rank or ""
    if rec.role then rank = rank .. " (" .. rec.role .. ")" end
    GameTooltip:AddLine("<" .. rec.guild .. "> " .. rank, 0.8, 0.8, 0.8)
  end
  GameTooltip:AddLine(" ")
  if #profList(rec) == 0 then
    GameTooltip:AddLine("No professions recorded", 0.6, 0.6, 0.6)
  else
    for _, p in ipairs(profList(rec)) do
      GameTooltip:AddDoubleLine(p.name, tostring(p.skill) .. " / " .. tostring(p.max), 1, 0.85, 0.6, 0.9, 0.9, 0.9)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Status: " .. statusText(rec), 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

local function columnSettings()
  local s = CWC_Account.settings
  s.columns = s.columns or {}
  return s.columns
end

-- Works out which columns show, their widths and x positions. The last visible column stretches to fill
-- any spare space. If the columns ask for more than the list's width, the overflow is clipped and the
-- count line suggests hiding or narrowing a column.
local function applyColumns()
  local saved = columnSettings()
  for i = #COLS, 1, -1 do COLS[i] = nil end
  for k in pairs(colByKey) do colByKey[k] = nil end
  local x = 0
  for _, d in ipairs(COLUMN_DEFS) do
    local cs = saved[d.key] or {}
    if d.fixed or cs.hidden ~= true then
      local w = math.max(d.min, tonumber(cs.w) or d.w)
      local col = { key = d.key, label = d.label, x = x, w = w, base = w, min = d.min }
      table.insert(COLS, col)
      colByKey[d.key] = col
      x = x + w
    end
  end
  naturalW = x
  local last = COLS[#COLS]
  if last and listW > x then last.w = last.w + (listW - x) end
end

local function place(region, key, offset)
  local c = colByKey[key]
  region:ClearAllPoints()
  if c then
    region:SetPoint("LEFT", c.x + offset, 0)
  else
    region:SetPoint("LEFT", -1000, 0)
  end
end

-- Puts a row's cells under their column headings (hidden columns' cells are hidden in fillRow).
local function positionRow(r)
  place(r.classIcon, "name", 12)
  place(r.name, "name", 48)
  for i, pf in ipairs(r.profs) do place(pf, "prof", 8 + (i - 1) * 24) end
  place(r.raceIcon, "race", 10)
  place(r.race, "race", 34)
  place(r.level, "level", 12)
  place(r.role, "role", 12)
  place(r.status, "status", 12)
  place(r.experience, "experience", 12)
end

local function makeRow()
  local r = CreateFrame("Button", nil, child)
  r:SetSize(listW, ROW_H)

  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(0, 0, 0, 0)

  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1)
  r.bar:SetWidth(3)
  r.bar:SetPoint("TOPLEFT")
  r.bar:SetPoint("BOTTOMLEFT")
  r.bar:Hide()

  r.classIcon = r:CreateTexture(nil, "ARTWORK")
  r.classIcon:SetSize(28, 28)
  r.name = T.Text(r, "bold", 13)
  r.name:SetWordWrap(true)
  if r.name.SetMaxLines then r.name:SetMaxLines(2) end

  -- Profession icons only, so the roster shows who has what at a glance. Up to five fit.
  r.profs = {}
  for i = 1, 5 do
    local pf = r:CreateTexture(nil, "ARTWORK")
    pf:SetSize(20, 20)
    pf:Hide()
    r.profs[i] = pf
  end

  r.raceIcon = r:CreateTexture(nil, "ARTWORK")
  r.raceIcon:SetSize(18, 18)
  r.race = T.Text(r, "body", 13)
  r.race:SetWordWrap(true) -- long races such as High Order Skyborne go onto two lines
  if r.race.SetMaxLines then r.race:SetMaxLines(2) end

  r.level = T.Text(r, "body", 13)

  r.role = T.Text(r, "body", 12)
  r.role:SetWordWrap(true)
  if r.role.SetMaxLines then r.role:SetMaxLines(2) end

  r.status = T.Text(r, "bold", 12)
  r.status:SetWordWrap(true)
  if r.status.SetMaxLines then r.status:SetMaxLines(2) end

  r.experience = T.Text(r, "body", 12)
  positionRow(r)

  r.line = r:CreateTexture(nil, "BORDER")
  r.line:SetColorTexture(0.2, 0.16, 0.11, 1)
  r.line:SetHeight(1)
  r.line:SetPoint("BOTTOMLEFT")
  r.line:SetPoint("BOTTOMRIGHT")

  r.UpdateStripe = function(self)
    local selected = self.rec and selectedName and self.rec.name == selectedName
    if selected then
      self.bg:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.12)
      self.bar:Show()
    else
      self.bar:Hide()
      if self.index and self.index % 2 == 0 then
        self.bg:SetColorTexture(1, 1, 1, 0.02)
      else
        self.bg:SetColorTexture(0, 0, 0, 0)
      end
    end
  end

  r:SetScript("OnEnter", function(self)
    if not (self.rec and self.rec.name == selectedName) then
      self.bg:SetColorTexture(1, 1, 1, 0.06)
    end
    showTooltip(self)
  end)
  r:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    self:UpdateStripe()
  end)
  r:SetScript("OnClick", function(self)
    if self.rec then
      selectedName = self.rec.name
      CWC.RefreshRoster()
    end
  end)
  return r
end

local function fillRow(r, rec, index)
  r.rec = rec
  r.index = index
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(index - 1) * ROW_H)
  r:SetWidth(listW)
  r:Show()
  positionRow(r)

  local c = colByKey
  setIcon(r.classIcon, T.ClassIcon(rec.classFile))
  r.name:SetTextColor(T.ClassColour(rec.classFile))
  r.name:SetWidth(c.name.w - 58)
  r.name:SetText(rec.name or "?")

  local profs = profList(rec)
  local fitIcons = c.prof and math.max(0, math.min(#r.profs, math.floor((c.prof.w - 8 + 4) / 24))) or 0
  for i, pf in ipairs(r.profs) do
    local p = profs[i]
    if p and i <= fitIcons then
      pf:SetTexture(T.ProfIcon(p.name))
      pf:Show()
    else
      pf:Hide()
    end
  end

  if c.race then
    local raceIcon = knownText(rec.race) and T.RaceIcon(rec.race) or nil
    local hasRaceIcon = raceIcon ~= nil and raceIcon ~= T.fallbackIcon
    setIcon(r.raceIcon, hasRaceIcon and raceIcon or nil)
    r.race:ClearAllPoints()
    r.race:SetPoint("LEFT", c.race.x + (hasRaceIcon and 34 or 10), 0)
    r.race:SetWidth(c.race.w - (hasRaceIcon and 42 or 18))
    r.race:SetText(raceText(rec))
    r.race:Show()
  else
    r.raceIcon:Hide()
    r.race:Hide()
  end

  r.level:SetShown(c.level ~= nil)
  r.level:SetText(tostring(rec.level or "-"))

  r.role:SetShown(c.role ~= nil)
  if c.role then
    local roleColour = T.c.muted
    if rec.role == "Guild Master" then roleColour = T.c.gold elseif rec.role == "Officer" then roleColour = T.c.cream end
    r.role:SetTextColor(roleColour[1], roleColour[2], roleColour[3], 1)
    r.role:SetWidth(c.role.w - 22)
    r.role:SetText(rec.role or "-")
  end

  r.status:SetShown(c.status ~= nil)
  if c.status then
    local colour = T.c.cream
    if rec.isMain == true then colour = T.c.gold end
    if rec.isMain == nil then colour = T.c.muted end
    r.status:SetTextColor(colour[1], colour[2], colour[3], 1)
    r.status:SetWidth(c.status.w - 22)
    r.status:SetText(statusText(rec))
  end

  r.experience:SetShown(c.experience ~= nil)
  if c.experience then
    local exp = experienceOf(rec)
    local ec = exp and T.c.cream or T.c.muted
    r.experience:SetTextColor(ec[1], ec[2], ec[3], 1)
    r.experience:SetWidth(c.experience.w - 22)
    r.experience:SetText(exp or "-")
  end

  r:UpdateStripe()
end

local headerBar
local lastContentW = 0
local layoutColumns -- defined below; re-lays out the headers and rows

local function updateHeaders()
  for _, d in ipairs(COLUMN_DEFS) do
    local b = headers[d.key]
    local arrow = ""
    if sortKey == d.key then arrow = (sortDir == 1) and "  ^" or "  v" end
    b.label:SetText(string.upper(d.label) .. arrow)
  end
end

-- Dragging a heading's right edge changes that column's width (saved for this player only).
local drag
local function startDrag(key)
  local col = colByKey[key]
  if not col then return end
  local x = GetCursorPosition()
  drag = { key = key, startX = x / UIParent:GetEffectiveScale(), startW = col.base, min = col.min }
end
local function updateDrag()
  if not drag then return end
  local x = GetCursorPosition() / UIParent:GetEffectiveScale()
  local w = math.floor(math.max(drag.min, math.min(500, drag.startW + (x - drag.startX))))
  local saved = columnSettings()
  saved[drag.key] = saved[drag.key] or {}
  if saved[drag.key].w ~= w then
    saved[drag.key].w = w
    layoutColumns()
  end
end

local function buildHeaders()
  headerBar = CreateFrame("Frame", nil, page)
  headerBar:SetPoint("TOPLEFT", 0, HEAD_Y)
  headerBar:SetSize(listW, 24)
  headerBar:SetClipsChildren(true)
  for _, d in ipairs(COLUMN_DEFS) do
    local key = d.key
    local b = CreateFrame("Button", nil, headerBar)
    b:SetHeight(24)
    b.label = T.Text(b, "bold", 11, T.c.muted)
    b.label:SetPoint("LEFT", 10, 0)
    b:SetScript("OnEnter", function() b.label:SetTextColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1) end)
    b:SetScript("OnLeave", function() b.label:SetTextColor(T.c.muted[1], T.c.muted[2], T.c.muted[3], 1) end)
    b:SetScript("OnClick", function()
      if sortKey == key then
        sortDir = -sortDir
      else
        sortKey = key
        sortDir = 1
      end
      CWC.RefreshRoster()
    end)

    -- The drag edge: a thin strip on the heading's right side that shows a gold line on hover.
    local grip = CreateFrame("Frame", nil, b)
    grip:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    grip:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    grip:SetWidth(8)
    grip:EnableMouse(true)
    grip.line = grip:CreateTexture(nil, "OVERLAY")
    grip.line:SetColorTexture(T.c.line[1], T.c.line[2], T.c.line[3], 1)
    grip.line:SetWidth(1)
    grip.line:SetPoint("TOPRIGHT", -3, -5)
    grip.line:SetPoint("BOTTOMRIGHT", -3, 5)
    grip:SetScript("OnEnter", function(self)
      self.line:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1)
      self.line:SetWidth(2)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Drag to resize this column")
      GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(self)
      if not drag then
        self.line:SetColorTexture(T.c.line[1], T.c.line[2], T.c.line[3], 1)
        self.line:SetWidth(1)
      end
      GameTooltip:Hide()
    end)
    grip:SetScript("OnMouseDown", function(self, button)
      if button == "LeftButton" then
        GameTooltip:Hide()
        startDrag(key)
        self:SetScript("OnUpdate", updateDrag)
      end
    end)
    grip:SetScript("OnMouseUp", function(self)
      self:SetScript("OnUpdate", nil)
      drag = nil
      self.line:SetColorTexture(T.c.line[1], T.c.line[2], T.c.line[3], 1)
      self.line:SetWidth(1)
    end)
    b.grip = grip
    headers[key] = b
  end
end

-- Places the headings and rows for the current column settings and list width.
layoutColumns = function()
  if not page then return end
  applyColumns()
  headerBar:SetWidth(listW)
  for _, d in ipairs(COLUMN_DEFS) do
    local b = headers[d.key]
    local col = colByKey[d.key]
    if col then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", headerBar, "TOPLEFT", col.x, 0)
      b:SetWidth(col.w)
      b:Show()
      -- No drag edge on the last column: it already stretches to fill the space.
      b.grip:SetShown(col ~= COLS[#COLS])
    else
      b:Hide()
    end
  end
  CWC.RefreshRoster()
  if CWC.RefreshColumnsPanel then CWC.RefreshColumnsPanel() end
end

local function canRemove(rec)
  if not rec or not rec.name or not rec.remote then return false end
  if CWC_Characters and CWC_Characters[rec.name] then return false end
  local me = CWC_Characters and CWC_Characters[CWC.PlayerName() or ""]
  return me ~= nil and me.role == "Guild Master"
end

-- Right-hand character card: circular portrait, key facts and professions.
local function buildCard(parent)
  local c = T.Card(parent)
  c:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, HEAD_Y)
  c:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  c:SetWidth(CARD_W)

  -- Circular portrait in a gold ring, centred, with space between it and the top of the card.
  local portrait = c:CreateTexture(nil, "ARTWORK")
  portrait:SetSize(116, 116)
  portrait:SetPoint("TOP", c, "TOP", 0, -14)
  portrait:SetTexture(T.portrait)

  c.classIcon = c:CreateTexture(nil, "OVERLAY")
  c.classIcon:SetSize(30, 30)
  c.classIcon:SetPoint("CENTER", portrait, "BOTTOMRIGHT", -12, 12)

  c.name = T.Text(c, "bold", 14, T.c.gold)
  c.name:SetPoint("TOP", portrait, "BOTTOM", 0, -10)
  c.name:SetWidth(CARD_W - 28)
  c.name:SetJustifyH("CENTER")
  c.name:SetWordWrap(true)
  if c.name.SetMaxLines then c.name:SetMaxLines(2) end
  c.sub = T.Text(c, "body", 12, T.c.muted)
  c.sub:SetPoint("TOP", c.name, "BOTTOM", 0, -3)
  c.sub:SetWidth(CARD_W - 28)
  c.sub:SetJustifyH("CENTER")
  c.sub:SetWordWrap(true)
  if c.sub.SetMaxLines then c.sub:SetMaxLines(2) end

  c.rule = T.Rule(c, 0.35)
  c.rule:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -10)
  c.rule:SetPoint("TOPRIGHT", c.sub, "BOTTOMRIGHT", 0, -10)

  c.kv = {}
  for i, key in ipairs(CARD_KEYS) do
    local k = T.Text(c, "bold", 11, T.c.muted)
    k:SetText(key)
    local v = T.Text(c, "body", 12, T.c.cream)
    v:SetWidth(KV_VALUE_W)
    v:SetJustifyH("RIGHT")
    v:SetWordWrap(true)
    if v.SetMaxLines then v:SetMaxLines(2) end
    local off = 10 + (i - 1) * KV_STEP
    k:SetPoint("TOPLEFT", c.rule, "BOTTOMLEFT", 0, -off)
    v:SetPoint("TOPRIGHT", c.rule, "BOTTOMRIGHT", 0, -off)
    c.kv[i] = { k = k, v = v }
  end

  c.profTitle = T.Text(c, "bold", 11, T.c.gold)
  c.profTitle:SetPoint("TOPLEFT", c.rule, "BOTTOMLEFT", 0, -(10 + #CARD_KEYS * KV_STEP + 8))
  c.profTitle:SetText("PROFESSIONS")
  -- Shown on the right of the heading when some professions are below the visible area.
  c.profHint = T.Text(c, "body", 11, T.c.muted)
  c.profHint:SetPoint("BOTTOMRIGHT", c.profTitle, "BOTTOMLEFT", CARD_W - 28, 0)
  c.profHint:SetJustifyH("RIGHT")

  -- Professions sit in their own scroll area between the heading and the "Updated" line, so a short
  -- window never pushes any of them off the card: the mouse wheel scrolls through the rest.
  local ps = CreateFrame("ScrollFrame", nil, c)
  ps:SetPoint("TOPLEFT", c.profTitle, "BOTTOMLEFT", 0, -8)
  ps:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -14, 34)
  ps:SetClipsChildren(true)
  local pc = CreateFrame("Frame", nil, ps)
  pc:SetSize(CARD_W - 28, PROF_STEP)
  ps:SetScrollChild(pc)
  c.profScroll, c.profChild = ps, pc

  c.profBar = T.ScrollBar(c, ps, pc, PROF_STEP)
  c.profBar:ClearAllPoints()
  c.profBar:SetPoint("TOPLEFT", ps, "TOPRIGHT", 2, 0)
  c.profBar:SetPoint("BOTTOMLEFT", ps, "BOTTOMRIGHT", 2, 0)

  function c.UpdateProfScroll()
    c.profBar.Update()
    if c.profBar:IsShown() then
      c.profHint:SetText("Scroll to see all " .. (c.profCount or 0))
    else
      c.profHint:SetText("")
    end
  end
  ps:HookScript("OnSizeChanged", function() c.UpdateProfScroll() end)
  pc:HookScript("OnSizeChanged", function() c.UpdateProfScroll() end)

  -- Each profession is a small row frame inside the scroll area.
  c.profRows = {}
  for i = 1, PROF_ROWS do
    local pr = {}
    pr.frame = CreateFrame("Frame", nil, pc)
    pr.frame:SetSize(CARD_W - 28, 26)
    pr.frame:SetPoint("TOPLEFT", pc, "TOPLEFT", 0, -((i - 1) * PROF_STEP))
    pr.icon = pr.frame:CreateTexture(nil, "ARTWORK")
    pr.icon:SetSize(18, 18)
    pr.icon:SetPoint("TOPLEFT", 0, 0)
    pr.name = T.Text(pr.frame, "body", 12)
    pr.name:SetPoint("TOPLEFT", 26, -1)
    pr.skill = T.Text(pr.frame, "bold", 12, T.c.gold)
    pr.skill:SetPoint("TOPRIGHT", 0, -1)
    pr.skill:SetJustifyH("RIGHT")
    pr.track = pr.frame:CreateTexture(nil, "ARTWORK")
    pr.track:SetColorTexture(1, 1, 1, 0.07)
    pr.track:SetSize(CARD_W - 54, 4)
    pr.track:SetPoint("TOPLEFT", 26, -20)
    pr.fill = pr.frame:CreateTexture(nil, "OVERLAY")
    pr.fill:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1)
    pr.fill:SetHeight(4)
    pr.fill:SetPoint("TOPLEFT", pr.track, "TOPLEFT", 0, 0)
    pr.frame:Hide()
    c.profRows[i] = pr
  end

  c.scanned = T.Text(c, "body", 11, T.c.muted)
  c.scanned:SetPoint("BOTTOMLEFT", 14, 12)

  c.remove = T.Button(c, "Remove", 72, function()
    local rec = c.rec
    if rec and rec.name then
      local name = rec.name
      CWC.ShowDialog({
        title = "Remove from the roster?",
        text = "Remove " .. name .. " from the CWC roster for everyone?\n\n"
          .. "They'll only reappear if they log in with CWC while still in the guild.",
        buttons = {
          { label = "Remove", onClick = function() CWC.RemoveCharacter(name) end },
          { label = CANCEL or "Cancel" },
        },
      })
    end
  end)
  c.remove:SetPoint("BOTTOMRIGHT", -10, 6)
  c.remove:Hide()

  -- Empty state: the site's monster logo, faded, with a line of text.
  c.mark = c:CreateTexture(nil, "ARTWORK")
  c.mark:SetSize(96, 96)
  c.mark:SetPoint("CENTER", 0, 40)
  c.mark:SetTexture(CWC.logoPath)
  c.mark:SetAlpha(0.22)
  c.mark:Hide()

  c.empty = T.Text(c, "body", 12, T.c.muted)
  c.empty:SetPoint("TOP", c.mark, "BOTTOM", 0, -12)
  c.empty:SetWidth(CARD_W - 40)
  c.empty:SetJustifyH("CENTER")
  c.empty:SetWordWrap(true)
  c.empty:Hide()

  return c
end

local function hideProfRow(pr)
  pr.frame:Hide()
end

-- "Updated 2 hours ago": how fresh a character's details are, from the time its owner last scanned it.
local function timeAgo(t)
  local d = time() - t
  if d < 60 then return "just now" end
  local function plural(n, unit) return n .. " " .. unit .. (n == 1 and "" or "s") .. " ago" end
  if d < 3600 then return plural(math.floor(d / 60), "minute") end
  if d < 86400 then return plural(math.floor(d / 3600), "hour") end
  if d < 30 * 86400 then return plural(math.floor(d / 86400), "day") end
  return "on " .. date("%d %b %Y", t)
end

local function fillCard(rec)
  card.rec = rec
  card.remove:SetShown(canRemove(rec))
  if not rec then
    card.classIcon:Hide()
    card.name:SetText("No characters yet")
    card.sub:SetText("")
    for _, kv in ipairs(card.kv) do
      kv.k:SetText("")
      kv.v:SetText("")
    end
    for _, pr in ipairs(card.profRows) do hideProfRow(pr) end
    card.profTitle:Hide()
    card.profHint:SetText("")
    card.profBar:Hide()
    card.scanned:SetText("")
    card.mark:Show()
    card.empty:SetText("Log in on a character to scan it.")
    card.empty:Show()
    return
  end

  card.mark:Hide()
  card.empty:Hide()
  card.profTitle:Show()
  setIcon(card.classIcon, T.ClassIcon(rec.classFile))
  card.name:SetTextColor(T.ClassColour(rec.classFile))
  card.name:SetText(rec.name or "?")
  local classText = knownText(rec.className) and rec.className or ""
  local subText = (knownText(rec.race) or classText ~= "") and (raceText(rec) .. " " .. classText) or "Race and class not received yet"
  card.sub:SetText(subText)

  local values = {
    rec.level and tostring(rec.level) or "-",
    rec.itemLevel and tostring(rec.itemLevel) or "-",
    rec.spec or "-",
    rec.rank or "-",
    rec.role or "-",
    statusText(rec),
    experienceOf(rec) or "-",
  }
  local off = 10
  for i, kv in ipairs(card.kv) do
    local text = tostring(values[i])
    kv.k:SetText(CARD_KEYS[i])
    kv.v:SetText(text)
    kv.k:ClearAllPoints()
    kv.k:SetPoint("TOPLEFT", card.rule, "BOTTOMLEFT", 0, -off)
    kv.v:ClearAllPoints()
    kv.v:SetPoint("TOPRIGHT", card.rule, "BOTTOMRIGHT", 0, -off)
    off = off + ((T.Measure(kv.v, text) > KV_VALUE_W) and KV_STEP_WRAPPED or KV_STEP)
  end
  card.profTitle:ClearAllPoints()
  card.profTitle:SetPoint("TOPLEFT", card.rule, "BOTTOMLEFT", 0, -(off + 8))

  local profs = profList(rec)
  for i, pr in ipairs(card.profRows) do
    local p = profs[i]
    if p then
      pr.icon:SetTexture(T.ProfIcon(p.name))
      T.Fit(pr.name, p.name, CARD_W - 28 - 26 - 66)
      pr.skill:SetText(tostring(p.skill) .. " / " .. tostring(p.max))
      local frac = 0
      if p.max and p.max > 0 then frac = math.min(1, (p.skill or 0) / p.max) end
      pr.fill:SetWidth(math.max(1, (CARD_W - 54) * frac))
      pr.frame:Show()
    else
      hideProfRow(pr)
    end
  end
  local count = math.min(#profs, PROF_ROWS)
  card.profCount = count
  card.profChild:SetHeight(math.max(1, count * PROF_STEP - 6))
  if card.lastProfRec ~= rec then card.profScroll:SetVerticalScroll(0) end
  card.lastProfRec = rec
  card.profTitle:SetText(#profs == 0 and "PROFESSIONS (NONE RECORDED)" or "PROFESSIONS")
  card.UpdateProfScroll()

  if rec.lastScanned then
    card.scanned:SetText("Updated " .. timeAgo(rec.lastScanned))
  else
    card.scanned:SetText("")
  end
end

-- Called by the window on resize. contentW is the width available for the whole roster page.
function CWC.LayoutRoster(contentW)
  if not page then return end
  lastContentW = contentW
  listW = math.max(MIN_LIST_W, contentW - CARD_W - GAP)
  scroll:SetWidth(listW)
  child:SetWidth(listW)
  headerRule:SetWidth(listW)
  for _, r in ipairs(rows) do r:SetWidth(listW) end
  layoutColumns()
end

function CWC.BuildRosterPage(parent)
  page = parent

  searchBox = T.Input(page, 280, 60)
  searchBox:SetPoint("TOPLEFT", 0, 0)
  searchBox:SetTextInsets(30, 8, 0, 0)

  local glass = searchBox:CreateTexture(nil, "OVERLAY")
  glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
  glass:SetSize(14, 14)
  glass:SetPoint("LEFT", searchBox, "LEFT", 10, 0)
  glass:SetVertexColor(T.c.muted[1], T.c.muted[2], T.c.muted[3], 1)

  placeholder = T.Text(searchBox, "body", 13, T.c.muted)
  placeholder:SetPoint("LEFT", searchBox, "LEFT", 30, 0)
  placeholder:SetText("Search name, class, race or profession")
  searchBox:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    placeholder:SetShown(text == "")
    query = string.lower(strtrim(text))
    CWC.RefreshRoster()
  end)

  countText = T.Text(page, "body", 12, T.c.muted)
  countText:SetPoint("LEFT", searchBox, "RIGHT", 14, 0)

  local rescan = T.Button(page, "Rescan character", 150, function()
    CWC.ScanCharacter()
    CWC.RefreshRoster()
    if CWC.RefreshSidebar then CWC.RefreshSidebar() end
    CWC.Print("Character rescanned.")
  end)
  rescan:SetPoint("TOPRIGHT", 0, 0)

  local columnsBtn = T.Button(page, "Columns", 100, function() CWC.ToggleColumnsPanel() end)
  columnsBtn:SetPoint("RIGHT", rescan, "LEFT", -8, 0)
  page.columnsBtn = columnsBtn

  card = buildCard(page)

  buildHeaders()
  applyColumns()
  headerRule = T.Rule(page, 0.3)
  headerRule:SetPoint("TOPLEFT", 0, HEAD_Y - 26)
  headerRule:SetHeight(1)

  scroll = CreateFrame("ScrollFrame", nil, page)
  scroll:SetPoint("TOPLEFT", 0, HEAD_Y - 30)
  scroll:SetPoint("BOTTOMLEFT", 0, 0)
  scroll:SetWidth(listW)
  scroll:EnableMouseWheel(true)
  child = CreateFrame("Frame", nil, scroll)
  child:SetSize(listW, 10)
  scroll:SetScrollChild(child)
  scroll:SetClipsChildren(true)
  rosterBar = T.ScrollBar(page, scroll, child, ROW_H * 2)

  emptyText = T.Text(page, "body", 14, T.c.muted)
  emptyText:SetPoint("TOP", scroll, "TOP", 0, -40)
  emptyText:SetJustifyH("CENTER")
  emptyText:Hide()
end

function CWC.RefreshRoster()
  if not page then return end
  local list = visibleList()
  local selected = selectedRecord(list)

  for i, rec in ipairs(list) do
    rows[i] = rows[i] or makeRow()
    fillRow(rows[i], rec, i)
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  child:SetHeight(math.max(1, #list * ROW_H))
  if rosterBar then rosterBar.Update() end
  updateHeaders()

  local total = 0
  for _ in ipairs(CWC.AllRecords()) do total = total + 1 end
  local note = ""
  if naturalW > listW then note = "   ·   Some columns don't fit: use Columns to hide or narrow them" end
  countText:SetText(#list .. " of " .. total .. " characters" .. note)
  emptyText:SetShown(#list == 0)
  if total == 0 then
    emptyText:SetText("Log in on a character to scan it.")
  else
    emptyText:SetText("No characters match your search.")
  end

  fillCard(selected)
end

-- Columns panel ---------------------------------------------------------------------------------------
-- Opened from the Columns button on the Roster page. Choices are saved on this computer only.
local columnsPanel

local function buildColumnsPanel()
  local p = T.Panel(page, T.c.bg, T.c.line)
  columnsPanel = p
  p:SetFrameStrata("DIALOG")
  p:SetSize(330, 74 + #COLUMN_DEFS * 32 + 54)
  p:SetPoint("TOPRIGHT", page.columnsBtn, "BOTTOMRIGHT", 0, -6)
  p:EnableMouse(true)
  p:Hide()

  local title = T.Text(p, "heading", 15, T.c.gold)
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("Roster columns")
  local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() p:Hide() end)
  local hint = T.Text(p, "body", 11, T.c.muted)
  hint:SetPoint("TOPLEFT", 16, -38)
  hint:SetWidth(298)
  hint:SetText("Tick to show a column. Use - and + to change its width, or drag the edge of a column heading.")

  p.rows = {}
  for i, d in ipairs(COLUMN_DEFS) do
    local y = -74 - (i - 1) * 32
    local row = {}
    row.check = T.Check(p, d.label, function(self)
      local saved = columnSettings()
      saved[d.key] = saved[d.key] or {}
      saved[d.key].hidden = not self:GetChecked()
      layoutColumns()
    end)
    row.check:SetPoint("TOPLEFT", 12, y)
    if d.fixed then
      row.check:SetChecked(true)
      row.check:Disable()
      row.check.label:SetText(d.label .. "  (always shown)")
    end
    local function nudge(delta)
      local saved = columnSettings()
      saved[d.key] = saved[d.key] or {}
      local w = tonumber(saved[d.key].w) or d.w
      saved[d.key].w = math.max(d.min, math.min(500, w + delta))
      layoutColumns()
    end
    row.plus = T.Button(p, "+", 28, function() nudge(10) end)
    row.plus:SetHeight(24)
    row.plus:SetPoint("TOPRIGHT", -14, y)
    row.width = T.Text(p, "body", 12, T.c.cream)
    row.width:SetPoint("RIGHT", row.plus, "LEFT", -8, 0)
    row.width:SetWidth(52)
    row.width:SetJustifyH("CENTER")
    row.minus = T.Button(p, "-", 28, function() nudge(-10) end)
    row.minus:SetHeight(24)
    row.minus:SetPoint("RIGHT", row.width, "LEFT", -8, 0)
    p.rows[d.key] = row
  end

  local reset = T.Button(p, "Reset to default", 150, function()
    CWC_Account.settings.columns = {}
    layoutColumns()
  end)
  reset:SetPoint("BOTTOMLEFT", 16, 14)
  local saveNote = T.Text(p, "body", 11, T.c.muted)
  saveNote:SetPoint("LEFT", reset, "RIGHT", 12, 0)
  saveNote:SetText("Saved for you only")
end

function CWC.RefreshColumnsPanel()
  if not columnsPanel then return end
  local saved = columnSettings()
  for _, d in ipairs(COLUMN_DEFS) do
    local row = columnsPanel.rows[d.key]
    local cs = saved[d.key] or {}
    local shown = d.fixed or cs.hidden ~= true
    row.check:SetChecked(shown)
    local w = math.max(d.min, tonumber(cs.w) or d.w)
    row.width:SetText(w .. " px")
    row.minus:SetShown(shown)
    row.plus:SetShown(shown)
    row.width:SetShown(shown)
  end
end

function CWC.ToggleColumnsPanel()
  if not page then return end
  if not columnsPanel then buildColumnsPanel() end
  if columnsPanel:IsShown() then
    columnsPanel:Hide()
  else
    CWC.RefreshColumnsPanel()
    columnsPanel:Show()
    columnsPanel:Raise()
  end
end
