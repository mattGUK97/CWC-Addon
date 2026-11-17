local ADDON, CWC = ...

-- Update notices. WoW addons cannot reach the internet, so the newest version comes from guild mates
-- (see Core\Sync.lua). Once any guild mate runs a newer CWC, this copy warns in chat, in a popup and in
-- the CWC window, and keeps warning at every login until it is updated.

local URL = "https://copingwithcaffeine.mattgtv.co.uk/CWC-Addon"
local RED = "|cffff5050"
local warned = {}

CWC.downloadURL = URL

-- Returns the newer version seen in the guild, or nil when this copy is up to date.
function CWC.UpdateAvailable()
  local latest = CWC_Account and CWC_Account.latestVersion
  if not latest or not latest.version then return nil end
  if CWC.CompareVersions(latest.version, CWC.version) <= 0 then
    CWC_Account.latestVersion = nil -- this copy has caught up
    return nil
  end
  return latest.version
end

local function editBoxOf(popup)
  return popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
end

StaticPopupDialogs["CWC_UPDATE"] = {
  text = "|cffd8a66bCWC UPDATE REQUIRED|r\n\nVersion %s is available. You have %s.\n\n"
    .. "Without it, guild sync can stop working, and the roster may show missing, mismatched or unreliable data.\n\n"
    .. "Copy the link below (Ctrl+C), download the update, replace your Interface\\AddOns\\CWC folder, then /reload.",
  button1 = OKAY or "OK",
  hasEditBox = 1,
  editBoxWidth = 340,
  OnShow = function(self)
    local eb = editBoxOf(self)
    if eb then
      eb:SetText(URL)
      eb:HighlightText()
      eb:SetFocus()
    end
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["CWC_DOWNLOAD_LINK"] = {
  text = "CWC download page\n\nYou're on the newest version CWC has seen in the guild (%s). Copy the link below (Ctrl+C) to share it.",
  button1 = OKAY or "OK",
  hasEditBox = 1,
  editBoxWidth = 340,
  OnShow = StaticPopupDialogs["CWC_UPDATE"].OnShow,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function CWC.ShowUpdatePopup()
  local v = CWC.UpdateAvailable()
  if v then
    StaticPopup_Show("CWC_UPDATE", v, CWC.version)
  else
    StaticPopup_Show("CWC_DOWNLOAD_LINK", CWC.version)
  end
end

local function chatWarning(v)
  CWC.Print(RED .. "UPDATE REQUIRED|r: CWC " .. v .. " is available. You have " .. CWC.version .. ".")
  CWC.Print(RED .. "Without the update, guild sync can stop working and the roster may show missing, mismatched or unreliable data.|r")
  CWC.Print("Download it from " .. URL .. ", replace your Interface\\AddOns\\CWC folder, then /reload.")
end

-- Shows every warning for a newer version once per session, and keeps the window and sidebar current.
function CWC.CheckForUpdate()
  if CWC.GuildState and CWC.GuildState() == "outsider" then return end
  local v = CWC.UpdateAvailable()
  if CWC.RefreshUpdateBanner then pcall(CWC.RefreshUpdateBanner) end
  if CWC.RefreshSidebar then pcall(CWC.RefreshSidebar) end
  if not v or warned[v] then return end
  warned[v] = true
  chatWarning(v)
  CWC.ShowUpdatePopup()
end

-- At login, warn about any newer version seen in an earlier session, even if nobody else is online.
CWC.On("PLAYER_LOGIN", function()
  C_Timer.After(12, function() CWC.CheckForUpdate() end)
end)
