local ADDON, CWC = ...
local T = CWC.Theme

-- Tabard page: the guild tabard on a 3D model of your character. Drag to turn it, scroll to zoom,
-- right-drag to move it. The game draws the guild's own emblem and colours on the tabard.

local TABARD_SLOT = 19      -- INVSLOT_TABARD
local GUILD_TABARD = 5976   -- the Guild Tabard item, used as a preview when you aren't wearing it
-- Zoom is the camera's distance: 1 is the game's own framing, larger is further away. The default
-- keeps the whole character in view with some room around it.
local ZOOM_DEFAULT, ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 1.45, 0.45, 2.6, 0.12
local CLOSE_UP = { zoom = 0.7, y = -0.45 }

local ui = {}
local view = { facing = 0, zoom = ZOOM_DEFAULT, x = 0, y = 0 }

local function settings() return CWC_Account.settings end

local function wornTabard()
  local ok, link = pcall(GetInventoryItemLink, "player", TABARD_SLOT)
  return ok and link or nil
end

local function applyView()
  local m = ui.model
  if not m then return end
  pcall(m.SetFacing, m, view.facing)
  local ok = m.SetCamDistanceScale and pcall(m.SetCamDistanceScale, m, view.zoom)
  if ok then
    pcall(m.SetPosition, m, 0, view.x, view.y)
  else
    -- No camera control on this client: move the model towards or away from the camera instead.
    pcall(m.SetPosition, m, (1 - view.zoom) * 2.5, view.x, view.y)
  end
end

-- Puts your character on the model, then (if "Tabard only" is ticked) takes everything else off.
local function dress()
  local m = ui.model
  if not m then return end
  pcall(m.SetUnit, m, "player")
  if m.SetSheathed then pcall(m.SetSheathed, m, true) end
  local link = wornTabard()
  if settings().tabardOnly ~= false then
    pcall(m.Undress, m)
    pcall(m.TryOn, m, link or ("item:" .. GUILD_TABARD))
  elseif not link then
    pcall(m.TryOn, m, "item:" .. GUILD_TABARD)
  end
  applyView()
  if link then
    ui.status:SetText("You're wearing the guild tabard. This is how it looks on you.")
  else
    ui.status:SetText("You aren't wearing a tabard right now, so this is a preview of the Guild Tabard. Buy one from a guild tabard vendor in a capital city and equip it to show off the guild colours.")
  end
  if ui.fitControls then C_Timer.After(0, ui.fitControls) end
end

function CWC.RefreshTabard()
  if not ui.page or not ui.page:IsVisible() then return end
  dress()
  -- The model can take a moment to load; dressing it again afterwards makes sure the gear change sticks.
  C_Timer.After(0.2, function() if ui.page:IsVisible() then dress() end end)
end

local function resetView()
  view.facing, view.zoom, view.x, view.y = 0, ZOOM_DEFAULT, 0, 0
  applyView()
end

local function zoom(delta)
  -- Scrolling up (delta 1) zooms in, which brings the camera closer.
  view.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, view.zoom - delta * ZOOM_STEP))
  applyView()
end

local function controlButton(parent, label, w, onClick)
  local b = T.Button(parent, label, w, onClick)
  return b
end

