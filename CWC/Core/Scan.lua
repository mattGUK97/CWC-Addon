local ADDON, CWC = ...

-- Guild ranks: index 0 = Guild Master, 1 = Officer, everything else = Member.
-- This assumes the default rank order; check against your guild's ranks in-game.
local function roleFor(rankIndex)
  if rankIndex == 0 then return "Guild Master" end
  if rankIndex == 1 then return "Officer" end
  return "Member"
end

-- Profession names CWC recognises, from any source.
local KNOWN = { ["Alchemy"]=1, ["Blacksmithing"]=1, ["Cooking"]=1, ["Enchanting"]=1, ["Engineering"]=1,
  ["First Aid"]=1, ["Fishing"]=1, ["Herbalism"]=1, ["Leatherworking"]=1, ["Mining"]=1, ["Skinning"]=1, ["Tailoring"]=1 }

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
  -- Check every profession slot, not just the six GetProfessions hands back.
  for _, p in ipairs(CWC.ProbeProfessionSlots()) do
    if KNOWN[p.name] and not have[p.name] and p.max > 0 then
      table.insert(list, { name = p.name, skill = p.skill, max = p.max, kind = "secondary" })
      have[p.name] = true
    end
  end
  -- Values read from the Professions window the last time the player opened it.
  local me = CWC_Characters and CWC_Characters[CWC.PlayerName() or ""]
  if me and me.windowProfs then
    for pname, v in pairs(me.windowProfs) do
      if KNOWN[pname] and not have[pname] and (v.max or 0) > 0 then
        table.insert(list, { name = pname, skill = v.skill or 0, max = v.max, kind = "secondary" })
        have[pname] = true
      end
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
  -- Forever can give the surname after a hyphen ("First-Last"); keep it as "First Last".
  return CWC.NormalizeName(full) or full
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
  for _, p in ipairs(CWC.ProbeProfessionSlots()) do
    CWC.Print(string.format("Profession slot %d: %s %d/%d", p.index, p.name, p.skill, p.max))
  end
  local frames = CWC.FindProfessionFrames()
  CWC.Print("Open profession windows: " .. (#frames > 0 and table.concat(frames, ", ") or "none (open your Professions window, then click this again)"))
  local me = CWC_Characters and CWC_Characters[CWC.PlayerName() or ""]
  if me and me.windowProfs then
    for pname, v in pairs(me.windowProfs) do
      CWC.Print("Saved from Professions window: " .. pname .. " " .. tostring(v.skill) .. "/" .. tostring(v.max))
    end
  end
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

-- Checks every profession slot (1 to 40) directly. GetProfessions only returns six of them.
function CWC.ProbeProfessionSlots()
  local out = {}
  if not GetProfessionInfo then return out end
  for i = 1, 40 do
    local ok, name, _, skill, max = pcall(GetProfessionInfo, i)
    if ok and type(name) == "string" and name ~= "" then
      table.insert(out, { index = i, name = name, skill = tonumber(skill) or 0, max = tonumber(max) or 0 })
    end
  end
  return out
end

-- Reads "First Aid 273/300"-style bars from a window and everything inside it.
local function collectBars(frame, depth, out)
  if not frame or depth > 12 then return end
  local okR, regions = pcall(function() return { frame:GetRegions() } end)
  if okR then
    for _, r in ipairs(regions) do
      local okT, isText = pcall(function() return r:GetObjectType() == "FontString" end)
      if okT and isText then
        local okG, t = pcall(r.GetText, r)
        if okG and type(t) == "string" then
          local n, sk, mx = string.match(t, "^%s*(.-)%s+(%d+)%s*/%s*(%d+)%s*$")
          if n and KNOWN[n] then out[n] = { skill = tonumber(sk), max = tonumber(mx) } end
        end
      end
    end
  end
  local okC, kids = pcall(function() return { frame:GetChildren() } end)
  if okC then
    for _, k in ipairs(kids) do collectBars(k, depth + 1, out) end
  end
end

-- Saves professions shown in the Professions window. With replace, the saved list becomes exactly what
-- the window shows, so a profession that has been unlearned drops off the next time the window opens.
function CWC.CaptureProfessionsWindow(frame, replace)
  local found = {}
  collectBars(frame, 0, found)
  if not next(found) then return 0 end
  local me = CWC_Characters and CWC_Characters[CWC.PlayerName() or ""]
  if not me then return 0 end
  local old = me.windowProfs or {}
  local new = replace and {} or old
  local changed, count = false, 0
  for pname, v in pairs(found) do
    local o = old[pname]
    if not o or o.skill ~= v.skill or o.max ~= v.max then changed = true end
    new[pname] = { skill = v.skill, max = v.max, seen = time() }
    count = count + 1
  end
  me.windowProfs = new
  if changed then
    CWC.ScanCharacter()
    if CWC.RefreshRoster then pcall(CWC.RefreshRoster) end
    if CWC.SendRecords then CWC.SendRecords() end
    local fa = found["First Aid"]
    if fa then CWC.Print("First Aid " .. fa.skill .. "/" .. fa.max .. " saved from the Professions window.") end
  end
  return count
end

-- Names of visible windows that look like a professions window, read for the diagnostics button.
function CWC.FindProfessionFrames()
  local names = {}
  if not EnumerateFrames then return names end
  local f = EnumerateFrames()
  while f do
    local okN, n = pcall(f.GetName, f)
    local okV, vis = pcall(f.IsVisible, f)
    if okN and okV and vis and type(n) == "string" and string.find(n, "Profession") and not string.find(n, "^CWC") then
      if CWC.CaptureProfessionsWindow(f, false) > 0 then table.insert(names, n) end
    end
    f = EnumerateFrames(f)
  end
  return names
end

-- Hook the Professions window so its bars are read every time it opens.
local CANDIDATES = { "ProfessionsBookFrame", "ProfessionsFrame", "TradeSkillFrame", "SpellBookFrame", "PlayerSpellsFrame" }
local hooked = {}
local function hookProfessionWindows()
  for _, n in ipairs(CANDIDATES) do
    local f = _G[n]
    if f and not hooked[n] and f.HookScript then
      hooked[n] = true
      f:HookScript("OnShow", function(self)
        C_Timer.After(0.5, function() CWC.CaptureProfessionsWindow(self, true) end)
        C_Timer.After(2, function() CWC.CaptureProfessionsWindow(self, true) end)
      end)
    end
  end
end
CWC.On("ADDON_LOADED", hookProfessionWindows)
CWC.On("PLAYER_LOGIN", hookProfessionWindows)
