local ADDON, CWC = ...

CWC.On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  CWC.InitStore()
end)

CWC.On("PLAYER_LOGIN", function()
  CWC.CreateMinimapButton()
  local ok, err = pcall(CWC.ScanCharacter)
  if not ok then CWC.Print("Scan error: " .. tostring(err)) end
  CWC.RefreshRoster()

  -- Give the UI a moment to settle before opening the wizard.
  C_Timer.After(2, function()
    local rec = CWC_Characters[CWC.PlayerName()]
    if not CWC_Account.setupComplete then
      CWC.ShowSetup("full")
    elseif rec and not rec.tagged and not rec.tagSkipped then
      CWC.ShowSetup("tag")
    elseif not CWC_Account.experience and not CWC_Account.experienceSkipped then
      -- Players who finished setup before 0.8.0 are asked for their experience once.
      CWC.ShowSetup("experience")
    end
  end)
end)

-- Re-scan when something changes, with a short debounce.
local pending = false
local function queueScan()
  if pending then return end
  pending = true
  C_Timer.After(1, function()
    pending = false
    CWC.ScanCharacter()
    CWC.RefreshRoster()
  end)
end
for _, ev in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_SPECIALIZATION_CHANGED", "SKILL_LINES_CHANGED", "PLAYER_GUILD_UPDATE" }) do
  CWC.On(ev, queueScan)
end

SLASH_CWC1 = "/cwc"
SlashCmdList["CWC"] = function(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "" or msg == "roster" then
    CWC.ToggleRoster()
  elseif msg == "setup" then
    CWC.ShowSetup("full")
  elseif msg == "clearremote" then
    CWC.ClearRemote()
  elseif msg == "profs" then
    CWC.DumpSkills()
  elseif msg == "minimap" then
    CWC.MinimapStatus()
  elseif msg == "minimap reset" then
    CWC.MinimapReset()
  elseif msg == "versions" then
    CWC.PrintGuildVersions()
  elseif msg == "update" then
    CWC.ShowUpdatePopup()
  elseif msg == "scan" then
    CWC.ScanCharacter()
    CWC.RefreshRoster()
    CWC.Print("Character scanned.")
  else
    CWC.Print("Commands: /cwc (roster), /cwc setup, /cwc scan, /cwc versions, /cwc update")
  end
end
