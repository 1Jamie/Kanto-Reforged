-- Viridian / Cherrygrove candy NPC + optional badge level caps.
return function(T, Data, run)
  local LevelCaps = require("mods.Kanto-Reforged.ui.level_caps")
  local Host = require("mods.Kanto-Reforged.core.host")
  local Experience = require("src.battle.Experience")
  local Pokemon = require("src.pokemon.Pokemon")
  local ItemEffects = require("src.inventory.ItemEffects")
  local Growth = require("src.pokemon.Growth")
  local MapScripts = require("src.script.MapScripts")

  -- install() keeps the mod API (with save/hooks); loader.mods entries do not.
  local mod = LevelCaps._mod
  T.check(mod ~= nil and mod.save ~= nil, "level caps installed with mod API")

  -- Viridian City NPC presence.
  local city = Data.maps.VIRIDIAN_CITY
  local found
  for _, obj in ipairs(city.objects or {}) do
    if obj.name == LevelCaps.NPC_NAME or obj.text == LevelCaps.TEXT_ID then
      found = obj
      break
    end
  end
  T.check(found ~= nil, "Viridian candy NPC object present")
  T.eq(found.x, LevelCaps.NPC.x, "candy NPC x near Poké Mart")
  T.eq(found.y, LevelCaps.NPC.y, "candy NPC y near Poké Mart")

  local scripts = MapScripts.get("VIRIDIAN_CITY")
  T.check(scripts and scripts.talk and scripts.talk[LevelCaps.TEXT_ID],
    "Viridian candy NPC talk script registered")
  T.check(run.loader.modSave, "loader modSave available")

  -- Caps off by default: vanilla XP and Rare Candy work past badge levels.
  mod.save:set(LevelCaps.SAVE_KEY, false)
  T.check(not LevelCaps.enabled(mod), "level caps off before candy")
  T.eq(LevelCaps.cap(mod, Data, { inventory = {} }), nil,
    "cap() nil while disabled")

  -- =========================================================
  -- Gen 1 Story milestones (Kanto)
  -- =========================================================
  Host.force(1)
  local save0 = { inventory = {}, flags = {} }
  T.eq(LevelCaps.capFor(Data, save0), 14, "Gen 1: start -> Pre-Brock 14")
  save0.flags.EVENT_BEAT_BROCK = true
  T.eq(LevelCaps.capFor(Data, save0), 16, "Gen 1: after Brock -> Pre-Mt. Moon 16")
  save0.flags.EVENT_GOT_HELIX_FOSSIL = true
  T.eq(LevelCaps.capFor(Data, save0), 18, "Gen 1: after Mt. Moon -> Pre-Nugget Bridge 18")
  save0.flags.EVENT_GOT_NUGGET = true
  T.eq(LevelCaps.capFor(Data, save0), 21, "Gen 1: after Nugget Bridge -> Pre-Misty 21")
  save0.flags.EVENT_BEAT_MISTY = true
  T.eq(LevelCaps.capFor(Data, save0), 24, "Gen 1: after Misty -> Pre-Surge 24")
  save0.flags.EVENT_BEAT_LT_SURGE = true
  T.eq(LevelCaps.capFor(Data, save0), 29, "Gen 1: after Surge -> Pre-Erika/Hideout 29")
  save0.flags.EVENT_BEAT_ERIKA = true
  T.eq(LevelCaps.capFor(Data, save0), 29, "Gen 1: Erika alone does not unlock Silph cap")
  save0.flags.EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI = true
  T.eq(LevelCaps.capFor(Data, save0), 41, "Gen 1: Erika+Hideout -> Pre-Silph 41")
  save0.flags.EVENT_BEAT_SILPH_CO_GIOVANNI = true
  T.eq(LevelCaps.capFor(Data, save0), 43, "Gen 1: after Silph -> Pre-Koga/Sabrina 43")
  save0.flags.EVENT_BEAT_KOGA = true
  T.eq(LevelCaps.capFor(Data, save0), 47, "Gen 1: after Koga -> Pre-Blaine 47")
  save0.flags.EVENT_BEAT_BLAINE = true
  T.eq(LevelCaps.capFor(Data, save0), 50, "Gen 1: after Blaine -> Pre-Giovanni 50")
  save0.flags.EVENT_BEAT_GIOVANNI = true
  T.eq(LevelCaps.capFor(Data, save0), 53, "Gen 1: after Giovanni -> Pre-Victory Road 53")
  save0.flags.EVENT_STARTED_ELITE_4 = true
  T.eq(LevelCaps.capFor(Data, save0), 65, "Gen 1: E4 started -> Pre-Champion 65")
  save0.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  T.eq(LevelCaps.capFor(Data, save0), 100, "Gen 1: champion beaten -> cap 100")

  -- Badge inventory is enough for Gen 1 gym milestones.
  local badgeSave = { inventory = { BOULDERBADGE = 1 }, flags = {} }
  T.eq(LevelCaps.capFor(Data, badgeSave), 16, "Gen 1: Boulder Badge alone -> 16")

  -- =========================================================
  -- Gen 2 Story milestones (Johto & Kanto Arcs)
  -- =========================================================
  Host.force(2)
  local saveG2 = { inventory = {}, flags = {}, engineFlags = {}, events = {} }
  T.eq(LevelCaps.capFor(Data, saveG2), 14, "Gen 2: start -> Pre-Falkner 14")

  saveG2.flags.EVENT_BEAT_FALKNER = true
  T.eq(LevelCaps.capFor(Data, saveG2), 16, "Gen 2: after Falkner -> Pre-Bugsy 16")

  saveG2.flags.EVENT_BEAT_BUGSY = true
  T.eq(LevelCaps.capFor(Data, saveG2), 20, "Gen 2: after Bugsy -> Pre-Whitney 20")

  saveG2.flags.EVENT_BEAT_WHITNEY = true
  T.eq(LevelCaps.capFor(Data, saveG2), 25, "Gen 2: after Whitney -> Pre-Morty 25")

  saveG2.flags.EVENT_BEAT_MORTY = true
  T.eq(LevelCaps.capFor(Data, saveG2), 30, "Gen 2: after Morty -> Pre-Chuck 30")

  saveG2.flags.EVENT_BEAT_CHUCK = true
  T.eq(LevelCaps.capFor(Data, saveG2), 32, "Gen 2: after Chuck -> Pre-Pryce 32")

  saveG2.flags.EVENT_BEAT_PRYCE = true
  T.eq(LevelCaps.capFor(Data, saveG2), 35, "Gen 2: after Pryce -> Pre-Jasmine 35")

  saveG2.flags.EVENT_BEAT_JASMINE = true
  T.eq(LevelCaps.capFor(Data, saveG2), 38, "Gen 2: after Jasmine -> Pre-Radio Tower 38")

  saveG2.flags.EVENT_CLEARED_RADIO_TOWER = true
  T.eq(LevelCaps.capFor(Data, saveG2), 40, "Gen 2: after Radio Tower -> Pre-Clair 40")

  saveG2.flags.EVENT_BEAT_CLAIR = true
  T.eq(LevelCaps.capFor(Data, saveG2), 44, "Gen 2: after Clair -> Pre-Victory Road Rival 44")

  saveG2.flags.EVENT_RIVAL_VICTORY_ROAD = true
  T.eq(LevelCaps.capFor(Data, saveG2), 50, "Gen 2: after Victory Road Rival -> Pre-Lance 50")

  -- Kanto Arc progression in Gen 2
  saveG2.flags.EVENT_BEAT_CHAMPION_LANCE = true
  T.eq(LevelCaps.capFor(Data, saveG2), 58, "Gen 2: after Lance (0-2 Kanto badges) -> 58")

  saveG2.engineFlags.ENGINE_BOULDERBADGE = true
  saveG2.engineFlags.ENGINE_CASCADEBADGE = true
  saveG2.engineFlags.ENGINE_THUNDERBADGE = true
  T.eq(LevelCaps.kantoBadgeCount(saveG2), 3, "Gen 2: 3 Kanto badges counted")
  T.eq(LevelCaps.capFor(Data, saveG2), 64, "Gen 2: 3-6 Kanto badges -> cap 64")

  saveG2.engineFlags.ENGINE_RAINBOWBADGE = true
  saveG2.engineFlags.ENGINE_SOULBADGE = true
  saveG2.engineFlags.ENGINE_MARSHBADGE = true
  saveG2.engineFlags.ENGINE_VOLCANOBADGE = true
  T.eq(LevelCaps.kantoBadgeCount(saveG2), 7, "Gen 2: 7 Kanto badges counted")
  T.eq(LevelCaps.capFor(Data, saveG2), 72, "Gen 2: 7 Kanto badges -> Pre-Blue 72")

  saveG2.engineFlags.ENGINE_EARTHBADGE = true
  T.eq(LevelCaps.kantoBadgeCount(saveG2), 8, "Gen 2: 8 Kanto badges counted")
  T.eq(LevelCaps.capFor(Data, saveG2), 85, "Gen 2: 8 Kanto badges -> Pre-Red 85")

  saveG2.flags.EVENT_RED_IN_MT_SILVER = true
  T.eq(LevelCaps.capFor(Data, saveG2), 100, "Gen 2: Red defeated -> cap 100")

  -- Reset host state
  Host.clearForce()

  -- Giving a stack tops up toward 99 and is how caps get enabled.
  local bag = { inventory = {}, bagOrder = {} }
  local qty = LevelCaps.giveCandyStack(bag)
  T.eq(qty, 99, "empty bag receives full stack")
  T.eq(bag.inventory.RARE_CANDY, 99, "bag holds 99 Rare Candies")
  T.eq(LevelCaps.giveCandyStack(bag), 0, "full stack gives nothing more")
  bag.inventory.RARE_CANDY = 90
  T.eq(LevelCaps.giveCandyStack(bag), 9, "top-up fills remaining stack room")

  -- Enable path: taking candy flips the permanent flag.
  mod.save:set(LevelCaps.SAVE_KEY, false)
  LevelCaps.enable(mod)
  T.check(LevelCaps.enabled(mod), "enable() sets permanent flag")
  T.check(mod.save:get(LevelCaps.SAVE_KEY, false), "flag persists in mod save")

  -- With caps on: at-cap mons get +1 XP and cannot level; Rare Candy fails.
  local gameSave = {
    inventory = {}, -- 0 badges -> cap 14
    flags = {},
    party = {},
  }
  package.loaded["src.core.Game"] = { save = gameSave, data = Data }

  mod.save:set(LevelCaps.SAVE_KEY, true)
  local mon = Pokemon.new(Data, "BULBASAUR", 14)
  local beforeExp = mon.exp
  local enemyDef = Data.pokemon.RATTATA
  local levels, gained = Experience.apply(Data, mon, enemyDef, 10, false, 1, false)
  T.eq(gained, 1, "at cap: battle XP is +1")
  T.eq(mon.level, 14, "at cap: level unchanged")
  T.eq(#levels, 0, "at cap: no level-ups reported")
  T.check(mon.exp == beforeExp + 1 or mon.exp == beforeExp,
    "at cap: exp moves by at most +1 and stays below next level")
  local nextExp = Growth.expForLevel(Data.pokemon.BULBASAUR.growthRate, 15)
  T.check(mon.exp < nextExp, "at cap: exp pinned below level 15")

  -- Below cap: normal XP still applies.
  local mon2 = Pokemon.new(Data, "BULBASAUR", 5)
  local full = Experience.gainFor(enemyDef, 10, false, 1, false, Data.constants)
  local _, gained2 = Experience.apply(Data, mon2, enemyDef, 10, false, 1, false)
  T.eq(gained2, full, "below cap: normal XP amount")

  -- Rare Candy blocked at cap, allowed below.
  local fail, _ = ItemEffects.use(Data, gameSave, "RARE_CANDY", mon)
  T.eq(fail, "failed", "Rare Candy fails at badge cap")
  local low = Pokemon.new(Data, "BULBASAUR", 10)
  local ok, _ = ItemEffects.use(Data, gameSave, "RARE_CANDY", low)
  T.eq(ok, "consumed", "Rare Candy works below cap")
  T.eq(low.level, 11, "Rare Candy leveled below-cap mon")

  -- Caps off: over-cap leveling behaves normally again.
  mod.save:set(LevelCaps.SAVE_KEY, false)
  local mon3 = Pokemon.new(Data, "BULBASAUR", 14)
  local _, gained3 = Experience.apply(Data, mon3, enemyDef, 10, false, 1, false)
  T.check(gained3 > 1, "caps off: XP is not forced to +1")

  -- Story progress raises the soft cap automatically.
  mod.save:set(LevelCaps.SAVE_KEY, true)
  gameSave.inventory.BOULDERBADGE = 1
  T.eq(LevelCaps.capFor(Data, gameSave), 16, "earning Brock's badge raises cap to 16")
  local mon4 = Pokemon.new(Data, "BULBASAUR", 14)
  local _, gained4 = Experience.apply(Data, mon4, enemyDef, 10, false, 1, false)
  T.check(gained4 > 1, "after Brock: former cap level gains normal XP")

  package.loaded["src.core.Game"] = nil
  mod.save:set(LevelCaps.SAVE_KEY, false)
end
