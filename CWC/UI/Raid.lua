local ADDON, CWC = ...
local T = CWC.Theme

-- Raid page: the WoW: Forever raids, their sizes, when they open, and whether you (and your guild
-- mates) are attuned. Sign-ups and raid nights are organised on the guild Discord.

local GREEN = { 0.5, 0.85, 0.5, 1 }
local AMBER = { 1, 0.72, 0.3, 1 }
local RED = { 1, 0.45, 0.4, 1 }
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December" }
local TICK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local WAIT = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local CROSS = "Interface\\RaidFrame\\ReadyCheck-NotReady"

local ui = { cards = {} }
local selected

local function raidByKey(key)
  for _, r in ipairs(CWC.RAIDS) do
    if r.key == key then return r end
  end
  return CWC.RAIDS[1]
end

local function openText(raid)
  local o = raid.opens
  if CWC.RaidOpen(raid) then return "Open now", GREEN end
  return "Opens " .. o[3] .. " " .. MONTHS[o[2]] .. " " .. o[1], T.c.gold
end

-- Gold heading with a rule underneath, at the top of a card.
local function cardTitle(card, text)
  local t = T.Text(card, "bold", 11, T.c.gold)
  t:SetPoint("TOPLEFT", 16, -14)
  t:SetText(string.upper(text))
  local r = T.Rule(card, 0.3)
  r:SetPoint("TOPLEFT", 16, -34)
  r:SetPoint("TOPRIGHT", -16, -34)
  return t
end

-- A badge sized to its text, so a label is never cut off.
local function sizedBadge(b, text, colour)
  b:SetLabel(text, colour)
  local w = T.Measure(b.text, text)
  if not w or w <= 0 then w = #text * 7.5 end -- the font isn't measurable yet: a generous estimate
  b:SetWidth(math.max(40, w + 18))
end

-- A scrolling body for a card. Everything inside is laid out on body.child, top to bottom, and
-- body.Finish(lastElement) sets the scroll height once the layout has settled.
local function scrollBody(card, top)
  local sf = CreateFrame("ScrollFrame", nil, card)
  sf:SetPoint("TOPLEFT", 16, top)
  sf:SetPoint("BOTTOMRIGHT", -20, 12)
  sf:SetClipsChildren(true)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(1, 1)
  sf:SetScrollChild(child)
  local bar = card:CreateTexture(nil, "OVERLAY")
  bar:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.55)
  bar:SetWidth(3)
  bar:Hide()
  local body = { sf = sf, child = child }
  local function range() return math.max(0, child:GetHeight() - sf:GetHeight()) end
  function body.UpdateBar()
    local r, viewH = range(), sf:GetHeight()
    if sf:GetVerticalScroll() > r then sf:SetVerticalScroll(r) end
    if r > 0 and viewH > 0 then
      local h = math.max(16, viewH * viewH / child:GetHeight())
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 8, -(viewH - h) * (sf:GetVerticalScroll() / r))
      bar:SetHeight(h)
      bar:Show()
    else
      bar:Hide()
    end
  end
  function body.Finish(last)
    child:SetWidth(math.max(1, sf:GetWidth() or 1))
    C_Timer.After(0, function()
      local topY, bottomY = child:GetTop(), last and last:GetBottom()
      if topY and bottomY then child:SetHeight(math.max(1, topY - bottomY + 8)) end
      body.UpdateBar()
    end)
  end
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, math.min(range(), self:GetVerticalScroll() - delta * 40)))
    body.UpdateBar()
  end)
  sf:SetScript("OnSizeChanged", function(self, w)
    child:SetWidth(math.max(1, w or self:GetWidth()))
    body.UpdateBar()
    if body.onResize then body.onResize() end
  end)
  return body
end

-- Font strings are reused between refreshes: pool(owner, key) hands out the next one of that kind.
local function pool(owner)
  local p = { items = {}, used = {} }
  function p.Get(kind, which, size, colour)
    p.items[kind] = p.items[kind] or {}
    p.used[kind] = (p.used[kind] or 0) + 1
    local fs = p.items[kind][p.used[kind]]
    if not fs then
      if kind == "tex" then
        fs = owner:CreateTexture(nil, which or "ARTWORK")
      else
        fs = T.Text(owner, which, size, colour)
        fs:SetWordWrap(true)
      end
      p.items[kind][p.used[kind]] = fs
    end
    if kind == "tex" then
      fs:SetDrawLayer(which or "ARTWORK")
      fs:SetAlpha(1)
    else
      T.Font(fs, which, size)
      local c = colour or T.c.cream
      fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
      fs:SetJustifyH("LEFT")
    end
    fs:ClearAllPoints()
    fs:Show()
    return fs
  end
  function p.Reset()
    for kind, list in pairs(p.items) do
      for _, item in ipairs(list) do
        item:Hide()
        if item.SetTexture and kind == "tex" then item:SetTexture(nil) end
      end
    end
    p.used = {}
  end
  return p
