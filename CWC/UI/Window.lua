local ADDON, CWC = ...
local T = CWC.Theme

-- Wide enough for every roster column plus the character card, so nothing has to be cut off.
local MIN_W, MIN_H = 1280, 640
local MAX_W, MAX_H = 1700, 950
local DEF_W, DEF_H = 1300, 760
local HEADER_H, FOOTER_H, SIDE_W, PAD = 96, 30, 212, 14
local BANNER_H = 52
local CONTENT_X = SIDE_W + PAD
local ROW_GAP = 16
local REQUEST_KEYS = { kos = true, blacklist = true }

-- Icons come from the game's built-in icon set. A missing path shows a question mark rather than failing.
local TABS = {
  { key = "roster", label = "Roster", icon = "Interface\\Icons\\INV_Misc_GroupLooking" },
  { key = "kos", label = "Kill on Sight", icon = "Interface\\Icons\\INV_Sword_04" },
  { key = "blacklist", label = "Blacklist", icon = "Interface\\Icons\\INV_Misc_Note_01" },
  { key = "raid", label = "Raid", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
  { key = "stats", label = "Statistics", icon = "Interface\\Icons\\INV_Misc_Book_09" },
  { key = "settings", label = "Settings", icon = "Interface\\Icons\\INV_Gizmo_01" },
}
local TAB_LABEL, OPEN_ORDER = {}, {}
for _, tab in ipairs(TABS) do
  TAB_LABEL[tab.key] = tab.label
  table.insert(OPEN_ORDER, tab.key)
end

local window, content, side
local navItems, pages = {}, {}
local statsUI = { tiles = {}, cols = {} }
local settingsUI = {}
local listUI = {}

local function cropBanner(tex, w, h)
  local natH = w * 0.5
  local frac = math.min(1, h / natH)
  local v0 = (1 - frac) / 2
  tex:SetTexCoord(0, 1, v0, 1 - v0)
end

local function requestStore(key)
  return CWC.RequestStore(key)
end

local function canApprove()
  local rec = CWC_Characters and CWC_Characters[CWC.PlayerName() or ""]
  return rec ~= nil and (rec.role == "Guild Master" or rec.role == "Officer")
end

local APPROVED = { 0.5, 0.85, 0.5 }

local ROW_H, ROW_STEP = 72, 78

local function makeListRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(ROW_H)
  r:EnableMouse(true)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(1, 1, 1, 0.03)

  r.faction = r:CreateTexture(nil, "ARTWORK")
  r.faction:SetSize(22, 22)
  r.faction:SetPoint("LEFT", r, "LEFT", 12, 0)
  r.faction:Hide()
  r.name = T.Text(r, "bold", 13, T.c.cream)
  r.name:SetPoint("TOPLEFT", 42, -8)
  r.reason = T.Text(r, "body", 12, T.c.cream)
  r.reason:SetWordWrap(true)
  r.reason:SetJustifyV("TOP")
  if r.reason.SetMaxLines then r.reason:SetMaxLines(2) end
  r.meta = T.Text(r, "body", 11, T.c.muted)
  r.meta:SetPoint("BOTTOMLEFT", 42, 8)

  -- Hover shows the whole reason, however long it is.
  r:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:AddLine(self.item.name or "?", 1, 1, 1)
    GameTooltip:AddLine(self.item.reason or "", T.c.cream[1], T.c.cream[2], T.c.cream[3], true)
    GameTooltip:AddLine(self.metaText or "", T.c.muted[1], T.c.muted[2], T.c.muted[3], true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)

  r.approve = T.Button(r, "Approve", 96, nil, true)
  r.approve:SetPoint("RIGHT", r, "RIGHT", -112, 0)

  r.deny = T.Button(r, "Deny", 80, nil, false)
  r.deny:SetPoint("RIGHT", r, "RIGHT", -216, 0)

  -- Guild Master and Officers: remove an approved entry.
  r.remove = T.Button(r, "Remove", 96, nil, false)
  r.remove:SetPoint("RIGHT", r, "RIGHT", -112, 0)

  r.badge = T.Badge(r, T.c.gold)
  r.badge:SetSize(92, 18)
  r.badge:SetPoint("RIGHT", r, "RIGHT", -10, 0)
  return r
end

local FACTION_ICONS = {
  Horde = "Interface\\PVPFrame\\PVP-Currency-Horde",
  Alliance = "Interface\\PVPFrame\\PVP-Currency-Alliance",
}

-- The guild is Alliance-only: Kill on Sight targets are Horde, and blacklisted players are Alliance.
local LIST_FACTION = { kos = "Horde", blacklist = "Alliance" }

local function fillListRow(r, item, key)
  r.item = item
  r.name:SetText(item.name)
  local faction = item.faction or LIST_FACTION[key]
  local icon = faction and FACTION_ICONS[faction]
  if icon then
    r.faction:SetTexture(icon)
    r.faction:Show()
  else
    r.faction:Hide()
  end
  local approved = item.status == "approved"
  local officer = canApprove()
  local reserve = 120
  if officer then reserve = approved and 224 or 320 end
  r.reason:ClearAllPoints()
  r.reason:SetPoint("TOPLEFT", 42, -28)
  r.reason:SetPoint("RIGHT", r, "RIGHT", -reserve, 0)
  r.reason:SetText(item.reason or "")
  local when = item.date and date("%d %b %Y", item.date) or ""
  local meta = "Added by " .. (item.by or "?") .. (when ~= "" and ("  ·  " .. when) or "")
  if approved and item.approvedBy then meta = meta .. "  ·  Approved by " .. item.approvedBy end
  r.metaText = meta
  r.meta:SetText(meta)
  if approved then
    r.badge:SetLabel("APPROVED", APPROVED)
  else
    r.badge:SetLabel("PENDING", T.c.gold)
  end
  r.approve:SetShown(canApprove() and not approved)
  r.approve:SetScript("OnClick", function()
    if CWC.ApproveRequest(key, item.id, CWC.PlayerName() or "Unknown") then
      CWC.Print("Approved. Sent to online guild members.")
    end
    CWC.RefreshList(key)
    CWC.RefreshSidebar()
  end)
  r.remove:SetShown(officer and approved)
  r.remove:SetScript("OnClick", function()
    local listName = key == "kos" and "Kill on Sight" or "Blacklist"
    CWC.ShowDialog({
      title = "Remove this entry?",
      text = "Remove " .. (item.name or "this player") .. " from the " .. listName .. " list for everyone?",
      buttons = {
        { label = "Remove", onClick = function()
          if CWC.RemoveRequest(key, item.id, CWC.PlayerName() or "Unknown") then
            CWC.Print((item.name or "Entry") .. " removed from the " .. listName .. " list. Sent to online guild members.")
          end
          CWC.RefreshList(key)
          CWC.RefreshSidebar()
        end },
        { label = CANCEL or "Cancel" },
      },
    })
  end)
  r.deny:SetShown(canApprove() and not approved)
  r.deny:SetScript("OnClick", function()
    if CWC.DenyRequest(key, item.id, CWC.PlayerName() or "Unknown") then
      CWC.Print("Request denied and removed. Sent to online guild members.")
    end
    CWC.RefreshList(key)
    CWC.RefreshSidebar()
  end)
end

-- Redraws the list of requests for Kill on Sight or Blacklist.
function CWC.RefreshList(key)
  local u = listUI[key]
  if not u then return end
  local all = requestStore(key)
  local items = {}
  for _, it in ipairs(all) do
    if it.status ~= "denied" and it.status ~= "removed" then table.insert(items, it) end
  end
  local empty = #items == 0
  u.mark:SetShown(empty)
  u.et:SetShown(empty)
  u.eh:SetShown(empty)

  local h = u.card:GetHeight()
  local maxRows = (h and h > 60) and math.max(1, math.floor((h - 20) / ROW_STEP)) or 4
  for i = 1, maxRows do
    local item = items[i]
    local r = u.rows[i]
    if item then
      if not r then
        r = makeListRow(u.card)
        u.rows[i] = r
      end
      local y = -14 - (i - 1) * ROW_STEP
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", u.card, "TOPLEFT", 14, y)
      r:SetPoint("TOPRIGHT", u.card, "TOPRIGHT", -14, y)
      fillListRow(r, item, key)
      r:Show()
    elseif r then
      r:Hide()
    end
  end
  for i = maxRows + 1, #u.rows do u.rows[i]:Hide() end
  local extra = #items - maxRows
  u.more:SetText(extra > 0 and ("+" .. extra .. " more on this computer") or "")
end

local function selectTab(key)
  for k, p in pairs(pages) do p:SetShown(k == key) end
  for k, b in pairs(navItems) do b:SetActive(k == key) end
  if key == "roster" then CWC.RefreshRoster() end
  if REQUEST_KEYS[key] then CWC.RefreshList(key) end
  if key == "stats" then CWC.RefreshStats() end
  if key == "settings" then CWC.RefreshSettings() end
end

-- Gold heading with a rule underneath, used at the top of each card.
local function cardTitle(card, text)
  local t = T.Text(card, "bold", 11, T.c.gold)
  t:SetPoint("TOPLEFT", 16, -14)
  t:SetText(string.upper(text))
  local r = T.Rule(card, 0.3)
  r:SetPoint("TOPLEFT", 16, -34)
  r:SetPoint("TOPRIGHT", -16, -34)
  return t
end

-- Forever characters have a first and a last name, each a single word.
local function nameFrom(firstBox, lastBox)
  local first = (strtrim(firstBox:GetText() or "")):gsub("%s+", "")
  local last = (strtrim(lastBox:GetText() or "")):gsub("%s+", "")
  if first == "" or last == "" then return nil end
  return first .. " " .. last
end

local function submitRequest(key, firstBox, lastBox, reasonBox, faction)
  local name = nameFrom(firstBox, lastBox)
  local reason = strtrim(reasonBox:GetText() or "")
  if not name then
    CWC.Print("Enter the character's first and last name.")
    return
  end
  if reason == "" then
    CWC.Print("Add a reason or evidence first.")
    return
  end
  CWC.AddRequest(key, name, reason, CWC.PlayerName() or "Unknown", faction)
  firstBox:SetText("")
  lastBox:SetText("")
  reasonBox:SetText("")
  firstBox:ClearFocus()
  lastBox:ClearFocus()
  reasonBox:ClearFocus()
  CWC.RefreshList(key)
  CWC.RefreshSidebar()
  if CWC.SyncStatus() == "On" then
    CWC.Print("Request sent to online guild members.")
  else
    CWC.Print("Request saved, but you're not in a guild, so it can't reach anyone yet.")
  end
end

-- Kill on Sight and Blacklist share one layout: a request form above a list of saved requests.
local function buildListPage(key, page, heading, desc)
  local h = T.Text(page, "heading", 20, T.c.gold)
  h:SetPoint("TOPLEFT", 0, 0)
  h:SetText(heading)

  local badge = T.Badge(page, T.c.gold)
  badge:SetSize(66, 16)
  badge:SetPoint("LEFT", h, "RIGHT", 12, 3)
  badge:SetLabel("PREVIEW", T.c.gold)

  local d = T.Text(page, "body", 13, T.c.muted)
  d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
  d:SetWordWrap(true)
  d:SetText(desc)

  local form = T.Card(page)
  form:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  form:SetHeight(140)
  cardTitle(form, "New request")

  local firstLabel = T.Text(form, "bold", 11, T.c.muted)
  firstLabel:SetPoint("TOPLEFT", 16, -48)
  firstLabel:SetText("FIRST NAME")
  local firstBox = T.Input(form, 150, 24)
  firstBox:SetPoint("TOPLEFT", 16, -68)

  local lastLabel = T.Text(form, "bold", 11, T.c.muted)
  lastLabel:SetPoint("TOPLEFT", 178, -48)
  lastLabel:SetText("LAST NAME")
  local lastBox = T.Input(form, 150, 24)
  lastBox:SetPoint("TOPLEFT", 178, -68)

  local reasonLabel = T.Text(form, "bold", 11, T.c.muted)
  reasonLabel:SetPoint("TOPLEFT", 340, -48)
  reasonLabel:SetText("REASON OR EVIDENCE")
  local reasonBox = T.Input(form, 300, 200)
  reasonBox:SetPoint("TOPLEFT", 340, -68)

  -- Tab moves from first name, to last name, to the reason.
  firstBox:SetScript("OnTabPressed", function() lastBox:SetFocus() end)
  lastBox:SetScript("OnTabPressed", function() reasonBox:SetFocus() end)
  reasonBox:SetScript("OnTabPressed", function() firstBox:SetFocus() end)

  local submit = T.Button(form, "Submit request", 150, function()
    submitRequest(key, firstBox, lastBox, reasonBox, LIST_FACTION[key])
  end, true)
  submit:SetPoint("BOTTOMRIGHT", -16, 14)

  local note = T.Text(form, "body", 12, T.c.muted)
  note:SetPoint("BOTTOMLEFT", 16, 20)
  note:SetText("Sent to online guild members. Officers and Guild Masters can approve here.")

  local list = T.Card(page)
  list:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -14)
  list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)

  local mark = list:CreateTexture(nil, "ARTWORK")
  mark:SetSize(88, 88)
  mark:SetPoint("CENTER", 0, 36)
  mark:SetTexture(CWC.logoPath)
  mark:SetAlpha(0.22)

  local et = T.Text(list, "heading", 18, T.c.cream)
  et:SetPoint("TOP", mark, "BOTTOM", 0, -10)
  et:SetJustifyH("CENTER")
  et:SetText("No entries yet")

  local eh = T.Text(list, "body", 13, T.c.muted)
  eh:SetPoint("TOP", et, "BOTTOM", 0, -6)
  eh:SetJustifyH("CENTER")
  eh:SetText("Requests appear here for everyone in the guild. Approved entries show once an officer approves them.")

  local more = T.Text(list, "body", 11, T.c.muted)
  more:SetPoint("BOTTOMLEFT", 16, 12)

  listUI[key] = {
    desc = d, form = form, reason = reasonBox, card = list,
    mark = mark, et = et, eh = eh, more = more, rows = {},
  }
