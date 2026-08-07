local Abilities = require("mods.Kanto-Reforged.abilities")
local ExpMoveEffects = require("mods.Kanto-Reforged.move_effects")
local HeldItems = require("mods.Kanto-Reforged.held_items")
local Gender = require("mods.Kanto-Reforged.gender")
local ModernXpShare = require("mods.Kanto-Reforged.modern_xp_share")
local TrainerAi = require("mods.Kanto-Reforged.trainer_ai")
local ExpTrainers = require("mods.Kanto-Reforged.trainers")
local Strings = require("src.core.Strings")

local function battlerHasType(battler, typeId)
  for _, t in ipairs((battler and battler.curTypes) or {}) do
    if t == typeId then return true end
  end
  return false
end

-- Helper to calculate battle Special Attack and Special Defense stats
local function getSpecialStat(battler, isAttack)
  local mon = battler.mon
  local def = battler.def
  if not def or not (def.sp_attack or def.sp_defense) then
    return battler.curStats.special
  end
  
  if not battler.sp_attack or not battler.sp_defense then
    local dvs = mon.dvs or {}
    local statExp = mon.statExp or {}
    local level = mon.level or 1
    
    local special_dv = dvs.special or 0
    local special_ev = statExp.special or 0
    
    local ev = math.floor(math.min(255, math.ceil(math.sqrt(special_ev))) / 4)
    
    local base_sp_atk = def.sp_attack or def.baseStats.special
    local base_sp_def = def.sp_defense or def.baseStats.special
    
    battler.sp_attack = math.floor(((base_sp_atk + special_dv) * 2 + ev) * level / 100) + 5
    battler.sp_defense = math.floor(((base_sp_def + special_dv) * 2 + ev) * level / 100) + 5
  end
  
  return isAttack and battler.sp_attack or battler.sp_defense
end

local mixEncounters = require("mods.Kanto-Reforged.encounters").mix
local ExpEncounters = require("mods.Kanto-Reforged.encounters")

local function spawnModeFromOptions(mod)
  if mod.options and mod.options:get("full_spawn_random") then
    return "full_random"
  end
  return "curated"
end

local function applySpawnTables(mod, pokemon_data)
  if not pokemon_data then return end
  local mode = spawnModeFromOptions(mod)
  ExpEncounters.apply(mod, pokemon_data, mode)
  mod.log:info("Wild encounters applied (%s)", mode)
end

