local ADDON, CWC = ...
local T = CWC.Theme

-- Alerts for approved Kill on Sight and Blacklist entries. Each plays a short warning sound and shows a
-- pop-up at the top of the screen.
--
-- Kill on Sight: the player comes into view, by their nameplate appearing (enemy players within about
-- 40 yards, when enemy nameplates are switched on), or by targeting or mousing over them. Visible
-- nameplates are re-checked every few seconds, so a target already on screen is still caught. Each
-- target alerts once per visit: again only after being out of sight for a while. Kill on Sight is off
-- in dungeons, raids, battlegrounds and sanctuaries, and optionally in neutral goblin towns.
--
-- Blacklist: only direct contact counts: they whisper you, invite you to a group, are in your group,
-- open a trade with you, or you exchange mail. Seeing them nearby or in public chat does not alert.
--
-- The combat log is not used: this version of the game reserves it for the Blizzard UI.

local REBUILD_EVERY = 10  -- seconds between refreshes of the approved lists
local SHOW_FOR = 7        -- seconds a pop-up stays on screen
local RESCAN_EVERY = 2.5  -- seconds between re-checks of visible nameplates
local GONE_AFTER = 20     -- seconds out of sight before a Kill on Sight target counts as having left
local NEUTRAL_TOWNS = { ["Booty Bay"] = true, ["Gadgetzan"] = true, ["Ratchet"] = true, ["Everlook"] = true }

local KINDS = {
  kos = {
    title = "KILL ON SIGHT",
    icon = "Interface\\PVPFrame\\PVP-Currency-Horde",
    titleColour = { 1, 0.3, 0.25, 1 },
    bg = { 0.16, 0.03, 0.03, 0.95 },
    border = { 0.9, 0.15, 0.12, 1 },
    setting = "kosAlerts",
    cooldown = 120,
  },
  blacklist = {
    title = "BLACKLISTED PLAYER",
    icon = "Interface\\PVPFrame\\PVP-Currency-Alliance",
    titleColour = { 1, 0.62, 0.2, 1 },
    bg = { 0.16, 0.09, 0.02, 0.95 },
    border = { 0.95, 0.55, 0.12, 1 },
    setting = "blacklistAlerts",
    cooldown = 60,
  },
}

local lists = { kos = { map = {}, at = 0 }, blacklist = { map = {}, at = 0 } }
local lastAlert = {}
local popup

local function enabled(kind)
  local s = CWC_Account and CWC_Account.settings
  return s ~= nil and s[KINDS[kind].setting] ~= false and (not CWC.IsGuildMember or CWC.IsGuildMember())
end

-- Lower-case "first last". A Forever surname sent after a hyphen ("First-Last") still matches.
local function key(name)
  local n = CWC.NormalizeName(name)
  return n and string.lower(n) or nil
end

-- Approved entries for a list, by lower-case full name ("john doe").
local function approved(kind)
  local l = lists[kind]
  if time() - l.at < REBUILD_EVERY then return l.map end
  l.map = {}
  for _, item in ipairs(CWC.RequestStore and CWC.RequestStore(kind) or {}) do
    local k = key(item.name)
    if k and item.status == "approved" then l.map[k] = item end
  end
  l.at = time()
  return l.map
end

local function buildPopup()
  popup = CreateFrame("Button", "CWCAlertPopup", UIParent, "BackdropTemplate")
  popup:SetSize(420, 104)
  popup:SetPoint("TOP", UIParent, "TOP", 0, -150)
  popup:SetFrameStrata("DIALOG")
  popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  popup:Hide()

  popup.icon = popup:CreateTexture(nil, "ARTWORK")
  popup.icon:SetSize(56, 56)
  popup.icon:SetPoint("LEFT", 16, 0)

  popup.title = T.Text(popup, "heading", 18, { 1, 1, 1, 1 })
  popup.title:SetPoint("TOPLEFT", 86, -14)

  popup.line = T.Text(popup, "bold", 15, T.c.gold)
  popup.line:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -6)
  popup.line:SetWidth(316)

  popup.reason = T.Text(popup, "body", 12, T.c.cream)
  popup.reason:SetPoint("TOPLEFT", popup.line, "BOTTOMLEFT", 0, -4)
  popup.reason:SetWidth(316)
  popup.reason:SetWordWrap(true)
  if popup.reason.SetMaxLines then popup.reason:SetMaxLines(2) end

  -- Click anywhere on the pop-up to dismiss it.
  popup:SetScript("OnClick", function(self) self:Hide() end)
