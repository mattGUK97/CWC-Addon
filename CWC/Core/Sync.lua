local ADDON, CWC = ...

-- Guild sync for Kill on Sight and Blacklist requests.
-- Messages travel as addon messages. Only addon users receive them, and only while online.
-- Approvals are accepted only when the approver is Guild Master or Officer in the guild roster.
-- Any addon user could forge a message, so this is for a trusted private guild, not a secure system.

local PREFIX = "CWCSYNC"
local MAX_LEN = 250
local MAX_DUMP = 150
local KEYS = { kos = true, blacklist = true }

local sendFn = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage

-- Request storage. Every entry gets an id, so the same request is never added twice.
function CWC.RequestStore(key)
  CWC_Account.requests = CWC_Account.requests or {}
  local list = CWC_Account.requests[key] or {}
  CWC_Account.requests[key] = list
  for _, item in ipairs(list) do
    if not item.id then
      item.id = (item.by or "?") .. ":" .. (item.date or 0) .. ":" .. math.random(1000, 9999)
    end
    if not item.status then item.status = "pending" end
  end
  return list
end

local function findById(list, id)
  for _, item in ipairs(list) do
    if item.id == id then return item end
  end
  return nil
end

local function clean(s)
  return (tostring(s or ""):gsub("[|\n\r]", " "))
end

local function baseName(name)
  return (tostring(name or ""):gsub("%-.*$", ""))
end

-- Splits into at most n + 1 parts. The last part keeps any remaining text, so reasons can contain spaces.
local function split(msg, n)
  local out, pos = {}, 1
  for _ = 1, n do
    local s, e = string.find(msg, "|", pos, true)
    if not s then
      table.insert(out, string.sub(msg, pos))
      return out
    end
    table.insert(out, string.sub(msg, pos, s - 1))
    pos = e + 1
  end
  table.insert(out, string.sub(msg, pos))
  return out
end

local function encodeRequest(key, item)
  local head = table.concat({
    "REQ", clean(item.id), key, clean(item.name), clean(item.by), tostring(item.date or 0),
    clean(item.faction or ""), "",
  }, "|")
  local room = MAX_LEN - #head
  return head .. string.sub(clean(item.reason), 1, math.max(0, room))
end

-- Outgoing messages are sent one at a time, so the game does not throttle or drop them.
local queue, busy = {}, false

local function pump()
  local job = table.remove(queue, 1)
  if not job then
    busy = false
    return
  end
  busy = true
  if job.target then
    sendFn(PREFIX, job.msg, "WHISPER", job.target)
  elseif IsInGuild() then
    sendFn(PREFIX, job.msg, "GUILD")
  end
  C_Timer.After(0.3, pump)
end

local function send(msg, target)
  table.insert(queue, { msg = msg, target = target })
  if not busy then pump() end
end

local function requestRoster()
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
  elseif GuildRoster then
    GuildRoster()
  end
end

-- Returns the guild rank index of a member from the roster, or nil if they are not listed.
local function rankOf(name)
  local target = baseName(name)
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  for i = 1, n do
    local full, _, rankIndex = GetGuildRosterInfo(i)
    if full and baseName(full) == target then return rankIndex end
  end
  return nil
end

-- Rank 0 is Guild Master and rank 1 is Officer, in the default rank order.
local function approverAllowed(name)
  local r = rankOf(name)
  return r ~= nil and r <= 1
end

local function refreshUI(key)
  if key == "roster" then
    if CWC.RefreshRoster then pcall(CWC.RefreshRoster) end
    if CWC.RefreshStats then pcall(CWC.RefreshStats) end
  elseif CWC.RefreshList then
    CWC.RefreshList(key)
  end
  if CWC.RefreshSidebar then CWC.RefreshSidebar() end
end

local function applyRequest(key, id, name, by, date, reason, faction)
  if not KEYS[key] or not id or id == "" then return end
  local list = CWC.RequestStore(key)
  if findById(list, id) then return end
  table.insert(list, 1, {
    id = id, name = name, by = by, date = tonumber(date), reason = reason, status = "pending",
    faction = (faction and faction ~= "") and faction or nil,
  })
  refreshUI(key)
end