end

-- Lays text out down the page: each line sits under the previous one and wraps to the full width.
local function stacker(body, P)
  local s = { last = nil }
  function s.Add(text, which, size, colour, gap, indent)
    local fs = P.Get("text", which, size, colour)
    fs:SetText(text)
    if s.last then
      fs:SetPoint("TOP", s.last, "BOTTOM", 0, -(gap or 6))
    else
      fs:SetPoint("TOP", body.child, "TOP", 0, -(gap or 0))
    end
    fs:SetPoint("LEFT", body.child, "LEFT", indent or 0, 0)
    fs:SetPoint("RIGHT", body.child, "RIGHT", 0, 0)
    s.last = fs
    return fs
  end
  return s
end

-- Selectable raid cards across the top.
local function makeRaidCard(parent, raid)
  local c = T.Card(parent)
  c:EnableMouse(true)
  c.raid = raid
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(44, 44)
  c.icon:SetPoint("TOPLEFT", 14, -14)
  c.icon:SetTexture(raid.icon or T.fallbackIcon)
  c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  c.name = T.Text(c, "heading", 15, T.c.gold)
  c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, -2)
  c.name:SetPoint("RIGHT", c, "RIGHT", -12, 0)
  c.name:SetWordWrap(true)
  c.name:SetText(raid.name)
  c.facts = T.Text(c, "body", 12, T.c.muted)
  c.facts:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
  c.facts:SetPoint("RIGHT", c, "RIGHT", -12, 0)
  c.facts:SetWordWrap(true)
  c.facts:SetText(raid.size .. " players  ·  " .. raid.bosses .. (raid.bosses == 1 and " boss" or " bosses") .. "  ·  Level " .. raid.level)
  c.open = T.Badge(c, T.c.gold)
  c.open:SetPoint("BOTTOMLEFT", 14, 12)
  c.attune = T.Badge(c, T.c.gold)
  c.attune:SetPoint("LEFT", c.open, "RIGHT", 8, 0)
  c.glow = c:CreateTexture(nil, "BORDER")
  c.glow:SetAllPoints()
  c.glow:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.08)
  c.glow:Hide()
  c:SetScript("OnEnter", function(self)
    if selected ~= raid.key then self:SetBackdropBorderColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.6) end
  end)
  c:SetScript("OnLeave", function(self)
    if selected ~= raid.key then self:SetBackdropBorderColor(T.c.line[1], T.c.line[2], T.c.line[3], 1) end
  end)
  c:SetScript("OnMouseUp", function()
    selected = raid.key
    CWC_Account.settings.raidSelected = raid.key
    CWC.RefreshRaid()
  end)
  return c
end

local function layoutCards()
  local w = ui.row:GetWidth()
  if not w or w <= 0 then return end
  local n, gap = #ui.cards, 12
  local cw = (w - gap * (n - 1)) / n
  for i, c in ipairs(ui.cards) do
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", ui.row, "TOPLEFT", (i - 1) * (cw + gap), 0)
    c:SetSize(cw, ui.row:GetHeight())
  end
  local dw = ui.detail:GetWidth()
  if dw and dw > 0 then
    local leftW = math.floor(dw * 0.30)
    local rightW = math.floor(dw * 0.27)
    ui.about:SetWidth(leftW)
    ui.guild:SetWidth(rightW)
  end
end

-- What this character's attunement looks like on a raid card and in the middle panel.
local function attuneBadge(raid)
  if not raid.attunement then return "No attunement", T.c.muted end
  local p = CWC.AttuneProgress(raid.attunement)
  if not p then return "Unknown", T.c.muted end
  if p.attuned then return "Attuned", GREEN end
  if p.done == 0 then return "Not attuned", RED end
  return "Step " .. p.current .. " of " .. p.total, AMBER
end

