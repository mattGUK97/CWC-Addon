local ADDON, CWC = ...
local T = CWC.Theme

-- Guild Master and Officers: change the name or the reason of a Kill on Sight or Blacklist entry,
-- without removing it and adding it again. The change is sent to every online guild mate.

local win

local LIST_NAME = { kos = "Kill on Sight", blacklist = "Blacklist" }

local function label(parent, text, x, y)
  local l = T.Text(parent, "bold", 11, T.c.muted)
  l:SetPoint("TOPLEFT", x, y)
  l:SetText(text)
  return l
end

local function build()
  win = T.Panel(UIParent, T.c.bg, { 0.55, 0.42, 0.24, 1 })
  _G.CWCEditEntry = win
  win:SetSize(560, 300)
  win:SetPoint("TOP", UIParent, "TOP", 0, -160)
  win:SetFrameStrata("FULLSCREEN_DIALOG")
  win:SetClampedToScreen(true)
  win:EnableMouse(true)
  win:SetMovable(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:Hide()
  table.insert(UISpecialFrames, "CWCEditEntry") -- Escape closes it

  local logo = win:CreateTexture(nil, "ARTWORK")
  logo:SetSize(36, 36)
  logo:SetPoint("TOPLEFT", 16, -14)
  logo:SetTexture(CWC.logoPath)
  win.title = T.Text(win, "heading", 16, T.c.gold)
  win.title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
  win.title:SetPoint("RIGHT", win, "RIGHT", -16, 0)

  win.sub = T.Text(win, "body", 12, T.c.muted)
  win.sub:SetPoint("TOPLEFT", 18, -58)
  win.sub:SetPoint("RIGHT", win, "RIGHT", -18, 0)
  win.sub:SetWordWrap(true)

  label(win, "FIRST NAME", 18, -92)
  win.first = T.Input(win, 250, 24)
  win.first:SetPoint("TOPLEFT", 18, -110)
  label(win, "LAST NAME", 290, -92)
  win.last = T.Input(win, 252, 24)
  win.last:SetPoint("TOPLEFT", 290, -110)
  label(win, "REASON OR EVIDENCE", 18, -148)
  win.reason = T.Input(win, 524, 200)
  win.reason:SetPoint("TOPLEFT", 18, -166)

  win.first:SetScript("OnTabPressed", function() win.last:SetFocus() end)
  win.last:SetScript("OnTabPressed", function() win.reason:SetFocus() end)
  win.reason:SetScript("OnTabPressed", function() win.first:SetFocus() end)
  for _, eb in ipairs({ win.first, win.last, win.reason }) do
    eb:SetScript("OnEscapePressed", function() win:Hide() end)
    eb:SetScript("OnEnterPressed", function() win.save:Click() end)
  end

  win.err = T.Text(win, "body", 12, { 1, 0.45, 0.4, 1 })
  win.err:SetPoint("TOPLEFT", win.reason, "BOTTOMLEFT", 0, -8)
  win.err:SetPoint("RIGHT", win, "RIGHT", -18, 0)
  win.err:SetWordWrap(true)

  win.save = T.Button(win, "Save changes", 140, nil, true)
  win.save:SetPoint("BOTTOM", win, "BOTTOM", -76, 16)
  local cancel = T.Button(win, CANCEL or "Cancel", 140, function() win:Hide() end)
  cancel:SetPoint("BOTTOM", win, "BOTTOM", 76, 16)
end

function CWC.ShowEditEntry(key, item)
  if not item then return end
  if not win then build() end
  local first, last = string.match(item.name or "", "^(%S+)%s+(.+)$")
  win.title:SetText("Edit " .. (LIST_NAME[key] or "") .. " entry")
  win.sub:SetText("Fix the name or change the reason. Everyone in the guild with CWC sees the change.")
  win.first:SetText(first or item.name or "")
  win.last:SetText(last or "")
  win.reason:SetText(item.reason or "")
  win.err:SetText("")
  win.save:SetScript("OnClick", function()
    local f = (strtrim(win.first:GetText() or "")):gsub("%s+", "")
    local l = (strtrim(win.last:GetText() or "")):gsub("%s+", "")
    local reason = strtrim(win.reason:GetText() or "")
    if f == "" or l == "" then
      win.err:SetText("Enter the character's first and last name.")
      return
    end
    if reason == "" then
      win.err:SetText("Add a reason or evidence.")
      return
    end
    local name = f .. " " .. l
    if name == item.name and reason == item.reason then
      win:Hide()
      return
    end
    if CWC.EditRequest(key, item.id, name, reason, CWC.PlayerName() or "Unknown") then
      CWC.Print((LIST_NAME[key] or "Entry") .. " entry updated. Sent to online guild members.")
      win:Hide()
      if CWC.RefreshList then CWC.RefreshList(key) end
    end
  end)
  win:Show()
  win:Raise()
  win.reason:SetFocus()
  win.reason:HighlightText(0, 0)
end
