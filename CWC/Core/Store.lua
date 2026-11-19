local ADDON, CWC = ...

function CWC.InitStore()
  CWC_Account = CWC_Account or {}
  local a = CWC_Account
  a.schemaVersion = a.schemaVersion or CWC.dataVersion
  if a.setupComplete == nil then a.setupComplete = false end
  a.settings = a.settings or {}
  local s = a.settings
  if s.minimapShown == nil then s.minimapShown = true end
  if s.shareProfessions == nil then s.shareProfessions = true end
  if s.shareOnline == nil then s.shareOnline = true end
  if s.showTooltips == nil then s.showTooltips = true end
  if s.note == nil then s.note = "" end
  if s.minimapAngle == nil then s.minimapAngle = 220 end
  if s.defaultTab == nil then s.defaultTab = "roster" end
  if s.kosAlerts == nil then s.kosAlerts = true end
  if s.blacklistAlerts == nil then s.blacklistAlerts = true end
  if s.kosMuteTowns == nil then s.kosMuteTowns = false end
  CWC_Characters = CWC_Characters or {}
end
