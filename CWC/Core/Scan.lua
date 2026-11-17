local ADDON, CWC = ...

-- Guild ranks: index 0 = Guild Master, 1 = Officer, everything else = Member.
-- This assumes the default rank order; check against your guild's ranks in-game.
local function roleFor(rankIndex)
  if rankIndex == 0 then return "Guild Master" end
  if rankIndex == 1 then return "Officer" end
  return "Member"
end

local function readProfessions()
  local list = {}
  if not GetProfessions or not GetProfessionInfo then return list end
  local prof1, prof2, _, fishing, cooking, firstAid = GetProfessions()
  local function add(index, kind)
    if not index then return end
    local name, _, skill, maxSkill = GetProfessionInfo(index)
    if name then
      table.insert(list, { name = name, skill = skill or 0, max = maxSkill or 0, kind = kind })
    end
  end
  add(prof1, "primary")
  add(prof2, "primary")
  add(fishing, "secondary")
  add(cooking, "secondary")
  add(firstAid, "secondary")

  -- Fallback: some profession slots are not reported by GetProfessions, so check the full skill list too.
  local known = { ["Alchemy"]=1, ["Blacksmithing"]=1, ["Cooking"]=1, ["Enchanting"]=1, ["Engineering"]=1,
    ["First Aid"]=1, ["Fishing"]=1, ["Herbalism"]=1, ["Leatherworking"]=1, ["Mining"]=1, ["Skinning"]=1, ["Tailoring"]=1 }
  local have = {}
  for _, p in ipairs(list) do have[p.name] = true end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
      if name and not isHeader and known[name] and not have[name] then
        table.insert(list, { name = name, skill = rank or 0, max = maxRank or 0, kind = "secondary" })
        have[name] = true
      end
    end
  end
  -- The Professions window reads from the trade skill API, which lists First Aid even when GetProfessions does not.
  for _, p in ipairs(CWC.ReadTradeSkillLines()) do
    if known[p.name] and not have[p.name] then
      table.insert(list, { name = p.name, skill = p.skill, max = p.max, kind = "secondary" })
      have[p.name] = true
    end
  end
  return list
end

local function readSpec()
  if not GetSpecialization or not GetSpecializationInfo then return nil end
  local index = GetSpecialization()
  if not index then return nil end
  local _, specName = GetSpecializationInfo(index)
  return specName
end

-- Full character name, e.g. "Crippling Anxiety". Forever characters have a first and last name.
-- UnitName returns only the first name, so GetUnitName(unit, true) is used.
function CWC.PlayerName()
  local full = GetUnitName and GetUnitName("player", true) or UnitName("player")
  if not full or full == "" then return nil end
  full = full:gsub("%-.*$", "")  -- drop any realm suffix; Forever is realmless
  return full
end

function CWC.ScanCharacter()
  local name = CWC.PlayerName()
  if not name or name == "" or not CWC_Characters then return nil end

  -- Records saved by the first build were keyed by first name only. Move them across.
  local rec = CWC_Characters[name]
  local legacy = UnitName("player")
  if not rec and legacy and legacy ~= name and CWC_Characters[legacy] then
    rec = CWC_Characters[legacy]
    CWC_Characters[legacy] = nil
  end
  rec = rec or {}

  local first, last = string.match(name, "^(%S+)%s+(.+)$")
  rec.firstName = first or name
  rec.lastName = last
  local className, classFile = UnitClass("player")
  local raceName = UnitRace("player")
  local guildName, rankName, rankIndex = GetGuildInfo("player")
  local ilvl = GetAverageItemLevel and GetAverageItemLevel() or nil

  rec.name = name
  rec.ruleset = CWC.guildRuleset
  rec.race = raceName
  rec.className = className
  rec.classFile = classFile
  rec.spec = readSpec()
  rec.level = UnitLevel("player")
  if ilvl then rec.itemLevel = math.floor(ilvl) end
  rec.professions = readProfessions()
  rec.guild = guildName
  rec.rank = rankName
  rec.rankIndex = rankIndex
  rec.role = guildName and roleFor(rankIndex) or nil
  rec.lastScanned = time()
  if rec.tagged == nil then rec.tagged = false end

  CWC_Characters[name] = rec
  return rec
end

-- /cwc profs: prints every skill line the client reports, to find out why a profession is missing.
function CWC.DumpSkills()
  for _, p in ipairs(CWC.ReadTradeSkillLines()) do
    CWC.Print("Trade skill: " .. p.name .. " id " .. p.id .. " " .. p.skill .. "/" .. p.max)
  end
  local a = { GetProfessions() }
  CWC.Print("GetProfessions: " .. table.concat({ tostring(a[1]), tostring(a[2]), tostring(a[3]),
    tostring(a[4]), tostring(a[5]), tostring(a[6]) }, " | "))
  CWC.Print("Spellbook entries named First Aid: " .. #CWC.FindSpellNamed("First Aid"))
  CWC.Print("C_SpellBook skill lines: " .. tostring(C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines()))
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "spell"
    for t = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(t)
      if line then
        local names, first = {}, line.itemIndexOffset or 0
        for i = first + 1, first + (line.numSpellBookItems or 0) do
          local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
          if info and info.name then table.insert(names, info.name) end
        end
        CWC.Print("  line " .. t .. ": " .. tostring(line.name) .. " (" .. #names .. " spells)")
        if #names <= 40 then CWC.Print("    " .. table.concat(names, ", ")) end
      end
    end
  end
  local tabs = GetNumSpellTabs and GetNumSpellTabs() or 0
  CWC.Print("Spell tabs: " .. tabs)
  for t = 1, tabs do
    local tabName, _, offset, numSlots = GetSpellTabInfo(t)
    CWC.Print("  tab " .. t .. ": " .. tostring(tabName) .. " slots " .. tostring(numSlots))
  end
  local n = GetNumSkillLines and GetNumSkillLines() or 0
  CWC.Print("Skill lines: " .. n)
  for i = 1, n do
    local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
    CWC.Print(string.format("%d. %s header=%s %s/%s", i, tostring(name), tostring(isHeader),
      tostring(rank), tostring(maxRank)))
  end
end

-- Returns the spellbook slots whose name matches target (for example "First Aid").
-- Uses the C_SpellBook API, because the older GetSpellBookItemName no longer exists on this client.
function CWC.FindSpellNamed(target)
  local found = {}
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return found end
  local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "spell"
  local ok = pcall(function()
    for t = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(t)
      if line then
        local first = line.itemIndexOffset or 0
        for i = first + 1, first + (line.numSpellBookItems or 0) do
          local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
          if info and info.name == target then table.insert(found, i) end
        end
      end
    end
  end)
  if not ok then return found end
  return found
end

-- Reads the learned professions from the trade skill API (the same data the Professions window uses).
function CWC.ReadTradeSkillLines()
  local out = {}
  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines) then return out end
  local ok, ids = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
  if not ok or type(ids) ~= "table" then return out end
  for _, id in ipairs(ids) do
    local ok2, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
    if ok2 and type(info) == "table" and info.professionName and (info.maxSkillLevel or 0) > 0 then
      table.insert(out, { id = id, name = info.professionName,
        skill = info.skillLevel or 0, max = info.maxSkillLevel or 0 })
    end
  end
  return out
end