return function(mod)
  -- Manager / card options
  mod.options:define({
    {
      key = "full_spawn_random",
      label = "FULL SPAWN MIX",
      type = "toggle",
      default = false,
    },
    ModernXpShare.OPTION,
    TrainerAi.OPTION,
  })

  -- Register Gen 2/3 move effects before content that references them
  ExpMoveEffects.register(mod)
  ExpMoveEffects.install(mod)

  -- Held items (items + link_fields + Give/Take + residuals)
  HeldItems.register(mod)
  HeldItems.registerMarts(mod)
  HeldItems.install(mod)

  -- Gender (DV-deterministic + Attract/Cute Charm infatuation)
  Gender.register(mod)
  Gender.install(mod)

  local Breeding = require("mods.Kanto-Reforged.breeding")
  Breeding.register(mod)
  Breeding.install(mod)

  local Daycare = require("mods.Kanto-Reforged.daycare")
  Daycare.register(mod)
  Daycare.install(mod)

  local BerryFarm = require("mods.Kanto-Reforged.berry_farm")
  BerryFarm.register(mod)
  BerryFarm.install(mod)

  local LevelCaps = require("mods.Kanto-Reforged.level_caps")
  LevelCaps.register(mod)
  LevelCaps.install(mod)

  local OverworldLoot = require("mods.Kanto-Reforged.overworld_loot")
  OverworldLoot.register(mod)

  local HouseNpcs = require("mods.Kanto-Reforged.house_npcs")
  HouseNpcs.resetClaims()

  local Competitive = require("mods.Kanto-Reforged.competitive_items")
  Competitive.register(mod)
  Competitive.install(mod)

  local BattleClubs = require("mods.Kanto-Reforged.battle_clubs")
  BattleClubs.register(mod)

  local JudgeNpc = require("mods.Kanto-Reforged.judge_npc")
  JudgeNpc.register(mod)

  local TradesExtra = require("mods.Kanto-Reforged.trades_extra")
  TradesExtra.register(mod)

  local BerryQuests = require("mods.Kanto-Reforged.berry_quests")
  BerryQuests.register(mod)

  local MoveHub = require("mods.Kanto-Reforged.move_hub")
  MoveHub.register(mod)

  local ItemSmith = require("mods.Kanto-Reforged.item_smith")
  ItemSmith.register(mod)

  local Roamers = require("mods.Kanto-Reforged.roamers")
  Roamers.register(mod)
  Roamers.install(mod)

  local RoamingRadar = require("mods.Kanto-Reforged.roaming_radar")
  RoamingRadar.register(mod)

  local RoamerDex = require("mods.Kanto-Reforged.roamer_dex")
  RoamerDex.install(mod)

  local LegendShrines = require("mods.Kanto-Reforged.legend_shrines")
  LegendShrines.register(mod)

  local LegendRegis = require("mods.Kanto-Reforged.legend_regis")
  LegendRegis.register(mod)

  local LegendMythicals = require("mods.Kanto-Reforged.legend_mythicals")
  LegendMythicals.register(mod)
  LegendMythicals.install(mod)

  local FossilsGen3 = require("mods.Kanto-Reforged.fossils_gen3")
  FossilsGen3.register(mod)

  ModernXpShare.install(mod)

  -- Smarter wild/trainer move scoring (prefer damage, skip no-ops)
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
  local Evolution = require("src.pokemon.Evolution")
  local original_learnEvolutionMoves = Evolution.learnEvolutionMoves
  Evolution.learnEvolutionMoves = function(game, mon, onDone)
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

  -- Wrap openParty to implement Shadow Tag / Magnet Pull switch block.
  -- openParty is always the player's party UI, so the blocker is the enemy.
  local BattleState = require("src.battle.BattleState")
  local original_openParty = BattleState.openParty
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
      -- Magnet Pull: Gen 1 Mean Look-style trap, but only vs Steel
      if ability == "MAGNET_PULL" and battlerHasType(self.player, "STEEL") then
        self:say(Strings("Cannot switch due to Magnet Pull!"))
        self.phase = "messages"
        self.afterQueue = "menu"
        return
      end
    end
    return original_openParty(self)
  end

  -- 1. Load generated databases
  local has_types, types_data = pcall(require, "mods.Kanto-Reforged.types_data")
  local has_pokemon, pokemon_data = pcall(require, "mods.Kanto-Reforged.pokemon_data")
  
  -- 2. Register Custom Types and Type Matchups
  if has_types then
    for id, record in pairs(types_data.types) do
      mod.content.type_chart:register(id, record)
      mod.log:info("Registered custom type: %s", id)
    end
    for _, row in ipairs(types_data.matchups) do
      local key = row.attacker .. ">" .. row.defender
      mod.content.type_chart:register(key, { multiplier = row.multiplier })
    end
    mod.log:info("Registered custom type effectiveness matchups")
  else
    mod.log:warn("types_data.lua not found (run generate_pokemon_mod.py first)")
  end
  
  -- 3. Register Custom Moves and Pokémon Species
  if has_pokemon then
    local moves_registered = 0
    for id, record in pairs(pokemon_data.moves) do
      mod.content.moves:register(id, record)
      moves_registered = moves_registered + 1
    end
    mod.log:info("Registered %d custom moves", moves_registered)

    local MoveAnims = require("mods.Kanto-Reforged.move_anims")
    MoveAnims.register(mod, pokemon_data.moves)
    MoveAnims.install(mod)
    
    local species_registered = 0
    local highestDex = 151
    local DexEntries = require("mods.Kanto-Reforged.dex_entries")
    local dexTexts = DexEntries.bindAll(mod, pokemon_data.species)
    for id, record in pairs(pokemon_data.species) do
      mod.content.pokemon:register(id, record)
      species_registered = species_registered + 1
      if record.dex and record.dex > highestDex then
        highestDex = record.dex
      end
    end
    mod.log:info("Registered %d custom Pokémon species", species_registered)
    if dexTexts > 0 then
      mod.log:info("Registered %d Pokédex flavor texts", dexTexts)
    end

    local SpeciesIcons = require("mods.Kanto-Reforged.species_icons")
    SpeciesIcons.register(mod, pokemon_data.species)

    -- Pokédex list is 1..constants.dexSize; vanilla import stamps 151, so
    -- Gen 2/3 numbers never appear until we extend the bound.
    mod.content.constants:patch("dexSize", highestDex)
    mod.content.constants:patch("dexDigits", math.max(3, #tostring(highestDex)))
    mod.log:info("Pokédex extended to %d", highestDex)
    
    -- Mix wild spawn distributions (curated slots, or full Gen1–3 random)
    applySpawnTables(mod, pokemon_data)

    -- Curated Gen 2/3 swaps into gyms, Elite Four, rival, and some trash
    local nTrainers = ExpTrainers.apply(mod)
    mod.log:info("Trainer parties mixed (%d classes)", nTrainers)

    -- Re-apply when the card toggle changes (restores vanilla baselines first)
    mod.events:on("mod.options_changed", function(ev)
      if ev and ev.mod == mod.id and ev.key == "full_spawn_random" then
        applySpawnTables(mod, pokemon_data)
      end
    end)

    -- Register Tyrogue custom evolution check logic
    local function checkTyrogue(mon, level, cond)
      if not mon or mon.level < level then return false end
      local att = mon.stats and mon.stats.attack or 0
      local def = mon.stats and mon.stats.defense or 0
      if cond == "atk" then return att > def
      elseif cond == "def" then return def > att
      else return att == def end
    end

    mod.content.evolution_methods:register("TYROGUE_ATK", {
      check = function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkTyrogue(mon, evo.level or 20, "atk")
      end
    })
    mod.content.evolution_methods:register("TYROGUE_DEF", {
      check = function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkTyrogue(mon, evo.level or 20, "def")
      end
    })
    mod.content.evolution_methods:register("TYROGUE_BAL", {
      check = function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkTyrogue(mon, evo.level or 20, "bal")
      end
    })

    -- Register Wurmple custom random split checking based on DVs modulo 2
    local function checkWurmple(mon, level, remainder)
      if not mon or mon.level < level then return false end
      local dvs = mon.dvs or {}
      local val = (dvs.attack or 0) + (dvs.defense or 0) + (dvs.speed or 0) + (dvs.special or 0)
      return val % 2 == remainder
    end

    mod.content.evolution_methods:register("WURMPLE_A", {
      check = function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkWurmple(mon, evo.level or 7, 0)
      end
    })
    mod.content.evolution_methods:register("WURMPLE_B", {
      check = function(game, mon, evo, trigger)
        return trigger.kind == "levelup" and checkWurmple(mon, evo.level or 7, 1)
      end
    })

    -- Patch vanilla Kanto species evolutions
    if pokemon_data.evolutions then
      local evos_patched = 0
      for speciesId, new_evos in pairs(pokemon_data.evolutions) do
        local existing = mod.content.pokemon:get(speciesId)
        if existing then
          local evos = {}
          if existing.evolutions then
            for _, evo in ipairs(existing.evolutions) do
              table.insert(evos, { method = evo.method, level = evo.level, item = evo.item, species = evo.species })
            end
          end
          local seen = {}
          for _, evo in ipairs(evos) do
            seen[evo.species] = true
          end
          for _, evo in ipairs(new_evos) do
            if not seen[evo.species] then
              table.insert(evos, evo)
              seen[evo.species] = true
            end
          end
          mod.content.pokemon:patch(speciesId, { evolutions = evos })
          evos_patched = evos_patched + 1
        end
      end
      mod.log:info("Patched evolutions for %d vanilla Pokémon species", evos_patched)
    end

    -- Patch Gen 1 species with Gen 2/3 level-up + TM learnset additions.
    -- Wild/trainer/gym parties all build moves via Pokemon.movesAtLevel, so
    -- this is what makes Charmander know Metal Claw, etc.
    local okPatches, learnset_patches = pcall(require, "mods.Kanto-Reforged.learnset_patches")
    if okPatches and learnset_patches then
      local function mergeLearnset(existing, additions)
        local byMove = {}
        local out = {}
        for _, entry in ipairs(existing or {}) do
          local copy = { level = entry.level, move = entry.move }
          out[#out + 1] = copy
          byMove[entry.move] = copy
        end
        for _, entry in ipairs(additions or {}) do
          local prev = byMove[entry.move]
          if prev then
            if entry.level < prev.level then
              prev.level = entry.level
            end
          else
            local copy = { level = entry.level, move = entry.move }
            out[#out + 1] = copy
            byMove[entry.move] = copy
          end
        end
        table.sort(out, function(a, b)
          if a.level == b.level then return a.move < b.move end
          return a.level < b.level
        end)
        return out
      end

      local function mergeTmhm(existing, additions)
        local seen = {}
        local out = {}
        for _, mv in ipairs(existing or {}) do
          if not seen[mv] then
            out[#out + 1] = mv
            seen[mv] = true
          end
        end
        for _, mv in ipairs(additions or {}) do
          if not seen[mv] then
            out[#out + 1] = mv
            seen[mv] = true
          end
        end
        table.sort(out)
        return out
      end

      local nLearn, nTm = 0, 0
      local speciesSeen = {}
      if learnset_patches.learnset then
        for speciesId, additions in pairs(learnset_patches.learnset) do
          local existing = mod.content.pokemon:get(speciesId)
          if existing then
            mod.content.pokemon:patch(speciesId, {
              learnset = mergeLearnset(existing.learnset, additions),
            })
            nLearn = nLearn + 1
            speciesSeen[speciesId] = true
          end
        end
      end
      if learnset_patches.tmhm then
        for speciesId, additions in pairs(learnset_patches.tmhm) do
          local existing = mod.content.pokemon:get(speciesId)
          if existing then
            -- Re-read after possible learnset patch above
            existing = mod.content.pokemon:get(speciesId)
            mod.content.pokemon:patch(speciesId, {
              tmhm = mergeTmhm(existing.tmhm, additions),
            })
            nTm = nTm + 1
            speciesSeen[speciesId] = true
          end
        end
      end
      local nSpecies = 0
      for _ in pairs(speciesSeen) do nSpecies = nSpecies + 1 end
      mod.log:info(
        "Patched Gen 2/3 moves onto %d Kanto species (%d learnsets, %d tmhm)",
        nSpecies, nLearn, nTm
      )
    else
      mod.log:warn("learnset_patches.lua missing; Kanto Gen 2/3 move backports skipped")
    end

    -- Gen 3 abilities for vanilla Kanto species (Bulbasaur OVERGROW, etc.)
    local okAbil, ability_patches = pcall(require, "mods.Kanto-Reforged.ability_patches")
    if okAbil and ability_patches and ability_patches.abilities then
      local nAbil = 0
      for speciesId, ability in pairs(ability_patches.abilities) do
        if ability and ability ~= "NONE" then
          mod.content.pokemon:patch(speciesId, { ability = ability })
          nAbil = nAbil + 1
        end
      end
      mod.log:info("Patched Gen 3 abilities onto %d Kanto species", nAbil)
    else
      mod.log:warn("ability_patches.lua missing; Kanto abilities skipped")
    end

    -- Gender rates (PokéAPI female eighths; -1 = genderless)
    local okGender, gender_patches = pcall(require, "mods.Kanto-Reforged.gender_patches")
    if okGender and gender_patches and gender_patches.rates then
      local nGender = 0
      for speciesId, rate in pairs(gender_patches.rates) do
        if type(rate) == "number" then
          mod.content.pokemon:patch(speciesId, { genderRate = rate })
          nGender = nGender + 1
        end
      end
      -- Form ids that do not match PokéAPI species names
      if type(gender_patches.rates.DEOXYS) == "number" then
        mod.content.pokemon:patch("DEOXYS_NORMAL", {
          genderRate = gender_patches.rates.DEOXYS,
        })
      end
      mod.log:info("Patched genderRate onto %d species", nGender)
    else
      mod.log:warn("gender_patches.lua missing; gender rates skipped")
    end

    -- Breeding: egg groups, hatch counters, baby species, egg moves
    local okBreed, breeding_patches = pcall(require, "mods.Kanto-Reforged.breeding_patches")
    if okBreed and breeding_patches then
      local nBreed = Breeding.applyPatches(mod, breeding_patches)
      mod.log:info("Patched breeding data onto %d species", nBreed)
    else
      mod.log:warn("breeding_patches.lua missing; daycare breeding skipped")
    end
  else
    mod.log:warn("pokemon_data.lua not found or failed to load: " .. tostring(pokemon_data))
  end

  local SummaryUi = require("mods.Kanto-Reforged.summary_ui")
  SummaryUi.register(mod)

  local DexNav = require("mods.Kanto-Reforged.dexnav")
  DexNav.register(mod)

  local BagPockets = require("mods.Kanto-Reforged.bag_pockets")
  BagPockets.register(mod)
  
  -- 4. Hook into battle damage pipeline (SpA/SpD + abilities +
  --    variable-power Gen 2/3 moves)
  mod.hooks:wrap("battle.damage", function(next, ctx)
    local move = ctx.move
    local user = ctx.user
    local target = ctx.target
    local TypeChart = require("src.battle.TypeChart")

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
    elseif move and move.id == "FACADE" and user.mon.status then
      bumpPower((move.power or 70) * 2)
    elseif move and (move.id == "ERUPTION" or move.id == "WATER_SPOUT") then
      bumpPower(math.max(1, math.floor((move.power or 150) * user.mon.hp / user.mon.stats.hp)))
    elseif move and (move.id == "FLAIL" or move.id == "REVERSAL") then
      bumpPower(ExpMoveEffects.flailPower(user))
    elseif move and move.id == "RETURN" then
      bumpPower(ExpMoveEffects.returnPower(user))
    elseif move and move.id == "FRUSTRATION" then
      bumpPower(ExpMoveEffects.frustrationPower(user))
    elseif move and move.id == "HEX" and target.mon.status then
      bumpPower((move.power or 65) * 2)
    elseif move and move.id == "VENOSHOCK" and target.mon.status == "PSN" then
      bumpPower((move.power or 65) * 2)
    elseif move and move.id == "BRINE" and target.mon.hp * 2 <= target.mon.stats.hp then
      bumpPower((move.power or 65) * 2)
    elseif move and (move.id == "REVENGE" or move.id == "AVALANCHE")
        and user.expTookDamageThisTurn then
      bumpPower((move.power or 60) * 2)
    elseif move and move.id == "PAYBACK" and target.expActedThisTurn then
      bumpPower((move.power or 50) * 2)
    elseif move and move.id == "PURSUIT" and target.expActedThisTurn then
      bumpPower((move.power or 40) * 2)
    elseif move and move.id == "KNOCK_OFF" and HeldItems.ofBattler(target) then
      bumpPower(math.floor((move.power or 65) * 1.5))
    elseif move and move.id == "FURY_CUTTER" then
      local n = user.expFuryCutter or 0
      bumpPower((move.power or 40) * (2 ^ math.min(n, 4)))
    elseif move and move.id == "MAGNITUDE" then
      local p = ExpMoveEffects.magnitudePower(ctx.battle.rng or love.math.random)
      bumpPower(p)
    elseif move and move.id == "SMELLING_SALTS" and target.mon.status == "PAR" then
      bumpPower((move.power or 70) * 2)
    elseif move and (move.id == "ROLLOUT" or move.id == "ICE_BALL") then
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
      local hasGhost = false
      for _, t in ipairs(target.curTypes or {}) do
        if t == "GHOST" then hasGhost = true break end
      end
      if hasGhost then
        oldTypes = target.curTypes
        local nt = {}
        for _, t in ipairs(oldTypes) do
          if t ~= "GHOST" then nt[#nt + 1] = t end
        end
        if #nt == 0 then nt = { "NORMAL" } end
        target.curTypes = nt
      end
    end

    local function finish(damage, info)
      -- Type boosters must see the effective move type (Hidden Power /
      -- Weather Ball mutate move.type before damage, then restore it).
      damage = HeldItems.modifyDamage(damage, ctx)
      if oldPower ~= nil then
        move.type, move.power, move.category = oldType, oldPower, oldCategory
      end
      if oldTypes then target.curTypes = oldTypes end
      -- Mirror Coat tracks special damage taken this hit
      local category = move.category or TypeChart.category(move.type) or "physical"
      if category == "special" and damage and damage > 0 then
        ctx.battle.expLastSpecialDamage = damage
      end
      return damage, info
    end

    local category = move.category or TypeChart.category(move.type) or "physical"
    local isSpecial = category == "special"

    if isSpecial then
      local oldUserSpecial = user.curStats.special
      local oldTargetSpecial = target.curStats.special

      user.curStats.special = getSpecialStat(user, true)
      target.curStats.special = getSpecialStat(target, false)

      local damage, info = Abilities.onDamage(next, ctx)

      user.curStats.special = oldUserSpecial
      target.curStats.special = oldTargetSpecial

      if damage and damage > 0 then
        Abilities.onPostDamage(ctx.battle, user, target, move, damage)
      end
      return finish(damage, info)
    else
      local damage, info = Abilities.onDamage(next, ctx)
      if damage and damage > 0 then
        Abilities.onPostDamage(ctx.battle, user, target, move, damage)
      end
      return finish(damage, info)
    end
  end)

  -- Hustle accuracy cut / Compound Eyes boost / Sand Veil / Lock-On / Foresight
  mod.hooks:wrap("battle.accuracy", function(next, ctx)
    if ctx.target and ctx.target.expProtected then
      return false
    end
    -- Lock-On / Mind Reader: next move against the marked target never misses
    if ctx.target and ctx.target.expLockedOn then
      ctx.target.expLockedOn = nil
      return true
    end

    local userAbility = Abilities.abilityOf(ctx.battle, ctx.user)
    local oldAcc
    if userAbility == "COMPOUND_EYES" and ctx.move and ctx.move.accuracy then
      oldAcc = ctx.move.accuracy
      ctx.move.accuracy = math.min(100, math.floor(oldAcc * 13 / 10))
    end

    -- Foresight: ignore positive evasion stages
    local oldEvasion
    if ctx.target and ctx.target.expIdentified and ctx.target.stages then
      oldEvasion = ctx.target.stages.evasion
      if (oldEvasion or 0) > 0 then
        ctx.target.stages.evasion = 0
      else
        oldEvasion = nil
      end
    end

    local hit = next(ctx)
    if oldAcc then ctx.move.accuracy = oldAcc end
    if oldEvasion ~= nil then ctx.target.stages.evasion = oldEvasion end
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
    if targetAbility == "SAND_VEIL" and ctx.battle.field
        and ctx.battle.field.weather == "SANDSTORM" then
      if (ctx.battle.rng or love.math.random)(0, 99) < 20 then
        return false
      end
    end
    return hit
  end)

  -- Battle Armor / Shell Armor / Lucky Chant: never crit
  mod.hooks:wrap("battle.crit", function(next, ctx)
    local battle = mod.activeBattle or ctx.battle
    if battle and ctx.attacker then
      local target = (ctx.attacker == battle.player) and battle.enemy or battle.player
      local ability = Abilities.abilityOf(battle, target)
      if ability == "BATTLE_ARMOR" or ability == "SHELL_ARMOR" then
        return false
      end
      local side = battle.sideOf and battle:sideOf(target)
      if side and side.expLuckyChantTurns and side.expLuckyChantTurns > 0 then
        return false
      end
    end
    return next(ctx)
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
    local TurnOrder = require("src.battle.TurnOrder")
    local ma, mb = Abilities.speedMult(battle, a), Abilities.speedMult(battle, b)
    local trick = battle.expTrickRoomTurns and battle.expTrickRoomTurns > 0
    if ma == 1 and mb == 1 and not trick then
      return next(a, aMove, b, bMove, ctx)
    end
    local oldA, oldB = a.curStats.speed, b.curStats.speed
    a.curStats.speed = math.floor(oldA * ma)
    b.curStats.speed = math.floor(oldB * mb)
    local first = TurnOrder.firstMover(a, aMove, b, bMove,
      (ctx and ctx.rng) or love.math.random, ctx and ctx.invertTie)
    a.curStats.speed, b.curStats.speed = oldA, oldB
    if trick then
      -- Invert: the slower one moves first
      return not first
    end
    return first
  end)

  -- Shadow Tag / Magnet Pull / Mean Look escape blocker; Run Away always escapes wilds
  mod.hooks:wrap("battle.run", function(next, ctx)
    local battle = ctx.battle or ctx
    local playerAbility = Abilities.abilityOf(battle, battle.player)
    if playerAbility == "RUN_AWAY" and battle.kind == "wild" then
      return true
    end
    if battle.player and battle.player.expTrapped
        and not battlerHasType(battle.player, "GHOST") then
      battle:sayNext(Strings("Cannot escape!"))
      return false
    end
    local opponent = battle.enemy
    if opponent and opponent.mon and opponent.mon.hp and opponent.mon.hp > 0 then
      local oppDef = battle.data.pokemon[opponent.mon.species]
      local ability = oppDef and oppDef.ability
      if ability == "SHADOW_TAG" and not battlerHasType(battle.player, "GHOST") then
        battle:sayNext(Strings("Cannot escape due to Shadow Tag!"))
        return false
      end
      if ability == "MAGNET_PULL" and battlerHasType(battle.player, "STEEL") then
        battle:sayNext(Strings("Cannot escape due to Magnet Pull!"))
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
      local Game = package.loaded["src.core.Game"]
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

  -- Castform Weather Forms Sprite Resolver Hook
  mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
    if ctx.species == "CASTFORM" and mod.activeBattle then
      local weather = mod.activeBattle.field.weather
      if weather == "SUNNY" or weather == "RAINY" or weather == "HAIL" or weather == "SNOWY" then
        local suffix = weather == "SUNNY" and "sunny" or (weather == "RAINY" and "rainy" or "snowy")
        return mod.path .. "/assets/castform_" .. suffix .. "_" .. ctx.side .. ".png"
      end
    end
    return next(path, ctx)
  end)

  -- 5. Hook battle entry, turns, and moves
  mod.events:on("game.ready", function(ev)
    if ev.game then
      mod.activeGame = ev.game
    end
  end)

  mod.events:on("battle.started", function(ev)
    if ev.battle then
      mod.activeBattle = ev.battle
      Abilities.onEntry(ev.battle, ev.battle.player)
      Abilities.onEntry(ev.battle, ev.battle.enemy)
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
    mod.activeBattle = nil
  end)
  
  mod.events:on("battle.battler_switched", function(ev)
    if ev.battle and ev.battler then
      Abilities.onEntry(ev.battle, ev.battler)
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
    -- Tick weather duration
    local field = ev.battle.field
    if field and field.weather and field.weatherTurns then
      field.weatherTurns = field.weatherTurns - 1
      if field.weatherTurns <= 0 then
        field.weather = nil
        field.weatherTurns = nil
      end
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
    end
  end)

  mod.events:on("battle.turn_ended", function(ev)
    if not ev.battle then return end
    Abilities.onTurnEnded(ev.battle, ev.battle.player)
    Abilities.onTurnEnded(ev.battle, ev.battle.enemy)
  end)

  -- Nincada → Ninjask leaves a Shedinja behind when a Poké Ball is
  -- consumed (Gen 3 split evolution). Inventory is id→count, not a list.
  mod.events:on("pokemon.evolved", function(ev)
    if ev.fromSpecies ~= "NINCADA" or ev.toSpecies ~= "NINJASK" then
      return
    end
    local game = ev.game or mod.activeGame
    if not game or not game.save then return end

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
    local shedinja = Pokemon.new(game.data, "SHEDINJA", ev.mon.level)
    shedinja.dvs = Merge.deepCopy(ev.mon.dvs)
    shedinja.statExp = Merge.deepCopy(ev.mon.statExp or {})
    shedinja.stats = Stats.calc(game.data.pokemon.SHEDINJA, shedinja.level,
                                shedinja.dvs, shedinja.statExp)
    shedinja.hp = 1

    local function announce(msg)
      if mod.activeBattle and mod.activeBattle.sayNext then
        mod.activeBattle:sayNext(Strings(msg))
      elseif game.stack then
        local TextBox = require("src.render.TextBox")
        game.stack:push(TextBox.new(game, Strings(msg), function() end))
      end
    end

    if #game.save.party < 6 then
      table.insert(game.save.party, shedinja)
      announce("A SHEDINJA appeared\nin the party!")
    else
      local Boxes = require("src.pokemon.Boxes")
      local boxNum = Boxes.deposit(game.save, shedinja)
      if boxNum then
        local pc = (game.save.flags and game.save.flags.EVENT_MET_BILL)
                   and "BILL's PC" or "someone's PC"
        announce(string.format("SHEDINJA was\ntransferred to\n%s!", pc))
      else
        announce("Every BOX is full!\nSHEDINJA escaped!")
      end
    end
  end)
  
  mod.log:info("Kanto Reforged mod successfully initialized!")
end
