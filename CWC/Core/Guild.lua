local ADDON, CWC = ...

-- CWC is for members of the Coping with Caffeine guild only. At startup it checks the player's guild,
-- and anyone outside it gets a message to contact the Guild Master instead of the addon. The window,
-- setup wizard and guild sync stay locked until the check passes.

CWC.GUILD_NAME = "Coping with Caffeine"
CWC.GUILD_MASTER = "Hello There"

local state = "checking" -- "checking", "member" or "outsider"
local told = false
local settled = false    -- true once the game has had time to load guild details

local function norm(s)
  return string.lower(strtrim(s or ""))
end

function CWC.GuildState()
  return state
end

function CWC.IsGuildMember()
  return state == "member"
end

StaticPopupDialogs["CWC_NOT_IN_GUILD"] = {
  text = "|cffd8a66bCoping with Caffeine|r\n\nSorry, you're not part of the Coping with Caffeine guild.\n\n"
    .. "CWC is a private addon for guild members only. If you'd like to join, or think this is a mistake, "
    .. "please reach out to the Guild Master, " .. CWC.GUILD_MASTER .. ".",
  button1 = OKAY or "OK",
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function CWC.ShowNotInGuild()
  StaticPopup_Show("CWC_NOT_IN_GUILD")
  CWC.Print("|cffff5050Sorry, you're not part of the Coping with Caffeine guild.|r CWC is for guild members only. "
    .. "Please reach out to the Guild Master, " .. CWC.GUILD_MASTER .. ".")
end

-- Works out the player's guild. Until the game has loaded guild details, a missing guild name only
-- counts as "not in the guild" once enough time has passed (final = true).
local function evaluate(final)
  local name = GetGuildInfo("player")
  if name then
    state = (norm(name) == norm(CWC.GUILD_NAME)) and "member" or "outsider"
  elseif not IsInGuild() and (final or settled) then
    state = "outsider"
  else
    return
  end

  if state == "outsider" then
    if CWCWindow and CWCWindow:IsShown() then CWCWindow:Hide() end
    if CWCSetupFrame and CWCSetupFrame:IsShown() then CWCSetupFrame:Hide() end
    if not told then
      told = true
      CWC.ShowNotInGuild()
    end
  else
    told = false
  end
  if CWC.RefreshSidebar then pcall(CWC.RefreshSidebar) end
end

CWC.On("PLAYER_LOGIN", function()
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
  C_Timer.After(3, function() evaluate(false) end)
  C_Timer.After(10, function()
    settled = true
    evaluate(true)
  end)
end)

-- Joining or leaving a guild mid-session updates the check straight away.
CWC.On("PLAYER_GUILD_UPDATE", function() evaluate(false) end)
CWC.On("GUILD_ROSTER_UPDATE", function() evaluate(false) end)