end

local function layoutList(key, w)
  local u = listUI[key]
  if not u then return end
  u.desc:SetWidth(w)
  u.form:SetWidth(w)
  u.reason:SetWidth(w - 356)
end

-- Statistics
local function buildTile(parent, label)
  local tile = T.Card(parent)
  local l = T.Text(tile, "bold", 11, T.c.muted)
  l:SetPoint("TOPLEFT", 16, -12)
  l:SetText(string.upper(label))
  tile.value = T.Text(tile, "heading", 24, T.c.gold)
  tile.value:SetPoint("BOTTOMLEFT", 16, 10)
  table.insert(statsUI.tiles, tile)
  return tile
end

local function buildColumn(parent, title)
  local col = T.Card(parent)
  cardTitle(col, title)
  col.rows = {}
  col.empty = T.Text(col, "body", 13, T.c.muted)
  col.empty:SetPoint("TOPLEFT", 16, -48)
  col.empty:SetText("Nothing recorded yet.")
  col.empty:Hide()
  table.insert(statsUI.cols, col)
  return col
end

local function fillColumn(col, entries)
  for _, r in ipairs(col.rows) do r:Hide() end
  local cw = col:GetWidth()
  if not cw or cw < 50 then cw = 220 end
  local maxCount = 1
  for _, e in ipairs(entries) do
    if e.count > maxCount then maxCount = e.count end
  end
  col.empty:SetShown(#entries == 0)
  local y = -44
  for i, e in ipairs(entries) do
    local r = col.rows[i]
    if not r then
      r = CreateFrame("Frame", nil, col)
      r:SetHeight(26)
      r.bar = r:CreateTexture(nil, "BACKGROUND")
      r.bar:SetColorTexture(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.14)
      r.bar:SetPoint("TOPLEFT", 0, 0)
      r.bar:SetHeight(26)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(18, 18)
      r.icon:SetPoint("LEFT", 8, 0)
      r.label = T.Text(r, "body", 13)
      r.label:SetPoint("LEFT", 34, 0)
      r.count = T.Text(r, "bold", 13, T.c.gold)
      r.count:SetPoint("RIGHT", -8, 0)
      col.rows[i] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", col, "TOPLEFT", 8, y)
    r:SetPoint("TOPRIGHT", col, "TOPRIGHT", -8, y)
    r.icon:SetTexture(e.icon)
    T.Fit(r.label, e.label, cw - 80)
    r.count:SetText(tostring(e.count))
    r.bar:SetWidth(math.max(2, (cw - 16) * e.count / maxCount))
    r:Show()
    y = y - 28
  end
end

local function buildStats(page)
  local h = T.Text(page, "heading", 20, T.c.gold)
  h:SetPoint("TOPLEFT", 0, 0)
  h:SetText("Statistics")
  local sub = T.Text(page, "body", 12, T.c.muted)
  sub:SetPoint("LEFT", h, "RIGHT", 14, 0)
  sub:SetText("Counted on this computer for now. Guild-wide figures arrive with sync.")

  statsUI.page = page
  statsUI.total = buildTile(page, "Characters")
  statsUI.mains = buildTile(page, "Mains")
  statsUI.alts = buildTile(page, "Alts")
  statsUI.classes = buildColumn(page, "Classes")
  statsUI.races = buildColumn(page, "Races")
  statsUI.profs = buildColumn(page, "Professions")
end

local function layoutStats(w)
  local page = statsUI.page
  if not page or #statsUI.tiles == 0 then return end
  local tw = math.floor((w - 2 * ROW_GAP) / 3)
  for i, tile in ipairs(statsUI.tiles) do
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (tw + ROW_GAP), -40)
    tile:SetSize(tw, 70)
  end
  for i, col in ipairs(statsUI.cols) do
    col:ClearAllPoints()
    col:SetPoint("TOPLEFT", page, "TOPLEFT", (i - 1) * (tw + ROW_GAP), -126)
    col:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", (i - 1) * (tw + ROW_GAP), 0)
    col:SetWidth(tw)
  end
  CWC.RefreshStats()
