local ADDON, CWC = ...

-- WoW: Forever raids and their attunements. Quest IDs and quest givers come from the WoW: Forever
-- quest data (Onyxia's attunement is unchanged from Classic). New raids are added to this list as
-- they are announced.
CWC.RAIDS = {
  {
    key = "onyxia",
    name = "Onyxia's Lair",
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
    size = 40, bosses = 1, level = 60,
    opens = { 2026, 12, 9 },
    location = "Wyrmbog, southern Dustwallow Marsh (52.3, 76.2)",
    about = "Onyxia, daughter of Deathwing, waits in her lair in a three-phase fight. Bring fire resistance.",
    attunement = "onyxia",
  },
  {
    key = "hyjal",
    name = "Hyjal Summit",
    icon = "Interface\\Icons\\Spell_Nature_ProtectionformNature",
    size = 20, bosses = 13, level = 60,
    opens = { 2026, 12, 9 },
    location = "The summit of Mount Hyjal, near the World Tree, Nordrassil",
    about = "The first fight is against an ancient guardian. After that, the raid picks its own route across the mountain, through ruins above and below ground, to reach the final encounters.",
  },
  {
    key = "barrow",
    name = "The Barrow Deeps",
    icon = "Interface\\Icons\\Spell_Shadow_Twilight",
    size = 10, bosses = 8, level = 60,
    opens = { 2026, 12, 9 },
    location = "Beneath Mount Hyjal. Entrances from Mount Hyjal, Winterspring and Blackmaw Hold",
    about = "Illidan's old prison beneath Kalimdor, with several ways in.",
  },
}

-- Alliance attunement chains. Each step is one quest, in order.
CWC.ATTUNEMENTS = {
  onyxia = {
    name = "Drakefire Amulet",
    item = 16309, -- the Drakefire Amulet: having it in your bags (or bank) is what lets you in
    startLevel = 48,
    steps = {
      { id = 4182, title = "Dragonkin Menace", who = "Helendis Riverhorn", where = "Morgan's Vigil, Burning Steppes (85.8, 69.0)",
        text = "Kill 15 Black Broodlings and 10 Black Dragonspawn in the Burning Steppes, then return to Helendis Riverhorn." },
      { id = 4183, title = "The True Masters (1 of 6)", who = "Magistrate Solomon", where = "Lakeshire, Redridge Mountains (24.9, 44.4)",
        text = "Take Helendis Riverhorn's letter to Magistrate Solomon in Lakeshire." },
      { id = 4184, title = "The True Masters (2 of 6)", who = "Highlord Bolvar Fordragon", where = "Stormwind Keep, Stormwind (78.2, 18.1)",
        text = "Take Solomon's plea to Highlord Bolvar Fordragon in Stormwind Keep." },
      { id = 4185, title = "The True Masters (3 of 6)", who = "Lady Katrana Prestor", where = "Stormwind Keep, Stormwind (78.2, 18.1)",
        text = "Ask Lady Katrana Prestor, beside Bolvar, for her advice, then speak to Bolvar again." },
      { id = 4186, title = "The True Masters (4 of 6)", who = "Magistrate Solomon", where = "Lakeshire, Redridge Mountains (24.9, 44.4)",
        text = "Take Bolvar's Decree back to Magistrate Solomon in Lakeshire." },
      { id = 4223, title = "The True Masters (5 of 6)", who = "Marshal Maxwell", where = "Morgan's Vigil, Burning Steppes (84.7, 69.0)",
        text = "Magistrate Solomon sends you to Marshal Maxwell at Morgan's Vigil." },
      { id = 4224, title = "The True Masters (6 of 6)", who = "Ragged John", where = "Northern Burning Steppes (65.0, 23.8)",
        text = "Hear Ragged John's story, then return to Marshal Maxwell at Morgan's Vigil." },
      { id = 4241, title = "Marshal Windsor", who = "Marshal Windsor", where = "Blackrock Depths (dungeon)",
        text = "Find Marshal Windsor, held in a cell in Blackrock Depths." },
      { id = 4242, title = "Abandoned Hope", who = "Marshal Maxwell", where = "Morgan's Vigil, Burning Steppes (84.7, 69.0)",
        text = "Marshal Windsor sends you back to Marshal Maxwell with the bad news." },
      { id = 4264, title = "A Crumpled Up Note", who = "Marshal Windsor", where = "Blackrock Depths (dungeon)",
        text = "Loot A Crumpled Up Note from enemies in Blackrock Depths, then take it to Marshal Windsor in his cell." },
      { id = 4282, title = "A Shred of Hope", who = "Marshal Windsor", where = "Blackrock Depths (dungeon)",
        text = "Recover Windsor's lost information from Golem Lord Argelmach and General Angerforge in Blackrock Depths." },
      { id = 4322, title = "Jail Break!", who = "Marshal Maxwell", where = "Blackrock Depths, then Morgan's Vigil",
        text = "Free Marshal Windsor and escort him out of Blackrock Depths, then report to Marshal Maxwell." },
      { id = 6402, title = "Stormwind Rendezvous", who = "Squire Rowe", where = "Outside the Stormwind city gates",
        text = "Marshal Maxwell sends you to Stormwind. Speak to Squire Rowe at the city gates to call Reginald Windsor." },
      { id = 6403, title = "The Great Masquerade", who = "Reginald Windsor", where = "Stormwind (64.7, 76.8)",
        text = "Follow Reginald Windsor into Stormwind Keep. Let Bolvar take on the dragons; bringing friends helps." },
      { id = 6501, title = "The Dragon's Eye", who = "Haleh", where = "Mazthoril, Winterspring (54.6, 51.2)",
        text = "Bolvar sends you to Haleh in Winterspring. Use the blue rune inside the cave at Mazthoril to reach her." },
      { id = 6502, title = "Drakefire Amulet", who = "Haleh", where = "Upper Blackrock Spire, then Winterspring",
        text = "Kill General Drakkisath in Upper Blackrock Spire for the Blood of the Black Dragon Champion, then take it to Haleh for the Drakefire Amulet." },
    },
  },
}

local function questDone(id)
  local ok, done = pcall(function()
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) end
    if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) end
    return false
  end)
  return ok and done == true
