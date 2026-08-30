local Abilities = require("mods.Kanto-Reforged.battle.abilities")
local ExpMoveEffects = require("mods.Kanto-Reforged.battle.move_effects")
local HeldItems = require("mods.Kanto-Reforged.items.held_items")
local Gender = require("mods.Kanto-Reforged.pokemon.gender")
local ModernXpShare = require("mods.Kanto-Reforged.ui.modern_xp_share")
local SplitSpecial = require("mods.Kanto-Reforged.battle.split_special")
local RulesetOpt = require("mods.Kanto-Reforged.battle.ruleset_option")
local MoveCategoryGen3 = require("mods.Kanto-Reforged.battle.move_category_gen3")
local CritGen3 = require("mods.Kanto-Reforged.battle.crit_gen3")
local TrainerAi = require("mods.Kanto-Reforged.battle.trainer_ai")
local ExpTrainers = require("mods.Kanto-Reforged.battle.trainers")
local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
local Strings = require("src.core.Strings")

local okSave, Save = pcall(require, "src.core.gen2.Save")
if okSave and Save then
  Save.EVENT_BYTES = math.max(Save.EVENT_BYTES or 256, 4096)
end

local okPerm, Permissions = pcall(require, "src.world.gen2.Permissions")
if okPerm and Permissions then
  function Permissions.doorForcedDirection(coll)
    return nil
  end
end

local function battlerHasType(battler, typeId)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  for _, t in ipairs(BattleCompat.types(battler)) do
    if t == typeId then return true end
  end
  return false
end

local mixEncounters = require("mods.Kanto-Reforged.world.encounters").mix
local ExpEncounters = require("mods.Kanto-Reforged.world.encounters")