local function fillAbout(raid)
  local P, body = ui.aboutPool, ui.aboutBody
  P.Reset()
  local s = stacker(body, P)
  local function row(k, v, first)
    local key = s.Add(string.upper(k), "bold", 10, T.c.muted, first and 0 or 12)
    local val = s.Add(v, "body", 13, T.c.cream, 3)
    return key, val
  end
  row("Players", raid.size .. "-player raid", true)
  row("Bosses", tostring(raid.bosses))
  row("Level", tostring(raid.level))
  local ot = openText(raid)
  row("Opens", ot == "Open now" and "Open now (opened " .. raid.opens[3] .. " " .. MONTHS[raid.opens[2]] .. ")" or ot:gsub("^Opens ", ""))
  row("Where", raid.location)
  if raid.attunement then
    local chain = CWC.ATTUNEMENTS[raid.attunement]
    row("Entry", "Every raider needs the " .. chain.name .. " in their bags. It doesn't need to be equipped.")
  else
    row("Entry", "No attunement. Anyone level " .. raid.level .. " can enter.")
  end
  s.Add(raid.about, "body", 13, T.c.muted, 16)
  body.Finish(s.last)
end

local function fillMine(raid)
  local P, body = ui.minePool, ui.mineBody
  P.Reset()
  local s = stacker(body, P)
  local level = UnitLevel("player") or 0

  if not raid.attunement then
    s.Add("No attunement needed", "heading", 16, GREEN)
    if level >= raid.level then
      s.Add("You're level " .. level .. ", so you can join this raid as soon as it opens.", "body", 13, T.c.cream, 8)
    else
      local togo = raid.level - level
      s.Add("You're level " .. level .. ". Reach level " .. raid.level .. " (" .. togo .. (togo == 1 and " level" or " levels") .. " to go) to join this raid.", "body", 13, T.c.cream, 8)
    end
    s.Add("Raid sign-ups, roles and raid nights are organised on the guild Discord.", "body", 12, T.c.muted, 14)
    body.Finish(s.last)
    return
  end

  local chain = CWC.ATTUNEMENTS[raid.attunement]
  local p = CWC.AttuneProgress(raid.attunement)

  -- Headline status with a progress bar.
  local head
  if p.attuned then
    head = s.Add("You're attuned", "heading", 16, GREEN)
  elseif p.done == 0 then
    head = s.Add("Not attuned yet", "heading", 16, RED)
  else
    head = s.Add("Attunement in progress", "heading", 16, AMBER)
  end
  local sub = s.Add(p.done .. " of " .. p.total .. " quests done", "body", 12, T.c.muted, 4)
  local track = P.Get("tex", "ARTWORK")
  track:SetColorTexture(1, 1, 1, 0.08)
  track:SetHeight(6)
  track:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8)
  track:SetPoint("RIGHT", body.child, "RIGHT", 0, 0)
  local fill = P.Get("tex", "OVERLAY")
  local col = p.attuned and GREEN or (p.done == 0 and RED or AMBER)
  fill:SetColorTexture(col[1], col[2], col[3], 1)
  fill:SetHeight(6)
  fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
  local frac = p.done / p.total
  fill:SetWidth(math.max(1, ((body.sf:GetWidth() or 300)) * frac))
  if frac <= 0 then fill:Hide() end
  s.last = track

  if p.attuned then
    local ok, n = pcall(function()
      if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(chain.item, false) end
      return GetItemCount(chain.item, false)
    end)
    local bags = not ok or (tonumber(n) or 0) > 0
    if bags then
      s.Add("Your " .. chain.name .. " is in your bags, so you're ready for Onyxia's Lair.", "body", 13, T.c.cream, 14)
    else
      s.Add("Your " .. chain.name .. " isn't in your bags. Take it out of your bank before the raid: you need it in your bags to enter.", "body", 13, AMBER, 14)
    end
  else
    -- The next step, in a highlighted box.
    local step = chain.steps[p.current]
    local label = s.Add("NEXT STEP", "bold", 10, T.c.gold, 22, 14)
    local title = s.Add(p.current .. ". " .. step.title, "bold", 14, T.c.cream, 6, 14)
    if p.inLog then
      s.Add("In your quest log", "bold", 11, GREEN, 3, 14)
    elseif p.current == 1 then
      s.Add("Start at level " .. chain.startLevel .. " or higher.", "body", 12, T.c.muted, 3, 14)
    end
    s.Add("Go to: " .. step.who, "body", 13, T.c.cream, 8, 14)
    s.Add("Where: " .. step.where, "body", 13, T.c.cream, 3, 14)
    local last = s.Add(step.text, "body", 13, T.c.muted, 8, 14)
    local box = P.Get("tex", "BACKGROUND")
    box:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.07)
    box:SetPoint("TOPLEFT", label, "TOPLEFT", -14, 12)
    box:SetPoint("BOTTOM", last, "BOTTOM", 0, -12)
    box:SetPoint("RIGHT", body.child, "RIGHT", 0, 0)
    local edge = P.Get("tex", "BORDER")
    edge:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.9)
    edge:SetWidth(3)
    edge:SetPoint("TOPLEFT", box, "TOPLEFT")
    edge:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT")
    -- Keeps the space under the box when the next line is added.
    local spacer = P.Get("tex", "ARTWORK")
    spacer:SetColorTexture(0, 0, 0, 0)
    spacer:SetHeight(1)
    spacer:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, 0)
    spacer:SetPoint("RIGHT", body.child, "RIGHT", 0, 0)
    s.last = spacer
  end

  -- Every step, ticked off as it's done.
  s.Add("ALL " .. p.total .. " STEPS", "bold", 10, T.c.gold, 22)
  for i, step in ipairs(chain.steps) do
    local done, current = i <= p.done, i == p.current
    local colour = current and T.c.gold or (done and T.c.muted or T.c.cream)
    local t = s.Add(i .. ". " .. step.title, "bold", 13, colour, i == 1 and 10 or 12, 26)
    local icon = P.Get("tex", "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOP", t, "TOP", 0, 1)
    icon:SetPoint("LEFT", body.child, "LEFT", 2, 0)
    if done then
      icon:SetTexture(TICK)
    elseif current then
      icon:SetTexture(WAIT)
    else
      icon:SetTexture(nil)
      icon:SetColorTexture(1, 1, 1, 0.12)
      icon:SetSize(8, 8)
      icon:ClearAllPoints()
      icon:SetPoint("TOP", t, "TOP", 0, -4)
      icon:SetPoint("LEFT", body.child, "LEFT", 6, 0)
    end
    s.Add(step.who .. "  ·  " .. step.where, "body", 12, T.c.muted, 2, 26)
  end
  body.Finish(s.last)
