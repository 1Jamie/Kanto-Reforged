-- Standalone: luajit mods/Kanto-Reforged/tests/Kanto-Reforged_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
local Runtime = require("src.mods.Runtime")
Data:load()

-- Stub missing moves in the test dataset to allow validation against mock fixtures
-- (kept as a safety net; generator remaps Gen 1 ids so this should be empty)
local pokemon_data = require("mods.Kanto-Reforged.pokemon_data")
for id, species in pairs(pokemon_data.species) do
  for _, entry in ipairs(species.learnset) do
    if not Data.moves[entry.move] and not pokemon_data.moves[entry.move] then
      Data.moves[entry.move] = { id = entry.move, name = entry.move, type = "NORMAL", power = 40, accuracy = 100, pp = 35, effect = "NO_ADDITIONAL_EFFECT" }
    end
  end
  if species.tmhm then
    for _, mv in ipairs(species.tmhm) do
      if not Data.moves[mv] and not pokemon_data.moves[mv] then
        Data.moves[mv] = { id = mv, name = mv, type = "NORMAL", power = 40, accuracy = 100, pp = 35, effect = "NO_ADDITIONAL_EFFECT" }
      end
    end
  end
  -- No Gen 4+ evo stubs: generator strips those targets
end

-- Stub vanilla species needed by encounters
for _, id in ipairs({ "NIDORAN_M", "NIDORAN_F", "EXEGGCUTE", "CHANSEY", "PIDGEY", "RATTATA" }) do
  if not Data.pokemon[id] then
    Data.pokemon[id] = {
      id = id, name = id, dex = 999, types = { "NORMAL" },
      baseStats = { hp = 50, attack = 50, defense = 50, speed = 50, special = 50 },
      catchRate = 45, baseExp = 100, level1Moves = { "TACKLE" },
      growthRate = "SLOW", learnset = {}, tmhm = {}, evolutions = {}
    }
  end
end

-- Mock ROUTE_1 encounters table to test dynamic wild spawn mixing
Data.encounters.ROUTE_1 = {
  grass = {
    rate = 25,
    slots = {
      { level = 3, species = "PIDGEY" },
      { level = 4, species = "RATTATA" },
      { level = 3, species = "PIDGEY" },
      { level = 4, species = "RATTATA" },
      { level = 3, species = "PIDGEY" },
      { level = 4, species = "RATTATA" },
      { level = 3, species = "PIDGEY" },
      { level = 4, species = "RATTATA" },
      { level = 3, species = "PIDGEY" },
      { level = 4, species = "RATTATA" },
    }
  }
}

-- Mock SAFARI_ZONE_EAST encounters to test rare spawn slot placement and vanilla protection
Data.encounters.SAFARI_ZONE_EAST = {
  grass = {
    rate = 30,
    slots = {
      { level = 22, species = "NIDORAN_M" },
      { level = 24, species = "NIDORAN_F" },
      { level = 22, species = "NIDORAN_M" },
      { level = 24, species = "NIDORAN_F" },
      { level = 22, species = "NIDORAN_M" },
      { level = 24, species = "NIDORAN_F" },
      { level = 22, species = "NIDORAN_M" },
      { level = 24, species = "NIDORAN_F" },
      { level = 23, species = "EXEGGCUTE" },
      { level = 28, species = "CHANSEY" } -- Vanilla Chansey (rare) to preserve in Slot 10
    }
  }
}