end

local function questInLog(id)
  local ok, found = pcall(function()
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
      local i = C_QuestLog.GetLogIndexForQuestID(id)
      return i ~= nil and i > 0
    end
    if C_QuestLog and C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id) end
    return false
  end)
  return ok and found == true
end

local function hasItem(id)
  local ok, n = pcall(function()
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id, true) end
    return GetItemCount(id, true)
  end)
  return ok and (tonumber(n) or 0) > 0
end

-- Where this character is in an attunement chain.
-- Returns { done = steps finished, total, attuned, current = the step to do next, inLog }.
function CWC.AttuneProgress(key)
  local chain = CWC.ATTUNEMENTS[key]
  if not chain then return nil end
  local total = #chain.steps
  local done = 0
  for i = total, 1, -1 do
    if questDone(chain.steps[i].id) then
      done = i
      break
    end
  end
  local attuned = done >= total or (chain.item and hasItem(chain.item))
  if attuned then done = total end
  local current = not attuned and (done + 1) or nil
  return {
    done = done, total = total, attuned = attuned, current = current,
    inLog = current and questInLog(chain.steps[current].id) or false,
  }
end

-- "Opens 9 December" until the date, then "Open".
function CWC.RaidOpen(raid)
  local o = raid.opens
  if not o then return true end
  local now = tonumber(date("%Y%m%d")) or 0
  return now >= o[1] * 10000 + o[2] * 100 + o[3]
end

-- Saves this character's attunement progress on its record, so guild mates can see it. When it
-- changes, the record is shared again straight away.
local sendPending = false
function CWC.UpdateOwnAttunement()
  local me = CWC.PlayerName and CWC.PlayerName()
  local rec = me and CWC_Characters and CWC_Characters[me]
  if not rec then return end
  rec.attune = rec.attune or {}
  local changed = false
  for key in pairs(CWC.ATTUNEMENTS) do
    local p = CWC.AttuneProgress(key)
    if p and rec.attune[key] ~= p.done then
      rec.attune[key] = p.done
      changed = true
    end
  end
  if changed then
    rec.lastScanned = time()
    if CWC.RefreshRaid then CWC.RefreshRaid() end
    if not sendPending and CWC.SendOwnRecords then
      sendPending = true
      C_Timer.After(5, function()
        sendPending = false
        CWC.SendOwnRecords()
      end)
    end
  end
end

local function soon()
  C_Timer.After(1, function() CWC.UpdateOwnAttunement() end)
end
CWC.On("PLAYER_LOGIN", function() C_Timer.After(8, function() CWC.UpdateOwnAttunement() end) end)
CWC.On("QUEST_TURNED_IN", soon)
CWC.On("QUEST_ACCEPTED", function() if CWC.RefreshRaid then C_Timer.After(0.5, CWC.RefreshRaid) end end)
CWC.On("QUEST_REMOVED", function() if CWC.RefreshRaid then C_Timer.After(0.5, CWC.RefreshRaid) end end)
local bagTimer
CWC.On("BAG_UPDATE_DELAYED", function()
  if bagTimer then return end
  bagTimer = true
  C_Timer.After(3, function()
    bagTimer = nil
    CWC.UpdateOwnAttunement()
  end)
end)
