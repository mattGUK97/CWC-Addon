local ADDON, CWC = ...

-- "Add to Kill on Sight" on the right-click menu of a Horde player (their target frame or focus frame). One click adds them to the Kill on Sight list as a pending request for the Guild
-- Master or an Officer to approve, with where they were spotted as the reason.
--
-- This uses the game's Menu API (Menu.ModifyMenu), the supported way for addons to add options to
-- these menus. It adds to the menu without changing Blizzard's own code, so it cannot taint it.

-- The player's full "First Last" name. If the game gives only a first name, the surname is taken from
-- UnitFullName, which on WoW: Forever returns it in the second value.
local function fullName(unit)
  local name = GetUnitName(unit, true)
  if issecretvalue and issecretvalue(name) then return nil end
  name = CWC.NormalizeName(name)
  if name and not name:find(" ", 1, true) and UnitFullName then
    local first, second = UnitFullName(unit)
    if not (issecretvalue and (issecretvalue(first) or issecretvalue(second))) then
      if type(first) == "string" and type(second) == "string" and second ~= "" then
        name = CWC.NormalizeName(first .. " " .. second)
      end
    end
  end
  return name
end

local function isHordePlayer(unit)
  if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
  local faction = UnitFactionGroup(unit)
  if issecretvalue and issecretvalue(faction) then return false end
  return faction == "Horde"
end

-- An existing pending or approved entry for this name, if there is one.
local function existingEntry(name)
  local want = string.lower(name)
  for _, item in ipairs(CWC.RequestStore("kos")) do
    local n = CWC.NormalizeName(item.name)
    if n and string.lower(n) == want and (item.status == "pending" or item.status == "approved") then
      return item
    end
  end
  return nil
end

local function whereAmI()
  local zone = GetZoneText and GetZoneText() or ""
  local sub = GetSubZoneText and GetSubZoneText() or ""
  if sub ~= "" and sub ~= zone then return sub .. ", " .. zone end
  return zone ~= "" and zone or "the world"
end

local function addToKillOnSight(name)
  if CWC.IsGuildMember and not CWC.IsGuildMember() then
    CWC.ShowNotInGuild()
    return
  end
  local existing = existingEntry(name)
  if existing then
    local state = existing.status == "approved" and "already on the Kill on Sight list" or "already waiting for approval"
    CWC.Print(name .. " is " .. state .. ".")
    return
  end
  CWC.AddRequest("kos", name, "Spotted in " .. whereAmI(), CWC.PlayerName() or "Unknown", "Horde")
  CWC.Print("|cffff5050" .. name .. "|r added to Kill on Sight. Waiting for the Guild Master or an Officer to approve.")
  if CWC.RefreshList then pcall(CWC.RefreshList, "kos") end
  if CWC.RefreshSidebar then pcall(CWC.RefreshSidebar) end
end

local function extendMenu(owner, root, contextData)
  local unit = contextData and contextData.unit
  if not unit then return end
  local ok, horde = pcall(isHordePlayer, unit)
  if not ok or not horde then return end
  if CWC.IsGuildMember and not CWC.IsGuildMember() then return end
  local okName, name = pcall(fullName, unit)
  if not okName or not name or not name:find(" ", 1, true) then return end

  root:CreateDivider()
  root:CreateTitle("Coping with Caffeine")
  root:CreateButton("Add to Kill on Sight", function() addToKillOnSight(name) end)
end

if Menu and Menu.ModifyMenu then
  -- Each menu has one tag, so a player only ever sees the option once.
  for _, tag in ipairs({ "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS" }) do
    pcall(Menu.ModifyMenu, tag, extendMenu)
  end
end
