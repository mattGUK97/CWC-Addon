local ADDON, CWC = ...
local T = CWC.Theme

-- Kill on Sight alerts. When a player on the approved Kill on Sight list comes into view, CWC plays a short
-- warning sound and shows a red pop-up with their name and the reason.
--
-- How a player is spotted: their nameplate appearing (enemy players within about 40 yards, when enemy
-- nameplates are switched on), or targeting or mousing over them. Each player alerts at most once every
-- two minutes, so a fight does not spam the alert.
--
-- The combat log is not used: this version of the game reserves it for the Blizzard UI, and registering
-- for it makes the game block the addon.

local COOLDOWN = 120       -- seconds between alerts for the same player
local SHOW_FOR = 7         -- seconds the pop-up stays on screen
local REBUILD_EVERY = 10   -- seconds between refreshes of the approved list

local lookup, builtAt = {}, 0
local lastAlert = {}
local popup

local function enabled()
  return CWC_Account and CWC_Account.settings and CWC_Account.settings.kosAlerts ~= false
    and (not CWC.IsGuildMember or CWC.IsGuildMember())
end

local function key(name)
  if type(name) ~= "string" or name == "" then return nil end
  return string.lower(strtrim((name:gsub("%-.*$", ""))))
end

-- Approved Kill on Sight entries, by lower-case full name ("john doe").
local function approvedList()
  if time() - builtAt < REBUILD_EVERY then return lookup end
  lookup = {}
  for _, item in ipairs(CWC.RequestStore and CWC.RequestStore("kos") or {}) do
    local k = key(item.name)
    if k and item.status == "approved" then lookup[k] = item end
  end
  builtAt = time()
  return lookup
end

local function buildPopup()
  popup = CreateFrame("Button", "CWCKillOnSightAlert", UIParent, "BackdropTemplate")
  popup:SetSize(400, 100)
  popup:SetPoint("TOP", UIParent, "TOP", 0, -150)
  popup:SetFrameStrata("DIALOG")
  popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
  popup:SetBackdropColor(0.16, 0.03, 0.03, 0.95)
  popup:SetBackdropBorderColor(0.9, 0.15, 0.12, 1)
  popup:Hide()

  local icon = popup:CreateTexture(nil, "ARTWORK")
  icon:SetSize(56, 56)
  icon:SetPoint("LEFT", 16, 0)
  icon:SetTexture("Interface\\PVPFrame\\PVP-Currency-Horde")

  popup.title = T.Text(popup, "heading", 18, { 1, 0.3, 0.25, 1 })
  popup.title:SetPoint("TOPLEFT", 86, -14)
  popup.title:SetText("KILL ON SIGHT")

  popup.name = T.Text(popup, "bold", 15, T.c.gold)
  popup.name:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -6)

  popup.reason = T.Text(popup, "body", 12, T.c.cream)
  popup.reason:SetPoint("TOPLEFT", popup.name, "BOTTOMLEFT", 0, -4)
  popup.reason:SetWidth(296)
  popup.reason:SetWordWrap(true)
  if popup.reason.SetMaxLines then popup.reason:SetMaxLines(2) end

  -- Click anywhere on the pop-up to dismiss it.
  popup:SetScript("OnClick", function(self) self:Hide() end)
end

local function showAlert(item, seenName)
  if not popup then buildPopup() end
  popup.name:SetText((seenName or item.name or "?") .. " is nearby")
  popup.reason:SetText(item.reason or "")
  popup:SetAlpha(1)
  popup:Show()
  popup.shownAt = GetTime()
  local shownAt = popup.shownAt
  C_Timer.After(SHOW_FOR, function()
    if popup.shownAt == shownAt then popup:Hide() end
  end)
  if SOUNDKIT and SOUNDKIT.RAID_WARNING then
    pcall(PlaySound, SOUNDKIT.RAID_WARNING, "Master")
  end
  CWC.Print("|cffff5050Kill on Sight:|r " .. (seenName or item.name or "?") .. " is nearby. " .. (item.reason or ""))
end

-- Checks one name against the approved list and alerts, respecting the per-player cooldown.
local function checkName(name)
  if not enabled() then return end
  local k = key(name)
  if not k then return end
  local item = approvedList()[k]
  if not item then return end
  local now = GetTime()
  if lastAlert[k] and now - lastAlert[k] < COOLDOWN then return end
  lastAlert[k] = now
  showAlert(item, name)
end

-- The game can hide some unit details during combat ("secret" values). Those are skipped, and any
-- unexpected error is contained so it can never interrupt play.
local function readUnitName(unit)
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return nil end
  local name = GetUnitName(unit, true)
  if issecretvalue and issecretvalue(name) then return nil end
  return name
end

local function checkUnit(unit)
  local ok, name = pcall(readUnitName, unit)
  if ok and name then pcall(checkName, name) end
end

CWC.On("NAME_PLATE_UNIT_ADDED", function(unit) checkUnit(unit) end)
CWC.On("PLAYER_TARGET_CHANGED", function() checkUnit("target") end)
CWC.On("UPDATE_MOUSEOVER_UNIT", function() checkUnit("mouseover") end)


-- Settings > Test: shows the alert with a sample entry, so players know what to expect.
function CWC.TestKOSAlert()
  showAlert({ name = "John Doe", reason = "This is a test alert. Real alerts only fire for approved Kill on Sight entries." }, "John Doe")
end
