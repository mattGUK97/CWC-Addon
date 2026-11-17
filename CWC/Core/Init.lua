local ADDON, CWC = ...

CWC.version = "0.9.2"
CWC.dataVersion = 1
CWC.guildRuleset = "PvP"
CWC.logoPath = "Interface\\AddOns\\CWC\\media\\cwc-logo.tga"
CWC.colour = "|cffd8a66b"

CWC.handlers = {}
CWC.frame = CreateFrame("Frame")
CWC.frame:SetScript("OnEvent", function(_, event, ...)
  local list = CWC.handlers[event]
  if not list then return end
  for _, fn in ipairs(list) do fn(...) end
end)

function CWC.On(event, fn)
  if not CWC.handlers[event] then
    CWC.handlers[event] = {}
    CWC.frame:RegisterEvent(event)
  end
  table.insert(CWC.handlers[event], fn)
end

function CWC.Print(msg)
  print(CWC.colour .. "CWC|r: " .. tostring(msg))
end