local function spawnModeFromOptions(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  -- PURE RANDOM overrides the gated FULL SPAWN MIX when both are on.
  if mod.options and mod.options:get(Host.optionKey("pure_spawn_random")) then
    return "pure_random"
  end
  if mod.options and mod.options:get(Host.optionKey("full_spawn_random")) then
    return "full_random"
  end
  return "curated"
end

local function spawnOptsFromOptions(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  -- LEGENDS IN MIX stays visible in the Manager (hiding it via mid-session
  -- re-define would reset the options cursor). Curated mode must ignore a
  -- leftover true if the player turned FULL/PURE off after enabling legends.
  local mode = spawnModeFromOptions(mod)
  local legends = false
  if mode == "full_random" or mode == "pure_random" then
    legends = mod.options
      and mod.options:get(Host.optionKey("legends_in_mix")) and true or false
  end
  return {
    legendsInMix = legends,
    speciesScope = SpeciesScope.mode(mod),
  }
end

-- Central schema for Manager / card options. Host rows use loader.generation
-- so a sticky GameVersion cannot mis-label Gen1 vs Gen2 menus.
local function buildOptionDefs(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local defs = {
    SpeciesScope.optionDef(mod),
    {
      key = Host.optionKey("full_spawn_random"),
      label = "FULL SPAWN MIX",
      type = "toggle",
      default = false,
    },
    {
      key = Host.optionKey("pure_spawn_random"),
      label = "PURE RANDOM SPAWN",
      type = "toggle",
      default = false,
    },
    {
      key = Host.optionKey("legends_in_mix"),
      label = "LEGENDS IN MIX",
      type = "toggle",
      default = false,
    },
    ModernXpShare.OPTION,
    TrainerAi.OPTION,
    TrainerAi.switchLockOptionForHost(),
    HeldItems.BAG_GIVE_OPTION,
  }
  -- RULESET is always MODERN (faithful removed); Gen3 crit via core capabilities.
  if Host.isGen1From(mod) then
    defs[#defs + 1] = SplitSpecial.OPTION
    defs[#defs + 1] = require("mods.Kanto-Reforged.ui.battle_exp_bar").OPTION
    -- DexNav label/off is only for the start-menu entry; Gen2 uses Pokegear.
    defs[#defs + 1] = require("mods.Kanto-Reforged.ui.dexnav").OPTION
    local SpriteCache = require("mods.Kanto-Reforged.core.sprite_cache")
    local spriteOpt = SpriteCache.optionDef(mod)
    if spriteOpt then defs[#defs + 1] = spriteOpt end
  end
  return defs
end

local function applySpawnTables(mod, pokemon_data, flags)
  if not pokemon_data then return end
  flags = flags or {}
  local mode = spawnModeFromOptions(mod)
  local opts = spawnOptsFromOptions(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if flags.clearPureSeed and mod.save then
    Host.saveSet(mod.save, ExpEncounters.PURE_SEED_KEY, nil)
  end
  if mode == "pure_random" then
    -- Roll once on toggle-on / first apply; reuse across mod loads.
    local seed = mod.save and Host.saveGet(mod.save, ExpEncounters.PURE_SEED_KEY, nil)
    if flags.rerollPure or seed == nil then
      seed = ExpEncounters.newPureSeed()
      if mod.save then
        Host.saveSet(mod.save, ExpEncounters.PURE_SEED_KEY, seed)
      end
      mod.log:info("Pure random spawn seed %s", tostring(seed))
    end
    opts.seed = seed
  end
  if Host.isGen2() then
    local RestoredDungeons = require("mods.Kanto-Reforged.world.restored_dungeons")
    pcall(function() RestoredDungeons.apply(mod) end)
    local EncountersGen2 = require("mods.Kanto-Reforged.world.encounters_gen2")
    EncountersGen2.apply(mod, pokemon_data, mode, opts)
    local JohtoDex = require("mods.Kanto-Reforged.pokemon.johto_dex")
    pcall(function()
      local n = JohtoDex.rebuildOrders(mod)
      mod.log:info("Johto Pokédex NEW order rebuilt (%d species)", n or 0)
    end)
  else
    ExpEncounters.apply(mod, pokemon_data, mode, opts)
  end
  local tag = mode
  if (mode == "full_random" or mode == "pure_random") and opts.legendsInMix then
    tag = mode .. "+legends"
  end
  mod.log:info("Wild encounters applied (%s)", tag)
end

-- After Gen2 spawn / Johto-scope toggles: keep the full-dex sidecar fresh and
-- re-mark party/PC/daycare as caught (NEW order changes do not wipe flags,
-- but recovery must still run when MOD_DEX_RECOVERED already latched).
local function syncGen2DexAfterToggle(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen2() then return end
  local game = Host.liveGame(mod)
  local save = game and game.save
  if not save then return end
  SpeciesScope.syncDexProgress(mod, save)
end

local _cachedPokemonData = nil

local function refreshScopeContent(mod, game, scopeMode)
  local pokemon_data = _cachedPokemonData
  if not pokemon_data then
    local okPack, data = pcall(require, "mods.Kanto-Reforged.pokemon.pokemon_data")
    if okPack and data then
      pokemon_data = data
      _cachedPokemonData = data
    end
  end
  -- Content registries freeze after load; live Data writes still apply for
  -- mid-session toggles (and headless tests).
  pcall(function() applySpawnTables(mod, pokemon_data) end)
  pcall(function() ExpTrainers.apply(mod) end)
  local okClubs, BattleClubs = pcall(require, "mods.Kanto-Reforged.battle.battle_clubs")
  if okClubs and BattleClubs.refreshScope then
    pcall(function() BattleClubs.refreshScope(mod, scopeMode) end)
  end
  local okFossils, FossilsGen3 = pcall(require, "mods.Kanto-Reforged.world.fossils_gen3")
  if okFossils and FossilsGen3.refreshScope then
    pcall(function() FossilsGen3.refreshScope(mod, scopeMode) end)
  end
  local okTrades, TradesExtra = pcall(require, "mods.Kanto-Reforged.world.trades_extra")
  if okTrades and TradesExtra.refreshScope then
    pcall(function() TradesExtra.refreshScope(mod, scopeMode) end)
  end
end

return function(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  local PokemonGen2 = require("mods.Kanto-Reforged.pokemon.pokemon_gen2")

  ExpTrainers.extendSchemas()
  ExpTrainers.install(mod)
  pcall(function() ExpTrainers.apply(mod) end)

  if Host.isGen2() then
    -- Capture static 1–251 battle pics into a per-edition sprite cache so
    -- Gen1 can offer GOLD/SILVER/CRYSTAL sprite sets. Never copies anim sheets.
    local SpriteCache = require("mods.Kanto-Reforged.core.sprite_cache")
    pcall(function() SpriteCache.captureActiveEdition(mod) end)

    local RestoredDungeons = require("mods.Kanto-Reforged.world.restored_dungeons")
    RestoredDungeons.apply(mod)
    local LegendMapsApply = require("mods.Kanto-Reforged.world.legend_maps_apply")
    pcall(function() LegendMapsApply.apply(mod) end)
  end

  -- Manager / card options (host-aware labels / visibility).
  mod.options:define(buildOptionDefs(mod))
  Host.installEngineShims(mod)
  Host.migrateScopedOptions(mod)
  if Host.isGen1From(mod) then
    RulesetOpt.install(mod)
  end

  SpeciesScope._refreshContent = refreshScopeContent
  SpeciesScope.install(mod)

  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  BattleCompat.install(mod)

  require("mods.Kanto-Reforged.battle.core.install").install(mod)

  local Weather = require("mods.Kanto-Reforged.battle.weather")
  Weather.install(mod)

  Abilities.install(mod)

  require("mods.Kanto-Reforged.battle.adapters.register").installContent(mod)
  require("mods.Kanto-Reforged.battle.adapters.register").installRuntime(mod)

  HeldItems.register(mod)
  if Host.isGen1() then
    HeldItems.registerMarts(mod)
  end
  -- Party GIVE/TAKE + bag berry USE on both hosts; Gen1 also patches
  -- BattleState / MoveEffects, Gen2 wires item heldEffect + wild holds.
  HeldItems.install(mod)
  if Host.isGen1() then
    Gender.register(mod)
    Gender.install(mod)
    local Breeding = require("mods.Kanto-Reforged.pokemon.breeding")
    Breeding.register(mod)
    Breeding.install(mod)
    local Daycare = require("mods.Kanto-Reforged.pokemon.daycare")
    Daycare.register(mod)
    Daycare.install(mod)
  end

  local BerryFarm = require("mods.Kanto-Reforged.world.berry_farm")
  BerryFarm.register(mod)
  BerryFarm.install(mod)

  if Host.isGen1() then
    require("mods.Kanto-Reforged.ui.battle_exp_bar").install(mod)
  end

  local HouseNpcs = require("mods.Kanto-Reforged.world.house_npcs")
  HouseNpcs.resetClaims()
  if Host.isGen2() then
    HouseNpcs.installTalkDispatch(mod)
    pcall(function()
      require("mods.Kanto-Reforged.world.kanto_campaign").install(mod)
    end)
  end

  local LevelCaps = require("mods.Kanto-Reforged.ui.level_caps")
  LevelCaps.register(mod)
  LevelCaps.install(mod)

  if Host.isGen1() then
    local OverworldLoot = require("mods.Kanto-Reforged.world.overworld_loot")
    OverworldLoot.register(mod)
    local Competitive = require("mods.Kanto-Reforged.items.competitive_items")
    Competitive.register(mod)
    Competitive.install(mod)
    local BattleClubs = require("mods.Kanto-Reforged.battle.battle_clubs")
    BattleClubs.register(mod)
    local JudgeNpc = require("mods.Kanto-Reforged.world.judge_npc")
    JudgeNpc.register(mod)
    local TradesExtra = require("mods.Kanto-Reforged.world.trades_extra")
    TradesExtra.register(mod)
    local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
    BerryQuests.register(mod)
    local MoveHub = require("mods.Kanto-Reforged.world.move_hub")
    MoveHub.register(mod)
    local ItemSmith = require("mods.Kanto-Reforged.world.item_smith")
    ItemSmith.register(mod)
    local Roamers = require("mods.Kanto-Reforged.world.roamers")
    Roamers.register(mod)
    Roamers.install(mod)
    local RoamingRadar = require("mods.Kanto-Reforged.world.roaming_radar")
    RoamingRadar.register(mod)
    local RoamerDex = require("mods.Kanto-Reforged.world.roamer_dex")
    RoamerDex.install(mod)
    local LegendShrines = require("mods.Kanto-Reforged.world.legend_shrines")
    LegendShrines.register(mod)
    local LegendRegis = require("mods.Kanto-Reforged.world.legend_regis")
    LegendRegis.register(mod)
    local LegendMythicals = require("mods.Kanto-Reforged.world.legend_mythicals")
    LegendMythicals.register(mod)
    LegendMythicals.install(mod)
    local FossilsGen3 = require("mods.Kanto-Reforged.world.fossils_gen3")
    FossilsGen3.register(mod)
    ModernXpShare.install(mod)
    local QuarantineRecover = require("mods.Kanto-Reforged.core.quarantine_recover")
    QuarantineRecover.install(mod)
  else
    -- Gold Kanto parity: farm quests + Celadon/Vermilion clubs (Kanto maps).
    -- Utility NPCs stay on Kanto maps (not Johto remaps).
    local Competitive = require("mods.Kanto-Reforged.items.competitive_items")
    Competitive.register(mod)
    Competitive.install(mod)
    local BattleClubs = require("mods.Kanto-Reforged.battle.battle_clubs")
    BattleClubs.register(mod)
    local BerryQuests = require("mods.Kanto-Reforged.world.berry_quests")
    BerryQuests.register(mod)
    local JudgeNpc = require("mods.Kanto-Reforged.world.judge_npc")
    JudgeNpc.register(mod)
    local MoveHub = require("mods.Kanto-Reforged.world.move_hub")
    MoveHub.register(mod)
    local ItemSmith = require("mods.Kanto-Reforged.world.item_smith")
    ItemSmith.register(mod)
  end

  local SEVII_ENABLED = false
  if SEVII_ENABLED and Host.isGen1() then
    local Sevii = require("mods.Kanto-Reforged.sevii.main_register")
    Sevii.register(mod)
  end

  TrainerAi.register(mod)
  TrainerAi.install(mod)

  -- Wrap Stats.calc to clamp Shedinja's maximum HP to 1 at runtime
  local Stats = require("src.pokemon.Stats")
  local original_calc = Stats.calc
  Stats.calc = function(speciesDef, level, dvs, statExp)
    local out = original_calc(speciesDef, level, dvs, statExp)
    if speciesDef and speciesDef.id == "SHEDINJA" then
      out.hp = 1
    end
    return out
  end

  -- Wrap learnEvolutionMoves to teach evolutionMoves (learned at level 0 in PokeAPI)
  -- and to flush any deferred Shedinja split announcement after the "evolved
  -- into NINJASK" text (never push a TextBox during pokemon.evolved — that
  -- lands under the congrats box and makes EvolutionState's stack:pop hit
  -- the wrong state, which crashes / softlocks the evo screen).
  local Evolution = require("src.pokemon.Evolution")
  local shedinjaAnnounceQueue = {}

  local function queueShedinjaAnnounce(game, msg)
    if not game or not msg then return end
    shedinjaAnnounceQueue[#shedinjaAnnounceQueue + 1] = { game = game, msg = msg }
  end

  local function flushShedinjaAnnounce(game, thenFn)
    local nextMsg
    for i, entry in ipairs(shedinjaAnnounceQueue) do
      if entry.game == game then
        nextMsg = entry.msg
        table.remove(shedinjaAnnounceQueue, i)
        break
      end
    end
    if not nextMsg then
      if thenFn then thenFn() end
      return
    end
    if game.stack then
      local TextBox = require("src.render.TextBox")
      game.stack:push(TextBox.new(game, Strings(nextMsg), function()
        flushShedinjaAnnounce(game, thenFn)
      end))
    elseif thenFn then
      thenFn()
    end
  end

  local original_apply = Evolution.apply
  Evolution.apply = function(game, mon, newSpecies, via)
    mod._evoGame = game
    local ok, err = pcall(original_apply, game, mon, newSpecies, via)
    mod._evoGame = nil
    if not ok then error(err) end
  end

  local original_learnEvolutionMoves = Evolution.learnEvolutionMoves
  Evolution.learnEvolutionMoves = function(game, mon, onDone)
    local function continueLearn()
      local Experience = require("src.battle.Experience")
      local original_movesLearnedAt = Experience.movesLearnedAt
      Experience.movesLearnedAt = function(speciesDef, level)
        local out = original_movesLearnedAt(speciesDef, level)
        if speciesDef and speciesDef.evolutionMoves then
          for _, mv in ipairs(speciesDef.evolutionMoves) do
            table.insert(out, 1, mv)
          end
        end
        return out
      end

      local ok, err = pcall(original_learnEvolutionMoves, game, mon, onDone)
      Experience.movesLearnedAt = original_movesLearnedAt
      if not ok then error(err) end
    end

    flushShedinjaAnnounce(game, continueLearn)
  end

  -- Wrap openParty to implement Shadow Tag / Magnet Pull switch block (Gen1).
  if Host.isGen1() then
    local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
    Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
      local original_openParty = BattleState.openParty
      if type(original_openParty) ~= "function" then return end
      BattleState.openParty = function(self)
        local opponent = self.enemy
        if opponent and opponent.mon and opponent.mon.hp and opponent.mon.hp > 0 then
          local oppDef = self.data.pokemon[opponent.mon.species]
          local ability = oppDef and oppDef.ability
          if ability == "SHADOW_TAG" and not battlerHasType(self.player, "GHOST") then
            self:say(Strings("Cannot switch due to Shadow Tag!"))
            self.phase = "messages"
            self.afterQueue = "menu"
            return
          end
          if ability == "MAGNET_PULL" and battlerHasType(self.player, "STEEL") then
            self:say(Strings("Cannot switch due to Magnet Pull!"))
            self.phase = "messages"
            self.afterQueue = "menu"
            return
          end
        end
        return original_openParty(self)
      end
    end)
  end

  -- 1. Load generated databases
  local has_types, types_data = pcall(require, "mods.Kanto-Reforged.battle.types_data")
  local has_pokemon, pokemon_data = pcall(require, "mods.Kanto-Reforged.pokemon.pokemon_data")
  if has_pokemon and pokemon_data then
    _cachedPokemonData = pokemon_data
  end
  
  -- 2. Register Custom Types and Type Matchups
  -- Same Dark/Steel/Fairy table on Red and Gold (upsert on Gold so ROM + KR agree).
  if has_types then
    local TypeChartPatches = require("mods.Kanto-Reforged.battle.type_chart_patches")

    for id, record in pairs(types_data.types) do
      if not mod.content.type_chart:get(id) then
        pcall(function()
          mod.content.type_chart:register(id, record)
        end)
        mod.log:info("Registered custom type: %s", id)
      end
    end

    if Host.isGen2() then
      -- Gold already has Dark/Steel from ROM; force KR Fairy + all modern
      -- matchup rows so effectiveness matches Red.
      TypeChartPatches.applyModernTypes(mod, types_data)
      mod.log:info("Synced Dark/Steel/Fairy matchups (Gold)")
    else
      for _, row in ipairs(types_data.matchups) do
        local key = row.attacker .. ">" .. row.defender
        pcall(function()
          mod.content.type_chart:register(key, { multiplier = row.multiplier })
        end)
      end
      mod.log:info("Registered custom type effectiveness matchups")
    end

    -- Classic Gen1 quirks → Gen3 on every host (idempotent on Gold).
    TypeChartPatches.apply(mod)
  else
    mod.log:warn("types_data.lua not found (run generate_pokemon_mod.py first)")
  end
  
  -- 3. Register Custom Moves and Pokémon Species
  if has_pokemon then
    local Gen2Compat = require("mods.Kanto-Reforged.core.gen2_compat")
    local gen2DataReady = false
    if Host.isGen2() then
      -- Seed growth rates, EVOLVE_* aliases, and move-effect stubs so Gen3
      -- content can resolve without requiring a full Gen2 ROM cache first.
      Gen2Compat.seedInfra(mod, pokemon_data)
      gen2DataReady = Gen2Compat.gen2DataReady(mod)
      if not gen2DataReady then
        mod.log:warn(
          "Gen2 ROM cache incomplete; Hoenn moves use effect stubs / "
            .. "known learnsets. Import Gold/Silver/Crystal for full move tables."
        )
      end
    end

    -- Gen3 type-based physical/special: strip Gen4 move.category fields.
    MoveCategoryGen3.stripTable(pokemon_data.moves)

    local moves_registered = 0
    if not Host.isGen2() or gen2DataReady then
      for id, record in pairs(pokemon_data.moves) do
        local ok = pcall(function()
          if Host.isGen2() then
            local copy = {}
            for k, v in pairs(record) do copy[k] = v end
            copy.effect = Gen2Compat.effectForMove(id, record.effect)
            mod.content.moves:register(id, copy)
          else
            mod.content.moves:register(id, record)
          end
        end)
        if ok then moves_registered = moves_registered + 1 end
      end
      mod.log:info("Registered %d custom moves", moves_registered)

      local MoveAnims = require("mods.Kanto-Reforged.battle.move_anims")
      MoveAnims.register(mod, pokemon_data.moves)
      MoveAnims.install(mod)
    else
      -- Incomplete Gen2 cache: still register moves whose type + effect already resolve.
      for id, record in pairs(pokemon_data.moves) do
        local ok = pcall(function()
          local copy = {}
          for k, v in pairs(record) do copy[k] = v end
          copy.effect = Gen2Compat.effectForMove(id, record.effect)
          if not mod.content.type_chart:get(copy.type) then return end
          if not mod.content.move_effects:get(copy.effect) then
            Gen2Compat.seedMoveEffectStubs(mod, { moves = { [id] = copy } })
          end
          mod.content.moves:register(id, copy)
        end)
        if ok and mod.content.moves:get(id) then
          moves_registered = moves_registered + 1
        end
      end
      mod.log:info("Registered %d custom moves (compat / partial Gen2)", moves_registered)
    end

    -- Gen3 move types on Red and Gen2 (Bite→Dark, Charm→Normal, …).
    -- Does not touch sprites or generate_pokemon_mod.py.
    local okMoves, MoveTypePatches = pcall(require, "mods.Kanto-Reforged.battle.move_type_patches")
    if okMoves then
      MoveTypePatches.apply(mod)
    end
    
    local DexEntries = require("mods.Kanto-Reforged.pokemon.dex_entries")
    local dexTexts = DexEntries.bindAll(mod, pokemon_data.species)
    DexEntries.installInlineTextFallback(mod)

    local okPals, species_palettes = pcall(require, "mods.Kanto-Reforged.pokemon.species_palettes")
    local PaletteGen2 = require("mods.Kanto-Reforged.pokemon.palette_gen2")
    if okPals and type(species_palettes) == "table" then
      if Host.isGen2() then
        -- Gen2: middle-two-color rows under gen2Palettes.pokemon[species].
        -- Do NOT Gen1-register named packs here — that pollutes top-level
        -- gen2Palettes keys and leaves Hoenn monColors nil (grayscale).
        PaletteGen2.apply(mod, species_palettes, pokemon_data)
      else
        PaletteGen2.applyGen1(mod, species_palettes)
      end
    else
      mod.log:warn("species_palettes.lua missing — Gen 2/3 mons will use MEWMON / grayscale")
    end

    if Host.isGen2() then
      PokemonGen2.registerForGen2(mod, pokemon_data, {
        gen2DataReady = gen2DataReady,
      })
      -- Gen2 dex UI reads gen2Pokedex.entries (not Data.text). Fill Hoenn rows.
      DexEntries.bindGen2Pokedex(mod, pokemon_data.species)
      -- Catch → NewPokedexEntry: land on OLD when species is off NEW/A–Z.
      DexEntries.installGen2CatchEntryFix(mod)
      applySpawnTables(mod, pokemon_data)
      local JohtoDex = require("mods.Kanto-Reforged.pokemon.johto_dex")
      JohtoDex.installNests(mod)
      JohtoDex.installArea(mod)
      -- Gold Kanto gym/route parties: write trainers[].party + lookup overlay
      -- (same contract as restored_dungeons). Must run after Gold trainer data
      -- exists, and installGen2 after RestoredDungeons so wraps compose.
      ExpTrainers.clearBaselines()
      local nTrainersG2 = ExpTrainers.apply(mod)
      ExpTrainers.installGen2(mod)
      mod.log:info("Gen2 overworld trainer parties mixed (%d classes)", nTrainersG2)
      local TrainersGen2 = require("mods.Kanto-Reforged.battle.trainers_gen2")
      TrainersGen2.install(mod)
      require("mods.Kanto-Reforged.world.e4_kanto_dialogue").install(mod)
      mod.events:on("mod.options_changed", function(ev)
        if not (ev and ev.mod == mod.id) then return end
        Host.persistModOptions(mod)
        if Host.optionEventIs(ev.key, "species_scope") then
          SpeciesScope.onOptionsChanged(mod, Host.liveGame(mod), ev)
          return
        end
        if Host.optionEventIs(ev.key, "pure_spawn_random") then
          if mod.options:get(Host.optionKey("pure_spawn_random")) then
            applySpawnTables(mod, pokemon_data, { rerollPure = true })
          else
            applySpawnTables(mod, pokemon_data, { clearPureSeed = true })
          end
          syncGen2DexAfterToggle(mod)
          return
        end
        if Host.optionEventIs(ev.key, "full_spawn_random")
            or Host.optionEventIs(ev.key, "legends_in_mix") then
          applySpawnTables(mod, pokemon_data)
          syncGen2DexAfterToggle(mod)
        end
      end)
      SpeciesScope.refresh(mod, nil, SpeciesScope.mode(mod))
      mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.mode(mod))
    else
      PokemonGen2.applyGen1DerivedSprites(mod, pokemon_data)
      local BattleSpriteScale = require("mods.Kanto-Reforged.battle.battle_sprite_scale")
      local species_registered = 0
      local highestDex = 151
      for id, record in pairs(pokemon_data.species) do
        -- Hoenn backs: Gen1-only 1.5× so they match Gen2 on-screen size
        -- (shared pokemon_data stays unset for the Gen2 bridge).
        mod.content.pokemon:register(id, BattleSpriteScale.gen1RegisterCopy(record))
        species_registered = species_registered + 1
        if record.dex and record.dex > highestDex then
          highestDex = record.dex
        end
      end
      mod.log:info("Registered %d custom Pokémon species", species_registered)
      -- National dex size by default; SpeciesScope.refresh may clamp to 151.
      mod.content.constants:patch("dexSize", highestDex)
      mod.content.constants:patch("dexDigits", math.max(3, #tostring(highestDex)))
      mod.log:info("Pokédex extended to %d", highestDex)

      local SpeciesIcons = require("mods.Kanto-Reforged.pokemon.species_icons")
      SpeciesIcons.register(mod, pokemon_data.species)

      applySpawnTables(mod, pokemon_data)
      local nTrainers = ExpTrainers.apply(mod)
      mod.log:info("Trainer parties mixed (%d classes)", nTrainers)
      mod.events:on("mod.options_changed", function(ev)
        if not (ev and ev.mod == mod.id) then return end
        Host.persistModOptions(mod)
        if Host.optionEventIs(ev.key, "species_scope") then
          SpeciesScope.onOptionsChanged(mod, Host.liveGame(mod), ev)
          return
        end
        if ev.key == "sprite_source" then
          local SpriteCache = require("mods.Kanto-Reforged.core.sprite_cache")
          SpriteCache.onSourceChanged(mod, pokemon_data)
          return
        end
        if Host.optionEventIs(ev.key, "pure_spawn_random") then
          if mod.options:get(Host.optionKey("pure_spawn_random")) then
            applySpawnTables(mod, pokemon_data, { rerollPure = true })
          else
            applySpawnTables(mod, pokemon_data, { clearPureSeed = true })
          end
          return
        end
        if Host.optionEventIs(ev.key, "full_spawn_random")
            or Host.optionEventIs(ev.key, "legends_in_mix") then
          applySpawnTables(mod, pokemon_data)
        end
      end)
      SpeciesScope.refresh(mod, nil, SpeciesScope.mode(mod))
      mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.mode(mod))
      -- Apply after merge so Red natives (1–151) pick up Gen2 caches too.
      local SpriteCache = require("mods.Kanto-Reforged.core.sprite_cache")
      SpriteCache.applyLive(mod)
      SpriteCache.invalidateAssets()
    end

    if dexTexts > 0 then
      mod.log:info("Registered %d Pokédex flavor texts", dexTexts)
    end

    -- Register Tyrogue custom evolution check logic
    local function checkTyrogue(mon, level, cond)
      if not mon or (mon.level or 0) < level then return false end
      local att = mon.stats and mon.stats.attack or 0
      local def = mon.stats and mon.stats.defense or 0
      if cond == "atk" then return att > def
      elseif cond == "def" then return def > att
      else return att == def end
    end

    local function registerEvoMethod(id, gen1Check, gen2Check)
      if Host.isGen2() then
        mod.content.evolution_methods:register(id, { check = gen2Check })
      else
        mod.content.evolution_methods:register(id, { check = gen1Check })
      end
    end

    registerEvoMethod("TYROGUE_ATK",
      function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkTyrogue(mon, evo.level or 20, "atk")
      end,
      function(entry, mon, ctx)
        return checkTyrogue(mon, (entry and entry.level) or 20, "atk")
      end)
    registerEvoMethod("TYROGUE_DEF",
      function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkTyrogue(mon, evo.level or 20, "def")
      end,
      function(entry, mon, ctx)
        return checkTyrogue(mon, (entry and entry.level) or 20, "def")
      end)
    registerEvoMethod("TYROGUE_BAL",
      function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkTyrogue(mon, evo.level or 20, "bal")
      end,
      function(entry, mon, ctx)
        return checkTyrogue(mon, (entry and entry.level) or 20, "bal")
      end)

    -- Register Wurmple custom random split checking based on DVs modulo 2
    local function checkWurmple(mon, level, remainder)
      if not mon or (mon.level or 0) < level then return false end
      local dvs = mon.dvs or {}
      local val = (dvs.attack or 0) + (dvs.defense or 0) + (dvs.speed or 0)
        + (dvs.special or dvs.specialAttack or 0)
      return val % 2 == remainder
    end

    registerEvoMethod("WURMPLE_A",
      function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkWurmple(mon, evo.level or 7, 0)
      end,
      function(entry, mon, ctx)
        return checkWurmple(mon, (entry and entry.level) or 7, 0)
      end)
    registerEvoMethod("WURMPLE_B",
      function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkWurmple(mon, evo.level or 7, 1)
      end,
      function(entry, mon, ctx)
        return checkWurmple(mon, (entry and entry.level) or 7, 1)
      end)

    -- Patch vanilla Kanto species evolutions
    if pokemon_data.evolutions then
      local evos_patched = 0
      local useInto = Host.isGen2()
      for speciesId, new_evos in pairs(pokemon_data.evolutions) do
        local existing = mod.content.pokemon:get(speciesId)
        if existing then
          local evos = {}
          local function evoTarget(evo)
            return evo.into or evo.species
          end
          -- Same-into is not a duplicate: Gold Scyther already has
          -- trade+Metal Coat → Scizor, and the Moon Stone remap is a
          -- second method to that form. Key on method+item too.
          local function evoKey(evo)
            return table.concat({
              tostring(evoTarget(evo) or ""),
              tostring(evo.method or ""),
              tostring(evo.item or ""),
              tostring(evo.level or ""),
            }, "\0")
          end
          local function copyEvo(evo)
            local target = evoTarget(evo)
            local method = evo.method
            if useInto then
              local Gen2Compat = require("mods.Kanto-Reforged.core.gen2_compat")
              method = Gen2Compat.remapEvoMethod(method)
              return {
                method = method,
                level = evo.level,
                item = evo.item,
                into = target,
                time = evo.time,
                comparison = evo.comparison,
              }
            end
            -- Nested evo recs are schema-strict on Gen1: species + item only.
            return {
              method = method,
              level = evo.level,
              item = evo.item,
              species = target,
            }
          end
          if existing.evolutions then
            for _, evo in ipairs(existing.evolutions) do
              table.insert(evos, copyEvo(evo))
            end
          end
          local seen = {}
          for _, evo in ipairs(evos) do
            seen[evoKey(evo)] = true
          end
          for _, evo in ipairs(new_evos) do
            local row = copyEvo(evo)
            local target = evoTarget(row)
            -- Skip into-targets that are not in this boot's pokemon table
            -- (headless Gold without a Gold cache has no Espeon/etc.).
            if target and not seen[evoKey(row)] and mod.content.pokemon:get(target) then
              table.insert(evos, row)
              seen[evoKey(row)] = true
            end
          end
          local ok = pcall(function()
            mod.content.pokemon:patch(speciesId, { evolutions = evos })
          end)
          if ok then evos_patched = evos_patched + 1 end
        end
      end
      mod.log:info("Patched evolutions for %d vanilla Pokémon species", evos_patched)
      SpeciesScope.captureEvoBaselines(mod, true)
      SpeciesScope.applyEvoScope(mod, SpeciesScope.mode(mod))
    end

    -- Gen3 learnsets (#1–386): replace ROM/Gold tables from learnset_gen3.lua.
    local ApplyGen3 = require("mods.Kanto-Reforged.pokemon.apply_gen3_learnsets")
    local okGen3, learnset_gen3 = pcall(require, "mods.Kanto-Reforged.pokemon.learnset_gen3")
    if okGen3 and learnset_gen3 then
      local nGen3 = ApplyGen3.apply(mod, Host, learnset_gen3)
      mod.log:info("Applied Gen3 learnsets to %d species (dex 1–386)", nGen3)
    else
      mod.log:warn("learnset_gen3.lua missing; run tools/gen3_learnsets.py")
    end

    -- Gen 3 abilities for vanilla Kanto species (Bulbasaur OVERGROW, etc.)
    local okAbil, ability_patches = pcall(require, "mods.Kanto-Reforged.battle.ability_patches")
    if okAbil and ability_patches and ability_patches.abilities then
      local nAbil = 0
      for speciesId, ability in pairs(ability_patches.abilities) do
        if ability and ability ~= "NONE" then
          local ok = pcall(function()
            mod.content.pokemon:patch(speciesId, { ability = ability })
          end)
          if ok then nAbil = nAbil + 1 end
        end
      end
      mod.log:info("Patched Gen 3 abilities onto %d Kanto species", nAbil)
    else
      mod.log:warn("ability_patches.lua missing; Kanto abilities skipped")
    end

    -- SpA/SpD bases for optional SP.ATK / SP.DEF toggle (vanilla Kanto)
    local okSp, special_stat_patches = pcall(require, "mods.Kanto-Reforged.battle.special_stat_patches")
    if okSp and special_stat_patches and special_stat_patches.stats then
      local nSp = 0
      for speciesId, row in pairs(special_stat_patches.stats) do
        if type(row) == "table" and row.sp_attack and row.sp_defense then
          local ok = pcall(function()
            if Host.isGen2() then
              mod.content.pokemon:patch(speciesId, {
                baseStats = {
                  specialAttack = row.sp_attack,
                  specialDefense = row.sp_defense,
                },
              })
            else
              mod.content.pokemon:patch(speciesId, {
                sp_attack = row.sp_attack,
                sp_defense = row.sp_defense,
              })
            end
          end)
          if ok then nSp = nSp + 1 end
        end
      end
      mod.log:info("Patched SpA/SpD onto %d Kanto species", nSp)
    else
      mod.log:warn("special_stat_patches.lua missing; Kanto SpA/SpD skipped")
    end

    -- Gender rates (PokéAPI female eighths; -1 = genderless)
    local okGender, gender_patches = pcall(require, "mods.Kanto-Reforged.pokemon.gender_patches")
    if okGender and gender_patches and gender_patches.rates then
      local nGender = 0
      local field = Host.isGen2() and "genderRatio" or "genderRate"
      for speciesId, rate in pairs(gender_patches.rates) do
        if speciesId ~= "DEOXYS" and type(rate) == "number" then
          -- Gen2 genderRatio is 0–255; KR genderRate is female eighths (-1 genderless).
          local value = rate
          if Host.isGen2() then
            if rate < 0 then
              value = 255
            else
              value = math.max(0, math.min(254, math.floor(rate * 32)))
            end
          end
          local ok = pcall(function()
            mod.content.pokemon:patch(speciesId, { [field] = value })
          end)
          if ok then nGender = nGender + 1 end
        end
      end
      if type(gender_patches.rates.DEOXYS) == "number" then
        pcall(function()
          mod.content.pokemon:patch("DEOXYS_NORMAL", {
            [field] = Host.isGen2() and 255 or gender_patches.rates.DEOXYS,
          })
        end)
      end
      mod.log:info("Patched %s onto %d species", field, nGender)
    else
      mod.log:warn("gender_patches.lua missing; gender rates skipped")
    end

    -- Breeding: egg groups, hatch counters, baby species, egg moves
    local okBreed, breeding_patches = pcall(require, "mods.Kanto-Reforged.pokemon.breeding_patches")
    if okBreed and breeding_patches then
      local Breeding = require("mods.Kanto-Reforged.pokemon.breeding")
      local DisabledMoves = require("mods.Kanto-Reforged.pokemon.disabled_moves")
      local nBreed = 0
      if Host.isGen2() then
        -- Gen2 schema uses eggSteps (not hatchCounter) and rejects KR-only fields.
        for speciesId, row in pairs(breeding_patches.species or {}) do
          if speciesId == "DEOXYS" then
            speciesId = "DEOXYS_NORMAL"
          end
          local patch = {}
          if row.eggGroups then patch.eggGroups = row.eggGroups end
          if row.hatchCounter then patch.eggSteps = row.hatchCounter end
          if row.eggMoves then
            local moves = {}
            for _, mv in ipairs(row.eggMoves) do
              if mod.content.moves:get(mv) and not DisabledMoves.isDisabled(mv) then
                moves[#moves + 1] = mv
              end
            end
            patch.eggMoves = moves
          end
          if next(patch) then
            local ok = pcall(function()
              mod.content.pokemon:patch(speciesId, patch)
            end)
            if ok then nBreed = nBreed + 1 end
          end
        end
      else
        nBreed = Breeding.applyPatches(mod, breeding_patches)
      end
      mod.log:info("Patched breeding data onto %d species", nBreed)
    else
      mod.log:warn("breeding_patches.lua missing; daycare breeding skipped")
    end

    -- Strip singles-useless moves (Helping Hand) from every learnset.
    do
      local DisabledMoves = require("mods.Kanto-Reforged.pokemon.disabled_moves")
      local nStrip = DisabledMoves.stripAllSpecies(mod)
      mod.log:info("Scrubbed disabled moves from %d species learnsets", nStrip)
    end
  else
    mod.log:warn("pokemon_data.lua not found or failed to load: " .. tostring(pokemon_data))
  end

  local SummaryUi = require("mods.Kanto-Reforged.ui.summary_ui")
  SummaryUi.register(mod)

  local GenderUi = require("mods.Kanto-Reforged.ui.gender_ui")
  GenderUi.register(mod)

  local DexNav = require("mods.Kanto-Reforged.ui.dexnav")
  DexNav.register(mod)

  local BagPockets = require("mods.Kanto-Reforged.items.bag_pockets")
  local Host = require("mods.Kanto-Reforged.core.host")
  local bagMod = mod.find("gen1_bag_pockets")
  if bagMod and bagMod.exports and bagMod.exports.addBagMenuDecorator then
    -- Gen1 UI owned by gen1_bag_pockets: inject BAG GIVE only.
    bagMod.exports.addBagMenuDecorator(function(game, list, opts)
      HeldItems.decorateBagMenu(mod, game, list, opts)
    end)
    -- Bag mod is Gen1-only; Gen2 still needs ITEM-pocket capacity 60.
    if Host.isGen2From(mod) then
      BagPockets.applyCapacity(mod)
    end
  elseif Host.isGen2From(mod) then
    -- Gen2 already has PackMenu pockets; only raise ITEM capacity.
    BagPockets.applyCapacity(mod)
  else
    BagPockets.register(mod)
  end

  -- Optional Gen1 Modern UI adapter (no-op when that mod is absent).
  if require("mods.Kanto-Reforged.ui.gen1_modern_ui_adapter")(mod) then
    mod.log:info("Gen1 Modern UI adapter registered")
  end
  -- Party/PC detail SPC→SAT/SDF patch may need a late bind if Modern UI
  -- loads after us; installModernUiPartyPatch watches render.hud once.
  SplitSpecial.installModernUiPartyPatch(mod)

  -- 4. Hook into battle damage pipeline (SpA/SpD + abilities +
  --    variable-power Gen 2/3 moves)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  mod.hooks:wrap("battle.damage", function(next, ctx)
    local move = ctx.move
    local user = ctx.user
    local target = ctx.target
    local TypeChart = require("src.battle.TypeChart")
    local userMon = BattleCompat.mon(user)
    local targetMon = BattleCompat.mon(target)

    local oldType, oldPower, oldCategory
    local function bumpPower(p)
      oldType, oldPower, oldCategory = move.type, move.power, move.category
      move.power = p
    end

    if move and move.id == "HIDDEN_POWER" then
      oldType, oldPower, oldCategory = move.type, move.power, move.category
      local t, p = ExpMoveEffects.hiddenPower(user)
      move.type, move.power = t, p
      move.category = TypeChart.category(t) or "special"
    elseif move and move.id == "WEATHER_BALL" then
      oldType, oldPower, oldCategory = move.type, move.power, move.category
      local t, p = ExpMoveEffects.weatherBall(ctx.battle)
      move.type, move.power = t, p
      move.category = TypeChart.category(t) or "special"
    elseif move and move.id == "FACADE" and BattleCompat.status(user) then
      bumpPower((move.power or 70) * 2)
    elseif move and (move.id == "ERUPTION" or move.id == "WATER_SPOUT") and userMon then
      bumpPower(math.max(1, math.floor((move.power or 150)
        * BattleCompat.hp(user) / BattleCompat.maxHp(user))))
    elseif move and (move.id == "FLAIL" or move.id == "REVERSAL") then
      bumpPower(ExpMoveEffects.flailPower(user))
    elseif move and move.id == "RETURN" then
      bumpPower(ExpMoveEffects.returnPower(user))
    elseif move and move.id == "FRUSTRATION" then
      bumpPower(ExpMoveEffects.frustrationPower(user))
    elseif move and move.id == "HEX" and BattleCompat.status(target) then
      bumpPower((move.power or 65) * 2)
    elseif move and move.id == "VENOSHOCK"
        and (BattleCompat.status(target) == "PSN"
          or BattleCompat.status(target) == "poison"
          or BattleCompat.status(target) == "TOX"
          or BattleCompat.status(target) == "toxic") then
      bumpPower((move.power or 65) * 2)
    elseif move and move.id == "BRINE" and targetMon
        and BattleCompat.hp(target) * 2 <= BattleCompat.maxHp(target) then
      bumpPower((move.power or 65) * 2)
    elseif move and (move.id == "REVENGE" or move.id == "AVALANCHE")
        and user.expTookDamageThisTurn then
      bumpPower((move.power or 60) * 2)
    elseif move and move.id == "PAYBACK" and target.expActedThisTurn then
      bumpPower((move.power or 50) * 2)
    elseif move and move.id == "PURSUIT" and ctx.battle and ctx.battle.expPursuitSwitch then
      bumpPower((move.power or 40) * 2)
    elseif move and move.id == "ASSURANCE" and target.expTookDamageThisTurn then
      bumpPower((move.power or 60) * 2)
    elseif move and move.id == "BEAT_UP" then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.beatUpPower(ctx.battle, user))
    elseif move and (move.id == "GRASS_KNOT" or move.id == "LOW_KICK") then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.weightPower(ctx.battle, target))
    elseif move and (move.id == "HEAVY_SLAM" or move.id == "HEAT_CRASH"
        or move.id == "HARD_PRESS") then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.heavySlamPower(ctx.battle, user, target))
    elseif move and move.id == "GYRO_BALL" then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.gyroBallPower(ctx.battle, user, target))
    elseif move and move.id == "ELECTRO_BALL" then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.electroBallPower(ctx.battle, user, target))
    elseif move and move.id == "PUNISHMENT" then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.punishmentPower(ctx.battle, target))
    elseif move and (move.id == "STORED_POWER" or move.id == "POWER_TRIP") then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.storedPower(ctx.battle, user))
    elseif move and (move.id == "WRING_OUT" or move.id == "CRUSH_GRIP") then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      bumpPower(VP.wringOutPower(target))
    elseif move and move.id == "TRUMP_CARD" then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      local inst = ctx.moveInst or (user.curMoves and user.curMoves[1])
      bumpPower(VP.trumpCardPower(inst))
    elseif move and move.id == "ACROBATICS"
        and not (HeldItems.ofBattler and HeldItems.ofBattler(user)) then
      bumpPower((move.power or 55) * 2)
    elseif move and move.id == "FLING" then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      local item = HeldItems.ofBattler and HeldItems.ofBattler(user)
      local p = VP.flingPower(item)
      if p then bumpPower(p) else bumpPower(1) end
    elseif move and move.id == "NATURAL_GIFT" then
      local VP = require("mods.Kanto-Reforged.battle.variable_power")
      local item = HeldItems.ofBattler and HeldItems.ofBattler(user)
      local gift = VP.naturalGift(item)
      if gift then
        oldType, oldPower, oldCategory = move.type, move.power, move.category
        move.type, move.power = gift.type, gift.power
        move.category = TypeChart.category(gift.type) or "physical"
      else
        bumpPower(1)
      end
    elseif move and move.id == "KNOCK_OFF" and HeldItems.ofBattler
        and HeldItems.ofBattler(target) then
      bumpPower(math.floor((move.power or 65) * 1.5))
    elseif move and move.id == "FURY_CUTTER" and not BattleCompat.isGen2(ctx.battle) then
      local n = user.expFuryCutter or 0
      bumpPower((move.power or 40) * (2 ^ math.min(n, 4)))
    elseif move and move.id == "MAGNITUDE" then
      local p = ExpMoveEffects.magnitudePower(ctx.battle.rng or love.math.random)
      bumpPower(p)
    elseif move and move.id == "SMELLING_SALTS"
        and (BattleCompat.status(target) == "PAR"
          or BattleCompat.status(target) == "paralyze"
          or BattleCompat.status(target) == "paralysis") then
      bumpPower((move.power or 70) * 2)
    elseif move and move.id == "WAKE_UP_SLAP"
        and (BattleCompat.hasStatus(target, "SLP", "sleep")) then
      bumpPower((move.power or 70) * 2)
    elseif move and (move.id == "ROLLOUT" or move.id == "ICE_BALL")
        and not BattleCompat.isGen2(ctx.battle) then
      local n = user.expRollout or 0
      local base = move.power or 30
      if user.defenseCurled then base = base * 2 end
      bumpPower(base * (2 ^ math.min(n, 4)))
    end

    -- Charge: next Electric move deals double damage
    if user.expCharged and move and move.type == "ELECTRIC" and move.power and move.power > 0 then
      if oldPower == nil then
        bumpPower((move.power or 50) * 2)
      else
        move.power = (move.power or 50) * 2
      end
      user.expCharged = nil
    end

    -- Me First: 1.5x power on the copied move
    if user.expMeFirst and move and move.power and move.power > 0 then
      if oldPower == nil then
        bumpPower(math.floor((move.power or 50) * 1.5))
      else
        move.power = math.floor((move.power or 50) * 1.5)
      end
      user.expMeFirst = nil
    end

    -- Foresight: Normal/Fighting hit Ghost
    local oldTypes
    if target and target.expIdentified and move
        and (move.type == "NORMAL" or move.type == "FIGHTING") then
      local types = BattleCompat.types(target)
      local hasGhost = false
      for _, t in ipairs(types) do
        if t == "GHOST" then hasGhost = true break end
      end
      if hasGhost then
        oldTypes = types
        local nt = {}
        for _, t in ipairs(oldTypes) do
          if t ~= "GHOST" then nt[#nt + 1] = t end
        end
        if #nt == 0 then nt = { "NORMAL" } end
        BattleCompat.setTypes(target, nt)
      end
    end

    local function finish(damage, info)
      -- Type boosters must see the effective move type (Hidden Power /
      -- Weather Ball mutate move.type before damage, then restore it).
      if HeldItems.modifyDamage then
        local ok, out = pcall(HeldItems.modifyDamage, damage, ctx)
        if ok then damage = out end
      end
      if damage and damage > 0 and not BattleCompat.isGen2(ctx.battle) then
        local Weather = require("mods.Kanto-Reforged.battle.weather")
        local wmod = Weather.typeModifier(ctx.battle, move and move.type)
        if wmod ~= 1 then
          damage = math.max(1, math.floor(damage * wmod))
        end
      end
      if oldPower ~= nil then
        move.type, move.power, move.category = oldType, oldPower, oldCategory
      end
      if oldTypes then BattleCompat.setTypes(target, oldTypes) end
      -- Mirror Coat tracks special damage taken this hit
      local category = move.category or TypeChart.category(move.type) or "physical"
      if category == "special" and damage and damage > 0 then
        ctx.battle.expLastSpecialDamage = damage
      end
      return damage, info
    end

    -- Gold damage calc prefers speciesDef.types, which ignores Forecast.
    if ctx.opts then
      if ctx.opts.attacker and user then
        ctx.opts.attacker.types = BattleCompat.types(user, ctx.battle and ctx.battle.data)
      end
      if ctx.opts.defender and target then
        ctx.opts.defender.types = BattleCompat.types(target, ctx.battle and ctx.battle.data)
      end
    end

    local category = move.category or TypeChart.category(move.type) or "physical"
    local isSpecial = category == "special"

    -- Foul Play: use target's Attack. Body Press: use user's Defense as Attack.
    -- Psyshock: special attack vs physical Defense.
    local oldUserAtk, oldUserDef, oldTargetDef, oldTargetSp
    if move and move.id == "FOUL_PLAY" and target.curStats and user.curStats then
      oldUserAtk = user.curStats.attack
      user.curStats.attack = target.curStats.attack or oldUserAtk
    elseif move and move.id == "BODY_PRESS" and user.curStats then
      oldUserAtk = user.curStats.attack
      user.curStats.attack = user.curStats.defense or oldUserAtk
    elseif move and move.id == "PSYSHOCK" and target.curStats then
      oldTargetSp = target.curStats.special
      target.curStats.special = target.curStats.defense or oldTargetSp
      isSpecial = true
    end

    -- Freeze-Dry: Ice hits Water super-effectively.
    local oldTypeMult
    if move and move.id == "FREEZE_DRY" and target then
      local types = target.curTypes or {}
      for _, t in ipairs(types) do
        if t == "WATER" then
          ctx.expFreezeDryWater = true
          break
        end
      end
    end

    if isSpecial and SplitSpecial.enabled(mod)
        and user.curStats and target.curStats then
      local oldUserSpecial = user.curStats.special
      local oldTargetSpecial = target.curStats.special

      user.curStats.special = SplitSpecial.getBattleStat(user, true)
      if not oldTargetSp then
        target.curStats.special = SplitSpecial.getBattleStat(target, false)
      end

      local damage, info = Abilities.onDamage(next, ctx)

      user.curStats.special = oldUserSpecial
      if not oldTargetSp then
        target.curStats.special = oldTargetSpecial
      else
        target.curStats.special = oldTargetSp
      end
      if oldUserAtk then user.curStats.attack = oldUserAtk end

      if damage and damage > 0 then
        Abilities.onPostDamage(ctx.battle, user, target, move, damage)
      end
      if ctx.expFreezeDryWater and info then
        info.typeMult = math.max(info.typeMult or 10, 20)
      end
      return finish(damage, info)
    else
      local damage, info = Abilities.onDamage(next, ctx)
      if oldUserAtk and user.curStats then user.curStats.attack = oldUserAtk end
      if oldTargetSp and target.curStats then target.curStats.special = oldTargetSp end
      if damage and damage > 0 then
        Abilities.onPostDamage(ctx.battle, user, target, move, damage)
      end
      if ctx.expFreezeDryWater and info and (info.typeMult or 10) > 0 then
        -- Force at least 2× from the Water interaction on top of other matchups.
        local mult = info.typeMult or 10
        if mult < 20 then
          damage = math.max(1, math.floor(damage * 20 / math.max(1, mult)))
          info.typeMult = 20
        end
      end
      return finish(damage, info)
    end
  end)

  -- Hustle accuracy cut / Compound Eyes boost / Sand Veil / Lock-On / Foresight
  mod.hooks:wrap("battle.accuracy", function(next, ctx)
    if ctx.target and ctx.target.expProtected then
      -- Feint breaks Protect / Detect.
      if ctx.move and ctx.move.id == "FEINT" then
        ctx.target.expProtected = nil
      else
        return false
      end
    end
    local Weather = require("mods.Kanto-Reforged.battle.weather")
    if Weather.neverMiss(ctx.battle, ctx.move) then
      return true
    end
    -- Gen 3: Thunder accuracy drops to 50% in harsh sunlight
    local curWeather = Weather.current(ctx.battle)
    if curWeather == "SUNNY" and ctx.move and ctx.move.id == "THUNDER" then
      if type(ctx.accuracy) == "number" then
        oldAcc = ctx.accuracy
        ctx.accuracy = 50
      elseif ctx.move and ctx.move.accuracy then
        oldAcc = ctx.move.accuracy
        ctx.move.accuracy = 50
      end
    end
    -- Lock-On / Mind Reader: next move against the marked target never misses
    if ctx.target and ctx.target.expLockedOn then
      ctx.target.expLockedOn = nil
      return true
    end

    local userAbility = Abilities.abilityOf(ctx.battle, ctx.user)
    local oldAcc
    if userAbility == "COMPOUND_EYES" then
      if type(ctx.accuracy) == "number" then
        oldAcc = ctx.accuracy
        ctx.accuracy = math.min(100, math.floor(oldAcc * 13 / 10))
      elseif ctx.move and ctx.move.accuracy then
        oldAcc = ctx.move.accuracy
        ctx.move.accuracy = math.min(100, math.floor(oldAcc * 13 / 10))
      end
    end

    -- Foresight: ignore positive evasion stages
    local oldEvasion
    local stages = ctx.target and BattleCompat.stages(ctx.battle, ctx.target)
    if ctx.target and ctx.target.expIdentified and stages then
      oldEvasion = stages.evasion
      if (oldEvasion or 0) > 0 then
        stages.evasion = 0
      else
        oldEvasion = nil
      end
    end

    local hit = next(ctx)
    if oldAcc then
      if type(ctx.accuracy) == "number" then
        ctx.accuracy = oldAcc
      elseif ctx.move then
        ctx.move.accuracy = oldAcc
      end
    end
    if oldEvasion ~= nil and stages then stages.evasion = oldEvasion end
    if hit == false then return false end

    local targetAbility = Abilities.abilityOf(ctx.battle, ctx.target)
    local TypeChart = require("src.battle.TypeChart")
    local category = ctx.move.category
        or TypeChart.category(ctx.move.type) or "physical"
    if userAbility == "HUSTLE" and category == "physical" then
      if (ctx.battle.rng or love.math.random)(0, 99) >= 80 then
        return false
      end
    end
    if targetAbility == "SAND_VEIL"
        and Weather.current(ctx.battle) == "SANDSTORM" then
      if (ctx.battle.rng or love.math.random)(0, 99) < 20 then
        return false
      end
    end
    return hit
  end)

  -- Battle Armor / Shell Armor / Lucky Chant: never crit.
  -- Under modern_clean (krGen3Crit), use Gen3 stage ladder instead of Gen1 speed crits.
  mod.hooks:wrap("battle.crit", function(next, ctx)
    local battle = mod.activeBattle or ctx.battle
    if battle and ctx.attacker then
      local target = (ctx.attacker == battle.player) and battle.enemy or battle.player
      -- Gen2 crit ctx may name the defender explicitly.
      target = ctx.target or ctx.defender or target
      local ability = Abilities.abilityOf(battle, target)
      if ability == "BATTLE_ARMOR" or ability == "SHELL_ARMOR" then
        return false
      end
      local sideKey = battle.sideOf and battle:sideOf(target)
      local side = sideKey
      if type(sideKey) == "string" and battle.sides then
        side = battle.sides[sideKey]
      elseif type(sideKey) == "number" and battle.sides then
        side = battle.sides[sideKey]
      end
      if side and side.expLuckyChantTurns and side.expLuckyChantTurns > 0 then
        return false
      end
    end
    local ruleset = ctx.ruleset or (battle and battle.ruleset)
    if CritGen3.rulesetWants(ruleset) or not battle or not BattleCompat.isGen2(battle) then
      return CritGen3.roll(ctx)
    end
    return next(ctx)
  end)

  -- Ensure Data.moves also lose Gen4 categories after merge (vanilla + KR).
  mod.events:on("game.ready", function()
    local n = MoveCategoryGen3.apply()
    if n > 0 and mod.log then
      mod.log:info("Stripped Gen4 move.category on %d moves (Gen3 type split)", n)
    end
  end)

  -- Rock Head: strip recoil from the vanilla recoil effect
  local function patchRecoil()
    local Data = require("src.core.Data")
    local rec = Data.move_effects and Data.move_effects.RECOIL_EFFECT
    if rec and rec.afterDamage and not rec._expPatched then
      local old = rec.afterDamage
      rec.afterDamage = function(ctx)
        if Abilities.abilityOf(ctx.battle, ctx.user) == "ROCK_HEAD" then
          return
        end
        return old(ctx)
      end
      rec._expPatched = true
    end
  end
  mod.events:on("game.ready", function() patchRecoil() end)
  patchRecoil()

  -- Chlorophyll / Swift Swim / Tailwind / Trick Room speed ordering
  mod.hooks:wrap("battle.turn_order", function(next, a, aMove, b, bMove, ctx)
    local battle = mod.activeBattle
    if not battle then return next(a, aMove, b, bMove, ctx) end
    local ma, mb = Abilities.speedMult(battle, a), Abilities.speedMult(battle, b)
    local trick = battle.expTrickRoomTurns and battle.expTrickRoomTurns > 0
    if ma == 1 and mb == 1 and not trick then
      return next(a, aMove, b, bMove, ctx)
    end
    -- Gen2 first: prepareAiBattle may stamp curStats on party mons for AI,
    -- which must not take the Gen1 TurnOrder.mon path.
    if BattleCompat.isGen2(battle) and type(battle.battleStat) == "function" then
      local G2Damage = require("src.battle.gen2.Damage")
      local function effSpeed(mon)
        if not mon then return 0 end
        local spd = battle:battleStat(mon, "speed") or 1
        local key = type(battle.sideOf) == "function" and battle:sideOf(mon)
        local stages = key and battle.stages and battle.stages[key]
        spd = G2Damage.applyStage(spd, stages and stages.speed or 0)
        if BattleCompat.hasStatus(mon, "PAR", "paralyze") then
          spd = math.floor(spd * 0.25)
        end
        return math.floor(spd * Abilities.speedMult(battle, mon))
      end
      local pa = (aMove and aMove.priority) or 0
      local pb = (bMove and bMove.priority) or 0
      if pa ~= pb then return pa > pb end
      local sa, sb = effSpeed(a), effSpeed(b)
      if trick then sa, sb = sb, sa end
      if sa ~= sb then return sa > sb end
      local rng = (ctx and ctx.rng) or love.math.random
      return rng(2) == 1
    end
    -- Gen1: mutate curStats.speed temporarily.
    if a.curStats and b.curStats then
      local TurnOrder = require("src.battle.TurnOrder")
      local oldA, oldB = a.curStats.speed, b.curStats.speed
      a.curStats.speed = math.floor(oldA * ma)
      b.curStats.speed = math.floor(oldB * mb)
      local first = TurnOrder.firstMover(a, aMove, b, bMove,
        (ctx and ctx.rng) or love.math.random, ctx and ctx.invertTie)
      a.curStats.speed, b.curStats.speed = oldA, oldB
      if trick then return not first end
      return first
    end
    if trick then
      local first = next(a, aMove, b, bMove, ctx)
      return not first
    end
    if ma ~= mb then
      local pa = (aMove and aMove.priority) or 0
      local pb = (bMove and bMove.priority) or 0
      if pa == pb then return ma > mb end
    end
    return next(a, aMove, b, bMove, ctx)
  end)

  -- Shadow Tag / Magnet Pull / Mean Look escape blocker; Run Away always escapes wilds
  mod.hooks:wrap("battle.run", function(next, ctx)
    local battle = ctx.battle or ctx
    local playerAbility = Abilities.abilityOf(battle, battle.player)
    if playerAbility == "RUN_AWAY" and battle.kind == "wild" then
      return true
    end
    do
      local PartialTrap = require("mods.Kanto-Reforged.battle.partial_trap")
      if PartialTrap.active(battle) and PartialTrap.isTrapped(battle.player)
          and not battlerHasType(battle.player, "GHOST") then
        battle:sayNext(Strings("Cannot escape!"))
        return false
      end
    end
    if battle.player and battle.player.expTrapped
        and not battlerHasType(battle.player, "GHOST") then
      battle:sayNext(Strings("Cannot escape!"))
      return false
    end
    local opponent = battle.enemy
    local oppMon = opponent and BattleCompat.mon(opponent)
    if oppMon and oppMon.hp and oppMon.hp > 0 then
      local ability = Abilities.abilityOf(battle, opponent)
      if ability == "SHADOW_TAG" and not battlerHasType(battle.player, "GHOST") then
        BattleCompat.say(battle, Strings("Cannot escape due to Shadow Tag!"))
        return false
      end
      if ability == "MAGNET_PULL" and battlerHasType(battle.player, "STEEL") then
        BattleCompat.say(battle, Strings("Cannot escape due to Magnet Pull!"))
        return false
      end
    end
    return next(ctx)
  end)

  -- Illuminate: boost wild encounter rate when the lead has it
  local function patchIlluminate()
    local Encounter = require("src.world.Encounter")
    if Encounter._expIlluminate then return end
    local original = Encounter.roll
    Encounter.roll = function(encounterDef, rng)
      local Game = Host.liveGame(mod)
      local mult = Game and Abilities.illuminateRateMult(Game) or 1
      if mult == 1 or not encounterDef or not encounterDef.grass then
        return original(encounterDef, rng)
      end
      local grass = encounterDef.grass
      local oldRate = grass.rate
      grass.rate = math.min(255, math.floor(oldRate * mult))
      local result = original(encounterDef, rng)
      grass.rate = oldRate
      return result
    end
    Encounter._expIlluminate = true
  end
  mod.events:on("game.ready", function() patchIlluminate() end)
  patchIlluminate()

  -- Battle pics re-resolve every frame through pokemon.sprite
  -- (Sprites.path: species, side front/back, kind, trueColor).
  mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
    local CastformFx = require("mods.Kanto-Reforged.battle.castform_fx")
    local resolved = CastformFx.resolveSprite(path, ctx, mod.activeBattle, mod)
    if resolved and resolved ~= path then return resolved end
    -- Gen1: Gold/Silver/Crystal static caches for dex 1–251.
    local SpriteCache = require("mods.Kanto-Reforged.core.sprite_cache")
    local alt = SpriteCache.resolvePath(mod, ctx and ctx.species, ctx and ctx.side)
    if alt then return alt end
    return next(path, ctx)
  end)

  -- 5. Hook battle entry, turns, and moves
  -- Gold never calls TypeChart.load (Gen1 BattleState does). KR AI / abilities
  -- use TypeChart.effectiveness — load the merged chart on ready + battle.
  local function ensureTypeChart(data)
    if not data or not data.type_chart then return end
    local ok, TypeChart = pcall(require, "src.battle.TypeChart")
    if not ok or not TypeChart or not TypeChart.load then return end
    local matchups = data.type_chart.matchups
    if type(matchups) ~= "table" then return end
    pcall(TypeChart.load, data)
  end

  mod.events:on("game.ready", function(ev)
    if ev.game then
      mod.activeGame = ev.game
      ensureTypeChart(ev.game.data)
    end
  end)

  mod.events:on("battle.started", function(ev)
    if ev.battle then
      mod.activeBattle = ev.battle
      ensureTypeChart(ev.battle.data or (ev.game and ev.game.data)
        or (mod.activeGame and mod.activeGame.data))
      -- After send-outs, not before trainer / "Go!" dialog (sayNext would
      -- otherwise insert at the front of the intro queue on Gen1).
      Abilities.scheduleBattleStartEntries(ev.battle)
    end
  end)
  
  mod.events:on("battle.ended", function(ev)
    if ev.battle and ev.battle.game and ev.result == "win" then
      local party = ev.battle.game.save and ev.battle.game.save.party
      local item, mon = Abilities.tryPickup(ev.battle.game, party, ev.battle.rng)
      if item and mon and ev.battle.sayNext then
        ev.battle:sayNext(Strings("%s found one\n%s!", mon.nickname or mon.species, item))
      elseif item and mon and ev.battle.game.stack then
        -- battle may already be tearing down; best-effort bag add already done
      end
    end
    -- Gold battlers are party tables; wipe AI facade fields before SAVE.
    local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
    BattleCompat.scrubBattle(ev.battle)
    mod.activeBattle = nil
  end)

  -- Belt-and-suspenders: scrub again at write time in case a battle left
  -- party[i].mon == party[i] (serialize cycle / former stack overflow).
  mod.events:on("save.writing", function(ev)
    local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
    if ev and ev.save then
      BattleCompat.scrubPartyMons(ev.save.party)
    end
  end)
  
  mod.events:on("battle.battler_switched", function(ev)
    if ev.previous then
      ev.previous.expProtectStreak = nil
      ev.previous.expFlashFire = nil
    end
    if ev.battler then
      ev.battler.expProtectStreak = nil
    end
    if ev.battle and ev.battler then
      Abilities.onEntry(ev.battle, ev.battler)
    end
    if ev.battle then
      Abilities.updateForecast(ev.battle, ev.battle.player)
      Abilities.updateForecast(ev.battle, ev.battle.enemy)
    end
  end)

  -- Protect / Detect / Endure: clear each turn, force accuracy misses while up
  mod.events:on("battle.turn_started", function(ev)
    if not ev.battle then return end
    if ev.battle.player then
      ev.battle.player.expProtected = nil
      ev.battle.player.expEnduring = nil
    end
    if ev.battle.enemy then
      ev.battle.enemy.expProtected = nil
      ev.battle.enemy.expEnduring = nil
    end
    Abilities.onTurnStart(ev.battle, ev.battle.player)
    Abilities.onTurnStart(ev.battle, ev.battle.enemy)
  end)

  mod.events:on("battle.move_used", function(ev)
    if ev.battle then
      Abilities.onMoveUsed(ev.battle, ev.user, ev.move)
    end
    if ev.user and ev.move then
      if ev.move.id == "DEFENSE_CURL" then
        ev.user.defenseCurled = true
      end
      if ev.move.id ~= "ROLLOUT" and ev.move.id ~= "ICE_BALL" then
        ev.user.expRollout = nil
        ev.user.expRolloutMove = nil
      end
      if ev.move.id ~= "FURY_CUTTER" then
        ev.user.expFuryCutter = nil
      end
      -- Gen3 Protect: consecutive-use counter resets on any other action.
      if ev.move.id ~= "PROTECT" and ev.move.id ~= "DETECT"
          and ev.move.id ~= "ENDURE" then
        ev.user.expProtectStreak = nil
      end
    end
  end)

  -- End-of-turn volatiles/weather/held items/abilities: core/residual_handlers.lua

  -- Nincada → Ninjask leaves a Shedinja behind when a Poké Ball is
  -- consumed (Gen 3 split evolution). Inventory is id→count, not a list.
  -- Announcements are queued and flushed from learnEvolutionMoves so we
  -- never push a TextBox during EvolutionState's apply→congrats window.
  mod.events:on("pokemon.evolved", function(ev)
    if ev.fromSpecies ~= "NINCADA" or ev.toSpecies ~= "NINJASK" then
      return
    end
    -- Gen1 KANTO scope: Shedinja is out of dex range — skip the split.
    if Host.isGen1()
        and SpeciesScope.mode(mod) == SpeciesScope.MODE_KANTO then
      return
    end
    local game = ev.game or mod._evoGame or mod.activeGame
    if not game or not game.save or not game.data then return end
    if not ev.mon then return end

    local Bag = require("src.inventory.Bag")
    local ballId = nil
    for _, id in ipairs({ "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL" }) do
      if (game.save.inventory[id] or 0) > 0 then
        ballId = id
        break
      end
    end
    if not ballId then return end
    Bag.remove(game.save, ballId, 1)

    local Pokemon = require("src.pokemon.Pokemon")
    local Merge = require("src.mods.Merge")
    local Stats = require("src.pokemon.Stats")
    local level = ev.mon.level or 20
    local shedinja = Pokemon.new(game.data, "SHEDINJA", level)
    -- Inherit DVs / effort / moves from the shell left behind (Gen 3).
    shedinja.dvs = Merge.deepCopy(ev.mon.dvs) or shedinja.dvs
    shedinja.statExp = Merge.deepCopy(ev.mon.statExp)
      or { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }
    if type(ev.mon.moves) == "table" then
      shedinja.moves = Merge.deepCopy(ev.mon.moves)
    end
    shedinja.otName = ev.mon.otName
    shedinja.stats = Stats.calc(game.data.pokemon.SHEDINJA, shedinja.level,
                                shedinja.dvs, shedinja.statExp)
    shedinja.hp = 1
    if game.save.pokedex then
      local dex = game.save.pokedex
      dex.seen = dex.seen or {}
      dex.seen.SHEDINJA = true
      -- Gen1: owned; Gold: caught (same DexNav mismatch class).
      if dex.owned then dex.owned.SHEDINJA = true end
      dex.caught = dex.caught or {}
      dex.caught.SHEDINJA = true
    end

    if #game.save.party < 6 then
      table.insert(game.save.party, shedinja)
      queueShedinjaAnnounce(game, "A SHEDINJA appeared\nin the party!")
    else
      local Boxes = require("src.pokemon.Boxes")
      local boxNum = Boxes.deposit(game.save, shedinja)
      if boxNum then
        local pc = (game.save.flags and game.save.flags.EVENT_MET_BILL)
                   and "BILL's PC" or "someone's PC"
        queueShedinjaAnnounce(game,
          string.format("SHEDINJA was\ntransferred to\n%s!", pc))
      else
        -- Ball already spent; nowhere to put it (Gen 3 refuses the split
        -- earlier — we can't refund cleanly mid-apply).
        queueShedinjaAnnounce(game, "Every BOX is full!\nSHEDINJA escaped!")
      end
    end
  end)
  
  mod.log:info("Kanto Reforged mod successfully initialized!")
end
