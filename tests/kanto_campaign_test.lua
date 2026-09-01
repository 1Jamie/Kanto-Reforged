-- kanto_campaign_test.lua
-- Gen2 Kanto Rocket campaign: overlays, Safari door gate, Silver gate.

local Host = require("mods.Kanto-Reforged.core.host")
local RestoredDungeons = require("mods.Kanto-Reforged.world.restored_dungeons")
local Campaign = require("mods.Kanto-Reforged.world.kanto_campaign")
local Content = require("mods.Kanto-Reforged.world.kanto_campaign_content")
local Data = require("mods.Kanto-Reforged.world.restored_dungeons_data")

local function runTests()
  print("Running kanto_campaign_test.lua...")

  Host.force(2)
  local CachePaths = require("mods.Kanto-Reforged.core.cache_paths")
  local goldTrainers = CachePaths.loadGenerated("trainers.lua", "gold")
  assert(goldTrainers, "Gen2 trainers.lua required")
  local gen2Maps = dofile("data/generated/maps.lua")
  local fakeMod = {
    data = {
      gen2Tilesets = CachePaths.loadGenerated("tilesets.lua", "gold") or {},
      gen2Palettes = {},
      gen2Maps = gen2Maps,
      gen2Trainers = goldTrainers,
      gen2Text = {},
      text = {},
      items = dofile("data/generated/items.lua"),
      pokemon = dofile("data/generated/pokemon.lua"),
      moves = dofile("data/generated/moves.lua"),
    },
    log = { info = function() end, warn = function() end, error = function() end },
    content = {
      maps = {
        patch = function() end,
        register = function() end,
      },
    },
    save = {
      get = function(_, k, d) return d end,
      set = function() end,
    },
  }
  fakeMod.data.trainers = fakeMod.data.gen2Trainers
  fakeMod.data.maps = gen2Maps

  RestoredDungeons.apply(fakeMod)
  Campaign.install(fakeMod)

  local F = Content.FLAGS

  -- Moon racket text reframed
  assert(RestoredDungeons.DUNGEON_TEXT.TEXT_MTMOONB2F_ROCKET4:find("SAFARI"),
    "Mt Moon Rocket4 text must mention SAFARI industry")
  assert(not RestoredDungeons.DUNGEON_TEXT.TEXT_MTMOONB2F_ROCKET1:find("fossils"),
    "Mt Moon Rockets must not use Gen1 fossil dialogue")

  -- Campaign dialogue must paginate Gen2-style: 18 cols, ≤2 lines/page, \f between pages.
  -- Soft-wrapped lines without \f auto-advance (no A wait) — the "smacking" bug.
  local TextBox = require("src.render.TextBox")
  local Dialogue = require("mods.Kanto-Reforged.core.dialogue")
  local function assertOwPages(name, text)
    assert(type(text) == "string" and #text > 0, name .. " missing")
    local pages = TextBox.paginate(text, 18)
    if #pages > 1 then
      assert(text:find("\f"), name .. " multi-page text must use \\f page breaks")
    end
    for i, page in ipairs(pages) do
      assert(#page <= 2,
        string.format("%s page %d has %d lines (will auto-scroll)", name, i, #page))
      for j, line in ipairs(page) do
        assert(Dialogue.glyphLen(line) <= 18,
          string.format("%s p%d l%d exceeds 18 cols: %q", name, i, j, line))
      end
    end
  end
  for key, text in pairs(Content.TEXT) do
    if type(text) == "string" then
      assertOwPages(key, text)
      assertOwPages(key .. " (merged)", RestoredDungeons.DUNGEON_TEXT[key])
    end
  end
  print("  Campaign dialogue Gen2 pagination OK.")

  -- Moon clear afterScript on admin
  local moon = Data.maps.MT_MOON_B2F_KR
  local rocket4
  for _, o in ipairs(moon.objects or {}) do
    if o.name == "MTMOONB2F_ROCKET4" then rocket4 = o break end
  end
  assert(rocket4 and rocket4.afterScriptKey, "Rocket4 must set clear flag via afterScriptKey")
  local foundMoonFlag = false
  for _, cmd in ipairs(rocket4.afterScriptKey) do
    if cmd.op == "setevent" and cmd.event == F.MT_MOON_ROCKETS_CLEARED then
      foundMoonFlag = true
    end
  end
  assert(foundMoonFlag, "Rocket4 afterScript must set MT_MOON_ROCKETS_CLEARED")

  -- Rock Tunnel overlays
  local rt1 = Data.maps.ROCK_TUNNEL_1F_KR
  local hasBlue, hasR1 = false, false
  for _, o in ipairs(rt1.objects or {}) do
    if o.name == "ROCKTUNNEL_BLUE" then hasBlue = true end
    if o.name == "ROCKTUNNEL_ROCKET1" then hasR1 = true end
  end
  assert(hasBlue and hasR1, "Rock Tunnel 1F must overlay Blue + Rockets")

  -- Trainer HUD/name + battle frontpic keys (not "GRUNT EXECUTIVE" / numeric class).
  local function assertRocketTrainer(obj, expectClassId, expectName)
    assert(obj and obj.trainer, (obj and obj.name or "?") .. " missing trainer")
    local tr = obj.trainer
    assert(tr.classId == expectClassId,
      string.format("%s classId want %s got %s", obj.name, expectClassId, tostring(tr.classId)))
    assert(tr.className == "ROCKET",
      string.format("%s className want ROCKET got %s", obj.name, tostring(tr.className)))
    assert(tr.name == expectName,
      string.format("%s name want %s got %s", obj.name, expectName, tostring(tr.name)))
  end
  for _, o in ipairs(rt1.objects or {}) do
    if o.name == "ROCKTUNNEL_ROCKET1" then
      assertRocketTrainer(o, "GRUNTM", "GRUNT")
    end
  end

  local rtB = Data.maps.ROCK_TUNNEL_B1F_KR
  local hasAdmin = false
  for _, o in ipairs(rtB.objects or {}) do
    if o.name == "ROCKTUNNEL_ADMIN" then
      hasAdmin = true
      assert(o.afterScriptKey, "Tunnel admin needs afterScriptKey")
      assertRocketTrainer(o, "EXECUTIVEM", "EXECUTIVE")
    end
  end
  assert(hasAdmin, "Rock Tunnel B1F must overlay admin")

  for _, o in ipairs(moon.objects or {}) do
    if o.name == "MTMOONB2F_ROCKET1" then
      assertRocketTrainer(o, "GRUNTM", "GRUNT")
    end
  end

  -- Safari occupation overlays
  local sc = Data.maps.SAFARI_ZONE_CENTER_KR
  local hasSz = false
  for _, o in ipairs(sc.objects or {}) do
    if o.name == "SAFARIZONE_ROCKET1" then
      hasSz = true
      assertRocketTrainer(o, "GRUNTM", "GRUNT")
    end
  end
  assert(hasSz, "Safari Center must overlay Rockets")
  for _, o in ipairs(sc.objects or {}) do
    if o.name == "SAFARIZONE_ROCKET1" then
      assert(o.movement == 9 and o.range == "RIGHT",
        "Safari entrance Rocket must use STANDING_RIGHT (movement 9)")
    end
  end
  local expectedRockets = {
    SAFARIZONE_ROCKET1 = { map = "SAFARI_ZONE_CENTER_KR", x = 13, y = 23, range = "RIGHT" },
    SAFARIZONE_ROCKET2 = { map = "SAFARI_ZONE_CENTER_KR", x = 14, y = 1, range = "UP" },
    SAFARIZONE_ROCKET3 = { map = "SAFARI_ZONE_EAST_KR", x = 3, y = 21, range = "LEFT" },
    SAFARIZONE_ROCKET4 = { map = "SAFARI_ZONE_WEST_KR", x = 28, y = 22, range = "RIGHT" },
    SAFARIZONE_ROCKET5 = { map = "SAFARI_ZONE_NORTH_KR", x = 18, y = 35, range = "RIGHT" },
  }
  for name, exp in pairs(expectedRockets) do
    local mdef = Data.maps[exp.map]
    local found
    for _, o in ipairs(mdef and mdef.objects or {}) do
      if o.name == name then found = o break end
    end
    assert(found, name .. " must be overlaid on " .. exp.map)
    assert(found.x == exp.x and found.y == exp.y and found.range == exp.range,
      string.format("%s must guard zone entrance at (%d,%d) %s", name, exp.x, exp.y, exp.range))
  end

  local secret = Data.maps.SAFARI_ZONE_SECRET_HOUSE_KR
  local boss
  for _, o in ipairs(secret.objects or {}) do
    if o.name == "SAFARIZONE_BOSS" then boss = o break end
  end
  assert(boss and type(boss.scriptKey) == "table", "Secret House must be Rocket boss")
  assert(boss.sprite == "SPRITE_ROCKET_GIRL", "Safari boss should use rocket girl OW sprite")
  assert(boss.trainerClass == "EXECUTIVEF", "Safari boss class EXECUTIVEF for frontpic")
  local loadOk = false
  for _, cmd in ipairs(boss.scriptKey) do
    if cmd.op == "loadtrainer" then
      assert(cmd.class == 55 and cmd.member == 235,
        "Safari boss loadtrainer must use EXECUTIVEF index 55")
      loadOk = true
    end
  end
  assert(loadOk, "Safari boss script must loadtrainer")
  local hmSurf = false
  for _, cmd in ipairs(boss.scriptKey) do
    if cmd.op == "verbosegiveitem" and cmd.item == 246 then hmSurf = true end
  end
  assert(not hmSurf, "Secret House must not give HM Surf")

  -- Silver gated on Safari clear
  local silver
  for _, o in ipairs(moon.objects or {}) do
    if o.name == "MTMOONB2F_SILVER_RIVAL" then silver = o break end
  end
  assert(silver and silver.scriptKey, "Silver must exist on B2F")
  local checksSafari = false
  for _, cmd in ipairs(silver.scriptKey) do
    if cmd.op == "checkevent" and cmd.event == F.SAFARI_ROCKETS_CLEARED then
      checksSafari = true
    end
  end
  assert(checksSafari, "Silver script must require SAFARI_ROCKETS_CLEARED")

  -- Fuchsia door closed without flags
  local fc = fakeMod.data.gen2Maps.FUCHSIA_CITY or Data.maps.FUCHSIA_CITY
  if not fc and fakeMod.data.maps then fc = fakeMod.data.maps.FUCHSIA_CITY end
  -- Sync against a fresh fuchsia copy from stock maps
  local stock = dofile("data/generated/maps.lua")
  local fuchsia = {}
  for k, v in pairs(stock.FUCHSIA_CITY or {}) do
    fuchsia[k] = v
  end
  fuchsia.blocks = {}
  for i, b in ipairs(stock.FUCHSIA_CITY.blocks or {}) do
    fuchsia.blocks[i] = b
  end
  fuchsia.warps = {}
  for i, w in ipairs(stock.FUCHSIA_CITY.warps or {}) do
    fuchsia.warps[i] = { x = w.x, y = w.y, destMap = w.destMap, destWarp = w.destWarp }
  end

  local saveClosed = { events = {} }

  Campaign.syncFuchsiaSafariDoor(fuchsia, saveClosed)
  local width = fuchsia.width or 20
  local idx = 1 * width + 9 + 1
  assert(fuchsia.blocks[idx] ~= 58, "Safari door block must not be open when locked")
  for _, w in ipairs(fuchsia.warps) do
    if (w.x == 18 or w.x == 19) and w.y == 3 then
      assert(not (type(w.destMap) == "string" and w.destMap:find("SAFARI")),
        "No Safari warps while locked")
    end
  end
  print("  Safari door locked without clear flags.")

  Campaign.setEvent(saveClosed, F.MT_MOON_ROCKETS_CLEARED, true)
  Campaign.setEvent(saveClosed, F.ROCK_TUNNEL_ROCKETS_CLEARED, true)
  assert(Campaign.isSafariUnlocked(saveClosed), "Both clears unlock Safari")
  Campaign.syncFuchsiaSafariDoor(fuchsia, saveClosed)
  assert(fuchsia.blocks[idx] == 58, "Safari door block 58 when unlocked")
  local warpHits = 0
  for _, w in ipairs(fuchsia.warps) do
    if (w.x == 18 or w.x == 19) and w.y == 3 and w.destMap == "SAFARI_ZONE_GATE_KR" then
      warpHits = warpHits + 1
    end
  end
  assert(warpHits >= 2, "Unlocked Fuchsia must warp to SAFARI_ZONE_GATE_KR")

  local preSafari = dofile("mods/Kanto-Reforged/test_saves/gold/03_pre_safari.lua")
  assert(Campaign.isSafariUnlocked(preSafari),
    "03_pre_safari save must carry Moon+Tunnel unlock flags")
  Campaign.syncFuchsiaSafariDoor(fuchsia, preSafari)
  assert(fuchsia.blocks[idx] == 58, "pre-Safari test save must open Fuchsia door")
  print("  Safari door opens after Moon+Tunnel clears.")

  -- Rosters registered + installed under correct battle classes
  assert(Content.ROSTERS.ROCKTUNNEL_ADMIN and Content.ROSTERS.SAFARIZONE_BOSS,
    "Campaign rosters present")
  local classes = fakeMod.data.gen2Trainers.classes or fakeMod.data.gen2Trainers
  assert(classes.GRUNTM.trainers[220], "campaign GRUNTM member 220 installed")
  assert(classes.EXECUTIVEM.trainers[223], "campaign EXECUTIVEM member 223 installed")
  assert(classes.EXECUTIVEF.trainers[235], "campaign EXECUTIVEF member 235 installed")

  print("All kanto_campaign_test.lua assertions passed!")
end

runTests()