end

local function showAlert(kind, item, line)
  local k = KINDS[kind]
  if not popup then buildPopup() end
  popup:SetBackdropColor(k.bg[1], k.bg[2], k.bg[3], k.bg[4])
  popup:SetBackdropBorderColor(k.border[1], k.border[2], k.border[3], k.border[4])
  popup.icon:SetTexture(k.icon)
  popup.title:SetText(k.title)
  popup.title:SetTextColor(k.titleColour[1], k.titleColour[2], k.titleColour[3], 1)
  popup.line:SetText(line)
  popup.reason:SetText(item.reason or "")
  popup:Show()
  popup.shownAt = GetTime()
  local shownAt = popup.shownAt
  C_Timer.After(SHOW_FOR, function()
    if popup.shownAt == shownAt then popup:Hide() end
  end)
  if SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING, "Master") end
  local colour = kind == "kos" and "|cffff5050" or "|cffffa040"
  CWC.Print(colour .. k.title .. ":|r " .. line .. ". " .. (item.reason or ""))
end

-- Checks a name against a list and alerts. "what" describes the contact, e.g. "%s whispered you".
local function check(kind, name, what, cooldown)
  if not enabled(kind) then return end
  local k = key(name)
  if not k or k == key(CWC.PlayerName()) then return end
  local item = approved(kind)[k]
  if not item then return end
  local tag = kind .. ":" .. k .. ":" .. what
  local now = GetTime()
  if lastAlert[tag] and now - lastAlert[tag] < (cooldown or KINDS[kind].cooldown) then return end
  lastAlert[tag] = now
  showAlert(kind, item, string.format(what, item.name or name))
end

local function safeCheck(kind, name, what, cooldown)
  pcall(check, kind, name, what, cooldown)
end

-- Reads a unit's full name, skipping units the game hides during combat.
local function unitName(unit)
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return nil end
  local name = GetUnitName(unit, true)
  if issecretvalue and issecretvalue(name) then return nil end
  return name
end

local function checkUnit(kind, unit, what)
  local ok, name = pcall(unitName, unit)
  if ok and name then safeCheck(kind, name, what) end
end

-- Kill on Sight ---------------------------------------------------------------------------------------

local function inNeutralTown()
  local sub = GetSubZoneText and GetSubZoneText() or ""
  local mini = GetMinimapZoneText and GetMinimapZoneText() or ""
  return NEUTRAL_TOWNS[sub] or NEUTRAL_TOWNS[mini] or false
end

-- Kill on Sight is for the open world: never in dungeons, raids, battlegrounds, arenas or sanctuaries.
local function kosAllowedHere()
  if IsInInstance then
    local ok, inInstance = pcall(IsInInstance)
    if not ok or inInstance then return false end
  end
  local zoneInfo = (C_PvP and C_PvP.GetZonePVPInfo) or GetZonePVPInfo
  if zoneInfo then
    local ok, pvpType = pcall(zoneInfo)
    if ok and pvpType == "sanctuary" then return false end
  end
  if CWC_Account.settings.kosMuteTowns and inNeutralTown() then return false end
  return true
end

local kosLastSeen = {} -- lower-case name -> GetTime() of the latest sighting

local function checkKos(unit)
  local list = approved("kos")
  if not next(list) then return end
  local ok, name = pcall(unitName, unit)
  if not ok or not name then return end
  local k = key(name)
  local item = k and list[k]
  if not item then return end
  -- Only players the game marks as hostile (a wrongly listed friendly player never alerts).
  local okH, friendly = pcall(function() return UnitIsEnemy("player", unit) == false end)
  if okH and friendly then return end

  local now = GetTime()
  local prev = kosLastSeen[k]
  kosLastSeen[k] = now
  if prev and now - prev < GONE_AFTER then return end -- still around since the last alert
  showAlert("kos", item, string.format("%s is nearby", item.name or name))
end

local function checkKosUnit(unit)
  if not unit or not enabled("kos") or not kosAllowedHere() then return end
  pcall(checkKos, unit)
end