end

local function sortedEntries(map)
  local list = {}
  for _, e in pairs(map) do table.insert(list, e) end
  table.sort(list, function(a, b)
    if a.count == b.count then return a.label < b.label end
    return a.count > b.count
  end)
  return list
end

function CWC.RefreshStats()
  if not statsUI.total then return end
  local total, mains, alts = 0, 0, 0
  local classes, races, profs = {}, {}, {}
  for _, rec in ipairs(CWC.AllRecords()) do
    total = total + 1
    if rec.isMain == true then mains = mains + 1 end
    if rec.isMain == false then alts = alts + 1 end
    if rec.className then
      local e = classes[rec.className] or { label = rec.className, icon = T.ClassIcon(rec.classFile), count = 0 }
      e.count = e.count + 1
      classes[rec.className] = e
    end
    if rec.race then
      local e = races[rec.race] or { label = rec.race, icon = T.RaceIcon(rec.race), count = 0 }
      e.count = e.count + 1
      races[rec.race] = e
    end
    for _, p in ipairs(rec.professions or {}) do
      local e = profs[p.name] or { label = p.name, icon = T.ProfIcon(p.name), count = 0 }
      e.count = e.count + 1
      profs[p.name] = e
    end
  end
  statsUI.total.value:SetText(tostring(total))
  statsUI.mains.value:SetText(tostring(mains))
  statsUI.alts.value:SetText(tostring(alts))
  fillColumn(statsUI.classes, sortedEntries(classes))
  fillColumn(statsUI.races, sortedEntries(races))
  fillColumn(statsUI.profs, sortedEntries(profs))