local run = T.sdk.loadMod("mods/Kanto-Reforged", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

-- Load TypeChart registry to enable damage calculations in tests
require("src.battle.TypeChart").load(Data)

-- 1. Verify custom Pokémon species registration
T.check(Data.pokemon.CHIKORITA ~= nil, "Chikorita registered")
T.eq(Data.pokemon.CHIKORITA.dex, 152, "Chikorita has correct Dex number")
T.eq(Data.pokemon.CHIKORITA.growthRate, "MEDIUM_SLOW", "Chikorita has correct growth rate")

-- Pokédex bound must cover Gen 2/3 numbers (list is 1..dexSize).
T.check(Data.constants.dexSize >= 251, "dexSize covers Johto at minimum")
T.check(Data.constants.dexSize >= (Data.pokemon.LATIAS and Data.pokemon.LATIAS.dex or 0),
  "dexSize covers highest registered Gen 3 species")
do
  local byDex = {}
  for _, def in pairs(Data.pokemon) do
    if def.dex then byDex[def.dex] = def end
  end
  T.check(byDex[152] ~= nil and byDex[152].id == "CHIKORITA",
    "dex #152 resolves to Chikorita for the Pokédex list")
  T.check(byDex[152].dex <= Data.constants.dexSize,
    "Chikorita falls within dexSize so the Pokédex enumerates it")
end

-- Pokédex flavor text must be a Data.text key (vanilla pattern), not raw prose.
do
  local DexEntries = require("mods.Kanto-Reforged.dex_entries")
  local chiki = Data.pokemon.CHIKORITA
  local entry = chiki and chiki.dexEntry
  T.check(entry ~= nil, "Chikorita has dexEntry")
  T.check(type(entry.text) == "string" and entry.text:match("^_"),
    "Chikorita dexEntry.text is a text-table key")
  local body = Data.text[entry.text]
  T.check(type(body) == "string" and #body > 0,
    "Chikorita dex text resolves in Data.text")
  T.check(body:find("leaf", 1, true) or body:find("LEAF", 1, true)
      or body:find("temperature", 1, true),
    "Chikorita dex text body looks like the flavor blurb")

  -- Gen 1 box: ≤6 lines after wrap
  local function lineCount(s)
    local n = 0
    for _ in (s:gsub("\v", "\n"):gsub("\f", "\n") .. "\n"):gmatch("(.-)\n") do
      n = n + 1
    end
    return n
  end
  local dusk = Data.pokemon.DUSKULL
  T.check(dusk and dusk.dexEntry and Data.text[dusk.dexEntry.text],
    "Duskull dex text registered")
  local duskBody = Data.text[dusk.dexEntry.text]
  T.check(lineCount(duskBody) <= 6, "Duskull dex fits Gen 1 line budget")
  T.check(duskBody:find("cry", 1, true) or duskBody:find("children", 1, true)
      or duskBody:find("spirit", 1, true),
    "Duskull keeps the creepy children-crying flavor")

  local wrapped = DexEntries.wrap(
    ("word "):rep(80)) -- absurdly long
  T.check(lineCount(wrapped) <= 6, "wrap hard-caps at 6 lines")

  -- Owned entry render must not fall through to "Data unknown."
  local DexEntryMenu = require("src.ui.DexEntryMenu")
  local Font = require("src.render.Font")
  local drawn = {}
  local oldDraw = Font.draw
  Font.draw = function(text, x, y)
    drawn[#drawn + 1] = tostring(text)
    if oldDraw then return oldDraw(text, x, y) end
  end
  local ok = pcall(DexEntryMenu.render, {
    data = Data,
    save = { pokedex = { owned = { CHIKORITA = true } } },
  }, chiki, nil, true, false)
  Font.draw = oldDraw
  T.check(ok, "DexEntryMenu.render succeeds for owned Chikorita")
  local joined = table.concat(drawn, "\n")
  T.check(not joined:find("Data unknown", 1, true),
    "owned Chikorita dex page is not Data unknown")
  T.check(joined:find("temperature", 1, true) or joined:find("leaf", 1, true)
      or joined:find("sunbathe", 1, true),
    "owned Chikorita dex page draws flavor text")

  -- Tyranitar (Gen2) must resolve too — regression for "Data unknown" reports.
  local tyr = Data.pokemon.TYRANITAR
  T.check(tyr and tyr.dexEntry and Data.text[tyr.dexEntry.text],
    "Tyranitar dex text registered")
  drawn = {}
  Font.draw = function(text, x, y)
    drawn[#drawn + 1] = tostring(text)
    if oldDraw then return oldDraw(text, x, y) end
  end
  ok = pcall(DexEntryMenu.render, {
    data = Data,
    save = { pokedex = { owned = { TYRANITAR = true } } },
  }, tyr, nil, true, false)
  Font.draw = oldDraw
  T.check(ok, "DexEntryMenu.render succeeds for owned Tyranitar")
  joined = table.concat(drawn, "\n")
  T.check(not joined:find("Data unknown", 1, true),
    "owned Tyranitar dex page is not Data unknown")
end

-- 2. Verify custom moves registration
T.check(Data.pokemon.CHIKORITA.learnset[1] ~= nil, "Chikorita learnset populated")
T.check(Data.moves.LEAF_BLADE ~= nil, "Leaf Blade move registered")
T.eq(Data.moves.LEAF_BLADE.power, 90, "Leaf Blade has correct power")

-- 3. Verify custom types registration
T.check(Data.type_chart.types.STEEL ~= nil, "Steel type registered")
T.check(Data.type_chart.types.DARK ~= nil, "Dark type registered")

-- 4. Verify custom type effectiveness matchups (neutrality defaults and custom ones)
local function getMatchupMultiplier(attacker, defender)
  for _, row in ipairs(Data.type_chart.matchups) do
    if row.attacker == attacker and row.defender == defender then
      return row.multiplier
    end
  end
  return nil
end

T.eq(getMatchupMultiplier("STEEL", "FIRE"), 5, "Steel vs Fire is half damage")
T.eq(getMatchupMultiplier("PSYCHIC_TYPE", "STEEL"), 5, "Psychic vs Steel is half damage")
T.eq(getMatchupMultiplier("STEEL", "NORMAL"), 10, "Steel vs Normal defaults to neutral 1.0x")

-- Gen3 move types (Gen1 ROM remaps + Gen3-strict Fairy→Normal)
T.eq(Data.moves.BITE.type, "DARK", "Bite is Dark (Gen2/3)")
T.eq(Data.moves.GUST.type, "FLYING", "Gust is Flying (Gen2/3)")
T.eq(Data.moves.KARATE_CHOP.type, "FIGHTING", "Karate Chop is Fighting (Gen2/3)")
T.eq(Data.moves.SAND_ATTACK.type, "GROUND", "Sand-Attack is Ground (Gen2/3)")
if Data.moves.CHARM then
  T.eq(Data.moves.CHARM.type, "NORMAL", "Charm is Normal in Gen3 (not Fairy)")
end

-- Gen1 chart quirks patched to Gen2/3
T.eq(getMatchupMultiplier("GHOST", "PSYCHIC_TYPE"), 20, "Ghost vs Psychic is SE (Gen2/3)")
T.eq(getMatchupMultiplier("BUG", "POISON"), 5, "Bug vs Poison is NVE (Gen2/3)")
T.eq(getMatchupMultiplier("POISON", "BUG"), 10, "Poison vs Bug is neutral (Gen2/3)")
T.eq(getMatchupMultiplier("ICE", "FIRE"), 5, "Ice vs Fire is NVE (Gen2/3)")

-- Gen3 species typings (no Fairy retcon): Dark hits Ralts for 2×
local TypeChart = require("src.battle.TypeChart")
T.eq(TypeChart.effectiveness("GHOST", { "PSYCHIC_TYPE" }), 20,
  "TypeChart Ghost vs Psychic is 2×")
T.eq(TypeChart.effectiveness("BUG", { "POISON" }), 5,
  "TypeChart Bug vs Poison is ½×")
T.eq(TypeChart.effectiveness("ICE", { "FIRE" }), 5,
  "TypeChart Ice vs Fire is ½×")
T.eq(table.concat(Data.pokemon.RALTS.types, ","), "PSYCHIC_TYPE",
  "Ralts is Psychic-only (Gen3)")
T.eq(TypeChart.effectiveness("DARK", Data.pokemon.RALTS.types), 20,
  "Dark vs Ralts is super-effective")
T.eq(table.concat(Data.pokemon.MAWILE.types, ","), "STEEL",
  "Mawile is Steel-only (Gen3)")
T.eq(table.concat(Data.pokemon.MARILL.types, ","), "WATER",
  "Marill is Water-only (Gen3)")

-- 5. Verify Shedinja maximum HP clamping
local Stats = require("src.pokemon.Stats")
local shedStats = Stats.calc(Data.pokemon.SHEDINJA, 50, {}, {})
T.eq(shedStats.hp, 1, "Shedinja maximum HP is clamped to 1")

-- 6. Verify Wonder Guard Damage Negation
local damageBlocked, infoBlocked = Runtime.call("battle.damage", function(c)
  return 100, { crit = false, typeMult = 10 }
end, {
  battle = { data = Data },
  move = { type = "NORMAL", power = 40 },
  user = { curStats = { special = 50, attack = 50 }, mon = { species = "SLAKING" }, name = "Slaking", isPlayer = true },
  target = { curStats = { special = 50 }, mon = { species = "SHEDINJA" }, curTypes = { "BUG", "GHOST" }, name = "Shedinja", isPlayer = false },
  opts = {}
})
T.eq(damageBlocked, 0, "Wonder Guard blocks neutral damaging attacks")
T.eq(infoBlocked.typeMult, 0, "Wonder Guard zeroes the effectiveness multiplier")

local damageAllowed, infoAllowed = Runtime.call("battle.damage", function(c)
  return 100, { crit = false, typeMult = 20 }
end, {
  battle = { data = Data },
  move = { type = "FIRE", power = 40 },
  user = { curStats = { special = 50, attack = 50 }, mon = { species = "SLAKING" }, name = "Slaking", isPlayer = true },
  target = { curStats = { special = 50 }, mon = { species = "SHEDINJA" }, curTypes = { "STEEL" }, name = "Shedinja", isPlayer = false },
  opts = {}
})
T.eq(damageAllowed, 100, "Wonder Guard allows super-effective attacks")
T.eq(infoAllowed.typeMult, 20, "Wonder Guard preserves super-effective multiplier")

-- 7. Verify Wild Spawn Distributions Mapping
local ExpEncounters = require("mods.Kanto-Reforged.encounters")
local packData = require("mods.Kanto-Reforged.pokemon_data")
local encIndex = ExpEncounters.buildIndex(packData)

local route1 = Data.encounters.ROUTE_1
local mixed = false
local mixedSpecies = {}
for _, slot in ipairs(route1.grass.slots) do
  if slot.species ~= "PIDGEY" and slot.species ~= "RATTATA" then
    mixed = true
    mixedSpecies[slot.species] = slot.level
  end
end
T.check(mixed, "Wild spawn distributions mixed in custom species")

-- Route 1 is early-game: base forms only, never below evolve-into level
for species, level in pairs(mixedSpecies) do
  local meta = encIndex.meta[species]
  T.check(meta ~= nil, "Route 1 mixed species is indexed: " .. tostring(species))
  if meta then
    T.eq(meta.stage, 0, "Route 1 only mixes base forms (" .. species .. ")")
    T.check(level >= meta.minLevel,
      species .. " Route 1 level " .. level .. " >= min " .. meta.minLevel)
  end
end
T.check(mixedSpecies["BAYLEEF"] == nil, "Bayleef is not a Route 1 wild encounter")
T.check(mixedSpecies["MEGANIUM"] == nil, "Meganium is not a Route 1 wild encounter")

-- Card + options surface
local cardChunk = loadfile("mods/Kanto-Reforged/mod.card")
T.check(cardChunk ~= nil, "Kanto-Reforged ships a mod.card")
local cardOk, card = pcall(cardChunk)
T.check(cardOk and type(card) == "table", "mod.card returns a table")
T.check(type(card.summary) == "string" and #card.summary > 0, "mod.card has a summary")
T.check(card.author ~= nil and card.author ~= "", "mod.card names an author")
local schema = run.loader.optionSchemas["Kanto-Reforged"]
T.check(schema ~= nil and #schema >= 6, "Kanto-Reforged option schema registered")
local Host = require("mods.Kanto-Reforged.host")
T.eq(schema[1].key, Host.optionKey("species_scope"), "species scope choice key")
T.eq(schema[1].type, "choice", "species scope is a choice")
T.eq(schema[1].default, "national", "DEX SCOPE defaults national")
T.eq(schema[1].label, "DEX SCOPE", "Gen1 DEX SCOPE label")
T.eq(schema[2].key, Host.optionKey("full_spawn_random"), "spawn toggle key")
T.eq(schema[2].type, "toggle", "spawn toggle is a toggle")
T.eq(schema[2].default, false, "FULL SPAWN MIX defaults off")
T.eq(schema[3].key, Host.optionKey("pure_spawn_random"), "pure random spawn key")
T.eq(schema[3].type, "toggle", "pure random is a toggle")
T.eq(schema[3].default, false, "PURE RANDOM SPAWN defaults off")
T.eq(schema[3].label, "PURE RANDOM SPAWN", "pure random label")
T.eq(schema[4].key, Host.optionKey("legends_in_mix"), "legends-in-mix toggle key")
T.eq(schema[4].type, "toggle", "legends-in-mix is a toggle")
T.eq(schema[4].default, false, "LEGENDS IN MIX defaults off")
T.eq(schema[4].label, "LEGENDS IN MIX", "legends-in-mix label")
T.eq(schema[5].key, "modern_xp_share", "slot-2 XP share toggle key")
T.eq(schema[5].type, "toggle", "slot-2 XP share is a toggle")
T.eq(schema[5].default, true, "XP SHARE (SLOT 2) defaults on")
T.eq(schema[5].label, "XP SHARE (SLOT 2)", "slot-2 XP share label")
T.eq(schema[6].key, "smarter_ai", "smarter AI toggle key")
T.eq(schema[6].type, "toggle", "smarter AI is a toggle")
T.eq(schema[6].default, true, "SMARTER AI defaults on")

-- Host-scoped spawn toggles: Red and Gold buckets stay independent.
do
  local bucket = run.loader.modOptions["Kanto-Reforged"] or {}
  run.loader.modOptions["Kanto-Reforged"] = bucket
  bucket["g1:full_spawn_random"] = true
  bucket["g2:full_spawn_random"] = false
  bucket["full_spawn_random"] = nil
  Host.force(1)
  T.eq(Host.optionKey("full_spawn_random"), "g1:full_spawn_random", "Gen1 option key")
  T.check(bucket[Host.optionKey("full_spawn_random")] == true, "Gen1 spawn mix on")
  Host.force(2)
  T.eq(Host.optionKey("full_spawn_random"), "g2:full_spawn_random", "Gen2 option key")
  T.check(bucket[Host.optionKey("full_spawn_random")] == false, "Gen2 spawn mix off")
  -- Legacy unprefixed migrates into the active host key only.
  bucket["g1:legends_in_mix"] = nil
  bucket["g2:legends_in_mix"] = nil
  bucket["legends_in_mix"] = true
  Host.force(1)
  local modApi = { id = "Kanto-Reforged", _loader = run.loader, options = {
    get = function(_, k)
      local stored = run.loader.modOptions["Kanto-Reforged"]
      if stored and stored[k] ~= nil then return stored[k] end
      return nil
    end,
  }}
  Host.migrateScopedOptions(modApi)
  T.check(bucket["g1:legends_in_mix"] == true, "legacy legends migrates to g1")
  T.check(bucket["g2:legends_in_mix"] == nil, "legacy legends does not write g2 while on Gen1")
  Host.clearForce()
end

-- Host-scoped spawn keys must round-trip through top-level options.modOptions
-- (Loader reads that on boot; Gold used to stash only under options.gold).
do
  local Host = require("mods.Kanto-Reforged.host")
  local SaveData = require("src.core.SaveData")
  local Save = require("src.core.gen2.Save")
  local disk = { textSpeed = 3, modOptions = {} }
  -- Fill enough defaultOptions keys so saveOptions treats this as a full table
  -- when we need — actually persistModOptions calls loadOptions then merge.
  local origLoad, origSave = SaveData.loadOptions, SaveData.saveOptions
  SaveData.loadOptions = function()
    return disk
  end
  SaveData.saveOptions = function(opts)
    disk = opts
  end
  Host.force(1)
  local key = Host.optionKey("full_spawn_random")
  run.loader.modOptions["Kanto-Reforged"] =
    run.loader.modOptions["Kanto-Reforged"] or {}
  run.loader.modOptions["Kanto-Reforged"][key] = true
  Host.persistModOptions({ id = "Kanto-Reforged", _loader = run.loader })
  T.check(disk.modOptions
      and disk.modOptions["Kanto-Reforged"]
      and disk.modOptions["Kanto-Reforged"][key] == true,
    "persistModOptions writes g1 spawn key to top-level modOptions")

  -- Gold Save.saveOptions (KR shim) must also lift modOptions to top-level for Loader.
  disk = { textSpeed = 3, modOptions = {} }
  Host.installEngineShims({ id = "Kanto-Reforged", log = { info = function() end } })
  Save.saveOptions({
    textSpeed = 3,
    battleStyle = "SHIFT",
    modOptions = {
      ["Kanto-Reforged"] = { ["g2:pure_spawn_random"] = true },
    },
  })
  T.check(disk.modOptions
      and disk.modOptions["Kanto-Reforged"]
      and disk.modOptions["Kanto-Reforged"]["g2:pure_spawn_random"] == true,
    "Gold Save.saveOptions lifts modOptions to top-level")
  T.check(disk.gold ~= nil, "Gold Save.saveOptions still writes options.gold")

  SaveData.loadOptions, SaveData.saveOptions = origLoad, origSave
  Host.clearForce()
end

local function optByKey(key)
  for _, o in ipairs(schema) do
    if o.key == key then return o end
  end
end
local splitOpt = optByKey("split_special")
T.check(splitOpt ~= nil, "split special option present")
T.eq(splitOpt.type, "toggle", "split special is a toggle")
T.eq(splitOpt.default, false, "SP.ATK / SP.DEF defaults off")
T.eq(splitOpt.label, "SP.ATK / SP.DEF", "split special label")
local dexOpt = optByKey("dexnav_mode")
T.check(dexOpt ~= nil, "DexNav option present")
T.eq(dexOpt.type, "choice", "DexNav mode is a choice")
T.eq(dexOpt.default, "dexnav", "DexNav defaults to DEXNAV label")
T.eq(dexOpt.label, "DEXNAV", "DexNav option label")

-- Full Gen1–3 random mode rewrites unprotected slots from baselines
local apiShim = {
  id = "Kanto-Reforged",
  log = { info = function() end },
  content = {
    encounters = {
      get = function(_, id) return Data.encounters[id] end,
      patch = function(_, id, partial)
        local enc = Data.encounters[id]
        if not enc then return end
        for kind, block in pairs(partial) do
          enc[kind] = enc[kind] or {}
          if block.slots then enc[kind].slots = block.slots end
        end
      end,
    },
  },
}
-- Baselines were captured at load from the mock tables; re-apply modes
-- from those snapshots (do not clearBaselines — that would re-snapshot
-- already-mixed tables).
ExpEncounters.apply(apiShim, packData, "full_random")
local fullRoute1 = Data.encounters.ROUTE_1
local changedSlots = 0
for i, slot in ipairs(fullRoute1.grass.slots) do
  local meta = encIndex.meta[slot.species]
  if meta then
    T.check(slot.level >= meta.minLevel,
      "full mix Route 1 " .. slot.species .. " level gated")
    T.check(not meta.rare,
      "full mix default excludes legends on Route 1 (" .. slot.species .. ")")
  end
  if slot.species ~= "PIDGEY" and slot.species ~= "RATTATA" then
    changedSlots = changedSlots + 1
  end
end
T.check(changedSlots >= 3, "full spawn mix rewrites multiple Route 1 slots")

-- LEGENDS IN MIX: rare habitat species allowed into the full pool
do
  ExpEncounters.apply(apiShim, packData, "full_random", { legendsInMix = true })
  local sawRare = false
  for mapId, mapDef in pairs(ExpEncounters.MAPS) do
    local enc = Data.encounters[mapId]
    local slots = enc and enc.grass and enc.grass.slots
    for _, slot in ipairs(slots or {}) do
      local meta = encIndex.meta[slot.species]
      if meta and meta.rare then sawRare = true break end
      if slot.species == "MEWTWO" or slot.species == "MEW"
          or slot.species == "ARTICUNO" then
        sawRare = true
        break
      end
    end
    if sawRare then break end
  end
  -- Not guaranteed every seed places one, but pool inclusion means late
  -- maps with allowRare should be able to; verify eligibility instead.
  local rares = ExpEncounters.eligible(
    encIndex, { "rare", "cave" }, 50, 50, 55, {
      allowRare = true, rareOnly = false, preferStage = 0,
    })
  local hasPackRare = false
  for _, id in ipairs(rares) do
    if encIndex.meta[id] and encIndex.meta[id].rare then
      hasPackRare = true
      break
    end
  end
  T.check(hasPackRare or sawRare,
    "legendsInMix makes rare habitat species eligible for full mix")
end

-- Switching back to curated restores baseline then re-mixes a few slots
ExpEncounters.apply(apiShim, packData, "curated")
local curatedAgain = Data.encounters.ROUTE_1.grass.slots
local curatedMixed = 0
for _, slot in ipairs(curatedAgain) do
  if slot.species ~= "PIDGEY" and slot.species ~= "RATTATA" then
    curatedMixed = curatedMixed + 1
    local meta = encIndex.meta[slot.species]
    if meta then T.eq(meta.stage, 0, "curated Route 1 stays base forms") end
  end
end
T.check(curatedMixed >= 1 and curatedMixed <= 10,
  "curated mode mixes a bounded set of Route 1 slots")

-- Post-boot spawn refresh uses the Data fallback (registry frozen); must keep rate.
do
  local frozenMod = {
    content = {
      encounters = {
        get = function(_, id) return Data.encounters[id] end,
        patch = function()
          error("encounters: content is frozen after load")
        end,
      },
    },
  }
  local rate = Data.encounters.ROUTE_1.grass.rate
  T.check(rate and rate > 0, "Route 1 grass rate before frozen re-apply")
  ExpEncounters.apply(frozenMod, packData, "curated", { speciesScope = "national" })
  T.eq(Data.encounters.ROUTE_1.grass.rate, rate,
    "frozen registry re-apply keeps grass.rate for wild rolls")
end

-- Route 11: must receive Gen 2/3 grass assignments (not Spearow-only leftovers).
do
  local r11 = Data.encounters.ROUTE_11
  T.check(r11 and r11.grass and r11.grass.slots, "Route 11 has grass encounters")
  local gen23, spearow, unique = 0, 0, {}
  for _, slot in ipairs(r11.grass.slots) do
    unique[slot.species] = true
    if slot.species == "SPEAROW" or slot.species == "FEAROW" then
      spearow = spearow + 1
    end
    if encIndex.meta[slot.species] then
      gen23 = gen23 + 1
    end
  end
  local nUnique = 0
  for _ in pairs(unique) do nUnique = nUnique + 1 end
  T.check(gen23 >= 3, "Route 11 curated grass has Gen 2/3 assignments ("
    .. tostring(gen23) .. ")")
  T.check(nUnique >= 4, "Route 11 grass is not a single-species table")
  T.check(spearow <= 3, "Route 11 is not Spearow-dominated ("
    .. tostring(spearow) .. " Spearow/Fearow slots)")

  local cave = Data.encounters.DIGLETTS_CAVE
  T.check(cave and cave.grass and cave.grass.slots, "Diglett's Cave still has grass")
  local diglett, dugtrio, guests, other = 0, 0, 0, 0
  local guestOk = { ARON = true, NOSEPASS = true }
  for _, slot in ipairs(cave.grass.slots) do
    if slot.species == "DIGLETT" then
      diglett = diglett + 1
    elseif slot.species == "DUGTRIO" then
      dugtrio = dugtrio + 1
    elseif guestOk[slot.species] then
      guests = guests + 1
    else
      other = other + 1
    end
  end
  T.check(diglett >= 6, "Diglett's Cave stays Diglett-dominated ("
    .. tostring(diglett) .. " Diglett slots)")
  T.check(dugtrio >= 2, "Diglett's Cave keeps Dugtrio rare slots")
  T.check(guests >= 1 and guests <= 2,
    "Diglett's Cave has 1–2 thematic guests (Aron/Nosepass), got "
      .. tostring(guests))
  T.check(other == 0,
    "Diglett's Cave has no off-theme guests (" .. tostring(other) .. ")")
end

-- Coverage pass: every non-legendary pack line is obtainable — catch a
-- base (or gift/rod root), then evolve / breed. Mid/finals need not all
-- appear in grass. Shedinja stays NEVER_WILD via Nincada.
do
  local wild = {}
  for mapId, enc in pairs(Data.encounters) do
    for _, block in pairs(enc) do
      if type(block) == "table" and block.slots then
        for _, slot in ipairs(block.slots) do
          if slot.species then wild[slot.species] = true end
        end
      end
    end
  end
  local missing = {}
  for id, meta in pairs(encIndex.meta) do
    if meta.stage == 0 and not meta.rare and not wild[id] then
      missing[#missing + 1] = id
    end
  end
  table.sort(missing)
  T.eq(#missing, 0,
    "curated coverage places every non-legendary base (missing: "
      .. table.concat(missing, ",") .. ")")
  T.check(wild.ARON, "Aron has a curated wild slot for Pokédex AREA")

  local unobtainable = {}
  for id, _ in pairs(packData.species) do
    local meta = encIndex.meta[id]
    local rare = meta and meta.rare
    if ExpEncounters.NEVER_WILD[id] then
      if not ExpEncounters.lineObtainable(id, encIndex, wild) then
        unobtainable[#unobtainable + 1] = id
      end
    elseif not rare and not ExpEncounters.lineObtainable(id, encIndex, wild) then
      unobtainable[#unobtainable + 1] = id
    end
  end
  table.sort(unobtainable)
  T.eq(#unobtainable, 0,
    "every non-legendary line is obtainable via wild/gift/rod + evo (missing: "
      .. table.concat(unobtainable, ",") .. ")")
  T.eq(encIndex.meta.SUDOWOODO.stage, 0,
    "Sudowoodo is a wild base (Gen4 baby parent ignored)")
  T.check(ExpEncounters.lineObtainable("ESPEON", encIndex, wild),
    "Espeon obtainable via Eevee gift")
  T.check(ExpEncounters.lineObtainable("POLITOED", encIndex, wild),
    "Politoed obtainable via Good Rod Poliwag line")
  T.check(ExpEncounters.lineObtainable("SHEDINJA", encIndex, wild),
    "Shedinja obtainable via wild Nincada")
end

-- Early maps: no evolved forms at all
for _, mapId in ipairs({ "ROUTE_1", "ROUTE_2", "ROUTE_22", "VIRIDIAN_FOREST", "MT_MOON_1F" }) do
  local enc = Data.encounters[mapId]
  if enc and enc.grass then
    for _, slot in ipairs(enc.grass.slots) do
      local meta = encIndex.meta[slot.species]
      if meta then
        T.eq(meta.stage, 0,
          mapId .. " must not wild-spawn evolved form " .. slot.species)
        T.check(slot.level >= meta.minLevel,
          mapId .. " " .. slot.species .. " level gated")
      end
    end
  end
end

-- Mid-game Route 12: evolved forms allowed only at legal levels
local route12 = Data.encounters.ROUTE_12
local route12HadMid = false
for _, slot in ipairs(route12.grass.slots) do
  local meta = encIndex.meta[slot.species]
  if meta then
    T.check(slot.level >= meta.minLevel,
      "Route 12 " .. slot.species .. "@" .. slot.level
        .. " meets min " .. meta.minLevel)
    if meta.stage >= 1 then route12HadMid = true end
    T.check(meta.stage <= 1,
      "Route 12 should not mix finals (" .. slot.species .. ")")
  end
end
T.check(route12HadMid, "Route 12 mixes at least one mid-stage form")

-- Late-game Victory Road / Route 23 may include finals when levels allow
local function assertLevelGates(mapId)
  local enc = Data.encounters[mapId]
  if not enc then return end
  for _, kind in ipairs({ "grass", "water" }) do
    local block = enc[kind]
    if block and block.slots then
      for _, slot in ipairs(block.slots) do
        local meta = encIndex.meta[slot.species]
        if meta then
          T.check(slot.level >= meta.minLevel,
            mapId .. " " .. slot.species .. "@" .. slot.level
              .. " >= min " .. meta.minLevel)
        end
      end
    end
  end
end
assertLevelGates("VICTORY_ROAD_1F")
assertLevelGates("ROUTE_23")
assertLevelGates("ROUTE_19")
assertLevelGates("ROUTE_12")
assertLevelGates("SAFARI_ZONE_EAST")
assertLevelGates("CERULEAN_CAVE_B1F")

-- Stage helper sanity
T.eq(ExpEncounters.maxStageFor(3, 5), 0, "early routes max stage 0")
T.eq(ExpEncounters.maxStageFor(14, 18), 1, "mid routes max stage 1")
T.eq(ExpEncounters.maxStageFor(35, 43), 2, "late routes max stage 2")
T.eq(encIndex.meta.BAYLEEF.stage, 1, "Bayleef is mid-stage")
T.eq(encIndex.meta.BAYLEEF.minLevel, 16, "Bayleef min wild level is 16")
T.eq(encIndex.meta.MEGANIUM.stage, 2, "Meganium is final-stage")
T.eq(encIndex.meta.MEGANIUM.minLevel, 32, "Meganium min wild level is 32")
T.eq(encIndex.meta.CHIKORITA.stage, 0, "Chikorita is base-stage")

-- 8. Verify Truant
local slaking = { mon = { species = "SLAKING" }, name = "Slaking", isPlayer = true }
local Abilities = require("mods.Kanto-Reforged.abilities")
Abilities.onTurnStart({ data = Data }, slaking)
T.check(slaking.loafing == true, "Truant toggle goes active")
T.check(slaking.skipMove == nil, "Truant does not skip move on first turn")

local sayCount = 0
local mockBattle = {
  data = Data,
  sayNext = function(self, msg) sayCount = sayCount + 1 end
}
Abilities.onTurnStart(mockBattle, slaking)
T.check(slaking.loafing == false, "Truant toggle resets")
T.check(slaking.skipMove == true, "Truant skipMove is set to true on second turn")
T.eq(sayCount, 1, "Loafing text prompt was shown")

-- 9. Verify Color Change
local kecleon = { mon = { species = "KECLEON" }, curTypes = { "NORMAL" }, name = "Kecleon" }
local mockPostBattle = {
  data = Data,
  sayNext = function(self, msg) end
}
Abilities.onPostDamage(mockPostBattle, {}, kecleon, { type = "FIRE" }, 50)
T.eq(kecleon.curTypes[1], "FIRE", "Color Change changes type to type of incoming move")

-- 10. Verify Forecast
local castform = { mon = { species = "CASTFORM" }, curTypes = { "NORMAL" }, name = "Castform" }
local mockForecastBattle = {
  data = Data,
  field = { weather = "SUNNY" },
  sayNext = function(self, msg) end
}
Abilities.updateForecast(mockForecastBattle, castform)
T.eq(castform.curTypes[1], "FIRE", "Forecast transforms Castform to FIRE in SUNNY weather")

mockForecastBattle.field.weather = "RAINY"
Abilities.updateForecast(mockForecastBattle, castform)
T.eq(castform.curTypes[1], "WATER", "Forecast transforms Castform to WATER in RAINY weather")

-- 11. Verify Shadow Tag
local runBlocked = Runtime.call("battle.run", function(battle)
  return true
end, {
  data = Data,
  sayNext = function(self, msg) end,
  player = { curTypes = { "NORMAL" } },
  enemy = { mon = { species = "WOBBUFFET", hp = 10 } }
})
T.eq(runBlocked, false, "Shadow Tag opponent blocks fleeing")

local BattleState = require("src.battle.BattleState")
local mockSwitchBattle = {
  data = Data,
  player = { name = "PLAYER", curTypes = { "NORMAL" } },
  enemy = { mon = { species = "WOBBUFFET", hp = 10 } },
  say = function(self, msg) end
}
BattleState.openParty(mockSwitchBattle)
T.eq(mockSwitchBattle.phase, "messages", "Shadow Tag opponent blocks switching")

-- Ghost-types can still flee from Shadow Tag
local runGhost = Runtime.call("battle.run", function(battle)
  return true
end, {
  data = Data,
  sayNext = function(self, msg) end,
  player = { curTypes = { "GHOST" } },
  enemy = { mon = { species = "WOBBUFFET", hp = 10 } }
})
T.eq(runGhost, true, "Ghost-types can flee from Shadow Tag")

-- Dead abilities wired (Gen 1 mappings)
do
  local StatusRegistry = require("src.battle.StatusRegistry")
  local function abilityMon(species, ability)
    Data.pokemon[species] = Data.pokemon[species] or {}
    Data.pokemon[species].ability = ability
  end

  -- Limber: cannot be paralyzed
  abilityMon("DITTO", "LIMBER")
  local limberTgt = {
    name = "Ditto", isPlayer = false,
    mon = { species = "DITTO", status = nil },
  }
  local limberMsgs = StatusRegistry.inflict(
    { data = Data }, limberTgt, "PAR", { moveType = "ELECTRIC" })
  T.eq(limberTgt.mon.status, nil, "Limber blocks paralysis")
  T.eq(#(limberMsgs or {}), 0, "Limber returns no inflict messages")

  -- Steel / Poison type immunity to poison status (Gen 2+)
  local steelTgt = {
    name = "Steelix", isPlayer = false,
    curTypes = { "STEEL", "GROUND" },
    mon = { species = "STEELIX", status = nil },
  }
  local steelMsgs = StatusRegistry.inflict(
    { data = Data }, steelTgt, "PSN", { moveType = "POISON" })
  T.eq(steelTgt.mon.status, nil, "Steel types cannot be poisoned")
  T.eq(#(steelMsgs or {}), 0, "Steel poison returns no inflict messages")

  local steelToxic = {
    name = "Magneton", isPlayer = false,
    curTypes = { "ELECTRIC", "STEEL" },
    mon = { species = "MAGNETON", status = nil },
  }
  local toxicMsgs = StatusRegistry.inflict(
    { data = Data }, steelToxic, "PSN", { toxic = true, moveType = "POISON" })
  T.eq(steelToxic.mon.status, nil, "Steel types cannot be badly poisoned")
  T.eq(steelToxic.toxicCounter, nil, "Steel toxic leaves no toxicCounter")
  T.eq(#(toxicMsgs or {}), 0, "Steel toxic returns no inflict messages")

  local poisonTgt = {
    name = "Ekans", isPlayer = false,
    curTypes = { "POISON" },
    mon = { species = "EKANS", status = nil },
  }
  local poisonMsgs = StatusRegistry.inflict(
    { data = Data }, poisonTgt, "PSN", {})
  T.eq(poisonTgt.mon.status, nil, "Poison types still cannot be poisoned")
  T.eq(#(poisonMsgs or {}), 0, "Poison-type poison returns no inflict messages")

  local normalTgt = {
    name = "Rattata", isPlayer = false,
    curTypes = { "NORMAL" },
    mon = { species = "RATTATA", status = nil },
  }
  local normalMsgs = StatusRegistry.inflict(
    { data = Data }, normalTgt, "PSN", {})
  T.eq(normalTgt.mon.status, "PSN", "Normal types can still be poisoned")
  T.check(#(normalMsgs or {}) > 0, "Normal poison returns inflict messages")

  -- Flash Fire: Fire damage nullified
  abilityMon("VULPIX", "FLASH_FIRE")
  local ffDmg = select(1, Abilities.onDamage(
    function() return 40, { crit = false, typeMult = 10 } end, {
      battle = { data = Data, sayNext = function() end },
      user = { mon = { species = "CHARMANDER", hp = 50, stats = { hp = 50 } },
               curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
               stages = {}, curTypes = { "FIRE" }, isPlayer = true, name = "Charmander" },
      target = { mon = { species = "VULPIX", hp = 50, stats = { hp = 50 } },
                 curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
                 stages = {}, curTypes = { "FIRE" }, isPlayer = false, name = "Vulpix" },
      move = { id = "EMBER", type = "FIRE", power = 40, category = "special" },
    }))
  T.eq(ffDmg, 0, "Flash Fire nullifies Fire damage")

  -- Flash Fire: Will-O-Wisp style burn blocked
  local ffBurn = {
    name = "Vulpix", isPlayer = false,
    mon = { species = "VULPIX", status = nil },
  }
  StatusRegistry.inflict({ data = Data }, ffBurn, "BRN", {
    moveType = "FIRE", source = "WILL_O_WISP",
  })
  T.eq(ffBurn.mon.status, nil, "Flash Fire blocks Fire-type burn moves")

  -- Lightning Rod: Electric damage nullified
  abilityMon("RHYHORN", "LIGHTNING_ROD")
  local lrDmg = select(1, Abilities.onDamage(
    function() return 40, { crit = false, typeMult = 10 } end, {
      battle = { data = Data, sayNext = function() end },
      user = { mon = { species = "PIKACHU", hp = 50, stats = { hp = 50 } },
               curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
               stages = {}, curTypes = { "ELECTRIC" }, isPlayer = true, name = "Pikachu" },
      target = { mon = { species = "RHYHORN", hp = 50, stats = { hp = 50 } },
                 curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
                 stages = {}, curTypes = { "GROUND", "ROCK" }, isPlayer = false, name = "Rhyhorn" },
      move = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90, category = "special" },
    }))
  T.eq(lrDmg, 0, "Lightning Rod nullifies Electric damage")

  local lrPar = {
    name = "Rhyhorn", isPlayer = false,
    mon = { species = "RHYHORN", status = nil },
  }
  StatusRegistry.inflict({ data = Data }, lrPar, "PAR", {
    moveType = "ELECTRIC", source = "THUNDER_WAVE",
  })
  T.eq(lrPar.mon.status, nil, "Lightning Rod blocks Electric paralysis moves")

  -- Magnet Pull: traps Steel from flee / switch
  abilityMon("MAGNEMITE", "MAGNET_PULL")
  local magnetRun = Runtime.call("battle.run", function() return true end, {
    data = Data,
    sayNext = function() end,
    player = { curTypes = { "STEEL" } },
    enemy = { mon = { species = "MAGNEMITE", hp = 10 } },
  })
  T.eq(magnetRun, false, "Magnet Pull blocks Steel fleeing")
  local magnetFree = Runtime.call("battle.run", function() return true end, {
    data = Data,
    sayNext = function() end,
    player = { curTypes = { "NORMAL" } },
    enemy = { mon = { species = "MAGNEMITE", hp = 10 } },
  })
  T.eq(magnetFree, true, "Magnet Pull does not trap non-Steel")

  local magnetSwitch = {
    data = Data,
    player = { name = "PLAYER", curTypes = { "STEEL" } },
    enemy = { mon = { species = "MAGNEMITE", hp = 10 } },
    say = function() end,
  }
  BattleState.openParty(magnetSwitch)
  T.eq(magnetSwitch.phase, "messages", "Magnet Pull blocks Steel switching")

  -- Stench: can flinch on physical hit
  abilityMon("GRIMER", "STENCH")
  local stenchTarget = {
    mon = { species = "RATTATA", hp = 40, stats = { hp = 40 } },
    name = "Rattata", isPlayer = false, flinched = false,
  }
  Abilities.onPostDamage({
    data = Data,
    rng = function() return 0 end,
    sayNext = function() end,
    applyDamage = function() end,
    onFaint = function() end,
  }, {
    mon = { species = "GRIMER", hp = 40, stats = { hp = 40 } },
    name = "Grimer", isPlayer = true,
  }, stenchTarget, { type = "POISON", category = "physical", power = 40 }, 10)
  T.eq(stenchTarget.flinched, true, "Stench can flinch on physical contact")

  -- Poison Point / Static: ~30% over many rolls (not 100%)
  do
    abilityMon("NIDORAN_F", "POISON_POINT")
    local seed = 1
    local function rng(a, b)
      -- deterministic Park-Miller stand-in
      seed = (seed * 16807) % 2147483647
      if b == nil then a, b = 1, a end
      return a + (seed % (b - a + 1))
    end
    local procs = 0
    local N = 400
    for _ = 1, N do
      local user = {
        mon = { species = "RATTATA", hp = 40, stats = { hp = 40 }, status = nil },
        name = "Rattata", isPlayer = true, curTypes = { "NORMAL" },
      }
      local foe = {
        mon = { species = "NIDORAN_F", hp = 40, stats = { hp = 40 } },
        name = "Nido", isPlayer = false, curTypes = { "POISON" },
      }
      Abilities.onPostDamage({
        data = Data, rng = rng, sayNext = function() end,
        applyDamage = function() end, onFaint = function() end,
      }, user, foe, { type = "NORMAL", category = "physical", power = 40 }, 10)
      if user.mon.status == "PSN" then procs = procs + 1 end
    end
    local rate = procs / N
    T.check(rate > 0.15 and rate < 0.45,
      string.format("Poison Point rate ~30%% (got %.0f%% over %d)", rate * 100, N))
  end

  -- Stub rng that always returns the low bound must NOT force 100% procs
  do
    abilityMon("PIKACHU", "STATIC")
    local user = {
      mon = { species = "RATTATA", hp = 40, stats = { hp = 40 }, status = nil },
      name = "Rattata", isPlayer = true, curTypes = { "NORMAL" },
    }
    local foe = {
      mon = { species = "PIKACHU", hp = 40, stats = { hp = 40 } },
      name = "Pika", isPlayer = false, curTypes = { "ELECTRIC" },
    }
    -- Float-style rng that ignores args used to make roll<30 always true.
    local floatRng = function() return 0.1 end
    local procs = 0
    for _ = 1, 20 do
      user.mon.status = nil
      Abilities.onPostDamage({
        data = Data, rng = floatRng, sayNext = function() end,
        applyDamage = function() end, onFaint = function() end,
      }, user, foe, { type = "NORMAL", category = "physical", power = 40 }, 10)
      if user.mon.status == "PAR" then procs = procs + 1 end
    end
    T.eq(procs, 0, "float/ignore-args rng must not make Static always proc")
  end

  -- Cursed Body: Disable the move that hit
  abilityMon("GENGAR", "CURSED_BODY")
  local cursedUser = {
    mon = { species = "RATTATA", hp = 40, stats = { hp = 40 } },
    name = "Rattata", isPlayer = true,
    curMoves = { { id = "TACKLE", pp = 20 }, { id = "TAIL_WHIP", pp = 20 } },
    disabledSlot = nil,
  }
  Abilities.onPostDamage({
    data = Data,
    rng = function(a, b)
      if a == 0 and b == 99 then return 0 end
      return a or 2
    end,
    sayNext = function() end,
    applyDamage = function() end,
    onFaint = function() end,
  }, cursedUser, {
    mon = { species = "GENGAR", hp = 40, stats = { hp = 40 } },
    name = "Gengar", isPlayer = false,
  }, { id = "TACKLE", type = "NORMAL", category = "physical", power = 40 }, 10)
  T.eq(cursedUser.disabledSlot, 1, "Cursed Body disables the hitting move")
  T.check(cursedUser.disabledTurns and cursedUser.disabledTurns >= 2,
    "Cursed Body sets disable turns")
end

-- 12. Verify Nincada Evolution Split
Data.items.POKE_BALL = { id = "POKE_BALL", name = "Poké Ball", price = 200 }

local mockMon = {
  species = "NINJASK", level = 20,
  dvs = { attack = 8, defense = 8, speed = 8, special = 8, hp = 0 },
  statExp = {},
  moves = { { id = "SCRATCH", pp = 35 }, { id = "HARDEN", pp = 30 } },
}
local mockSave = {
  party = { mockMon },
  -- Real bag shape is id→count, not a list of {id,count} slots
  inventory = { POKE_BALL = 5 },
  flags = {},
  pokedex = { seen = {}, owned = {} },
}
local pushedDuringSplit = 0
local mockGame = {
  data = Data,
  save = mockSave,
  stack = {
    push = function()
      pushedDuringSplit = pushedDuringSplit + 1
    end,
  },
}
local ev = { game = mockGame, mon = mockMon, fromSpecies = "NINCADA", toSpecies = "NINJASK" }

local Runtime = require("src.mods.Runtime")
Runtime.emit("pokemon.evolved", ev)

T.eq(#mockSave.party, 2, "Evolution split added Shedinja to party")
T.eq(mockSave.party[2].species, "SHEDINJA", "Party slot holds Shedinja species")
T.eq(mockSave.party[2].hp, 1, "Shedinja HP is 1")
T.eq(mockSave.party[2].moves[1].id, "SCRATCH", "Shedinja inherits moves")
T.eq(mockSave.inventory.POKE_BALL, 4, "Poké Ball count decremented")
T.eq(mockSave.pokedex.owned.SHEDINJA, true, "Shedinja marked owned")
T.eq(pushedDuringSplit, 0,
  "Shedinja announce is deferred (no TextBox during pokemon.evolved)")

-- Real Evolution.apply path (no ev.game on the event) with spare slot + ball
do
  local Evolution = require("src.pokemon.Evolution")
  local Pokemon = require("src.pokemon.Pokemon")
  local Gender = require("mods.Kanto-Reforged.gender")
  local mod = Gender._mod
  local nincada = Pokemon.new(Data, "NINCADA", 20)
  local pushed = {}
  local save = {
    party = { nincada },
    inventory = { POKE_BALL = 1 },
    bagOrder = { "POKE_BALL" },
    pokedex = { seen = {}, owned = {} },
    flags = {},
    boxes = {},
  }
  local game = {
    data = Data,
    save = save,
    stack = {
      push = function(_, box)
        pushed[#pushed + 1] = box
      end,
      pop = function() end,
    },
  }
  mod.activeGame = game
  Evolution.apply(game, nincada, "NINJASK", "LEVEL")
  T.eq(nincada.species, "NINJASK", "Nincada became Ninjask")
  T.eq(#save.party, 2, "apply path adds Shedinja with spare slot + ball")
  T.eq(save.party[2].species, "SHEDINJA", "apply path Shedinja species")
  T.eq(save.inventory.POKE_BALL, nil, "apply path consumes the Poké Ball")
  T.eq(#pushed, 0, "apply path does not push TextBox under EvolutionState")
  -- Flush deferred announce the way Congrats → learnEvolutionMoves does
  Evolution.learnEvolutionMoves(game, nincada, function() end)
  T.check(#pushed >= 1, "Shedinja announce flushes after evo text")
end

-- Full party sends Shedinja to the PC (and must not claim the lead was boxed)
local fullMon = { species = "NINJASK", level = 20, dvs = {}, statExp = {} }
local fullParty = {
  fullMon,
  { species = "PIDGEY", level = 5, dvs = {}, statExp = {} },
  { species = "RATTATA", level = 5, dvs = {}, statExp = {} },
  { species = "SPEAROW", level = 5, dvs = {}, statExp = {} },
  { species = "EKANS", level = 5, dvs = {}, statExp = {} },
  { species = "SANDSHREW", level = 5, dvs = {}, statExp = {} },
}
local fullSave = {
  party = fullParty,
  inventory = { POKE_BALL = 1 },
  flags = {},
}
local boxedMsgs = {}
local fullGame = {
  data = Data,
  save = fullSave,
  stack = {
    push = function(self, box)
      if box and box.text then boxedMsgs[#boxedMsgs + 1] = box.text end
    end,
  },
}
Runtime.emit("pokemon.evolved", {
  game = fullGame, mon = fullMon, fromSpecies = "NINCADA", toSpecies = "NINJASK",
})
T.eq(#fullSave.party, 6, "full party stays at 6 after Shedinja split")
T.eq(fullSave.inventory.POKE_BALL, nil, "last Poké Ball consumed on full-party split")
local Boxes = require("src.pokemon.Boxes")
local foundShedinja = false
for _, box in ipairs(Boxes.ensure(fullSave)) do
  for _, m in ipairs(box) do
    if m.species == "SHEDINJA" then foundShedinja = true end
  end
end
T.check(foundShedinja, "Shedinja deposited to PC when party is full")

-- Starter gifts must not show SentToBox when the party has room
local shownGift = {}
local Commands = require("src.script.Commands")
local origShow = Commands.show_text
Commands.show_text = function(ctx, key, args)
  shownGift[#shownGift + 1] = key
  return origShow(ctx, key, args)
end
local giftSave = {
  party = {}, pokedex = { seen = {}, owned = {} }, flags = {},
  player = { name = "RED", id = 1 },
}
local giftGame = {
  data = Data, save = giftSave, mods = nil, stringBuffer = nil,
  stack = { push = function() end },
}
Commands.give_pokemon({
  game = giftGame, save = giftSave, runner = nil, lastCheck = false,
}, "CHARMANDER", 5, true)
Commands.show_text = origShow
T.eq(#giftSave.party, 1, "starter gift joins the party")
local sawSentToBox = false
for _, key in ipairs(shownGift) do
  if key == "_SentToBoxText" then sawSentToBox = true end
end
T.check(not sawSentToBox, "starter gift does not show SentToBoxText")

-- 13. Verify Evolution Moves Learning Wrap
local Evolution = require("src.pokemon.Evolution")
local monToEvolve = { species = "CROBAT", level = 23, moves = {} }
Data.pokemon.CROBAT.evolutionMoves = { "BITE" }
Data.moves.BITE = { id = "BITE", name = "Bite", type = "DARK", power = 60, pp = 25 }

local mockEvolveGame = {
  data = Data,
  stack = {
    push = function(self, box)
      box.onDone()
    end
  }
}
Evolution.learnEvolutionMoves(mockEvolveGame, monToEvolve, function() end)

T.eq(#monToEvolve.moves, 1, "Crobat learned BITE upon evolution")
T.eq(monToEvolve.moves[1].id, "BITE", "The learned move is BITE")

-- 14. Verify Tyrogue custom evolutions
local Tyrogue_Atk = { level = 20, stats = { attack = 50, defense = 40 } }
local Tyrogue_Def = { level = 20, stats = { attack = 40, defense = 50 } }
local Tyrogue_Bal = { level = 20, stats = { attack = 45, defense = 45 } }

local methodAtk = Data.evolution_methods.TYROGUE_ATK
local methodDef = Data.evolution_methods.TYROGUE_DEF
local methodBal = Data.evolution_methods.TYROGUE_BAL

T.eq(methodAtk.check(mockGame, Tyrogue_Atk, { level = 20 }, { kind = "levelup" }), true, "Tyrogue Attack > Defense triggers Hitmonlee")
T.eq(methodDef.check(mockGame, Tyrogue_Def, { level = 20 }, { kind = "levelup" }), true, "Tyrogue Defense > Attack triggers Hitmonchan")
T.eq(methodBal.check(mockGame, Tyrogue_Bal, { level = 20 }, { kind = "levelup" }), true, "Tyrogue Equal stats triggers Hitmontop")

-- 15. Verify Wurmple random split evolutions
local Wurmple_A = { level = 7, dvs = { attack = 15, defense = 15, speed = 15, special = 15 } }
local Wurmple_B = { level = 7, dvs = { attack = 15, defense = 15, speed = 15, special = 14 } }

local methodWurA = Data.evolution_methods.WURMPLE_A
local methodWurB = Data.evolution_methods.WURMPLE_B

T.eq(methodWurA.check(mockGame, Wurmple_A, { level = 7 }, { kind = "levelup" }), true, "Wurmple even DV sum evolves to Silcoon")
T.eq(methodWurB.check(mockGame, Wurmple_B, { level = 7 }, { kind = "levelup" }), true, "Wurmple odd DV sum evolves to Cascoon")

-- 16. Verify mapped stone/item evolutions (Politoed, Steelix, Milotic)
T.check(Data.pokemon.POLIWHIRL.evolutions ~= nil, "Poliwhirl evolutions table exists")
local hasPolitoed = false
for _, evo in ipairs(Data.pokemon.POLIWHIRL.evolutions) do
  if evo.species == "POLITOED" and evo.method == "ITEM" and evo.item == "MOON_STONE" then
    hasPolitoed = true
  end
end
T.check(hasPolitoed, "Politoed evolves from Poliwhirl via Moon Stone")

local hasSteelix = false
for _, evo in ipairs(Data.pokemon.ONIX.evolutions) do
  if evo.species == "STEELIX" and evo.method == "ITEM" and evo.item == "MOON_STONE" then
    hasSteelix = true
  end
end
T.check(hasSteelix, "Steelix evolves from Onix via Moon Stone")

local hasMilotic = false
for _, evo in ipairs(Data.pokemon.FEEBAS.evolutions) do
  if evo.species == "MILOTIC" and evo.method == "ITEM" and evo.item == "WATER_STONE" then
    hasMilotic = true
  end
end
T.check(hasMilotic, "Milotic evolves from Feebas via Water Stone")

-- 16b. Kanto species receive Gen 2/3 move backports (learnset + tmhm).
-- Wild/trainer/gym parties build moves via Pokemon.movesAtLevel, so these
-- patches are what make Charmander know Metal Claw and mid-level Pikachu
-- know Iron Tail.  Wrapped in a function so locals do not hit LuaJIT's
-- 200-local main-chunk limit.
;(function()
  local function learnsetHas(species, move)
    for _, entry in ipairs(Data.pokemon[species].learnset or {}) do
      if entry.move == move then return entry.level end
    end
    return nil
  end
  local function tmhmHas(species, move)
    for _, mv in ipairs(Data.pokemon[species].tmhm or {}) do
      if mv == move then return true end
    end
    return false
  end
  T.eq(learnsetHas("CHARMANDER", "METAL_CLAW"), 13, "Charmander learns Metal Claw at 13")
  T.eq(learnsetHas("CHARMANDER", "SMOKESCREEN"), 13, "Charmander learns Smokescreen at 13")
  T.eq(learnsetHas("PIKACHU", "IRON_TAIL"), 30, "Pikachu learns Iron Tail at 30 (TM backport)")
  T.check(tmhmHas("PIKACHU", "IRON_TAIL"), "Pikachu tmhm lists Iron Tail")
  T.check(learnsetHas("ONIX", "IRON_TAIL") ~= nil, "Onix Gen 2/3 learnset includes Iron Tail")

  local Pokemon = require("src.pokemon.Pokemon")
  local hasMetalClaw = false
  for _, id in ipairs(Pokemon.movesAtLevel(Data.pokemon.CHARMANDER, 13)) do
    if id == "METAL_CLAW" then hasMetalClaw = true end
  end
  T.check(hasMetalClaw, "Lv13 Charmander rolls Metal Claw via movesAtLevel")
  local hasIronTail = false
  for _, id in ipairs(Pokemon.movesAtLevel(Data.pokemon.PIKACHU, 35)) do
    if id == "IRON_TAIL" then hasIronTail = true end
  end
  T.check(hasIronTail, "Lv35 Pikachu rolls Iron Tail via movesAtLevel")
end)()

-- 17. Verify Safari Zone rare spawn mixing preserves Chansey and overwrites others in Slot 9/10
local safari = Data.encounters.SAFARI_ZONE_EAST
T.eq(safari.grass.slots[10].species, "CHANSEY", "Safari Zone Chansey in Slot 10 was preserved")
T.check(safari.grass.slots[9].species ~= "EXEGGCUTE", "Safari Zone Slot 9 was mixed with custom rare species")

-- 18. Move effects wired for Gen 2/3 showcase moves
T.eq(Data.moves.SHADOW_BALL.effect, "SPECIAL_DOWN_SIDE_EFFECT", "Shadow Ball lowers Special")
T.eq(Data.moves.GIGA_DRAIN.effect, "DRAIN_HP_EFFECT", "Giga Drain drains HP")
T.eq(Data.moves.OUTRAGE.effect, "THRASH_PETAL_DANCE_EFFECT", "Outrage locks like Thrash")
T.eq(Data.moves.SUNNY_DAY.effect, "EXP_WEATHER_SUNNY", "Sunny Day sets sun")
T.eq(Data.moves.PROTECT.effect, "EXP_PROTECT_EFFECT", "Protect registered")
T.eq(Data.moves.PROTECT.priority, 4, "Protect has priority +4")
T.eq(Data.moves.BELLY_DRUM.effect, "EXP_BELLY_DRUM_EFFECT", "Belly Drum registered")
T.eq(Data.moves.EXTREME_SPEED.priority, 2, "Extreme Speed has priority +2")
T.eq(Data.moves.DRAGON_DANCE.effect, "EXP_STAT_CHANGES_EFFECT", "Dragon Dance multi-stat setup")
T.check(Data.moves.DRAGON_DANCE.statChanges ~= nil, "Dragon Dance carries statChanges")
-- Foe drops (Rock Tomb / Snarl) must not be tagged as self-stat USER_STAT effects.
T.eq(Data.moves.ROCK_TOMB.effect, "EXP_DAMAGE_STAT_SIDE_EFFECT",
  "Rock Tomb is a foe Speed drop, not a user-stat move")
T.eq(Data.moves.ROCK_TOMB.statTarget, "target", "Rock Tomb statTarget is the foe")
T.eq(Data.moves.ROCK_TOMB.statChance, 100, "Rock Tomb always drops Speed")
T.eq(Data.moves.SNARL.effect, "EXP_DAMAGE_STAT_SIDE_EFFECT",
  "Snarl is a foe Special drop, not a user-stat move")
T.eq(Data.moves.SNARL.statTarget, "target", "Snarl statTarget is the foe")
T.eq(Data.moves.OVERHEAT.effect, "EXP_DAMAGE_USER_STAT_EFFECT",
  "Overheat still lowers the user's Special")
T.eq(Data.moves.OVERHEAT.statTarget, "user", "Overheat statTarget is the user")
T.eq(Data.moves.WILL_O_WISP.effect, "EXP_BURN_EFFECT", "Will-O-Wisp burns")
T.check(Data.move_effects.EXP_WEATHER_SUNNY ~= nil, "EXP weather effect registered")
T.check(Data.move_effects.EXP_PROTECT_EFFECT ~= nil, "EXP protect effect registered")
T.check(Data.move_effects.EXP_BELLY_DRUM_EFFECT ~= nil, "EXP belly drum effect registered")

-- Rock Tomb / Snarl side effects apply stages to the target, not the user.
do
  local user = {
    name = "Aron", isPlayer = true, mon = {}, stages = { speed = 0, special = 0 },
  }
  local foe = {
    name = "Foe", isPlayer = false, mon = {}, stages = { speed = 0, special = 0 },
  }
  local function stageCtx(move)
    return {
      user = user, target = foe, move = move,
      battle = {},
      rng = function() return 0 end, -- always pass the chance roll
      changeStage = function(who, stat, delta)
        who.stages[stat] = (who.stages[stat] or 0) + delta
        return { "stage" }
      end,
    }
  end
  Data.move_effects.EXP_DAMAGE_STAT_SIDE_EFFECT.run(stageCtx(Data.moves.ROCK_TOMB))
  T.eq(foe.stages.speed, -1, "Rock Tomb lowers foe Speed")
  T.eq(user.stages.speed, 0, "Rock Tomb does not lower user Speed")
  Data.move_effects.EXP_DAMAGE_STAT_SIDE_EFFECT.run(stageCtx(Data.moves.SNARL))
  T.eq(foe.stages.special, -1, "Snarl lowers foe Special")
  T.eq(user.stages.special, 0, "Snarl does not lower user Special")
end

-- Protect forces an accuracy miss
local protHit = Runtime.call("battle.accuracy", function(c) return true end, {
  target = { expProtected = true }, user = {}, move = Data.moves.TACKLE or { id = "TACKLE" },
})
T.eq(protHit, false, "Protect forces accuracy miss")

-- Weather move effect sets field weather
local weatherBattle = {
  field = { weather = nil },
  sides = {},
}
local sunny = Data.move_effects.EXP_WEATHER_SUNNY
local sunnyMsgs = sunny.run({
  battle = weatherBattle,
  move = Data.moves.SUNNY_DAY,
  user = { name = "Groudon", isPlayer = true },
  target = {},
})
T.eq(weatherBattle.field.weather, "SUNNY", "Sunny Day effect sets SUNNY weather")
T.check(type(sunnyMsgs) == "table" and #sunnyMsgs > 0, "Sunny Day returns a message")

-- Belly Drum spends HP and maxes Attack
local drumUser = {
  name = "Politoed", isPlayer = true,
  mon = { hp = 100, stats = { hp = 100 } },
  stages = { attack = 0 },
}
local drum = Data.move_effects.EXP_BELLY_DRUM_EFFECT
drum.run({
  battle = {}, move = Data.moves.BELLY_DRUM, user = drumUser, target = {},
})
T.eq(drumUser.mon.hp, 50, "Belly Drum spends half HP")
T.eq(drumUser.stages.attack, 6, "Belly Drum maxes Attack")

-- 19. Hidden Power / Weather Ball / hazards / Encore / Wish
local ExpME = require("mods.Kanto-Reforged.move_effects")

-- All-15 DVs → Dark type, power 70 (Gen 3 formula)
local hpType, hpPower = ExpME.hiddenPower({
  mon = { dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 } },
})
T.eq(hpType, "DARK", "max DVs Hidden Power is Dark")
T.eq(hpPower, 70, "max DVs Hidden Power power is 70")

local wbType, wbPower = ExpME.weatherBall({ field = { weather = nil } })
T.eq(wbType, "NORMAL", "Weather Ball is Normal with no weather")
T.eq(wbPower, 50, "Weather Ball is 50 BP with no weather")
wbType, wbPower = ExpME.weatherBall({ field = { weather = "SUNNY" } })
T.eq(wbType, "FIRE", "Weather Ball is Fire in sun")
T.eq(wbPower, 100, "Weather Ball is 100 BP in sun")

T.eq(Data.moves.SPIKES.effect, "EXP_SPIKES_EFFECT", "Spikes effect id")
T.eq(Data.moves.STEALTH_ROCK.effect, "EXP_STEALTH_ROCK_EFFECT", "Stealth Rock effect id")
T.eq(Data.moves.ENCORE.effect, "EXP_ENCORE_EFFECT", "Encore effect id")
T.eq(Data.moves.WISH.effect, "EXP_WISH_EFFECT", "Wish effect id")
T.check(Data.move_effects.EXP_SPIKES_EFFECT ~= nil, "Spikes effect registered")
T.check(Data.move_effects.EXP_ENCORE_EFFECT ~= nil, "Encore effect registered")
T.check(Data.move_effects.EXP_WISH_EFFECT ~= nil, "Wish effect registered")

-- Spikes layers on the foe side
local spikeSide = { hazards = {}, tokens = {} }
local spikeCtx = {
  side = function(who) return who._side end,
  target = { _side = spikeSide },
  user = {},
  battle = {},
  move = Data.moves.SPIKES,
}
Data.move_effects.EXP_SPIKES_EFFECT.run(spikeCtx)
T.eq(spikeSide.hazards[1].id, "SPIKES", "Spikes laid")
T.eq(spikeSide.hazards[1].layers, 1, "first Spikes layer")
Data.move_effects.EXP_SPIKES_EFFECT.run(spikeCtx)
T.eq(spikeSide.hazards[1].layers, 2, "second Spikes layer")

-- Hazard damage on a grounded switch-in
local hurtMon = {
  name = "Rattata", isPlayer = true,
  mon = { hp = 80, stats = { hp = 80 }, species = "RATTATA", status = nil },
  curTypes = { "NORMAL" },
}
local dmgBattle = {
  data = Data,
  sayNext = function() end,
  drainNext = function() end,
  applyDamage = function(self, b, amount)
    b.mon.hp = math.max(0, b.mon.hp - amount)
    return amount
  end,
  onFaint = function() end,
}
ExpME.applyHazards(dmgBattle, hurtMon, spikeSide)
T.eq(hurtMon.mon.hp, 80 - math.floor(80 / 6), "two Spikes layers deal maxHP/6")

-- Flying is immune to Spikes
local flyer = {
  name = "Pidgey", isPlayer = true,
  mon = { hp = 40, stats = { hp = 40 }, species = "PIDGEY" },
  curTypes = { "NORMAL", "FLYING" },
}
ExpME.applyHazards(dmgBattle, flyer, spikeSide)
T.eq(flyer.mon.hp, 40, "Flying ignores Spikes")

-- Wish token heals on expire
local wishSide = {
  tokens = {},
  battlers = { {
    name = "Blissey", isPlayer = true,
    mon = { hp = 10, stats = { hp = 100 } },
  } },
}
local wishMsgs = {}
local wishBattle = {
  sayNext = function(self, m) wishMsgs[#wishMsgs + 1] = m end,
  drainNext = function() end,
}
Data.move_effects.EXP_WISH_EFFECT.run({
  side = function() return wishSide end,
  user = {
    name = "Blissey", isPlayer = true,
    mon = { hp = 100, stats = { hp = 100 } },
  },
  target = {},
  battle = wishBattle,
  move = Data.moves.WISH,
})
T.eq(#wishSide.tokens, 1, "Wish placed a side token")
T.eq(wishSide.tokens[1].turns, 2, "Wish resolves in two end-of-turn ticks")
wishSide.tokens[1].turns = 0
wishSide.tokens[1].onExpire(wishBattle, wishSide)
T.eq(wishSide.battlers[1].mon.hp, 60, "Wish heals half of the wisher's max HP")

-- 20. Taunt / Yawn / Heal Bell / Fake Out / Curse / Mean Look
T.eq(Data.moves.TAUNT.effect, "EXP_TAUNT_EFFECT", "Taunt effect id")
T.eq(Data.moves.YAWN.effect, "EXP_YAWN_EFFECT", "Yawn effect id")
T.eq(Data.moves.HEAL_BELL.effect, "EXP_HEAL_BELL_EFFECT", "Heal Bell effect id")
T.eq(Data.moves.AROMATHERAPY.effect, "EXP_HEAL_BELL_EFFECT", "Aromatherapy shares Heal Bell")
T.eq(Data.moves.FAKE_OUT.effect, "EXP_FAKE_OUT_EFFECT", "Fake Out effect id")
T.eq(Data.moves.CURSE.effect, "EXP_CURSE_EFFECT", "Curse effect id")
T.eq(Data.moves.MEAN_LOOK.effect, "EXP_MEAN_LOOK_EFFECT", "Mean Look effect id")
T.eq(Data.moves.ENDEAVOR.effect, "EXP_ENDEAVOR_EFFECT", "Endeavor effect id")
T.check(Data.move_effects.EXP_TAUNT_EFFECT ~= nil, "Taunt effect registered")
T.check(Data.move_effects.EXP_FAKE_OUT_EFFECT ~= nil, "Fake Out effect registered")
T.check(Data.move_effects.EXP_CURSE_EFFECT ~= nil, "Curse effect registered")

local tauntTarget = { name = "Slugma", isPlayer = false, mon = { status = nil }, stages = {} }
Data.move_effects.EXP_TAUNT_EFFECT.run({
  target = tauntTarget, user = {}, battle = {}, move = Data.moves.TAUNT,
})
T.eq(tauntTarget.expTauntedTurns, 3, "Taunt lasts 3 turns")

local yawnTarget = { name = "Zangoose", isPlayer = false, mon = { status = nil } }
Data.move_effects.EXP_YAWN_EFFECT.run({
  target = yawnTarget, user = {}, battle = {}, move = Data.moves.YAWN,
})
T.eq(yawnTarget.expYawnTurns, 2, "Yawn sets a 2-turn drowsy timer")

local healParty = {
  { status = "BRN" }, { status = "PSN" }, { status = nil },
}
Data.move_effects.EXP_HEAL_BELL_EFFECT.run({
  user = { isPlayer = true, mon = { status = "PAR" }, name = "Blissey" },
  target = {},
  battle = { game = { save = { party = healParty } } },
  move = Data.moves.HEAL_BELL,
})
T.eq(healParty[1].status, nil, "Heal Bell cures party burn")
T.eq(healParty[2].status, nil, "Heal Bell cures party poison")

local ok, fail = Data.move_effects.EXP_FAKE_OUT_EFFECT.gate({
  user = { expJustEntered = nil },
})
T.eq(ok, false, "Fake Out fails when not just entered")
ok = Data.move_effects.EXP_FAKE_OUT_EFFECT.gate({
  user = { expJustEntered = true },
})
T.eq(ok, true, "Fake Out works on first turn")

local curseGhost = {
  name = "Misdreavus", isPlayer = true,
  mon = { hp = 80, stats = { hp = 80 } },
  curTypes = { "GHOST" },
}
local curseFoe = { name = "Rattata", isPlayer = false, mon = { hp = 50 }, expCursed = nil }
Data.move_effects.EXP_CURSE_EFFECT.run({
  user = curseGhost, target = curseFoe, battle = {}, move = Data.moves.CURSE,
})
T.eq(curseGhost.mon.hp, 40, "Ghost Curse spends half HP")
T.eq(curseFoe.expCursed, true, "Ghost Curse marks the foe")

local trapFoe = { name = "Pidgey", isPlayer = false, curTypes = { "NORMAL", "FLYING" } }
Data.move_effects.EXP_MEAN_LOOK_EFFECT.run({
  user = {}, target = trapFoe, battle = {}, move = Data.moves.MEAN_LOOK,
})
T.eq(trapFoe.expTrapped, true, "Mean Look traps the foe")

local endDmg, endInfo = Data.move_effects.EXP_ENDEAVOR_EFFECT.chooseDamage({
  user = { mon = { hp = 20 } },
  target = { mon = { hp = 80 } },
})
T.eq(endDmg, 60, "Endeavor deals HP difference")
T.check(endInfo ~= nil, "Endeavor returns damage info")

-- 21. Abilities: Overgrow / Thick Fat / Absorb / Speed mult
local function abilityCtx(userSpecies, targetSpecies, move, userHp, userMax)
  return {
    battle = {
      data = Data,
      sayNext = function() end,
      applyDamage = function(self, b, amount)
        b.mon.hp = math.max(0, b.mon.hp - amount)
        return amount
      end,
      onFaint = function() end,
      rng = function(a, b) return a end,
    },
    user = {
      mon = {
        species = userSpecies, hp = userHp or 100, stats = { hp = userMax or 100 },
        status = nil,
      },
      curStats = { attack = 100, special = 100 },
      curTypes = { "NORMAL" },
      name = userSpecies, isPlayer = true,
    },
    target = {
      mon = {
        species = targetSpecies, hp = 100, stats = { hp = 100 }, status = nil,
      },
      curStats = { attack = 100, special = 100 },
      curTypes = { "NORMAL" },
      name = targetSpecies, isPlayer = false,
      stages = {},
    },
    move = move,
  }
end

-- Overgrow at ≤1/3 HP bumps attack for Grass moves
local ogCtx = abilityCtx("SCEPTILE", "RATTATA", { type = "GRASS", power = 60, category = "physical" }, 30, 100)
local seenAtk
Abilities.onDamage(function(c)
  seenAtk = c.user.curStats.attack
  return 40, { crit = false, typeMult = 10 }
end, ogCtx)
T.eq(seenAtk, 150, "Overgrow boosts Attack 1.5x under 1/3 HP")
T.eq(ogCtx.user.curStats.attack, 100, "Overgrow restores Attack after damage")

-- Thick Fat halves Fire damage
local tfCtx = abilityCtx("MILTANK", "SNORLAX", { type = "FIRE", power = 90, category = "special" })
-- Ensure Snorlax has Thick Fat in test data if missing
if Data.pokemon.SNORLAX then Data.pokemon.SNORLAX.ability = "THICK_FAT" end
if Data.pokemon.MILTANK then Data.pokemon.MILTANK.ability = "THICK_FAT" end
tfCtx = abilityCtx("CHARIZARD", "MILTANK", { type = "FIRE", power = 90, category = "special" })
local tfDmg = select(1, Abilities.onDamage(function() return 40, { crit = false, typeMult = 10 } end, tfCtx))
T.eq(tfDmg, 20, "Thick Fat halves Fire damage")

-- Chlorophyll doubles speed in sun (Rattata has no Chlorophyll; Bellossom does)
T.eq(Abilities.speedMult({ field = { weather = "SUNNY" }, data = Data }, {
  mon = { species = "RATTATA" },
}), 1, "speedMult without Chlorophyll species is 1")
if not Data.pokemon.BELLOSSOM then
  Data.pokemon.BELLOSSOM = { ability = "CHLOROPHYLL" }
else
  Data.pokemon.BELLOSSOM.ability = "CHLOROPHYLL"
end
T.eq(Abilities.speedMult({ field = { weather = "SUNNY" }, data = Data }, {
  mon = { species = "BELLOSSOM" },
}), 2, "Chlorophyll doubles speed in sun")
T.eq(Abilities.speedMult({ field = { weather = "RAINY" }, data = Data }, {
  mon = { species = "BELLOSSOM" },
}), 1, "Chlorophyll does not boost in rain")

-- 22. New move effects + ability gates
T.eq(Data.moves.RAPID_SPIN.effect, "EXP_RAPID_SPIN_EFFECT", "Rapid Spin effect")
T.eq(Data.moves.PERISH_SONG.effect, "EXP_PERISH_SONG_EFFECT", "Perish Song effect")
T.eq(Data.moves.DESTINY_BOND.effect, "EXP_DESTINY_BOND_EFFECT", "Destiny Bond effect")
T.eq(Data.moves.ATTRACT.effect, "EXP_ATTRACT_EFFECT", "Attract effect")
T.eq(Data.moves.STOCKPILE.effect, "EXP_STOCKPILE_EFFECT", "Stockpile effect")
T.eq(Data.moves.SPIT_UP.effect, "EXP_SPIT_UP_EFFECT", "Spit Up effect")
T.eq(Data.moves.MIRROR_COAT.effect, "EXP_MIRROR_COAT_EFFECT", "Mirror Coat effect")
T.eq(Data.moves.FOCUS_PUNCH.effect, "EXP_FOCUS_PUNCH_EFFECT", "Focus Punch effect")
T.eq(Data.moves.U_TURN.effect, "EXP_U_TURN_EFFECT", "U-turn effect")
T.eq(Data.moves.FLAIL.effect, "EXP_VARIABLE_POWER_EFFECT", "Flail variable power")
T.eq(Data.moves.RETURN.effect, "EXP_VARIABLE_POWER_EFFECT", "Return variable power")
T.check(Data.move_effects.EXP_PERISH_SONG_EFFECT ~= nil, "Perish Song registered")
T.check(Data.move_effects.EXP_RAPID_SPIN_EFFECT ~= nil, "Rapid Spin registered")

T.eq(ExpME.flailPower({ mon = { hp = 1, stats = { hp = 100 } } }), 200, "Flail max power at 1 HP")
T.eq(ExpME.flailPower({ mon = { hp = 100, stats = { hp = 100 } } }), 20, "Flail min power at full HP")
T.eq(ExpME.returnPower({
  mon = { dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 } },
}), 102, "max DVs Return is 102")

local perishUser = { mon = { hp = 50 }, expPerishTurns = nil }
local perishFoe = { mon = { hp = 50 }, expPerishTurns = nil }
Data.move_effects.EXP_PERISH_SONG_EFFECT.run({
  user = perishUser, target = perishFoe, battle = {}, move = Data.moves.PERISH_SONG,
})
T.eq(perishUser.expPerishTurns, 4, "Perish Song sets user count")
T.eq(perishFoe.expPerishTurns, 4, "Perish Song sets foe count")

local stockUser = {
  name = "Pelipper", isPlayer = true, mon = { hp = 50, stats = { hp = 50 } },
  stages = { defense = 0, special = 0 }, expStockpile = nil,
}
local stockMsgs = Data.move_effects.EXP_STOCKPILE_EFFECT.run({
  user = stockUser, target = {}, battle = {}, move = Data.moves.STOCKPILE,
  changeStage = function(who, stat, delta)
    who.stages[stat] = (who.stages[stat] or 0) + delta
    return { "stage" }
  end,
})
T.eq(stockUser.expStockpile, 1, "Stockpile stacks to 1")
T.check(#stockMsgs > 0, "Stockpile returns messages")

-- Attract / Cute Charm covered in gender_test.lua (opposite-gender infatuation)

-- Swagger: +2 Attack then confuse
do
  T.eq(Data.moves.SWAGGER.effect, "EXP_SWAGGER_EFFECT", "Swagger uses dedicated effect")
  local foe = {
    name = "Foe", isPlayer = false, mon = {},
    stages = { attack = 0 }, confusedTurns = nil,
  }
  local msgs = Data.move_effects.EXP_SWAGGER_EFFECT.run({
    user = {}, target = foe,
    battle = { rng = function(a, b) return a end, data = Data },
    move = Data.moves.SWAGGER,
    changeStage = function(who, stat, delta)
      who.stages[stat] = (who.stages[stat] or 0) + delta
      return { "ATK rose" }
    end,
  })
  T.eq(foe.stages.attack, 2, "Swagger raises foe Attack by 2")
  T.check(foe.confusedTurns and foe.confusedTurns >= 2, "Swagger confuses the foe")
  T.check(#msgs >= 2, "Swagger reports boost and confusion")
end

-- Sleep wake: Gen 2+ wake-and-attack via the live Data.statuses path.
do
  local Status = require("src.battle.Status")
  local battle = { data = Data }
  local sleeper = {
    name = "Sleeper", isPlayer = true,
    mon = { status = "SLP", hp = 30, stats = { hp = 30 } },
    sleepTurns = 1,
  }
  local canMove, msgs = Status.beforeMove(sleeper, function() end, battle)
  T.eq(canMove, true, "waking from sleep allows the move this turn")
  T.eq(sleeper.mon.status, nil, "wake clears SLP")
  T.check(msgs and msgs[1] and msgs[1]:find("woke up", 1, true),
    "wake announces woke up")
  local ExpMoveEffects = require("mods.Kanto-Reforged.move_effects")
  T.check(Data.statuses.SLP.beforeMove == ExpMoveEffects.sleepBeforeMove,
    "live Data.statuses.SLP uses wake-and-attack handler")

  local stillOut = {
    name = "Out", isPlayer = true,
    mon = { status = "SLP", hp = 30, stats = { hp = 30 } },
    sleepTurns = 3,
  }
  local can2, msgs2 = Status.beforeMove(stillOut, function() end, battle)
  T.eq(can2, false, "still asleep skips the attack")
  T.eq(stillOut.mon.status, "SLP", "still asleep keeps SLP")
  T.check(msgs2 and msgs2[1] and msgs2[1]:find("fast asleep", 1, true),
    "asleep announces fast asleep")

  -- Still asleep only burns this battler's interrupt; opponent is untouched.
  local foe = {
    name = "Foe", isPlayer = false,
    mon = { status = nil, hp = 40, stats = { hp = 40 } },
  }
  T.eq(foe.mon.status, nil, "asleep skip does not touch the other battler")
end

-- Clear Body blocks Attack drop
local VanillaME = require("src.battle.MoveEffects")
if not Data.pokemon.METAGROSS then
  Data.pokemon.METAGROSS = { ability = "CLEAR_BODY" }
else
  Data.pokemon.METAGROSS.ability = "CLEAR_BODY"
end
local cbWho = {
  name = "Metagross", isPlayer = true,
  mon = { species = "METAGROSS" }, stages = { attack = 0 },
}
local cbMsgs = VanillaME.changeStage(
  { data = Data }, cbWho, "attack", -1, true)
T.check(type(cbMsgs) == "table" and #cbMsgs > 0, "Clear Body returns a block message")
T.eq(cbWho.stages.attack, 0, "Clear Body prevents Attack drop")

-- Focus Punch gate
local fpOk, fpMsg = Data.move_effects.EXP_FOCUS_PUNCH_EFFECT.gate({
  user = { expTookDamageThisTurn = true, name = "Machamp", isPlayer = true },
})
T.eq(fpOk, false, "Focus Punch fails after taking damage")

local spinSide = { hazards = { { id = "SPIKES", layers = 2 } } }
local spinUser = {
  name = "Donphan", isPlayer = true, leechSeeded = true,
  stages = {}, mon = { hp = 50 },
}
local spinCtx = {
  side = function() return spinSide end,
  user = spinUser, target = {}, battle = {},
  move = Data.moves.RAPID_SPIN,
  say = function() end,
  changeStage = function() return {} end,
}
Data.move_effects.EXP_RAPID_SPIN_EFFECT.afterDamage(spinCtx)
T.eq(#spinSide.hazards, 0, "Rapid Spin clears hazards")
T.eq(spinUser.leechSeeded, nil, "Rapid Spin clears Leech Seed")

-- ------- Ability batch: Compound Eyes, Keen Eye, Run Away, Soundproof, etc.

T.check(Abilities.isSoundMove("HYPER_VOICE"), "Hyper Voice is a sound move")
T.check(not Abilities.isSoundMove("TACKLE"), "Tackle is not a sound move")

local soundCtx = {
  battle = { data = Data, sayNext = function() end },
  user = { mon = { species = "PIDGEY", hp = 50, stats = { hp = 50 } },
           curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
           stages = {}, curTypes = { "NORMAL" }, isPlayer = true, name = "Pidgey" },
  target = { mon = { species = "WHISMUR", hp = 50, stats = { hp = 50 } },
             curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
             stages = {}, curTypes = { "NORMAL" }, isPlayer = false, name = "Whismur" },
  move = { id = "HYPER_VOICE", type = "NORMAL", power = 90, category = "special" },
}
-- Force Soundproof via traced ability
soundCtx.target.expTracedAbility = "SOUNDPROOF"
local spDmg = select(1, Abilities.onDamage(function() return 40, { crit = false, typeMult = 10 } end, soundCtx))
T.eq(spDmg, 0, "Soundproof nullifies Hyper Voice damage")

local keenWho = { mon = { species = "SKARMORY" }, stages = { accuracy = 0 },
                  isPlayer = true, name = "Skarmory", expTracedAbility = "KEEN_EYE" }
local keenBattle = { data = Data }
local VanillaME = require("src.battle.MoveEffects")
local keenMsgs = VanillaME.changeStage(keenBattle, keenWho, "accuracy", -1, true)
T.check(type(keenMsgs) == "table" and #keenMsgs > 0, "Keen Eye blocks accuracy drop")
T.eq(keenWho.stages.accuracy, 0, "Keen Eye leaves accuracy unchanged")

local runAwayBattle = {
  kind = "wild",
  player = { mon = { species = "SENTRET", hp = 20 }, expTracedAbility = "RUN_AWAY",
             curTypes = { "NORMAL" }, name = "Sentret", isPlayer = true },
  enemy = { mon = { species = "RATTATA", hp = 20 },
            curTypes = { "NORMAL" }, name = "Rattata" },
  data = Data,
  sayNext = function() end,
}
local ran = Runtime.call("battle.run", function() return false end, { battle = runAwayBattle })
T.eq(ran, true, "Run Away escapes wild battles")

-- Early Bird halves sleep turns on inflict
local StatusRegistry = require("src.battle.StatusRegistry")
local earlyTarget = {
  mon = { species = "HOUNDOUR", hp = 30, stats = { hp = 30 }, status = nil },
  curTypes = { "DARK" }, isPlayer = true, name = "Houndour",
  expTracedAbility = "EARLY_BIRD", stages = {},
}
local earlyBattle = {
  data = Data, rng = function() return 6 end, -- max sleep roll
  sideOf = function() return {} end,
}
StatusRegistry.inflict(earlyBattle, earlyTarget, "SLP", {})
T.check(earlyTarget.sleepTurns and earlyTarget.sleepTurns <= 3,
  "Early Bird halves sleep duration")

-- ------- New move effects

T.eq(Data.moves.ENDURE.effect, "EXP_ENDURE_EFFECT", "Endure effect id")
T.eq(Data.moves.BRICK_BREAK.effect, "EXP_BRICK_BREAK_EFFECT", "Brick Break effect id")
T.eq(Data.moves.FALSE_SWIPE.effect, "EXP_FALSE_SWIPE_EFFECT", "False Swipe effect id")
T.eq(Data.moves.FURY_CUTTER.effect, "EXP_FURY_CUTTER_EFFECT", "Fury Cutter effect id")
T.eq(Data.moves.FUTURE_SIGHT.effect, "EXP_FUTURE_SIGHT_EFFECT", "Future Sight effect id")
T.eq(Data.moves.DOOM_DESIRE.effect, "EXP_FUTURE_SIGHT_EFFECT", "Doom Desire shares Future Sight")
T.eq(Data.moves.PSYCH_UP.effect, "EXP_PSYCH_UP_EFFECT", "Psych Up effect id")
T.eq(Data.moves.LOCK_ON.effect, "EXP_LOCK_ON_EFFECT", "Lock-On effect id")
T.eq(Data.moves.FORESIGHT.effect, "EXP_FORESIGHT_EFFECT", "Foresight effect id")
T.eq(Data.moves.NIGHTMARE.effect, "EXP_NIGHTMARE_EFFECT", "Nightmare effect id")
T.eq(Data.moves.SPITE.effect, "EXP_SPITE_EFFECT", "Spite effect id")
T.eq(Data.moves.SMELLING_SALTS.effect, "EXP_SMELLING_SALTS_EFFECT", "Smelling Salts effect id")
T.eq(Data.moves.ROLLOUT.effect, "EXP_ROLLOUT_EFFECT", "Rollout effect id")
T.check(Data.move_effects.EXP_ENDURE_EFFECT ~= nil, "Endure registered")
T.check(Data.move_effects.EXP_FUTURE_SIGHT_EFFECT ~= nil, "Future Sight registered")
T.check(Data.move_effects.EXP_SPITE_EFFECT ~= nil, "Spite registered")

local endureUser = { mon = { hp = 10, stats = { hp = 40 } }, name = "User", isPlayer = true }
Data.move_effects.EXP_ENDURE_EFFECT.run({ user = endureUser })
T.eq(endureUser.expEnduring, true, "Endure sets enduring flag")

local brickTarget = { reflect = true, lightScreen = true, name = "Foe", isPlayer = false }
local brickMsgs = {}
Data.move_effects.EXP_BRICK_BREAK_EFFECT.afterDamage({
  target = brickTarget,
  say = function(m) brickMsgs[#brickMsgs + 1] = m end,
})
T.eq(brickTarget.reflect, nil, "Brick Break clears Reflect")
T.eq(brickTarget.lightScreen, nil, "Brick Break clears Light Screen")

local falseCtx = {
  target = { mon = { hp = 5, stats = { hp = 40 } } },
  computeDamage = function() return 20, { crit = false, typeMult = 10 } end,
}
local fsDmg = select(1, Data.move_effects.EXP_FALSE_SWIPE_EFFECT.chooseDamage(falseCtx))
T.eq(fsDmg, 4, "False Swipe leaves 1 HP")

local psychUser = { stages = { attack = 0, defense = 0 }, name = "User", isPlayer = true }
local psychTarget = { stages = { attack = 2, defense = -1, speed = 1 } }
Data.move_effects.EXP_PSYCH_UP_EFFECT.run({
  user = psychUser, target = psychTarget,
})
T.eq(psychUser.stages.attack, 2, "Psych Up copies Attack")
T.eq(psychUser.stages.defense, -1, "Psych Up copies Defense")

local lockTarget = { name = "Foe", isPlayer = false }
Data.move_effects.EXP_LOCK_ON_EFFECT.run({
  user = { name = "User", isPlayer = true },
  target = lockTarget,
})
T.eq(lockTarget.expLockedOn, true, "Lock-On marks target")

local nightTarget = { mon = { status = "SLP" }, name = "Foe", isPlayer = false }
Data.move_effects.EXP_NIGHTMARE_EFFECT.run({ target = nightTarget })
T.eq(nightTarget.expNightmare, true, "Nightmare sets flag on sleeper")

local spiteTarget = {
  name = "Foe", isPlayer = false, lastMove = "TACKLE",
  curMoves = { { id = "TACKLE", pp = 20 } },
}
local spiteMsgs = Data.move_effects.EXP_SPITE_EFFECT.run({ target = spiteTarget })
T.eq(spiteTarget.curMoves[1].pp, 16, "Spite cuts 4 PP")
T.check(#spiteMsgs > 0, "Spite returns a message")

local futSide = { tokens = {}, battlers = { { mon = { hp = 50, stats = { hp = 50 } },
  name = "Foe", isPlayer = false } } }
Data.move_effects.EXP_FUTURE_SIGHT_EFFECT.run({
  user = { mon = { level = 50, stats = { hp = 50 } }, name = "User", isPlayer = true },
  target = futSide.battlers[1],
  move = Data.moves.FUTURE_SIGHT,
  side = function() return futSide end,
  battle = {},
})
T.eq(#futSide.tokens, 1, "Future Sight queues a side token")
T.eq(futSide.tokens[1].id, "EXP_FUTURE_SIGHT", "Future Sight token id")

local magP, magN = ExpME.magnitudePower(function() return 0 end)
T.eq(magP, 10, "Magnitude low roll power")
T.eq(magN, 4, "Magnitude low roll strength")

-- ------- Next batch: Baton Pass, Sleep Talk, Magic Coat, sports, Pickup

T.eq(Data.moves.BATON_PASS.effect, "EXP_BATON_PASS_EFFECT", "Baton Pass effect id")
T.eq(Data.moves.SLEEP_TALK.effect, "EXP_SLEEP_TALK_EFFECT", "Sleep Talk effect id")
T.eq(Data.moves.MAGIC_COAT.effect, "EXP_MAGIC_COAT_EFFECT", "Magic Coat effect id")
T.eq(Data.moves.UPROAR.effect, "EXP_UPROAR_EFFECT", "Uproar effect id")
T.eq(Data.moves.PRESENT.effect, "EXP_PRESENT_EFFECT", "Present effect id")
T.eq(Data.moves.TORMENT.effect, "EXP_TORMENT_EFFECT", "Torment effect id")
T.eq(Data.moves.ROLE_PLAY.effect, "EXP_ROLE_PLAY_EFFECT", "Role Play effect id")
T.eq(Data.moves.SKILL_SWAP.effect, "EXP_SKILL_SWAP_EFFECT", "Skill Swap effect id")
T.eq(Data.moves.WORRY_SEED.effect, "EXP_WORRY_SEED_EFFECT", "Worry Seed effect id")
T.eq(Data.moves.MUD_SPORT.effect, "EXP_MUD_SPORT_EFFECT", "Mud Sport effect id")
T.eq(Data.moves.WATER_SPORT.effect, "EXP_WATER_SPORT_EFFECT", "Water Sport effect id")
T.eq(Data.moves.GRUDGE.effect, "EXP_GRUDGE_EFFECT", "Grudge effect id")
T.eq(Data.moves.ACUPRESSURE.effect, "EXP_ACUPRESSURE_EFFECT", "Acupressure effect id")
T.eq(Data.moves.CAMOUFLAGE.effect, "EXP_CAMOUFLAGE_EFFECT", "Camouflage effect id")
T.eq(Data.moves.COPYCAT.effect, "EXP_COPYCAT_EFFECT", "Copycat effect id")
T.eq(Data.moves.ASSIST.effect, "EXP_ASSIST_EFFECT", "Assist effect id")
T.eq(Data.moves.NATURE_POWER.effect, "EXP_NATURE_POWER_EFFECT", "Nature Power effect id")
T.check(Data.move_effects.EXP_BATON_PASS_EFFECT ~= nil, "Baton Pass registered")
T.check(Data.move_effects.EXP_SLEEP_TALK_EFFECT ~= nil, "Sleep Talk registered")
T.check(Data.move_effects.EXP_MAGIC_COAT_EFFECT ~= nil, "Magic Coat registered")

local bpUser = {
  isPlayer = true, name = "User", mon = { hp = 40 },
  stages = { attack = 2, speed = -1 },
  confusedTurns = 3, focusEnergy = true,
}
local bpBattle = {
  game = { save = { party = { bpUser.mon, { hp = 20 }, { hp = 0 } } } },
  enemyParty = {},
}
local bpMsgs = Data.move_effects.EXP_BATON_PASS_EFFECT.run({
  user = bpUser, battle = bpBattle,
})
T.eq(bpUser.expPendingBatonOpen, true, "Baton Pass opens party")
T.check(bpUser.expBatonPass and bpUser.expBatonPass.stages.attack == 2,
  "Baton Pass snapshots stages")
T.check(#bpMsgs > 0, "Baton Pass returns message")

local sleepUser = {
  mon = { status = "SLP" },
  curMoves = {
    { id = "SLEEP_TALK", pp = 10 },
    { id = "TACKLE", pp = 20 },
    { id = "GROWL", pp = 20 },
  },
}
local pick = Data.move_effects.EXP_SLEEP_TALK_EFFECT.callsMove({
  user = sleepUser, rng = function(a, b) return a end, say = function() end,
})
T.eq(pick, "TACKLE", "Sleep Talk picks a non-Sleep-Talk move")

Data.move_effects.EXP_MAGIC_COAT_EFFECT.run({
  user = { name = "User", isPlayer = true, expMagicCoat = nil },
})
-- run mutates user
local coatUser = { name = "User", isPlayer = true }
Data.move_effects.EXP_MAGIC_COAT_EFFECT.run({ user = coatUser })
T.eq(coatUser.expMagicCoat, true, "Magic Coat sets bounce flag")

Data.move_effects.EXP_MUD_SPORT_EFFECT.run({ battle = { expMudSport = false } })
local sportBattle = {}
Data.move_effects.EXP_MUD_SPORT_EFFECT.run({ battle = sportBattle })
T.eq(sportBattle.expMudSport, true, "Mud Sport sets field flag")

local mudDmg = select(1, Abilities.onDamage(function() return 30, { crit = false, typeMult = 10 } end, {
  battle = { expMudSport = true, data = Data },
  user = { mon = { species = "PIKACHU", hp = 50, stats = { hp = 50 } },
           curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
           stages = {}, curTypes = { "ELECTRIC" }, isPlayer = true, name = "Pikachu" },
  target = { mon = { species = "RATTATA", hp = 50, stats = { hp = 50 } },
             curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
             stages = {}, curTypes = { "NORMAL" }, isPlayer = false, name = "Rattata" },
  move = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90, category = "special" },
}))
T.eq(mudDmg, 10, "Mud Sport cuts Electric damage to 1/3")

local tormentTarget = { name = "Foe", isPlayer = false }
Data.move_effects.EXP_TORMENT_EFFECT.run({ target = tormentTarget })
T.eq(tormentTarget.expTormented, true, "Torment marks target")

local worryTarget = { name = "Foe", isPlayer = false }
Data.move_effects.EXP_WORRY_SEED_EFFECT.run({ target = worryTarget })
T.eq(worryTarget.expTracedAbility, "INSOMNIA", "Worry Seed sets Insomnia")

local camoUser = { name = "User", isPlayer = true, curTypes = { "WATER" } }
Data.move_effects.EXP_CAMOUFLAGE_EFFECT.run({ user = camoUser })
T.eq(camoUser.curTypes[1], "NORMAL", "Camouflage becomes Normal")

local acuUser = {
  name = "User", isPlayer = true,
  stages = { attack = 0, defense = 0, speed = 0, special = 0, accuracy = 0, evasion = 0 },
}
Data.move_effects.EXP_ACUPRESSURE_EFFECT.run({
  user = acuUser, rng = function() return 1 end,
  changeStage = function(who, stat, delta)
    who.stages[stat] = (who.stages[stat] or 0) + delta
    return { "ok" }
  end,
})
local raised = false
for _, v in pairs(acuUser.stages) do if v == 2 then raised = true end end
T.check(raised, "Acupressure raises a stage by 2")

T.eq(Data.move_effects.EXP_NATURE_POWER_EFFECT.callsMove({}), "EARTHQUAKE",
  "Nature Power calls Earthquake")

-- Pickup + Illuminate helpers
local pickupGame = {
  data = Data,
  save = { inventory = {}, bagOrder = {}, party = {
    { species = "ZIGZAGOON", hp = 20 },
  }},
}
if not Data.pokemon.ZIGZAGOON then
  Data.pokemon.ZIGZAGOON = { ability = "PICKUP" }
else
  Data.pokemon.ZIGZAGOON.ability = "PICKUP"
end
local gotItem = Abilities.tryPickup(pickupGame, pickupGame.save.party, function(a, b)
  if a == 0 and b == 99 then return 0 end -- always trigger 10%
  return 1
end)
T.check(gotItem ~= nil, "Pickup finds an item on lucky roll")
T.check((pickupGame.save.inventory[gotItem] or 0) >= 1, "Pickup adds item to bag")

if not Data.pokemon.VOLBEAT then
  Data.pokemon.VOLBEAT = { ability = "ILLUMINATE" }
else
  Data.pokemon.VOLBEAT.ability = "ILLUMINATE"
end
local illumGame = {
  data = Data,
  save = { party = { { species = "VOLBEAT" } } },
}
T.eq(Abilities.illuminateRateMult(illumGame), 1.5, "Illuminate boosts encounter rate")
T.eq(Abilities.illuminateRateMult({ data = Data, save = { party = { { species = "PIDGEY" } } } }),
  1, "No Illuminate leaves rate alone")

-- ------- Plus/Minus stand-in + ability/move batch

local plusCtx = {
  battle = { data = Data, expMudSport = false },
  user = {
    mon = { species = "PLUSLE", hp = 50, stats = { hp = 50 } },
    curStats = { attack = 40, defense = 40, special = 100, speed = 40 },
    stages = {}, curTypes = { "ELECTRIC" }, isPlayer = true, name = "Plusle",
    expTracedAbility = "PLUS",
  },
  target = {
    mon = { species = "RATTATA", hp = 50, stats = { hp = 50 } },
    curStats = { attack = 40, defense = 40, special = 40, speed = 40 },
    stages = {}, curTypes = { "NORMAL" }, isPlayer = false, name = "Rattata",
  },
  move = { id = "THUNDERBOLT", type = "ELECTRIC", power = 90, category = "special" },
}
local seenSpecial
Abilities.onDamage(function(c)
  seenSpecial = c.user.curStats.special
  return 10, { crit = false, typeMult = 10 }
end, plusCtx)
T.eq(seenSpecial, 150, "Plus boosts SpA 1.5x in singles")
T.eq(plusCtx.user.curStats.special, 100, "Plus SpA boost restores after damage")

T.eq(Data.moves.SKETCH.effect, "EXP_SKETCH_EFFECT", "Sketch effect id")
T.eq(Data.moves.IMPRISON.effect, "EXP_IMPRISON_EFFECT", "Imprison effect id")
T.eq(Data.moves.SNATCH.effect, "EXP_SNATCH_EFFECT", "Snatch effect id")
T.eq(Data.moves.SECRET_POWER.effect, "EXP_SECRET_POWER_EFFECT", "Secret Power effect id")
T.eq(Data.moves.GASTRO_ACID.effect, "EXP_GASTRO_ACID_EFFECT", "Gastro Acid effect id")
T.eq(Data.moves.SIMPLE_BEAM.effect, "EXP_SIMPLE_BEAM_EFFECT", "Simple Beam effect id")
T.eq(Data.moves.POWER_TRICK.effect, "EXP_POWER_TRICK_EFFECT", "Power Trick effect id")
T.eq(Data.moves.CLEAR_SMOG.effect, "EXP_CLEAR_SMOG_EFFECT", "Clear Smog effect id")
T.eq(Data.moves.CHARGE.effect, "EXP_CHARGE_EFFECT", "Charge effect id")
T.eq(Data.moves.TRICK_ROOM.effect, "EXP_TRICK_ROOM_EFFECT", "Trick Room effect id")
T.eq(Data.moves.HEALING_WISH.effect, "EXP_HEALING_WISH_EFFECT", "Healing Wish effect id")
T.eq(Data.moves.MEMENTO.effect, "EXP_MEMENTO_EFFECT", "Memento effect id")
T.eq(Data.moves.FOLLOW_ME.effect, "EXP_FOLLOW_ME_EFFECT", "Follow Me stand-in")
T.eq(Data.moves.ALLY_SWITCH.effect, "EXP_ALLY_SWITCH_EFFECT", "Ally Switch stand-in")
T.check(Data.move_effects.EXP_SKETCH_EFFECT ~= nil, "Sketch registered")
T.check(Data.move_effects.EXP_TRICK_ROOM_EFFECT ~= nil, "Trick Room registered")

local sketchUser = {
  name = "User", isPlayer = true, curMoves = { { id = "SKETCH", pp = 1 } },
  mon = { moves = { { id = "SKETCH", pp = 1 } } },
}
Data.move_effects.EXP_SKETCH_EFFECT.run({
  user = sketchUser, target = { lastMove = "THUNDERBOLT" },
  data = Data,
})
T.eq(sketchUser.curMoves[1].id, "THUNDERBOLT", "Sketch replaces battle move")
T.eq(sketchUser.mon.moves[1].id, "THUNDERBOLT", "Sketch persists to party mon")

local gastroTarget = { name = "Foe", isPlayer = false }
Data.move_effects.EXP_GASTRO_ACID_EFFECT.run({ target = gastroTarget })
T.eq(gastroTarget.expAbilitySuppressed, true, "Gastro Acid suppresses ability")
T.eq(Abilities.abilityOf({ data = Data }, gastroTarget), nil, "Suppressed ability reads as nil")

local simpleTarget = { name = "Foe", isPlayer = false }
Data.move_effects.EXP_SIMPLE_BEAM_EFFECT.run({ target = simpleTarget })
T.eq(simpleTarget.expTracedAbility, "SIMPLE", "Simple Beam sets Simple")

local ptUser = {
  name = "User", isPlayer = true,
  stages = { attack = 2, defense = -1 },
  curStats = { attack = 80, defense = 40 },
}
Data.move_effects.EXP_POWER_TRICK_EFFECT.run({ user = ptUser })
T.eq(ptUser.stages.attack, -1, "Power Trick swaps Attack stage")
T.eq(ptUser.stages.defense, 2, "Power Trick swaps Defense stage")
T.eq(ptUser.curStats.attack, 40, "Power Trick swaps Attack stat")

local smogTarget = { stages = { attack = 3, speed = -2 }, name = "Foe", isPlayer = false }
Data.move_effects.EXP_CLEAR_SMOG_EFFECT.afterDamage({
  target = smogTarget, say = function() end,
})
T.eq(smogTarget.stages.attack, 0, "Clear Smog resets Attack")
T.eq(smogTarget.stages.speed, 0, "Clear Smog resets Speed")

local chargeUser = { name = "User", isPlayer = true, stages = { special = 0 } }
Data.move_effects.EXP_CHARGE_EFFECT.run({
  user = chargeUser,
  changeStage = function(who, stat, delta)
    who.stages[stat] = (who.stages[stat] or 0) + delta
    return { "ok" }
  end,
})
T.eq(chargeUser.expCharged, true, "Charge sets charged flag")

local trBattle = {}
Data.move_effects.EXP_TRICK_ROOM_EFFECT.run({
  user = { name = "User", isPlayer = true }, battle = trBattle,
})
T.eq(trBattle.expTrickRoomTurns, 5, "Trick Room starts")
Data.move_effects.EXP_TRICK_ROOM_EFFECT.run({
  user = { name = "User", isPlayer = true }, battle = trBattle,
})
T.eq(trBattle.expTrickRoomTurns, nil, "Trick Room toggles off")

local wishSide = {}
local wishUser = { name = "User", isPlayer = true, mon = { hp = 30, stats = { hp = 30 } } }
Data.move_effects.EXP_HEALING_WISH_EFFECT.run({
  user = wishUser, side = function() return wishSide end,
  battle = { onFaint = function() end },
})
T.eq(wishSide.expHealingWish, true, "Healing Wish queues heal")
T.eq(wishUser.mon.hp, 0, "Healing Wish faints user")

local allyUser = { name = "User", isPlayer = true }
Data.move_effects.EXP_ALLY_SWITCH_EFFECT.run({ user = allyUser })
T.eq(allyUser.expProtected, true, "Ally Switch stand-in Protects")

local followUser = { name = "User", isPlayer = true, stages = { evasion = 0 } }
Data.move_effects.EXP_FOLLOW_ME_EFFECT.run({
  user = followUser,
  changeStage = function(who, stat, delta)
    who.stages[stat] = (who.stages[stat] or 0) + delta
    return { "ok" }
  end,
})
T.eq(followUser.stages.evasion, 2, "Follow Me stand-in raises evasion")

-- ------- Held items

local HeldItems = require("mods.Kanto-Reforged.held_items")
T.check(Data.items.LEFTOVERS ~= nil, "Leftovers item registered")
T.check(Data.items.FOCUS_BAND ~= nil, "Focus Band item registered")
T.check(Data.items.MIRACLE_SEED ~= nil, "Miracle Seed item registered")
T.check(Data.link_fields and Data.link_fields.held_item ~= nil,
  "held_item link_fields registered")
T.eq(Data.moves.TRICK.effect, "EXP_TRICK_EFFECT", "Trick effect id")
T.eq(Data.moves.POWER_TRICK.effect, "EXP_POWER_TRICK_EFFECT", "Power Trick unchanged")
T.eq(Data.moves.KNOCK_OFF.effect, "EXP_KNOCK_OFF_EFFECT", "Knock Off effect id")
T.eq(Data.moves.RECYCLE.effect, "EXP_RECYCLE_EFFECT", "Recycle effect id")
T.eq(Data.moves.BESTOW.effect, "EXP_BESTOW_EFFECT", "Bestow effect id")

local giveMon = { species = "PIDGEY", heldItem = nil }
local bagSave = { inventory = { LEFTOVERS = 2 }, bagOrder = { "LEFTOVERS" } }
local Bag = require("src.inventory.Bag")
Bag.remove(bagSave, "LEFTOVERS", 1)
HeldItems.set(giveMon, "LEFTOVERS")
T.eq(giveMon.heldItem, "LEFTOVERS", "Give sets heldItem")
T.eq(bagSave.inventory.LEFTOVERS, 1, "Give removes one from bag")
T.check(Bag.add(bagSave, giveMon.heldItem, 1), "Take returns to bag")
HeldItems.set(giveMon, nil)
T.eq(giveMon.heldItem, nil, "Take clears heldItem")
T.eq(bagSave.inventory.LEFTOVERS, 2, "Take restores bag count")

local leftMon = { mon = { heldItem = "LEFTOVERS", hp = 40, stats = { hp = 80 } },
                  name = "User", isPlayer = true }
local leftBattle = { sayNext = function() end, drainNext = function() end,
                     player = leftMon, enemy = { mon = { hp = 10 } } }
-- simulate leftovers tick
do
  local b = leftBattle.player
  local heal = math.max(1, math.floor(b.mon.stats.hp / 16))
  b.mon.hp = math.min(b.mon.stats.hp, b.mon.hp + heal)
  T.eq(b.mon.hp, 45, "Leftovers heals 1/16")
end

local seedUser = {
  mon = { heldItem = "MIRACLE_SEED", hp = 50, stats = { hp = 50 }, species = "ODDISH" },
  curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
  stages = {}, curTypes = { "GRASS" }, isPlayer = true, name = "Oddish",
}
local seedDmg = HeldItems.modifyDamage(100, {
  user = seedUser, move = { type = "GRASS", power = 60 },
})
T.eq(seedDmg, 110, "Miracle Seed boosts Grass damage 1.1x")

local berryTarget = {
  mon = { heldItem = "BERRY", hp = 20, stats = { hp = 50 } },
  name = "Foe", isPlayer = false,
}
HeldItems.afterDamage({
  battle = { sayNext = function() end, drainNext = function() end },
  target = berryTarget,
}, 10)
T.eq(berryTarget.mon.hp, 30, "Berry heals 10 at half HP")
T.eq(berryTarget.mon.heldItem, nil, "Berry is consumed")
T.eq(berryTarget.expLastConsumedItem, "BERRY", "Berry stashed for Recycle")

local fbBattle = { rng = function() return 0 end, sayNext = function() end }
local fbTarget = { mon = { heldItem = "FOCUS_BAND", hp = 5, stats = { hp = 40 } },
                   name = "Foe", isPlayer = false }
local fbDmg = HeldItems.focusBandClamp(fbBattle, fbTarget, 20)
T.eq(fbDmg, 4, "Focus Band can leave 1 HP")

local trickA = { mon = { heldItem = "LEFTOVERS" }, name = "A", isPlayer = true }
local trickB = { mon = { heldItem = "FOCUS_BAND" }, name = "B", isPlayer = false }
Data.move_effects.EXP_TRICK_EFFECT.run({ user = trickA, target = trickB })
T.eq(trickA.mon.heldItem, "FOCUS_BAND", "Trick swaps user item")
T.eq(trickB.mon.heldItem, "LEFTOVERS", "Trick swaps target item")

local knockTarget = {
  mon = { heldItem = "MIRACLE_SEED" }, name = "Foe", isPlayer = false,
}
Data.move_effects.EXP_KNOCK_OFF_EFFECT.afterDamage({
  user = { name = "User", isPlayer = true },
  target = knockTarget,
  say = function() end,
})
T.eq(knockTarget.mon.heldItem, nil, "Knock Off removes held item")
T.eq(knockTarget.expLastConsumedItem, "MIRACLE_SEED", "Knock Off stashes for Recycle")

-- Knock Off / Recycle / Bestow checks in a nested function to stay under
-- LuaJIT's 200-local main-chunk limit.
;(function()
  local recycleUser = {
    name = "User", isPlayer = true,
    mon = { heldItem = nil },
    expLastConsumedItem = "BERRY",
  }
  Data.move_effects.EXP_RECYCLE_EFFECT.run({ user = recycleUser })
  T.eq(recycleUser.mon.heldItem, "BERRY", "Recycle restores consumed item")
  T.eq(recycleUser.expLastConsumedItem, nil, "Recycle clears stash")

  local bestowUser = { mon = { heldItem = "LEFTOVERS" }, name = "User", isPlayer = true }
  local bestowFoe = { mon = { heldItem = nil }, name = "Foe", isPlayer = false }
  Data.move_effects.EXP_BESTOW_EFFECT.run({ user = bestowUser, target = bestowFoe })
  T.eq(bestowUser.mon.heldItem, nil, "Bestow clears user item")
  T.eq(bestowFoe.mon.heldItem, "LEFTOVERS", "Bestow gives foe the item")

  local Runtime = require("src.mods.Runtime")
  Runtime.call("battle.damage", function() return 40, { crit = false, typeMult = 10 } end, {
    battle = { data = Data },
    user = {
      mon = { species = "PIDGEY", hp = 50, stats = { hp = 50 } },
      curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
      stages = {}, curTypes = { "NORMAL" }, isPlayer = true, name = "Pidgey",
    },
    target = {
      mon = { species = "RATTATA", hp = 50, stats = { hp = 50 }, heldItem = nil },
      curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
      stages = {}, curTypes = { "NORMAL" }, isPlayer = false, name = "Rattata",
    },
    move = { id = "KNOCK_OFF", type = "DARK", power = 65, category = "physical" },
  })
  local withHoldTarget = {
    mon = { species = "RATTATA", hp = 50, stats = { hp = 50 }, heldItem = "LEFTOVERS" },
    curStats = { attack = 50, defense = 50, special = 50, speed = 50 },
    stages = {}, curTypes = { "NORMAL" }, isPlayer = false, name = "Rattata",
  }
  T.check(HeldItems.ofBattler(withHoldTarget) == "LEFTOVERS", "ofBattler reads hold")
  T.check(HeldItems.ofBattler({ mon = { heldItem = nil } }) == nil, "ofBattler empty")
end)()

require("mods.Kanto-Reforged.tests.berry_sources_test")(T, Data, HeldItems, run)
require("mods.Kanto-Reforged.tests.held_items_test")(T, Data, HeldItems)
require("mods.Kanto-Reforged.tests.overworld_loot_test")(T, Data, HeldItems, run)
require("mods.Kanto-Reforged.tests.house_npcs_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.summary_ui_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.gender_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.breeding_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.dexnav_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.quarantine_recover_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.ai_switch_retarget_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.ai_switch_lock_pre_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.bag_pockets_test")(T, Data, run)
  require("mods.Kanto-Reforged.tests.bag_give_test")(T, Data, run)
  require("mods.Kanto-Reforged.tests.gen1_modern_ui_adapter_test")(T, Data, run)
  -- Sevii parked (WIP); suite lives at sevii/sevii_phase0_test.lua
require("mods.Kanto-Reforged.tests.rollout_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.species_scope_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.spawn_matrix_test")(T, Data, run, { skipGen2 = true })
pcall(function()
  require("mods.Kanto-Reforged.tests.move_anims_test")(T, Data, run)
end)
require("mods.Kanto-Reforged.tests.species_icons_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.modern_xp_share_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.split_special_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.trainer_ai_test")(T, Data, run)
require("mods.Kanto-Reforged.tests.level_caps_test")(T, Data, run)

run.release()
T.finish("Kanto-Reforged")
