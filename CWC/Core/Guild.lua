local ADDON, CWC = ...

-- CWC is for members of the Coping with Caffeine guild only. At startup it checks the player's guild,
-- and anyone outside it gets a message to contact the Guild Master instead of the addon. The window,
-- setup wizard and guild sync stay locked until the check passes.
--
-- The game briefly reports "no guild" at login and during loading screens (for example after using a
-- Hearthstone). So a different guild name counts straight away, but a missing guild only counts once the
-- game has reported it consistently for 15 seconds, and never during a loading screen.

CWC.GUILD_NAME = "Coping with Caffeine"
CWC.GUILD_MASTER = "Hello There"

local CONFIRM_AFTER = 15  -- seconds a missing guild must persist before a member counts as having left

local state = "checking" -- "checking", "member" or "outsider"
local told = false
local settled = false    -- true once the game has had time to load guild details after login
local loading = false    -- true while a loading screen is up
local missingSince       -- when the game first reported no guild, while the player was a member

local function norm(s)
  return string.lower(strtrim(s or ""))
end

function CWC.GuildState()
  return state
end

function CWC.IsGuildMember()
  return state == "member"
end

function CWC.ShowNotInGuild()
  CWC.ShowDialog({
    title = "Coping with Caffeine",
    text = "Sorry, you're not part of the Coping with Caffeine guild.\n\n"
      .. "CWC is a private addon for guild members only. If you'd like to join, or think this is a mistake, "
      .. "please reach out to the Guild Master, " .. CWC.GUILD_MASTER .. ".",
  })
  CWC.Print("|cffff5050Sorry, you're not part of the Coping with Caffeine guild.|r CWC is for guild members only. "
    .. "Please reach out to the Guild Master, " .. CWC.GUILD_MASTER .. ".")
end

local function setState(new)
  state = new
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

local evaluate
evaluate = function(final)
  if loading then return end
  local name = GetGuildInfo("player")
  if name then
    missingSince = nil
    setState(norm(name) == norm(CWC.GUILD_NAME) and "member" or "outsider")
    return
  end
  if IsInGuild() then return end -- in a guild, details still loading

  if state == "member" then
    -- A member who seems to have no guild: wait and check again before believing it.
    if not missingSince then
      missingSince = GetTime()
      C_Timer.After(CONFIRM_AFTER + 1, function() evaluate(true) end)
      return
    end
    if GetTime() - missingSince < CONFIRM_AFTER then return end
    setState("outsider")
  elseif final or settled then
    setState("outsider")
  end
end

CWC.On("PLAYER_LOGIN", function()
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
  C_Timer.After(3, function() evaluate(false) end)
  C_Timer.After(10, function()
    settled = true
    evaluate(true)
  end)
end)

CWC.On("LOADING_SCREEN_ENABLED", function() loading = true end)
CWC.On("LOADING_SCREEN_DISABLED", function()
  loading = false
  C_Timer.After(3, function() evaluate(false) end)
end)

-- Joining or leaving a guild mid-session updates the check (with the confirmation delay above).
CWC.On("PLAYER_GUILD_UPDATE", function() evaluate(false) end)
CWC.On("GUILD_ROSTER_UPDATE", function() evaluate(false) end)