end

-- Settings: two cards per row. Widths follow the window.
-- Label on the left, box on the right, as in FlareUI's settings rows.
local function settingsCheck(parent, y, label, key, extra)
  local cb = T.Check(parent, label, function(self)
    local v = self:GetChecked() and true or false
    CWC_Account.settings[key] = v
    if extra then extra(v) end
  end)
  cb:ClearAllPoints()
  cb:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)
  cb.label:ClearAllPoints()
  cb.label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y - 4)
  return cb
end

local ROW1_H = 226

local function buildSettings(page)
  local h = T.Text(page, "heading", 20, T.c.gold)
  h:SetPoint("TOPLEFT", 0, 0)
  h:SetText("Settings & preferences")

  local general = T.Card(page)
  cardTitle(general, "General")
  settingsUI.minimap = settingsCheck(general, -44, "Show the minimap button", "minimapShown", function(v)
    CWC.SetMinimapShown(v)
  end)
  settingsUI.tooltips = settingsCheck(general, -74, "Show tooltips on roster rows", "showTooltips")
  settingsUI.kosAlerts = settingsCheck(general, -104, "Kill on Sight alerts (sound and pop-up)", "kosAlerts")
  local testAlert = T.Button(general, "Test", 56, function() CWC.TestKOSAlert() end)
  testAlert:SetPoint("TOPRIGHT", general, "TOPRIGHT", -48, -102)
  settingsUI.blacklistAlerts = settingsCheck(general, -134, "Blacklist alerts (sound and pop-up)", "blacklistAlerts")
  local testBlacklist = T.Button(general, "Test", 56, function() CWC.TestBlacklistAlert() end)
  testBlacklist:SetPoint("TOPRIGHT", general, "TOPRIGHT", -48, -132)
  local openLabel = T.Text(general, "body", 13, T.c.muted)
  openLabel:SetPoint("TOPLEFT", 16, -168)
  openLabel:SetText("Window opens on")
  settingsUI.openOn = T.Button(general, "", 260, function()
    local s = CWC_Account.settings
    local idx = 1
    for i, k in ipairs(OPEN_ORDER) do
      if k == s.defaultTab then idx = i end
    end
    idx = idx % #OPEN_ORDER + 1
    s.defaultTab = OPEN_ORDER[idx]
    CWC.RefreshSettings()
  end)
  settingsUI.openOn:SetPoint("TOPLEFT", 16, -188)
  settingsUI.general = general

  local sharing = T.Card(page)
  cardTitle(sharing, "Sharing (applies once sync is on)")
  settingsUI.shareProfessions = settingsCheck(sharing, -44, "Share my professions and skill levels", "shareProfessions")
  settingsUI.shareOnline = settingsCheck(sharing, -74, "Share my online status and last seen", "shareOnline")
  local noteLabel = T.Text(sharing, "body", 13, T.c.muted)
  noteLabel:SetPoint("TOPLEFT", 16, -110)
  noteLabel:SetText("Note shown beside your name (60 characters)")
  settingsUI.note = T.Input(sharing, 300, 60)
  settingsUI.note:SetPoint("TOPLEFT", 16, -132)
  settingsUI.note:HookScript("OnEditFocusLost", function(self)
    CWC_Account.settings.note = strtrim(self:GetText() or "")
  end)
  settingsUI.sharing = sharing

  local me = T.Card(page)
  cardTitle(me, "Your character")
  settingsUI.tagText = T.Text(me, "body", 13)
  settingsUI.tagText:SetPoint("TOPLEFT", 16, -44)
  settingsUI.tagText:SetWordWrap(true)
  local setup = T.Button(me, "Run setup again", 170, function()
    CWC.ShowSetup("full")
  end)
  setup:SetPoint("BOTTOMLEFT", 16, 14)
  settingsUI.me = me

  -- Tools: buttons for the commands that used to be typed in chat.
  local tools = T.Card(page)
  cardTitle(tools, "Tools")
  local actions = {
    { "Rescan character", function()
      CWC.ScanCharacter()
      if CWC.RefreshRoster then CWC.RefreshRoster() end
    end },
    { "Refresh guild data", function() CWC.RefreshGuildData() end },
    { "Clear received records", function() CWC.ClearRemote() end },
    { "Check minimap button", function() CWC.MinimapStatus() end },
    { "Reset minimap button", function() CWC.MinimapReset() end },
    { "Profession diagnostics", function() CWC.DumpSkills() end },
    { "Check guild versions", function() CWC.PrintGuildVersions() end },
    { "Copy download link", function() CWC.ShowUpdatePopup() end },
  }
  for i, a in ipairs(actions) do
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    local b = T.Button(tools, a[1], 180, a[2])
    b:SetPoint("TOPLEFT", tools, "TOPLEFT", 16 + col * 190, -44 - row * 42)
  end
  settingsUI.tools = tools

  local about = T.Card(page)
  cardTitle(about, "About")
  settingsUI.aboutText = T.Text(about, "body", 13, T.c.muted)
  settingsUI.aboutText:SetPoint("TOPLEFT", 16, -44)
  settingsUI.aboutText:SetWordWrap(true)
  settingsUI.aboutText:SetText("CWC version " .. CWC.version .. ". Shares your characters, Kill on Sight and Blacklist entries with guild mates who also have CWC. Updates: " .. (CWC.downloadURL or "copingwithcaffeine.mattgtv.co.uk/CWC-Addon") .. ". Icons and typefaces match the Coping with Caffeine site.")
  settingsUI.about = about