function CWC.BuildTabardPage(page)
  ui.page = page
  local s = settings()
  if s.tabardOnly == nil then s.tabardOnly = true end

  local h = T.Text(page, "heading", 20, T.c.gold)
  h:SetPoint("TOPLEFT", 0, 0)
  h:SetText("Guild Tabard")
  local d = T.Text(page, "body", 13, T.c.muted)
  d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
  d:SetPoint("RIGHT", page, "RIGHT", 0, 0)
  d:SetWordWrap(true)
  d:SetText("The Coping with Caffeine tabard, in 3D on your own character. Turn it, zoom in and take a closer look.")

  -- Controls on the right.
  local side = T.Card(page)
  side:SetPoint("TOPRIGHT", d, "BOTTOMRIGHT", 0, -14)
  side:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
  side:SetWidth(268)
  -- The controls scroll if the window is too short to show them all.
  local area = T.ScrollArea(side, 40)
  area:SetPoint("TOPLEFT", 0, 0)
  area:SetPoint("BOTTOMRIGHT", -4, 6)
  local sc = area.child
  local st = T.Text(sc, "bold", 11, T.c.gold)
  st:SetPoint("TOPLEFT", 16, -14)
  st:SetText("VIEW")
  local sr = T.Rule(sc, 0.3)
  sr:SetPoint("TOPLEFT", 16, -34)
  sr:SetPoint("TOPRIGHT", -16, -34)

  local only = T.Check(sc, "Tabard only (hide my other gear)", function(self)
    settings().tabardOnly = self:GetChecked() and true or false
    CWC.RefreshTabard()
  end)
  only:SetPoint("TOPLEFT", 12, -46)
  only:SetChecked(s.tabardOnly ~= false)
  if only.label then
    only.label:SetPoint("RIGHT", sc, "RIGHT", -14, 0)
    only.label:SetWordWrap(true)
  end

  local BW, GAP = 106, 10
  local left = controlButton(sc, "Turn left", BW, function() view.facing = view.facing + math.pi / 8; applyView() end)
  left:SetPoint("TOPLEFT", 16, -86)
  local right = controlButton(sc, "Turn right", BW, function() view.facing = view.facing - math.pi / 8; applyView() end)
  right:SetPoint("LEFT", left, "RIGHT", GAP, 0)
  local zin = controlButton(sc, "Zoom in", BW, function() zoom(1) end)
  zin:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -GAP)
  local zout = controlButton(sc, "Zoom out", BW, function() zoom(-1) end)
  zout:SetPoint("LEFT", zin, "RIGHT", GAP, 0)
  local front = controlButton(sc, "Front", BW, function() view.facing = 0; applyView() end)
  front:SetPoint("TOPLEFT", zin, "BOTTOMLEFT", 0, -GAP)
  local back = controlButton(sc, "Back", BW, function() view.facing = math.pi; applyView() end)
  back:SetPoint("LEFT", front, "RIGHT", GAP, 0)
  local close = controlButton(sc, "Close-up", BW, function()
    view.facing, view.zoom, view.x, view.y = 0, CLOSE_UP.zoom, 0, CLOSE_UP.y
    applyView()
  end)
  close:SetPoint("TOPLEFT", front, "BOTTOMLEFT", 0, -GAP)
  local reset = controlButton(sc, "Reset", BW, function() resetView() end)
  reset:SetPoint("LEFT", close, "RIGHT", GAP, 0)

  local ht = T.Text(sc, "bold", 11, T.c.gold)
  ht:SetPoint("TOPLEFT", close, "BOTTOMLEFT", 0, -22)
  ht:SetText("MOUSE")
  local help = T.Text(sc, "body", 12, T.c.cream)
  help:SetPoint("TOPLEFT", ht, "BOTTOMLEFT", 0, -6)
  help:SetPoint("RIGHT", sc, "RIGHT", -16, 0)
  help:SetWordWrap(true)
  help:SetSpacing(3)
  help:SetText("Drag: turn the model\nScroll: zoom in and out\nRight-drag: move the model")

  ui.status = T.Text(sc, "body", 12, T.c.muted)
  ui.status:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)
  ui.status:SetPoint("RIGHT", sc, "RIGHT", -16, 0)
  ui.status:SetWordWrap(true)

  -- The scroll height follows the last line of text, once it has been laid out.
  local function fitControls()
    local top, bottom = sc:GetTop(), ui.status:GetBottom()
    if top and bottom then sc:SetHeight(math.max(1, top - bottom + 16)) end
    area.bar.Update()
  end
  ui.fitControls = fitControls
  area.sf:HookScript("OnSizeChanged", function() C_Timer.After(0, fitControls) end)

  -- The model, on a dark stage with a soft gold glow behind it.
  local stage = T.Card(page)
  stage:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  stage:SetPoint("BOTTOMRIGHT", side, "BOTTOMLEFT", -12, 0)
  local mark = stage:CreateTexture(nil, "BORDER")
  mark:SetTexture(CWC.logoPath)
  mark:SetSize(260, 260)
  mark:SetPoint("CENTER", 0, 10)
  mark:SetAlpha(0.06)

  local m = CreateFrame("DressUpModel", nil, stage)
  m:SetPoint("TOPLEFT", 2, -2)
  m:SetPoint("BOTTOMRIGHT", -2, 2)
  m:EnableMouse(true)
  m:EnableMouseWheel(true)
  ui.model = m

  local dragging, lastX, lastY
  m:SetScript("OnMouseDown", function(self, button)
    dragging = button
    lastX, lastY = GetCursorPosition()
  end)
  m:SetScript("OnMouseUp", function() dragging = nil end)
  m:SetScript("OnHide", function() dragging = nil end)
  m:SetScript("OnUpdate", function(self)
    if not dragging then return end
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    local dx, dy = (x - lastX) / scale, (y - lastY) / scale
    lastX, lastY = x, y
    if dragging == "LeftButton" then
      view.facing = view.facing + dx * 0.012
    elseif dragging == "RightButton" then
      view.x = view.x + dx * 0.006
      view.y = view.y + dy * 0.006
    end
    applyView()
  end)
  m:SetScript("OnMouseWheel", function(_, delta) zoom(delta) end)
  if m.HasScript and m:HasScript("OnModelLoaded") then
    m:SetScript("OnModelLoaded", function() applyView() end)
  end

  page:SetScript("OnShow", function() CWC.RefreshTabard() end)
end

-- Gear changes (such as putting the tabard on) show straight away if the page is open.
CWC.On("PLAYER_EQUIPMENT_CHANGED", function(slot)
  if slot == TABARD_SLOT or not slot then CWC.RefreshTabard() end
end)