-- Runs fn(rank) once the approver's rank is known. The guild roster can take a moment to load,
-- so this asks for it and retries rather than silently dropping an officer's denial or approval.
local function whenRankKnown(name, tries, fn)
  local r = rankOf(name)
  if r ~= nil then
    fn(r)
    return
  end
  if tries > 0 then
    requestRoster()
    C_Timer.After(3, function() whenRankKnown(name, tries - 1, fn) end)
  end
end

local function applyDenial(id, key, approver)
  if not KEYS[key] then return end
  whenRankKnown(approver, 5, function(r)
    if r > 1 then return end
    local item = findById(CWC.RequestStore(key), id)
    if not item or item.status == "denied" then return end
    item.status = "denied"
    item.deniedBy = approver
    refreshUI(key)
  end)
end

local function applyApproval(id, key, approver)
  if not KEYS[key] then return end
  whenRankKnown(approver, 5, function(r)
    if r > 1 then return end
    local item = findById(CWC.RequestStore(key), id)
    if not item or item.status == "approved" then return end
    item.status = "approved"
    item.approvedBy = approver
    refreshUI(key)
  end)
end

-- Clears the guild records this computer has received, so they can be rebuilt from scratch.
function CWC.ClearRemote()
  CWC_Account.remote = {}
  refreshUI("roster")
  CWC.Print("Received guild records cleared. Log in alongside your guild mates to receive them again.")
end