end

local function layoutSettings(w)
  local ui = settingsUI
  local page = pages.settings
  if not ui.general or not page then return end
  local half = math.floor((w - ROW_GAP) / 2)
  local right = w - half - ROW_GAP
  local row2 = 40 + ROW1_H + ROW_GAP

  ui.general:ClearAllPoints()
  ui.general:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -40)
  ui.general:SetSize(half, ROW1_H)

  ui.sharing:ClearAllPoints()
  ui.sharing:SetPoint("TOPLEFT", page, "TOPLEFT", half + ROW_GAP, -40)
  ui.sharing:SetSize(right, ROW1_H)
  ui.note:SetWidth(right - 32)

  ui.me:ClearAllPoints()
  ui.me:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -row2)
  ui.me:SetSize(half, 170)
  ui.tagText:SetWidth(half - 32)

  ui.about:ClearAllPoints()
  ui.about:SetPoint("TOPLEFT", page, "TOPLEFT", half + ROW_GAP, -row2)
  ui.about:SetSize(right, 170)
  ui.aboutText:SetWidth(right - 32)

  ui.tools:ClearAllPoints()
  ui.tools:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(row2 + 170 + ROW_GAP))
  ui.tools:SetSize(w, 150)
end

function CWC.RefreshSettings()
  if not settingsUI.minimap then return end
  local s = CWC_Account.settings
  settingsUI.minimap:SetChecked(s.minimapShown)
  settingsUI.tooltips:SetChecked(s.showTooltips)
  settingsUI.kosAlerts:SetChecked(s.kosAlerts ~= false)
  settingsUI.blacklistAlerts:SetChecked(s.blacklistAlerts ~= false)
  settingsUI.shareProfessions:SetChecked(s.shareProfessions)
  settingsUI.shareOnline:SetChecked(s.shareOnline)
  settingsUI.note:SetText(s.note or "")
  settingsUI.openOn.text:SetText("Opens on: " .. (TAB_LABEL[s.defaultTab] or "Roster"))

  local name = CWC.PlayerName() or ""
  local rec = CWC_Characters[name]
  local tag
  if rec then
    if rec.isMain == true then
      tag = "Main character"
    elseif rec.isMain == false then
      tag = rec.mainOf and ("Alt of " .. rec.mainOf) or "Alt character"
    else
      tag = "Not tagged yet."
    end
    tag = name .. ": " .. tag
  else
    tag = name .. ": not scanned yet."
  end
  tag = tag .. "\nExperience: " .. (CWC_Account.experience or "not set (use Run setup again)")
  settingsUI.tagText:SetText(tag)
