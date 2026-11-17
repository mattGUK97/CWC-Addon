local ADDON, CWC = ...
local T = CWC.Theme

local ROW_H = 44
local CARD_W = 224
local KV_VALUE_W = CARD_W - 28 - 84   -- room for a value beside its label; longer values wrap
local KV_STEP, KV_STEP_WRAPPED = 22, 36
local PROF_STEP = 32
local GAP = 14
local HEAD_Y = -44
local MIN_LIST_W = 770

-- Column x positions are fixed; the status column takes whatever width is left.
local COLS = {
  { key = "name", label = "Character", x = 0, w = 200 },
  { key = "prof", label = "Professions", x = 200, w = 128 },
  { key = "race", label = "Race", x = 328, w = 122 },
  { key = "level", label = "Lvl", x = 450, w = 40 },
  { key = "status", label = "Status", x = 490, w = 170 },
  { key = "experience", label = "Experience", x = 660, w = 0 },
}
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
    tex:SetTexture(path)
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

local function sortValue(rec, key)
  if key == "experience" then return EXP_RANK[experienceOf(rec) or ""] or 9 end
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
  r.classIcon:SetPoint("LEFT", COLS[1].x + 12, 0)
  r.name = T.Text(r, "bold", 13)
  r.name:SetPoint("LEFT", COLS[1].x + 48, 0)
  r.name:SetWordWrap(true)
  if r.name.SetMaxLines then r.name:SetMaxLines(2) end

  -- Profession icons only, so the roster shows who has what at a glance. Up to five fit.
  r.profs = {}
  for i = 1, 5 do
    local pf = r:CreateTexture(nil, "ARTWORK")
    pf:SetSize(20, 20)
    pf:SetPoint("LEFT", COLS[2].x + 8 + (i - 1) * 24, 0)
    pf:Hide()
    r.profs[i] = pf
  end

  r.raceIcon = r:CreateTexture(nil, "ARTWORK")
  r.raceIcon:SetSize(18, 18)
  r.raceIcon:SetPoint("LEFT", COLS[3].x + 10, 0)
  r.race = T.Text(r, "body", 13)
  r.race:SetPoint("LEFT", COLS[3].x + 34, 0)

  r.level = T.Text(r, "body", 13)
  r.level:SetPoint("LEFT", COLS[4].x + 12, 0)

  r.status = T.Text(r, "bold", 12)
  r.status:SetPoint("LEFT", COLS[5].x + 12, 0)
  r.status:SetWordWrap(true)
  if r.status.SetMaxLines then r.status:SetMaxLines(2) end

  r.experience = T.Text(r, "body", 12)
  r.experience:SetPoint("LEFT", COLS[6].x + 12, 0)

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

  setIcon(r.classIcon, T.ClassIcon(rec.classFile))
  r.name:SetTextColor(T.ClassColour(rec.classFile))
  r.name:SetWidth(COLS[1].w - 58)
  r.name:SetText(rec.name or "?")

  local profs = profList(rec)
  for i, pf in ipairs(r.profs) do
    local p = profs[i]
    if p then
      pf:SetTexture(T.ProfIcon(p.name))
      pf:Show()
    else
      pf:Hide()
    end
  end

  local raceIcon = knownText(rec.race) and T.RaceIcon(rec.race) or nil
  local hasRaceIcon = raceIcon ~= nil and raceIcon ~= T.fallbackIcon
  setIcon(r.raceIcon, hasRaceIcon and raceIcon or nil)
  r.race:ClearAllPoints()
  r.race:SetPoint("LEFT", COLS[3].x + (hasRaceIcon and 34 or 10), 0)
  T.Fit(r.race, raceText(rec), COLS[3].w - (hasRaceIcon and 42 or 18))

  r.level:SetText(tostring(rec.level or "-"))

  local colour = T.c.cream
  if rec.isMain == true then colour = T.c.gold end
  if rec.isMain == nil then colour = T.c.muted end
  r.status:SetTextColor(colour[1], colour[2], colour[3], 1)
  r.status:SetWidth(COLS[5].w - 22)
  r.status:SetText(statusText(rec))

  local exp = experienceOf(rec)
  local ec = exp and T.c.cream or T.c.muted
  r.experience:SetTextColor(ec[1], ec[2], ec[3], 1)
  T.Fit(r.experience, exp or "-", math.max(60, COLS[6].w - 22))

  r:UpdateStripe()