-- Sends everything this computer holds to one player, so they catch up after logging in.
local function dumpTo(target)
  for _, key in ipairs({ "kos", "blacklist" }) do
    local list = CWC.RequestStore(key)
    for i = math.min(#list, MAX_DUMP), 1, -1 do
      local item = list[i]
      send(encodeRequest(key, item), target)
      if item.status == "approved" and item.approvedBy then
        send("APP|" .. clean(item.id) .. "|" .. key .. "|" .. clean(item.approvedBy), target)
      end
      if item.status == "denied" and item.deniedBy then
        send("DEN|" .. clean(item.id) .. "|" .. key .. "|" .. clean(item.deniedBy), target)
      end
    end
  end
end

-- Character records. Each character is sent as a CHR line (details) and a PRF line (professions).
local function nonEmpty(v)
  if v == nil or v == "" then return nil end
  return v
end

local function recordMsg(rec)
  local flag = rec.isMain == true and "1" or (rec.isMain == false and "0" or "")
  local msg = table.concat({
    "CHR", clean(rec.name), flag, clean(rec.mainOf), clean(rec.firstName), clean(rec.lastName),
    clean(rec.classFile), clean(rec.className), clean(rec.race), tostring(rec.level or ""),
    tostring(rec.itemLevel or ""), clean(rec.spec), clean(rec.guild), clean(rec.rank), clean(rec.role),
    tostring(rec.lastScanned or 0),
  }, "|")
  return string.sub(msg, 1, MAX_LEN)
end

local function profMsg(rec)
  local parts = {}
  for _, p in ipairs(rec.professions or {}) do
    table.insert(parts, clean(p.name) .. ":" .. tostring(p.skill or 0) .. ":" .. tostring(p.max or 0))
  end
  return string.sub("PRF|" .. clean(rec.name) .. "|" .. table.concat(parts, ","), 1, MAX_LEN)
end

local function sendRecords()
  if not IsInGuild() then return end
  for _, rec in pairs(CWC_Characters or {}) do
    send(recordMsg(rec))
    send(profMsg(rec))
  end
end

local function storeRemote(msg)
  local p = split(msg, 15)
  local name = p[2]
  if not name or name == "" then return end
  if CWC_Characters and CWC_Characters[name] then return end -- this computer's own record wins
  CWC_Account.remote = CWC_Account.remote or {}
  local old = CWC_Account.remote[name] or {}
  local flag = p[3]
  CWC_Account.remote[name] = {
    name = name,
    isMain = flag == "1" and true or (flag == "0" and false or nil),
    mainOf = nonEmpty(p[4]),
    firstName = nonEmpty(p[5]),
    lastName = nonEmpty(p[6]),
    classFile = nonEmpty(p[7]),
    className = nonEmpty(p[8]),
    race = nonEmpty(p[9]),
    level = tonumber(p[10]),
    itemLevel = tonumber(p[11]),
    spec = nonEmpty(p[12]),
    guild = nonEmpty(p[13]),
    rank = nonEmpty(p[14]),
    role = nonEmpty(p[15]),
    lastScanned = tonumber(p[16]),
    professions = old.professions or {},
    remote = true,
  }
  refreshUI("roster")
end

local function storeProfs(msg)
  local p = split(msg, 2)
  local name = p[2]
  local rec = CWC_Account.remote and CWC_Account.remote[name]
  if not rec then return end
  local list = {}
  for entry in string.gmatch(p[3] or "", "[^,]+") do
    local pname, skill, max = string.match(entry, "^(.-):(%d+):(%d+)$")
    if pname then
      table.insert(list, { name = pname, skill = tonumber(skill), max = tonumber(max), kind = "secondary" })
    end
  end
  rec.professions = list
  refreshUI("roster")
end

local function onAddonMessage(prefix, msg, channel, sender)
  if prefix ~= PREFIX then return end
  if not (channel == "GUILD" or channel == "WHISPER") then return end
  local from = baseName(sender)
  if from == "" or from == CWC.PlayerName() then return end
  msg = msg or ""

  if string.sub(msg, 1, 4) == "REQ|" then
    local p = split(msg, 7) -- REQ, id, key, name, by, date, faction, reason
    applyRequest(p[3], p[2], p[4], p[5], p[6], p[8], p[7])
  elseif string.sub(msg, 1, 4) == "DEN|" then
    local p = split(msg, 3) -- DEN, id, key, approver
    applyDenial(p[2], p[3], p[4])
  elseif string.sub(msg, 1, 4) == "APP|" then
    local p = split(msg, 3) -- APP, id, key, approver
    applyApproval(p[2], p[3], p[4])
  elseif string.sub(msg, 1, 4) == "CHR|" then
    storeRemote(msg)
  elseif string.sub(msg, 1, 4) == "PRF|" then
    storeProfs(msg)
  elseif string.sub(msg, 1, 6) == "HELLO|" and channel == "GUILD" then
    -- Several online members may answer. Duplicates are ignored, so this is safe.
    C_Timer.After(1 + math.random() * 4, function()
      dumpTo(from)
      sendRecords()
    end)
  end
end

-- Public API used by the window.
function CWC.SyncStatus()
  if IsInGuild() then return "On" end
  return "Not in a guild"
end

function CWC.AddRequest(key, name, reason, by, faction)
  local item = {
    id = (by or "?") .. ":" .. time() .. ":" .. math.random(1000, 9999),
    name = name,
    reason = reason,
    faction = faction,
    by = by,
    date = time(),
    status = "pending",
  }
  table.insert(CWC.RequestStore(key), 1, item)
  send(encodeRequest(key, item))
  return item
end

function CWC.DenyRequest(key, id, approver)
  local item = findById(CWC.RequestStore(key), id)
  if not item then return false end
  item.status = "denied"
  item.deniedBy = approver
  send("DEN|" .. clean(id) .. "|" .. key .. "|" .. clean(approver))
  return true
end

function CWC.ApproveRequest(key, id, approver)
  local item = findById(CWC.RequestStore(key), id)
  if not item then return false end
  item.status = "approved"
  item.approvedBy = approver
  send("APP|" .. clean(id) .. "|" .. key .. "|" .. clean(approver))
  return true
end

CWC.On("PLAYER_LOGIN", function()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  end
  requestRoster()
  C_Timer.After(6, function()
    if IsInGuild() then send("HELLO|" .. CWC.version) end
  end)
end)

CWC.On("CHAT_MSG_ADDON", onAddonMessage)

CWC.On("PLAYER_LOGIN", function()
  C_Timer.After(8, sendRecords)
  C_Timer.NewTicker(300, sendRecords)
end)

-- All characters the roster knows about: this computer's own, plus records received from guild members.
function CWC.AllRecords()
  local out, seen = {}, {}
  for name, rec in pairs(CWC_Characters or {}) do
    table.insert(out, rec)
    seen[name] = true
  end
  for name, rec in pairs((CWC_Account and CWC_Account.remote) or {}) do
    if not seen[name] then table.insert(out, rec) end
  end
  return out
end

-- Asks online guild members to send their characters, and sends ours. Used by the Settings button.
function CWC.RefreshGuildData()
  if not IsInGuild() then
    CWC.Print("You're not in a guild, so there's nothing to refresh.")
    return
  end
  sendRecords()
  send("HELLO|" .. CWC.version)
  CWC.Print("Asked online guild members to send their characters.")
end

-- Lets other files send this computer's characters to the guild (for example after a profession update).
CWC.SendRecords = sendRecords