end

-- Sidebar: the current character, and a summary of what this computer holds.
function CWC.RefreshSidebar()
  if not side or not side.name then return end
  local rec = CWC_Characters and CWC_Characters[CWC.PlayerName() or ""]
  if rec then
    side.icon:SetTexture(T.ClassIcon(rec.classFile))
    T.Fit(side.name, rec.name or "?", SIDE_W - 84)
    local role = "Untagged"
    if rec.isMain == true then role = "Main" end
    if rec.isMain == false then role = "Alt" end
    side.role:SetText(role .. " · Level " .. tostring(rec.level or "?"))
  else
    side.icon:SetTexture(T.fallbackIcon)
    side.name:SetText("Not scanned yet")
    side.role:SetText("Log in to scan")
  end

  local total, mains, alts = 0, 0, 0
  for _, r in pairs(CWC_Characters or {}) do
    total = total + 1
    if r.isMain == true then mains = mains + 1 end
    if r.isMain == false then alts = alts + 1 end
  end
  local pending = 0
  for key in pairs(REQUEST_KEYS) do
    for _, item in ipairs(requestStore(key)) do
      if item.status == "pending" then pending = pending + 1 end
    end
  end
  local values = { tostring(total), tostring(mains), tostring(alts), tostring(pending), CWC.SyncStatus() }
  for i, row in ipairs(side.statRows or {}) do
    row.value:SetText(values[i])
  end
  local syncRow = side.statRows and side.statRows[5]
  if syncRow then
    if values[5] == "Update needed" then
      syncRow.value:SetTextColor(1, 0.35, 0.3, 1)
    else
      syncRow.value:SetTextColor(T.c.cream[1], T.c.cream[2], T.c.cream[3], 1)
    end
  end
end

-- Lays out everything that depends on the window width.
local function relayout()
  if not window or not content then return end
  local w = window:GetWidth() - CONTENT_X - PAD
  CWC.LayoutRoster(w)
  layoutList("kos", w)
  layoutList("blacklist", w)
  layoutStats(w)
  layoutSettings(w)
end

