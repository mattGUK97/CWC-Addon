local ADDON, CWC = ...

CWC.version = "0.9.8"
CWC.dataVersion = 1
CWC.guildRuleset = "PvP"
CWC.logoPath = "Interface\\AddOns\\CWC\\media\\cwc-logo.tga"
CWC.colour = "|cffd8a66b"

CWC.handlers = {}
CWC.frame = CreateFrame("Frame")
CWC.frame:SetScript("OnEvent", function(_, event, ...)
  local list = CWC.handlers[event]
  if not list then return end
  -- Each handler runs on its own, so an error in one never stops the others. Errors still reach the
  -- game's error display, so they can be reported.
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, ...)
    if not ok and geterrorhandler then geterrorhandler()(err) end
  end
end)

function CWC.On(event, fn)
  if not CWC.handlers[event] then
    CWC.handlers[event] = {}
    -- An event this game version doesn't have is skipped, rather than stopping the addon loading.
    pcall(CWC.frame.RegisterEvent, CWC.frame, event)
  end
  table.insert(CWC.handlers[event], fn)
end

-- WoW: Forever character names are "First Last". The game sometimes gives the surname where a realm
-- would normally go ("First-Last"), so a hyphen counts as the space between the two names.
function CWC.NormalizeName(name)
  if type(name) ~= "string" then return nil end
  if issecretvalue and issecretvalue(name) then return nil end
  local ok, out = pcall(function()
    local n = name:gsub("%s*%-%s*", " "):gsub("%s+", " ")
    return n:match("^%s*(.-)%s*$")
  end)
  if not ok or not out or out == "" then return nil end
  return out
end

function CWC.Print(msg)
  print(CWC.colour .. "CWC|r: " .. tostring(msg))
end