-- Re-checks every visible nameplate, so targets already on screen are caught (their "appeared" event
-- only fires once) and the "still around" timer stays fresh while they remain in view.
local function scanNameplates()
  if not enabled("kos") or not next(approved("kos")) or not kosAllowedHere() then return end
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
  local ok, plates = pcall(C_NamePlate.GetNamePlates, false)
  if not ok or type(plates) ~= "table" then return end
  for _, plate in ipairs(plates) do
    pcall(function()
      local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
      if unit then checkKos(unit) end
    end)
  end
end

-- Most missed alerts come from enemy nameplates being switched off, so say so once per session.
local warnedNameplates = false
local function warnIfNameplatesOff()
  if warnedNameplates or not enabled("kos") or not GetCVarBool then return end
  local ok, off = pcall(function() return GetCVarBool("nameplateShowEnemies") == false end)
  if ok and off then
    warnedNameplates = true
    CWC.Print("|cffff5050Kill on Sight alerts need enemy nameplates.|r Press V, or switch on Enemy Nameplates in the game's Options under Nameplates.")
  end
end

CWC.On("NAME_PLATE_UNIT_ADDED", function(unit) checkKosUnit(unit) end)
CWC.On("PLAYER_TARGET_CHANGED", function() checkKosUnit("target") end)
CWC.On("UPDATE_MOUSEOVER_UNIT", function() checkKosUnit("mouseover") end)
-- A player's PvP state or faction can change while they are in view.
local function onUnitChanged(unit)
  if type(unit) ~= "string" then return end
  if unit == "target" or unit:find("^nameplate%d") then checkKosUnit(unit) end
end
CWC.On("UNIT_FLAGS", onUnitChanged)
CWC.On("UNIT_FACTION", onUnitChanged)

CWC.On("PLAYER_LOGIN", function()
  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(RESCAN_EVERY, scanNameplates) end
end)
CWC.On("PLAYER_ENTERING_WORLD", function()
  C_Timer.After(2, function()
    checkKosUnit("target")
    scanNameplates()
  end)
  C_Timer.After(8, warnIfNameplatesOff)
end)

-- Blacklist: direct contact only.
CWC.On("CHAT_MSG_WHISPER", function(_, sender) safeCheck("blacklist", sender, "%s whispered you") end)
CWC.On("PARTY_INVITE_REQUEST", function(inviter) safeCheck("blacklist", inviter, "%s invited you to a group") end)
CWC.On("TRADE_SHOW", function() checkUnit("blacklist", "NPC", "%s opened a trade with you") end)

-- In your group: alert once when they are first seen in the group, again only if they leave and come back.
local inGroup = {}
CWC.On("GROUP_ROSTER_UPDATE", function()
  local seen = {}
  local prefix, count = "party", 4
  if IsInRaid and IsInRaid() then prefix, count = "raid", 40 end
  if (IsInGroup and IsInGroup()) or prefix == "raid" then
    for i = 1, count do
      local ok, name = pcall(unitName, prefix .. i)
      local k = ok and key(name) or nil
      if k then
        seen[k] = true
        if not inGroup[k] then safeCheck("blacklist", name, "%s is in your group", 0) end
      end
    end
  end
  inGroup = seen
end)

-- Mail: checks the inbox when it updates, and warns after sending mail to them.
CWC.On("MAIL_INBOX_UPDATE", function()
  if not GetInboxNumItems or not GetInboxHeaderInfo then return end
  for i = 1, GetInboxNumItems() do
    local ok, _, _, sender = pcall(GetInboxHeaderInfo, i)
    if ok and sender then safeCheck("blacklist", sender, "You have mail from %s", 600) end
  end
end)
if hooksecurefunc and SendMail then
  hooksecurefunc("SendMail", function(recipient)
    safeCheck("blacklist", recipient, "You just sent mail to %s", 0)
  end)
end

-- Settings > Test buttons: show each alert with a sample entry.
function CWC.TestKOSAlert()
  showAlert("kos", { reason = "This is a test alert. Real alerts only fire for approved Kill on Sight entries." }, "John Doe is nearby")
end

function CWC.TestBlacklistAlert()
  showAlert("blacklist", { reason = "This is a test alert. Real alerts only fire for approved Blacklist entries." }, "John Doe whispered you")
end