-- Runs one layout step. A failure prints its name and message in chat instead of stopping the window.
local function safe(name, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then CWC.Print("Layout error in " .. name .. ": " .. tostring(err)) end
end

-- Shows the update banner above the pages when a newer CWC has been seen, and moves the pages down to fit.
function CWC.RefreshUpdateBanner()
  if not window or not window.updateBanner or not content then return end
  local v = CWC.UpdateAvailable and CWC.UpdateAvailable()
  local b = window.updateBanner
  local top = HEADER_H + PAD
  if v then
    b.title:SetText("UPDATE REQUIRED: CWC " .. v .. " is available. You have " .. CWC.version .. ".")
    b.body:SetText("Without it, guild sync can stop working and the roster may show missing, mismatched or unreliable data.")
    b:Show()
    top = top + BANNER_H + 10
  else
    b:Hide()
  end
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", CONTENT_X, -top)
  content:SetPoint("BOTTOMRIGHT", -PAD, FOOTER_H + 8)
  relayout()
end

-- Raid: a preview page describing what is planned. Nothing on it works yet.
local function buildRaidPage(page)
  local h = T.Text(page, "heading", 20, T.c.gold)
  h:SetPoint("TOPLEFT", 0, 0)
  h:SetText("Raid")

  local badge = T.Badge(page, T.c.gold)
  badge:SetSize(66, 16)
  badge:SetPoint("LEFT", h, "RIGHT", 12, 3)
  badge:SetLabel("PREVIEW", T.c.gold)

  local d = T.Text(page, "body", 13, T.c.muted)
  d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
  d:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  d:SetWordWrap(true)
  d:SetText("This section is a work in progress. Raid tools are planned for when raids become available, so nothing here works yet.")

  local card = T.Card(page)
  card:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  card:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  card:SetHeight(260)
  cardTitle(card, "What's planned")

  local mark = card:CreateTexture(nil, "ARTWORK")
  mark:SetSize(150, 150)
  mark:SetPoint("RIGHT", -30, -10)
  mark:SetTexture(CWC.logoPath)
  mark:SetAlpha(0.14)

  local intro = T.Text(card, "body", 14, T.c.cream)
  intro:SetPoint("TOPLEFT", 16, -50)
  intro:SetPoint("RIGHT", card, "RIGHT", -200, 0)
  intro:SetWordWrap(true)
  intro:SetText("When raids open up, this page will let you mark your interest in raiding with the guild, so officers can see who wants to raid before they plan a raid night.")

  local list = T.Text(card, "body", 13, T.c.muted)
  list:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
  list:SetPoint("RIGHT", card, "RIGHT", -200, 0)
  list:SetWordWrap(true)
  list:SetText("•  Mark yourself as interested in raiding\n•  Choose the roles you can fill: tank, healer or damage\n•  See who else is interested, and which roles are covered\n\nDetails may change as the feature takes shape. Ideas are welcome: tell an officer what you'd like to see.")
end

local function buildSidebarFooter()
  local stats = T.Card(side)
  stats:SetPoint("BOTTOMLEFT", 12, 84)
  stats:SetPoint("BOTTOMRIGHT", -12, 84)
  stats:SetHeight(126)
  local st = T.Text(stats, "bold", 10, T.c.gold)
  st:SetPoint("TOPLEFT", 14, -12)
  st:SetText("THIS COMPUTER")
  side.statRows = {}
  local labels = { "Characters", "Mains", "Alts", "Pending requests", "Guild sync" }
  for i, lbl in ipairs(labels) do
    local y = -34 - (i - 1) * 18
    local l = T.Text(stats, "body", 12, T.c.muted)
    l:SetPoint("TOPLEFT", 14, y)
    l:SetText(lbl)
    local v = T.Text(stats, "bold", 12, T.c.cream)
    v:SetPoint("TOPRIGHT", -14, y)
    v:SetJustifyH("RIGHT")
    side.statRows[i] = { value = v }
  end

  local me = T.Card(side)
  me:SetPoint("BOTTOMLEFT", 12, 12)
  me:SetPoint("BOTTOMRIGHT", -12, 12)
  me:SetHeight(60)
  side.icon = me:CreateTexture(nil, "ARTWORK")
  side.icon:SetSize(36, 36)
  side.icon:SetPoint("LEFT", 10, 0)
  side.name = T.Text(me, "bold", 12, T.c.cream)
  side.name:SetPoint("TOPLEFT", 56, -13)
  side.role = T.Text(me, "body", 11, T.c.muted)
  side.role:SetPoint("BOTTOMLEFT", 56, 12)
end

-- Window
local function build()
  local s = CWC_Account.settings
  local startW = math.max(MIN_W, math.min(MAX_W, s.windowW or DEF_W))
  local startH = math.max(MIN_H, math.min(MAX_H, s.windowH or DEF_H))

  window = T.Panel(UIParent, T.c.bg, { 0.3, 0.24, 0.15, 1 })
  _G.CWCWindow = window
  window:SetSize(startW, startH)
  window:SetPoint("CENTER")
  window:SetFrameStrata("HIGH")
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:SetResizable(true)
  if window.SetResizeBounds then
    window:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
  elseif window.SetMinResize then
    window:SetMinResize(MIN_W, MIN_H)
    window:SetMaxResize(MAX_W, MAX_H)
  end
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:SetScript("OnSizeChanged", function() relayout() end)
  window:SetScript("OnShow", function() relayout() end)
  window:Hide()
  table.insert(UISpecialFrames, "CWCWindow")

  -- Warm gradient base and a thin inset gold line, for the layered look.
  T.Gradient(window, { 0.12, 0.095, 0.07, 1 }, { 0.055, 0.045, 0.035, 1 }, "BACKGROUND")
  local inner = CreateFrame("Frame", nil, window, "BackdropTemplate")
  inner:SetPoint("TOPLEFT", 3, -3)
  inner:SetPoint("BOTTOMRIGHT", -3, 3)
  inner:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  inner:SetBackdropBorderColor(T.c.gold[1], T.c.gold[2], T.c.gold[3], 0.16)
  inner:EnableMouse(false)

  -- Header: valley banner faded into the window background, with logo and title.
  local header = CreateFrame("Frame", nil, window)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetHeight(HEADER_H)

  local art = header:CreateTexture(nil, "BACKGROUND")
  art:SetAllPoints()
  art:SetTexture(T.banner)
  cropBanner(art, startW, HEADER_H)
  T.Gradient(header, { 0.043, 0.043, 0.043, 0.15 }, { 0.043, 0.043, 0.043, 0.95 }, "ARTWORK")

  local headRule = T.Rule(header, 0.5)
  headRule:SetPoint("BOTTOMLEFT")
  headRule:SetPoint("BOTTOMRIGHT")

  local logo = header:CreateTexture(nil, "OVERLAY")
  logo:SetSize(52, 52)
  logo:SetPoint("LEFT", 20, 0)
  logo:SetTexture(CWC.logoPath)

  local title = T.Text(header, "heading", 24, T.c.gold)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -4)
  title:SetText("Coping with Caffeine")
  local ver = T.Text(header, "body", 11, T.c.muted)
  ver:SetPoint("LEFT", title, "RIGHT", 10, 2)
  ver:SetText("v" .. CWC.version)
  local sub = T.Text(header, "body", 12, T.c.cream)
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)
  sub:SetText("Private guild addon · roster, Kill on Sight and player blacklist")

  -- Close button belongs to the window itself, so it hides the whole window.
  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() window:Hide() end)

  -- Sidebar: navigation, a summary of this computer, and the current character.
  side = CreateFrame("Frame", nil, window)
  side:SetPoint("TOPLEFT", 0, -HEADER_H)
  side:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
  side:SetWidth(SIDE_W)
  T.Gradient(side, { 0.075, 0.075, 0.075, 1 }, { 0.043, 0.043, 0.043, 1 }, "BACKGROUND")

  local sideRule = side:CreateTexture(nil, "ARTWORK")
  sideRule:SetColorTexture(T.c.line[1], T.c.line[2], T.c.line[3], 1)
  sideRule:SetWidth(1)
  sideRule:SetPoint("TOPRIGHT")
  sideRule:SetPoint("BOTTOMRIGHT")

  -- Grouped navigation, with muted gold group headings.
  local NAV_Y = { roster = -38, kos = -78, blacklist = -118, raid = -158, stats = -222, settings = -262 }
  local GROUP_HEADS = { { text = "GUILD", y = -18 }, { text = "TOOLS", y = -202 } }
  for _, g in ipairs(GROUP_HEADS) do
    local gh = T.Text(side, "bold", 10, T.c.gold)
    gh:SetPoint("TOPLEFT", 22, g.y)
    gh:SetText(g.text)
  end

  for _, tab in ipairs(TABS) do
    local b = T.NavItem(side, tab.label, tab.icon, function() selectTab(tab.key) end)
    b:SetPoint("TOPLEFT", side, "TOPLEFT", 8, NAV_Y[tab.key])
    b:SetPoint("TOPRIGHT", side, "TOPRIGHT", -8, NAV_Y[tab.key])
    navItems[tab.key] = b
  end

  buildSidebarFooter()

  -- Content area: each tab is a page that fills it.
  content = CreateFrame("Frame", nil, window)
  content:SetPoint("TOPLEFT", CONTENT_X, -(HEADER_H + PAD))
  content:SetPoint("BOTTOMRIGHT", -PAD, FOOTER_H + 8)
  for _, tab in ipairs(TABS) do
    local p = CreateFrame("Frame", nil, content)
    p:SetAllPoints(content)
    p:Hide()
    pages[tab.key] = p
  end

  CWC.BuildRosterPage(pages.roster)
  buildListPage("kos", pages.kos, "Kill on Sight", "Mark enemies to hunt. Requests go to officers for approval, and approved entries show for everyone in the guild who has CWC.")
  buildListPage("blacklist", pages.blacklist, "Blacklist", "Players to avoid, such as scammers and ninja looters. Requests need officer approval.")
  buildRaidPage(pages.raid)
  buildStats(pages.stats)
  buildSettings(pages.settings)

  -- Update banner: shown above the pages whenever a newer CWC has been seen in the guild.
  local banner = CreateFrame("Frame", nil, window, "BackdropTemplate")
  banner:SetPoint("TOPLEFT", CONTENT_X, -(HEADER_H + PAD))
  banner:SetPoint("TOPRIGHT", -PAD, -(HEADER_H + PAD))
  banner:SetHeight(BANNER_H)
  banner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  banner:SetBackdropColor(0.32, 0.06, 0.05, 0.95)
  banner:SetBackdropBorderColor(1, 0.35, 0.3, 1)
  local warnIcon = banner:CreateTexture(nil, "ARTWORK")
  warnIcon:SetSize(28, 28)
  warnIcon:SetPoint("LEFT", 12, 0)
  warnIcon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
  banner.title = T.Text(banner, "bold", 13, { 1, 0.85, 0.8, 1 })
  banner.title:SetPoint("TOPLEFT", 50, -9)
  banner.title:SetPoint("RIGHT", banner, "RIGHT", -190, 0)
  banner.body = T.Text(banner, "body", 12, T.c.cream)
  banner.body:SetPoint("BOTTOMLEFT", 50, 9)
  banner.body:SetPoint("RIGHT", banner, "RIGHT", -190, 0)
  banner.body:SetWordWrap(false)
  local getIt = T.Button(banner, "Get the update", 160, function() CWC.ShowUpdatePopup() end, true)
  getIt:SetPoint("RIGHT", -12, 0)
  banner:Hide()
  window.updateBanner = banner

  -- Footer with the resize grip in the bottom-right corner.
  local footRule = T.Rule(window, 0.25)
  footRule:SetPoint("BOTTOMLEFT", 0, FOOTER_H)
  footRule:SetPoint("BOTTOMRIGHT", 0, FOOTER_H)
  local footer = T.Text(window, "body", 11, T.c.muted)
  footer:SetPoint("BOTTOMLEFT", 22, 9)
  footer:SetText("Version " .. CWC.version .. " · Shares data with online guild mates who have CWC.")

  local grip = CreateFrame("Button", nil, window)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetFrameLevel(window:GetFrameLevel() + 10)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnEnter", function()
    GameTooltip:SetOwner(grip, "ANCHOR_TOP")
    GameTooltip:AddLine("Drag to resize")
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Resizing starts only after the mouse actually moves (a drag), so a plain click does nothing.
  grip:RegisterForDrag("LeftButton")
  grip:SetScript("OnDragStart", function() window:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnDragStop", function()
    window:StopMovingOrSizing()
    local saved = CWC_Account.settings
    saved.windowW = math.floor(window:GetWidth() + 0.5)
    saved.windowH = math.floor(window:GetHeight() + 0.5)
    relayout()
  end)

  safe("layout", relayout)
  safe("sidebar", CWC.RefreshSidebar)
  safe("update", CWC.RefreshUpdateBanner)
end

function CWC.OpenWindow(key)
  if CWC.GuildState and CWC.GuildState() == "outsider" then
    CWC.ShowNotInGuild()
    return
  end
  if not window then build() end
  window:Show()
  safe("update", CWC.RefreshUpdateBanner)
  selectTab(key or CWC_Account.settings.defaultTab or "roster")
  safe("sidebar", CWC.RefreshSidebar)
  safe("layout", relayout)
end

function CWC.ToggleRoster()
  if window and window:IsShown() then
    window:Hide()
    return
  end
  CWC.OpenWindow(CWC_Account.settings.defaultTab)
end