end

local function fillGuild(raid)
  local P, body = ui.guildPool, ui.guildBody
  P.Reset()
  local s = stacker(body, P)
  local list = {}
  for _, rec in ipairs(CWC.AllRecords and CWC.AllRecords() or {}) do
    if rec.name then
      if raid.attunement then
        local n = type(rec.attune) == "table" and tonumber(rec.attune[raid.attunement])
        if n and n > 0 then table.insert(list, { rec = rec, n = n }) end
      elseif (tonumber(rec.level) or 0) >= raid.level then
        table.insert(list, { rec = rec, n = 0 })
      end
    end
  end
  table.sort(list, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return (a.rec.name or "") < (b.rec.name or "")
  end)

  if raid.attunement then
    local total = #CWC.ATTUNEMENTS[raid.attunement].steps
    local attuned = 0
    for _, e in ipairs(list) do if e.n >= total then attuned = attuned + 1 end end
    ui.guildTitle:SetText("GUILD ATTUNEMENT")
    s.Add(attuned .. " attuned  ·  " .. (#list - attuned) .. " working on it", "bold", 13, T.c.cream)
    s.Add("Shows guild mates on CWC 0.9.7 or newer, once they log in.", "body", 12, T.c.muted, 4)
    for i, e in ipairs(list) do
      local done = e.n >= total
      local name = s.Add(e.rec.name, "bold", 13, nil, i == 1 and 14 or 8)
      name:SetTextColor(T.ClassColour(e.rec.classFile))
      name:SetPoint("RIGHT", body.child, "RIGHT", -96, 0)
      local st = P.Get("text", "bold", 12, done and GREEN or AMBER)
      st:SetJustifyH("RIGHT")
      st:SetPoint("TOP", name, "TOP", 0, 0)
      st:SetPoint("RIGHT", body.child, "RIGHT", 0, 0)
      st:SetWidth(92)
      st:SetText(done and "Attuned" or (e.n .. " of " .. total))
    end
    if #list == 0 then
      s.Add("Nobody has started yet, or guild mates haven't updated CWC.", "body", 13, T.c.muted, 14)
    end
  else
    ui.guildTitle:SetText("LEVEL " .. raid.level .. " IN THE GUILD")
    s.Add(#list .. (#list == 1 and " character" or " characters") .. " at level " .. raid.level, "bold", 13, T.c.cream)
    s.Add("From the CWC roster: guild mates who have logged in with CWC.", "body", 12, T.c.muted, 4)
    for i, e in ipairs(list) do
      local name = s.Add(e.rec.name, "bold", 13, nil, i == 1 and 14 or 8)
      name:SetTextColor(T.ClassColour(e.rec.classFile))
    end
  end
  body.Finish(s.last)
end

function CWC.RefreshRaid()
  if not ui.page or not ui.page:IsVisible() then return end
  selected = selected or CWC_Account.settings.raidSelected or "onyxia"
  local raid = raidByKey(selected)
  selected = raid.key
  for _, c in ipairs(ui.cards) do
    local on = c.raid.key == selected
    c.glow:SetShown(on)
    local b = on and T.c.gold or T.c.line
    c:SetBackdropBorderColor(b[1], b[2], b[3], 1)
    local ot, oc = openText(c.raid)
    sizedBadge(c.open, string.upper(ot), oc)
    local at, ac = attuneBadge(c.raid)
    sizedBadge(c.attune, string.upper(at), ac)
  end
  ui.mineTitle:SetText(raid.attunement and "YOUR ATTUNEMENT" or "CAN YOU JOIN?")
  fillAbout(raid)
  fillMine(raid)
  fillGuild(raid)
end

function CWC.BuildRaidPage(page)
  ui.page = page
  local h = T.Text(page, "heading", 20, T.c.gold)
  h:SetPoint("TOPLEFT", 0, 0)
  h:SetText("Raids")
  local d = T.Text(page, "body", 13, T.c.muted)
  d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
  d:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  d:SetWordWrap(true)
  d:SetText("The WoW: Forever raids, how many players each needs, and whether you can get in. Sign-ups, roles and raid nights are on the guild Discord.")

  ui.row = CreateFrame("Frame", nil, page)
  ui.row:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  ui.row:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  ui.row:SetHeight(104)
  for i, raid in ipairs(CWC.RAIDS) do ui.cards[i] = makeRaidCard(ui.row, raid) end

  ui.detail = CreateFrame("Frame", nil, page)
  ui.detail:SetPoint("TOPLEFT", ui.row, "BOTTOMLEFT", 0, -12)
  ui.detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)

  ui.about = T.Card(ui.detail)
  ui.about:SetPoint("TOPLEFT")
  ui.about:SetPoint("BOTTOMLEFT")
  cardTitle(ui.about, "About this raid")
  ui.aboutBody = scrollBody(ui.about, -46)
  ui.aboutPool = pool(ui.aboutBody.child)

  ui.guild = T.Card(ui.detail)
  ui.guild:SetPoint("TOPRIGHT")
  ui.guild:SetPoint("BOTTOMRIGHT")
  ui.guildTitle = cardTitle(ui.guild, "Guild")
  ui.guildBody = scrollBody(ui.guild, -46)
  ui.guildPool = pool(ui.guildBody.child)

  ui.mine = T.Card(ui.detail)
  ui.mine:SetPoint("TOPLEFT", ui.about, "TOPRIGHT", 12, 0)
  ui.mine:SetPoint("BOTTOMRIGHT", ui.guild, "BOTTOMLEFT", -12, 0)
  ui.mineTitle = cardTitle(ui.mine, "Your attunement")
  ui.mineBody = scrollBody(ui.mine, -46)
  ui.minePool = pool(ui.mineBody.child)

  -- Widths change with the window, so the text is laid out again after a resize.
  local pending = false
  local function relayout()
    layoutCards()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function()
      pending = false
      CWC.RefreshRaid()
    end)
  end
  page:SetScript("OnSizeChanged", relayout)
  ui.row:SetScript("OnSizeChanged", layoutCards)
  ui.detail:SetScript("OnSizeChanged", layoutCards)
  page:SetScript("OnShow", function()
    layoutCards()
    CWC.RefreshRaid()
    -- Sizes are only known once the page has been drawn, so the layout runs again a moment later.
    C_Timer.After(0.05, function()
      layoutCards()
      CWC.RefreshRaid()
    end)
  end)
end
