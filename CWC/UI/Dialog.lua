local ADDON, CWC = ...
local T = CWC.Theme

-- CWC's own dialog window, used instead of the game's StaticPopup system. Adding entries to StaticPopup
-- can taint it, after which Blizzard's own popups get blocked and the game blames the addon. Keeping
-- every CWC message in this separate window avoids that entirely.

local dialog

local function build()
  dialog = T.Panel(UIParent, T.c.bg, { 0.55, 0.42, 0.24, 1 })
  _G.CWCDialog = dialog
  dialog:SetSize(440, 220)
  dialog:SetPoint("TOP", UIParent, "TOP", 0, -180)
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
  dialog:SetClampedToScreen(true)
  dialog:EnableMouse(true)
  dialog:SetMovable(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:Hide()
  table.insert(UISpecialFrames, "CWCDialog") -- Escape closes it

  dialog.logo = dialog:CreateTexture(nil, "ARTWORK")
  dialog.logo:SetSize(36, 36)
  dialog.logo:SetPoint("TOPLEFT", 16, -14)
  dialog.logo:SetTexture(CWC.logoPath)

  dialog.title = T.Text(dialog, "heading", 16, T.c.gold)
  dialog.title:SetPoint("LEFT", dialog.logo, "RIGHT", 10, 0)
  dialog.title:SetPoint("RIGHT", dialog, "RIGHT", -16, 0)

  dialog.text = T.Text(dialog, "body", 13, T.c.cream)
  dialog.text:SetPoint("TOPLEFT", 18, -62)
  dialog.text:SetWidth(404)
  dialog.text:SetWordWrap(true)
  dialog.text:SetJustifyV("TOP")

  dialog.edit = T.Input(dialog, 404, 200)
  dialog.edit:SetPoint("BOTTOMLEFT", 18, 58)
  dialog.edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
  dialog.edit:SetScript("OnEnterPressed", function() dialog:Hide() end)
  -- Keep the link intact if someone types into it; it is there to copy.
  dialog.edit:SetScript("OnTextChanged", function(self, user)
    if user and self.fixed then
      self:SetText(self.fixed)
      self:HighlightText()
    end
  end)

  dialog.buttons = {}
  for i = 1, 2 do
    local b = T.Button(dialog, "", 130, nil, i == 1)
    dialog.buttons[i] = b
  end
end

-- opts: title, text, editText (optional, shown highlighted for copying), buttons = { { label, onClick } }.
-- The first button is the main one. With no buttons, a single OK button closes the dialog.
function CWC.ShowDialog(opts)
  if not dialog then build() end
  dialog.title:SetText(opts.title or "Coping with Caffeine")
  dialog.text:SetText(opts.text or "")

  local hasEdit = opts.editText ~= nil
  dialog:SetHeight(hasEdit and 250 or 214)
  dialog.edit:SetShown(hasEdit)
  dialog.edit.fixed = opts.editText

  local buttons = opts.buttons or { { label = OKAY or "OK" } }
  for i, b in ipairs(dialog.buttons) do
    local spec = buttons[i]
    if spec then
      b.text:SetText(spec.label)
      b:SetScript("OnClick", function()
        dialog:Hide()
        if spec.onClick then spec.onClick() end
      end)
      b:ClearAllPoints()
      if #buttons == 1 then
        b:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 16)
      else
        b:SetPoint("BOTTOM", dialog, "BOTTOM", i == 1 and -70 or 70, 16)
      end
      b:Show()
    else
      b:Hide()
    end
  end

  dialog:Show()
  dialog:Raise()
  if hasEdit then
    dialog.edit:SetText(opts.editText)
    dialog.edit:SetFocus()
    dialog.edit:HighlightText()
  end
end
