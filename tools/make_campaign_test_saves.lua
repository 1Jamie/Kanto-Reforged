#!/usr/bin/env luajit
-- Build progressive Gold test saves for the Gen2 Kanto Rocket campaign.
-- Clones ~/.local/share/love/pokemon-love2d/saves/gold/slot2.lua by default.
-- Does NOT touch modData["Kanto-Reforged"].level_caps_on.
--
-- Usage (from gen1recomp repo root):
--   luajit mods/Kanto-Reforged/tools/make_campaign_test_saves.lua
--   luajit mods/Kanto-Reforged/tools/make_campaign_test_saves.lua --install

package.path = "./?.lua;./?/init.lua;" .. package.path

local SaveSerializer = require("src.core.SaveSerializer")

local HOME = os.getenv("HOME") or ""
local BASE = HOME .. "/.local/share/love/pokemon-love2d/saves/gold/slot2.lua"
local OUT_DIR = "mods/Kanto-Reforged/test_saves/gold"
local INSTALL_DIR = HOME .. "/.local/share/love/pokemon-love2d/saves/gold"

local FLAGS = {
  MT_MOON_ROCKETS_CLEARED = 3001,
  ROCK_TUNNEL_ROCKETS_CLEARED = 3002,
  SAFARI_UNLOCKED = 3003,
  SAFARI_ROCKETS_CLEARED = 3004,
  ROUTE22_BLUE_MET = 3005,
}

local KANTO_BADGES = {
  "BOULDER", "CASCADE", "THUNDER", "RAINBOW",
  "SOUL", "MARSH", "VOLCANO", "EARTH",
}

local ENGINE_KANTO = {
  BOULDER = 34, CASCADE = 35, THUNDER = 36, RAINBOW = 37,
  SOUL = 38, MARSH = 39, VOLCANO = 40, EARTH = 41,
}

local JOHTO_BADGES = {
  "ZEPHYR", "HIVE", "PLAIN", "FOG",
  "STORM", "MINERAL", "GLACIER", "RISING",
}

local function deepcopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, val in pairs(v) do
    out[deepcopy(k)] = deepcopy(val)
  end
  return out
end

local function setEventBit(events, id, on)
  local byte = math.floor(id / 8)
  local bitn = id % 8
  local mask = 2 ^ bitn
  local row = events[byte] or 0
  local has = math.floor(row / mask) % 2 == 1
  if on and not has then
    events[byte] = row + mask
  elseif not on and has then
    events[byte] = row - mask
  end
end

local function setEvents(save, ids)
  save.events = save.events or {}
  for _, id in ipairs(ids) do
    setEventBit(save.events, id, true)
  end
end

