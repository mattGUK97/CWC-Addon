local ADDON, CWC = ...
local T = CWC.Theme

local W, H = 520, 540
local frame
local pages = {}
local c = {}
local mode = "full"
local pageIndex = 1
local refreshTag

local TITLES = {
  welcome = "Welcome",
  tag = "Your character",
  experience = "Your experience",
  sharing = "Sharing",
  interface = "Interface",
  finish = "All set",
}

-- Experience levels, newest players last. Saved once per player (account-wide), not per character.
local EXPERIENCE = {
  { name = "Master", desc = "Playing since 2004 across most versions: Retail, the Classic eras, Season of Discovery and private servers." },
  { name = "Veteran", desc = "Playing for 10 years or more, across several versions of the game." },
  { name = "Experienced", desc = "Several years of play in at least one version of World of Warcraft." },
  { name = "Novice", desc = "Fairly new to the game, but you know the basics and how it works." },
  { name = "Newbie", desc = "Brand new to World of Warcraft. Welcome! The guild is happy to help you learn." },
}

local function currentKeys()
  if mode == "full" then
    return { "welcome", "tag", "experience", "sharing", "interface", "finish" }
  elseif mode == "experience" then
    return { "experience", "finish" }
  end
  return { "tag", "finish" }
end

local function chosenExperience()
  for _, e in ipairs(EXPERIENCE) do
    if c.exp[e.name]:GetChecked() then return e.name end
  end
  return nil
end

local function newPage(key)
  local p = CreateFrame("Frame", nil, frame)
  p:SetPoint("TOPLEFT", 28, -150)
  p:SetPoint("BOTTOMRIGHT", -28, 64)
  p:Hide()
  pages[key] = p
  return p
end

local function para(parent, y, str, which, size, colour)
  local fs = T.Text(parent, which or "body", size or 14, colour)
  fs:SetPoint("TOPLEFT", 0, y)
  fs:SetWidth(W - 56)
  fs:SetWordWrap(true)
  fs:SetText(str)
  return fs
end

refreshTag = function()
  local alt = c.isAlt:GetChecked()
  c.altLabel:SetShown(alt)
  c.altFirst:SetShown(alt)
  c.altLast:SetShown(alt)
  c.altFirstLabel:SetShown(alt)
  c.altLastLabel:SetShown(alt)
end

local function prepareSummary()
  local rec = CWC_Characters[CWC.PlayerName() or ""] or {}
  local lines = {}
  local identity = (rec.name or "Your character") .. ": " .. (rec.race or "?") .. " " .. (rec.className or "?")
  if rec.spec then identity = identity .. " (" .. rec.spec .. ")" end
  table.insert(lines, identity)
  local level = "Level " .. tostring(rec.level or "?")
  if rec.itemLevel then level = level .. ", item level " .. rec.itemLevel end
  table.insert(lines, level)
  local profs = {}
  for _, p in ipairs(rec.professions or {}) do table.insert(profs, p.name .. " " .. p.skill) end
  if #profs > 0 then
    table.insert(lines, "Professions: " .. table.concat(profs, ", "))
  else
    table.insert(lines, "Professions: none found")
  end
  local status = "Not set"
  if c.isMain:GetChecked() then
    status = "Main"
  elseif c.isAlt:GetChecked() then
    status = "Alt"
  end
  table.insert(lines, "Status: " .. status)
  table.insert(lines, "Experience: " .. (chosenExperience() or "Not set"))
  table.insert(lines, "")
  table.insert(lines, "Press Finish to save. You can change any of this later from the CWC window's Settings tab.")
  c.summary:SetText(table.concat(lines, "\n"))
end