end

local function updateHeaders()
  for _, col in ipairs(COLS) do
    local b = headers[col.key]
    local arrow = ""
    if sortKey == col.key then arrow = (sortDir == 1) and "  ^" or "  v" end
    b.label:SetText(string.upper(col.label) .. arrow)
  end
end

local function buildHeaders()
  for _, col in ipairs(COLS) do
    local b = CreateFrame("Button", nil, page)
    b:SetSize(col.w > 0 and col.w or 80, 24)
    b:SetPoint("TOPLEFT", col.x, HEAD_Y)
    b.label = T.Text(b, "bold", 11, T.c.muted)
    b.label:SetPoint("LEFT", 10, 0)
    b:SetScript("OnEnter", function() b.label:SetTextColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 1) end)
    b:SetScript("OnLeave", function() b.label:SetTextColor(T.c.muted[1], T.c.muted[2], T.c.muted[3], 1) end)
    b:SetScript("OnClick", function()
      if sortKey == col.key then
        sortDir = -sortDir
      else
        sortKey = col.key
        sortDir = 1
      end
      CWC.RefreshRoster()
    end)
    headers[col.key] = b
  end
end

-- Guild Master only: remove a character received from the guild (not one on this computer).
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

  -- Each profession is a small row frame under the PROFESSIONS heading.
  c.profRows = {}
  for i = 1, PROF_ROWS do
    local pr = {}
    pr.frame = CreateFrame("Frame", nil, c)
    pr.frame:SetSize(CARD_W - 28, 26)
    pr.frame:SetPoint("TOPLEFT", c.profTitle, "BOTTOMLEFT", 0, -(8 + (i - 1) * PROF_STEP))
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

  -- Work out how many profession rows fit above the "Scanned" line at the bottom of the card.
  local nameLines = T.Measure(card.name, rec.name or "?") > CARD_W - 28 and 2 or 1
  local subLines = T.Measure(card.sub, subText) > CARD_W - 28 and 2 or 1
  local titleY = 14 + 116 + 10 + nameLines * 17 + 3 + subLines * 15 + 10 + 1 + off + 8
  local cardH = card:GetHeight() or 0
  local fits = PROF_ROWS
  if cardH > 0 then
    fits = math.floor((cardH - 34 - titleY - 14 - 8 - 26) / PROF_STEP) + 1
    fits = math.max(0, math.min(PROF_ROWS, fits))
  end

  local profs = profList(rec)
  for i, pr in ipairs(card.profRows) do
    local p = profs[i]
    if p and i <= fits then
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
  if #profs == 0 then
    card.profTitle:SetText("PROFESSIONS (NONE RECORDED)")
  elseif #profs > fits then
    card.profTitle:SetText("PROFESSIONS (" .. fits .. " OF " .. #profs .. ", MAKE THE WINDOW TALLER)")
  else
    card.profTitle:SetText("PROFESSIONS")
  end

  if rec.lastScanned then
    card.scanned:SetText("Scanned " .. date("%d %b, %H:%M", rec.lastScanned))
  else
    card.scanned:SetText("")
  end
end

-- Called by the window on resize. contentW is the width available for the whole roster page.
function CWC.LayoutRoster(contentW)
  if not page then return end
  listW = math.max(MIN_LIST_W, contentW - CARD_W - GAP)
  COLS[6].w = listW - COLS[6].x
  scroll:SetWidth(listW)
  child:SetWidth(listW)
  headerRule:SetWidth(listW)
  headers.experience:SetWidth(COLS[6].w)
  for _, r in ipairs(rows) do r:SetWidth(listW) end
  CWC.RefreshRoster()
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

  card = buildCard(page)

  buildHeaders()
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
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, child:GetHeight() - self:GetHeight())
    local target = self:GetVerticalScroll() - delta * ROW_H * 2
    self:SetVerticalScroll(math.min(max, math.max(0, target)))
  end)

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
  updateHeaders()

  local total = 0
  for _ in ipairs(CWC.AllRecords()) do total = total + 1 end
  countText:SetText(#list .. " of " .. total .. " characters")
  emptyText:SetShown(#list == 0)
  if total == 0 then
    emptyText:SetText("Log in on a character to scan it.")
  else
    emptyText:SetText("No characters match your search.")
  end

  fillCard(selected)
end