-- Custom event IDs used by restored *_KR dungeon trainers/items and campaign
-- overlays. The base slot2 clone often has these already set from playtesting.
local function collectKrTrainerEventIds()
  local ids = {}
  local seen = {}
  local function add(id)
    id = tonumber(id)
    if not id or seen[id] then return end
    -- Keep campaign chapter flags (3001–3006) out of the wipe list; those are
    -- set explicitly per beat. Trainer overlay IDs start at 3010+.
    if id >= 3001 and id <= 3006 then return end
    seen[id] = true
    ids[#ids + 1] = id
  end
  local paths = {
    "mods/Kanto-Reforged/world/restored_dungeons.lua",
    "mods/Kanto-Reforged/world/restored_dungeons_data.lua",
    "mods/Kanto-Reforged/world/kanto_campaign.lua",
    "mods/Kanto-Reforged/world/kanto_campaign_content.lua",
  }
  for _, path in ipairs(paths) do
    local f = io.open(path, "r")
    if f then
      local body = f:read("*a")
      f:close()
      for id in body:gmatch("event%s*=%s*(%d+)") do add(id) end
      for id in body:gmatch("eventFlag%s*=%s*(%d+)") do add(id) end
      for id in body:gmatch("setevent\"%s*,%s*event%s*=%s*(%d+)") do add(id) end
    end
  end
  -- Silver / rival gates used by KR Mt. Moon
  add(793)
  add(1914)
  add(2998)
  add(2999)
  table.sort(ids)
  return ids
end

local function clearKrTrainerEvents(save)
  save.events = save.events or {}
  for _, id in ipairs(collectKrTrainerEventIds()) do
    setEventBit(save.events, id, false)
  end
end

local function setNamedBadges(store, names, count)
  local out = {}
  for i, name in ipairs(names) do
    if i <= count then
      out[name] = true
    end
  end
  return out
end

local function setEngineBadgeBits(save, count)
  save.engineFlags = save.engineFlags or {}
  for i, name in ipairs(KANTO_BADGES) do
    local id = ENGINE_KANTO[name]
    if id then
      save.engineFlags[id] = (i <= count) or nil
    end
  end
end

local BEATS = {
  {
    file = "01_pre_moon.lua",
    slot = "slot10",
    label = "pre-Moon (Blue / early campaign)",
    map = "ROUTE_3",
    x = 50,
    y = 4,
    facing = "left",
    events = { FLAGS.ROUTE22_BLUE_MET },
    kantoBadges = 1,
  },
  {
    file = "02_pre_tunnel.lua",
    slot = "slot11",
    label = "pre-Tunnel (Moon cleared)",
    map = "ROCK_TUNNEL_1F_KR",
    x = 15,
    y = 29,
    facing = "down",
    events = {
      FLAGS.ROUTE22_BLUE_MET,
      FLAGS.MT_MOON_ROCKETS_CLEARED,
    },
    kantoBadges = 3,
  },
  {
    file = "03_pre_safari.lua",
    slot = "slot12",
    label = "pre-Safari (Moon+Tunnel; door open)",
    map = "FUCHSIA_CITY",
    x = 18,
    y = 5,
    facing = "up",
    events = {
      FLAGS.ROUTE22_BLUE_MET,
      FLAGS.MT_MOON_ROCKETS_CLEARED,
      FLAGS.ROCK_TUNNEL_ROCKETS_CLEARED,
      FLAGS.SAFARI_UNLOCKED,
    },
    kantoBadges = 5,
  },
  {
    file = "04_pre_silver.lua",
    slot = "slot13",
    label = "pre-Silver (Safari cleared + 8 badges)",
    map = "MT_MOON_B2F_KR",
    x = 5,
    y = 5,
    facing = "up",
    events = {
      FLAGS.ROUTE22_BLUE_MET,
      FLAGS.MT_MOON_ROCKETS_CLEARED,
      FLAGS.ROCK_TUNNEL_ROCKETS_CLEARED,
      FLAGS.SAFARI_UNLOCKED,
      FLAGS.SAFARI_ROCKETS_CLEARED,
    },
    kantoBadges = 8,
    -- Do not set 793 / 1914 / 2998 — those are set by beating Silver.
  },
}

local function mkdir_p(path)
  local cmd = string.format("mkdir -p %q", path)
  local ok = os.execute(cmd)
  if ok ~= true and ok ~= 0 then
    error("mkdir failed: " .. path)
  end
end

local function writeFile(path, body)
  local f, err = io.open(path, "w")
  if not f then error(err or path) end
  f:write(body)
  f:close()
end

-- Append campaign slots to options.lua saveSlots.gold without changing active.
local function registerInstallSlots(beats)
  local optsPath = HOME .. "/.local/share/love/pokemon-love2d/options.lua"
  local f = io.open(optsPath, "r")
  if not f then
    print("warn: no options.lua; slots written but not registered")
    return
  end
  local text = f:read("*a")
  f:close()

  local startPos, endPos = text:find("saveSlots%s*=%s*%{")
  if not startPos then
    print("warn: saveSlots missing in options.lua")
    return
  end
  local goldAt = text:find("gold%s*=%s*%{", startPos)
  if not goldAt or goldAt > startPos + 800 then
    print("warn: saveSlots.gold missing")
    return
  end
  local closeAt = text:find("\n    %},", goldAt)
  if not closeAt then
    print("warn: could not bound saveSlots.gold")
    return
  end
  local block = text:sub(goldAt, closeAt - 1)

  local names = {
    slot2 = "test-kanto-dungeons",
  }
  local list = { "slot2", "slot3" }
  for _, beat in ipairs(beats) do
    list[#list + 1] = beat.slot
    names[beat.slot] = "KR campaign: " .. beat.label:match("^[^%(]+"):gsub("%s+$", "")
  end
  -- Dedup list preserving order
  local seen, ordered = {}, {}
  for _, id in ipairs(list) do
    if not seen[id] then
      seen[id] = true
      ordered[#ordered + 1] = id
    end
  end

  local listLines = { "      list = {" }
  for i, id in ipairs(ordered) do
    listLines[#listLines + 1] = string.format('        [%d] = "%s",', i, id)
  end
  listLines[#listLines + 1] = "      },"
  local nameLines = { "      names = {" }
  local nameKeys = {}
  for k in pairs(names) do nameKeys[#nameKeys + 1] = k end
  table.sort(nameKeys)
  for _, k in ipairs(nameKeys) do
    nameLines[#nameLines + 1] = string.format('        %s = "%s",', k, names[k])
  end
  nameLines[#nameLines + 1] = "      },"

  if block:find("\n      list = %{") then
    block = block:gsub("\n      list = %{.-\n      %},", "\n" .. table.concat(listLines, "\n"), 1)
  else
    block = block .. "\n" .. table.concat(listLines, "\n")
  end
  if block:find("\n      names = %{") then
    block = block:gsub("\n      names = %{.-\n      %},", "\n" .. table.concat(nameLines, "\n"), 1)
  else
    block = block .. "\n" .. table.concat(nameLines, "\n")
  end

  text = text:sub(1, goldAt - 1) .. block .. text:sub(closeAt)
  writeFile(optsPath, text)
  print("registered slots in options.lua (active unchanged)")
end

local function buildOne(base, beat)
  local save = deepcopy(base)
  save.position = save.position or {}
  save.position.map = beat.map
  save.position.x = beat.x
  save.position.y = beat.y
  save.position.facing = beat.facing or "down"

  -- Wipe KR trainer/item defeat bits inherited from the playtest clone, then
  -- apply this beat's campaign progress flags.
  clearKrTrainerEvents(save)
  setEvents(save, beat.events or {})

  save.player = save.player or {}
  -- Name-keyed tables so World:engineFlag / checkflag ENGINE_*BADGE work.
  save.player.badges = setNamedBadges(save.player.badges, JOHTO_BADGES, 8)
  save.player.kantoBadges = setNamedBadges(
    save.player.kantoBadges, KANTO_BADGES, beat.kantoBadges or 0
  )
  setEngineBadgeBits(save, beat.kantoBadges or 0)
  -- Intentionally leave modData["Kanto-Reforged"].level_caps_on alone.

  save.meta = save.meta or {}
  save.meta.krNote = "KR campaign test: " .. beat.label
  save.savedAt = os.time()
  return save
end

local function main(argv)
  local install = false
  for _, a in ipairs(argv or {}) do
    if a == "--install" then install = true end
  end

  local base = dofile(BASE)
  if type(base) ~= "table" then
    error("failed to load base save: " .. BASE)
  end

  mkdir_p(OUT_DIR)

  local readme = {
    "# Kanto Rocket campaign test saves",
    "",
    "Built from Gold `slot2.lua`. Campaign progress flags only.",
    "Clears restored-dungeon / campaign trainer+item event bits inherited from the clone.",
    "**Does not set or clear `level_caps_on`.**",
    "",
    "| File | Slot | Where | Flags |",
    "|---|---|---|---|",
  }

  for _, beat in ipairs(BEATS) do
    local save = buildOne(base, beat)
    local body = SaveSerializer.encode(save)
    local outPath = OUT_DIR .. "/" .. beat.file
    writeFile(outPath, body)
    print("wrote " .. outPath)

    if install then
      local dest = INSTALL_DIR .. "/" .. beat.slot .. ".lua"
      writeFile(dest, body)
      print("installed " .. dest)
    end

    local flagList = {}
    for _, id in ipairs(beat.events or {}) do
      flagList[#flagList + 1] = tostring(id)
    end
    readme[#readme + 1] = string.format(
      "| `%s` | `%s` | `%s` (%d,%d) | %s + %d Kanto badges |",
      beat.file,
      beat.slot,
      beat.map,
      beat.x,
      beat.y,
      (#flagList > 0 and table.concat(flagList, ", ") or "none"),
      beat.kantoBadges or 0
    )
  end

  if install then
    registerInstallSlots(BEATS)
  end

  readme[#readme + 1] = ""
  readme[#readme + 1] = "Regenerate:"
  readme[#readme + 1] = "```"
  readme[#readme + 1] = "luajit mods/Kanto-Reforged/tools/make_campaign_test_saves.lua --install"
  readme[#readme + 1] = "```"
  readme[#readme + 1] = ""
  readme[#readme + 1] = "Slots 10–13 are written only with `--install` (does not change active slot)."
  readme[#readme + 1] = ""

  writeFile(OUT_DIR .. "/README.md", table.concat(readme, "\n"))
  print("wrote " .. OUT_DIR .. "/README.md")
end

main(arg)