local function showPage()
  local keys = currentKeys()
  if pageIndex < 1 then pageIndex = 1 end
  for _, p in pairs(pages) do p:Hide() end
  local key = keys[pageIndex]
  pages[key]:Show()
  frame.title:SetText(TITLES[key])
  frame.step:SetText(pageIndex .. " of " .. #keys)
  frame.back:SetEnabled(pageIndex > 1)
  frame.next.text:SetText(pageIndex == #keys and "Finish" or "Next")
  if key == "tag" then refreshTag() end
  if key == "finish" then prepareSummary() end
end

local function prefill()
  local s = CWC_Account.settings
  local rec = CWC_Characters[CWC.PlayerName() or ""] or {}
  c.isMain:SetChecked(rec.isMain == true)
  c.isAlt:SetChecked(rec.isMain == false)
  local mf, ml = string.match(rec.mainOf or "", "^(%S+)%s+(.+)$")
  c.altFirst:SetText(mf or rec.mainOf or "")
  c.altLast:SetText(ml or "")
  c.shareProfessions:SetChecked(s.shareProfessions)
  c.shareOnline:SetChecked(s.shareOnline)
  c.note:SetText(s.note or "")
  c.minimap:SetChecked(s.minimapShown)
  for _, e in ipairs(EXPERIENCE) do
    c.exp[e.name]:SetChecked(CWC_Account.experience == e.name)
  end
end

-- The main's name as "First Last", "" when both boxes are empty, or nil when only one is filled in.
local function mainNameFromBoxes()
  local first = (strtrim(c.altFirst:GetText() or "")):gsub("%s+", "")
  local last = (strtrim(c.altLast:GetText() or "")):gsub("%s+", "")
  if first == "" and last == "" then return "" end
  if first == "" or last == "" then return nil end
  return first .. " " .. last
end

local function save(skipped)
  local a = CWC_Account
  local s = a.settings
  if not skipped and mode ~= "experience" and c.isAlt:GetChecked() and mainNameFromBoxes() == nil then
    CWC.Print("Enter both your main's first and last name, or leave both empty to add them later.")
    return
  end
  if mode == "full" then
    s.shareProfessions = c.shareProfessions:GetChecked() and true or false
    s.shareOnline = c.shareOnline:GetChecked() and true or false
    s.note = strtrim(c.note:GetText() or "")
    s.minimapShown = c.minimap:GetChecked() and true or false
    a.setupComplete = true
  end

  if mode == "full" or mode == "experience" then
    local chosen = chosenExperience()
    if chosen then
      a.experience = chosen
    elseif skipped then
      a.experienceSkipped = true
    end
  end

  local rec = mode ~= "experience" and CWC_Characters[CWC.PlayerName() or ""] or nil
  if rec then
    if skipped then
      rec.tagSkipped = true
    else
      if c.isMain:GetChecked() then
        rec.isMain = true
        rec.mainOf = nil
      elseif c.isAlt:GetChecked() then
        rec.isMain = false
        local mainName = mainNameFromBoxes()
        rec.mainOf = (mainName and mainName ~= "") and mainName or nil
      else
        rec.isMain = nil
        rec.mainOf = nil
      end
      rec.tagged = true
    end
  end

  CWC.SetMinimapShown(s.minimapShown)
  CWC.RefreshRoster()
  if CWC.SendRecords then CWC.SendRecords() end
  if CWC.RefreshSettings then CWC.RefreshSettings() end
  frame:Hide()
  if not skipped then CWC.Print("Setup saved.") end
end

local function build()
  frame = T.Panel(UIParent, T.c.bg, T.c.line)
  _G.CWCSetupFrame = frame
  frame:SetSize(W, H)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  table.insert(UISpecialFrames, "CWCSetupFrame")

  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetSize(76, 76)
  logo:SetPoint("TOP", 0, -16)
  logo:SetTexture(CWC.logoPath)

  frame.title = T.Text(frame, "heading", 20, T.c.gold)
  frame.title:SetPoint("TOP", logo, "BOTTOM", 0, -8)
  frame.title:SetWidth(W)
  frame.title:SetJustifyH("CENTER")

  frame.step = T.Text(frame, "body", 11, T.c.muted)
  frame.step:SetPoint("TOPRIGHT", -16, -12)

  local p = newPage("welcome")
  para(p, 0, "CWC keeps the Coping with Caffeine roster and shared lists in your game.", "bold", 16)
  para(p, -64, "It scans your character when you log in and keeps your details up to date. It shares them with guild mates who also have CWC, so everyone's roster stays current.")
  para(p, -140, "You can change any of this later from the CWC window's Settings tab, or with /cwc setup.", "body", 12, T.c.muted)

  p = newPage("tag")
  para(p, 0, "Is this character your main, or an alt?", "bold", 16)
  c.isMain = T.Check(p, "Main character", function(self)
    if self:GetChecked() then c.isAlt:SetChecked(false) end
    refreshTag()
  end)
  c.isMain:SetPoint("TOPLEFT", 0, -44)
  c.isAlt = T.Check(p, "Alt character", function(self)
    if self:GetChecked() then c.isMain:SetChecked(false) end
    refreshTag()
  end)
  c.isAlt:SetPoint("TOPLEFT", 0, -76)
  c.altLabel = para(p, -112, "Your main's first and last name (you can add them later):", "body", 13)
  c.altFirstLabel = T.Text(p, "bold", 11, T.c.muted)
  c.altFirstLabel:SetPoint("TOPLEFT", 0, -136)
  c.altFirstLabel:SetText("FIRST NAME")
  c.altFirst = T.Input(p, 170, 24)
  c.altFirst:SetPoint("TOPLEFT", 0, -152)
  c.altLastLabel = T.Text(p, "bold", 11, T.c.muted)
  c.altLastLabel:SetPoint("TOPLEFT", 182, -136)
  c.altLastLabel:SetText("LAST NAME")
  c.altLast = T.Input(p, 170, 24)
  c.altLast:SetPoint("TOPLEFT", 182, -152)
  c.altFirst:SetScript("OnTabPressed", function() c.altLast:SetFocus() end)
  c.altLast:SetScript("OnTabPressed", function() c.altFirst:SetFocus() end)

  p = newPage("experience")
  para(p, 0, "How much World of Warcraft have you played?", "bold", 16)
  c.exp = {}
  for i, e in ipairs(EXPERIENCE) do
    local y = -34 - (i - 1) * 56
    local cb = T.Check(p, e.name, function(self)
      if self:GetChecked() then
        for name, other in pairs(c.exp) do
          if name ~= e.name then other:SetChecked(false) end
        end
      end
    end)
    cb:SetPoint("TOPLEFT", 0, y)
    T.Font(cb.label, "bold", 14)
    local d = para(p, 0, e.desc, "body", 12, T.c.muted)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", 28, y - 24)
    d:SetWidth(W - 56 - 28)
    c.exp[e.name] = cb
  end

  p = newPage("sharing")
  para(p, 0, "Choose what other guildmates can see. These apply once guild sync is switched on.")
  c.shareProfessions = T.Check(p, "Share my professions and skill levels")
  c.shareProfessions:SetPoint("TOPLEFT", 0, -56)
  c.shareOnline = T.Check(p, "Share my online status and last seen time")
  c.shareOnline:SetPoint("TOPLEFT", 0, -88)
  para(p, -126, "Optional note shown beside your name (60 characters):", "body", 13)
  c.note = T.Input(p, 360, 60)
  c.note:SetPoint("TOPLEFT", 0, -150)

  p = newPage("interface")
  para(p, 0, "Choose how CWC appears.")
  c.minimap = T.Check(p, "Show the minimap button")
  c.minimap:SetPoint("TOPLEFT", 0, -40)

  p = newPage("finish")
  c.summary = para(p, 0, "")

  frame.back = T.Button(frame, "Back", 110, function()
    pageIndex = pageIndex - 1
    showPage()
  end)
  frame.back:SetPoint("BOTTOMLEFT", 28, 22)

  frame.skip = T.Button(frame, "Skip", 110, function() save(true) end)
  frame.skip:SetPoint("BOTTOM", 0, 22)

  frame.next = T.Button(frame, "Next", 110, function()
    if pageIndex >= #currentKeys() then
      save(false)
    else
      pageIndex = pageIndex + 1
      showPage()
    end
  end, true)
  frame.next:SetPoint("BOTTOMRIGHT", -28, 22)
end

function CWC.ShowSetup(newMode)
  if CWC.GuildState and CWC.GuildState() == "outsider" then
    CWC.ShowNotInGuild()
    return
  end
  if not frame then build() end
  mode = newMode or "full"
  pageIndex = 1
  prefill()
  showPage()
  frame:Show()
end
