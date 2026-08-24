-- Gen 2 / Gold infrastructure so Gen 3 KR content can register and resolve.
-- Real Gold ROM caches already seed most of this; headless / incomplete boots
-- and Gen1-shaped KR records still need these bridges (mod-only, no engine edits).

local Gen2Compat = {}

-- Gen1 pokemon_data / KR use LEVEL|ITEM|TRADE; Gold's registry is EVOLVE_*.
Gen2Compat.EVO_METHOD = {
  LEVEL = "EVOLVE_LEVEL",
  ITEM = "EVOLVE_ITEM",
  TRADE = "EVOLVE_TRADE",
  HAPPINESS = "EVOLVE_HAPPINESS",
  FRIENDSHIP = "EVOLVE_HAPPINESS",
  STAT = "EVOLVE_STAT",
}

-- Closest Gold effect ids for common Gen1 effect names (battle dispatch).
-- Unmapped names get a no-run stub so refs validate; Battle falls through to
-- ordinary damage when `run` is absent.
-- Prefer real Gold natives over EFFECT_NORMAL_HIT — that path used to strip
-- flinch / drain / recoil / multi-hit / stat drops on newly registered KR moves.
local EFFECT_MAP = {
  NO_ADDITIONAL_EFFECT = "EFFECT_NORMAL_HIT",
  BURN_SIDE_EFFECT1 = "EFFECT_BURN_HIT",
  BURN_SIDE_EFFECT2 = "EFFECT_BURN_HIT",
  PARALYZE_SIDE_EFFECT1 = "EFFECT_PARALYZE_HIT",
  PARALYZE_SIDE_EFFECT2 = "EFFECT_PARALYZE_HIT",
  POISON_SIDE_EFFECT1 = "EFFECT_POISON_HIT",
  POISON_SIDE_EFFECT2 = "EFFECT_POISON_HIT",
  POISON_EFFECT = "EFFECT_POISON",
  FREEZE_SIDE_EFFECT1 = "EFFECT_FREEZE_HIT",
  FREEZE_SIDE_EFFECT2 = "EFFECT_FREEZE_HIT",
  SLEEP_EFFECT = "EFFECT_SLEEP",
  CONFUSION_EFFECT = "EFFECT_CONFUSE",
  CONFUSION_SIDE_EFFECT = "EFFECT_CONFUSE_HIT",
  TOXIC_EFFECT = "EFFECT_TOXIC",
  DRAIN_HP_EFFECT = "EFFECT_LEECH_HIT",
  RECOIL_EFFECT = "EFFECT_RECOIL_HIT",
  HEAL_EFFECT = "EFFECT_HEAL",
  FLINCH_SIDE_EFFECT1 = "EFFECT_FLINCH_HIT",
  FLINCH_SIDE_EFFECT2 = "EFFECT_FLINCH_HIT",
  TWO_TO_FIVE_ATTACKS_EFFECT = "EFFECT_MULTI_HIT",
  ATTACK_TWICE_EFFECT = "EFFECT_DOUBLE_HIT",
  HYPER_BEAM_EFFECT = "EFFECT_HYPER_BEAM",
  SWIFT_EFFECT = "EFFECT_ALWAYS_HIT",
  FLY_EFFECT = "EFFECT_FLY",
  TRAPPING_EFFECT = "EFFECT_TRAP_TARGET",
  SPECIAL_DOWN_SIDE_EFFECT = "EFFECT_SP_DEF_DOWN_HIT",
  DEFENSE_DOWN_SIDE_EFFECT = "EFFECT_DEFENSE_DOWN_HIT",
  ATTACK_DOWN_SIDE_EFFECT = "EFFECT_ATTACK_DOWN_HIT",
  SPEED_DOWN_SIDE_EFFECT = "EFFECT_SPEED_DOWN_HIT",
  ATTACK_DOWN1_EFFECT = "EFFECT_ATTACK_DOWN",
  SPEED_DOWN1_EFFECT = "EFFECT_SPEED_DOWN",
  ACCURACY_DOWN1_EFFECT = "EFFECT_ACCURACY_DOWN",
  ACCURACY_DOWN2_EFFECT = "EFFECT_ACCURACY_DOWN_2",
  DEFENSE_UP1_EFFECT = "EFFECT_DEFENSE_UP",
  DEFENSE_UP2_EFFECT = "EFFECT_DEFENSE_UP_2",
  ATTACK_UP1_EFFECT = "EFFECT_ATTACK_UP",
  SPEED_UP2_EFFECT = "EFFECT_SPEED_UP_2",
  SPECIAL_UP2_EFFECT = "EFFECT_SP_ATK_UP_2",
  OHKO_EFFECT = "EFFECT_OHKO",
  THRASH_PETAL_DANCE_EFFECT = "EFFECT_RAMPAGE",
  REFLECT_EFFECT = "EFFECT_REFLECT",
  LIGHT_SCREEN_EFFECT = "EFFECT_LIGHT_SCREEN",
  MIST_EFFECT = "EFFECT_MIST",
  SAFEGUARD_EFFECT = "EFFECT_SAFEGUARD",
  FOCUS_ENERGY_EFFECT = "EFFECT_FOCUS_ENERGY",
  SUBSTITUTE_EFFECT = "EFFECT_SUBSTITUTE",
  LEECH_SEED_EFFECT = "EFFECT_LEECH_SEED",
  DISABLE_EFFECT = "EFFECT_DISABLE",
  HAZE_EFFECT = "EFFECT_RESET_STATS",
  BIDE_EFFECT = "EFFECT_BIDE",
  METRONOME_EFFECT = "EFFECT_METRONOME",
  MIRROR_MOVE_EFFECT = "EFFECT_MIRROR_MOVE",
  EXPLOSION_EFFECT = "EFFECT_SELFDESTRUCT",
  RAGE_EFFECT = "EFFECT_RAGE",
  CONVERSION_EFFECT = "EFFECT_CONVERSION",
  TRANSFORM_EFFECT = "EFFECT_TRANSFORM",
  SPLASH_EFFECT = "EFFECT_SPLASH",
  TELEPORT_EFFECT = "EFFECT_TELEPORT",
  REST_EFFECT = "EFFECT_HEAL",
  COUNTER_EFFECT = "EFFECT_COUNTER",
  MIRROR_COAT_EFFECT = "EFFECT_MIRROR_COAT",
  PROTECT_EFFECT = "EFFECT_PROTECT",
  ENDURE_EFFECT = "EFFECT_ENDURE",
  DESTINY_BOND_EFFECT = "EFFECT_DESTINY_BOND",
  SPITE_EFFECT = "EFFECT_SPITE",
  ENCORE_EFFECT = "EFFECT_ENCORE",
  CURSE_EFFECT = "EFFECT_CURSE",
  BELLY_DRUM_EFFECT = "EFFECT_BELLY_DRUM",
  SPIKES_EFFECT = "EFFECT_SPIKES",
  MEAN_LOOK_EFFECT = "EFFECT_MEAN_LOOK",
  NIGHTMARE_EFFECT = "EFFECT_NIGHTMARE",
  HEAL_BELL_EFFECT = "EFFECT_HEAL_BELL",
  PAIN_SPLIT_EFFECT = "EFFECT_PAIN_SPLIT",
  SKETCH_EFFECT = "EFFECT_SKETCH",
  TRIPLE_KICK_EFFECT = "EFFECT_TRIPLE_KICK",
  THIEF_EFFECT = "EFFECT_THIEF",
  MIND_READER_EFFECT = "EFFECT_LOCK_ON",
  SNORE_EFFECT = "EFFECT_SNORE",
  FLAIL_EFFECT = "EFFECT_REVERSAL",
  REVERSAL_EFFECT = "EFFECT_REVERSAL",
  CONVERSION2_EFFECT = "EFFECT_CONVERSION2",
  FORESIGHT_EFFECT = "EFFECT_FORESIGHT",
  PERISH_SONG_EFFECT = "EFFECT_PERISH_SONG",
  SANDSTORM_EFFECT = "EFFECT_SANDSTORM",
  GIGA_DRAIN_EFFECT = "EFFECT_LEECH_HIT",
  ROLLOUT_EFFECT = "EFFECT_ROLLOUT",
  SWAGGER_EFFECT = "EFFECT_SWAGGER",
  FURY_CUTTER_EFFECT = "EFFECT_FURY_CUTTER",
  ATTRACT_EFFECT = "EFFECT_ATTRACT",
  SLEEP_TALK_EFFECT = "EFFECT_SLEEP_TALK",
  RETURN_EFFECT = "EFFECT_RETURN",
  PRESENT_EFFECT = "EFFECT_PRESENT",
  FRUSTRATION_EFFECT = "EFFECT_FRUSTRATION",
  BATON_PASS_EFFECT = "EFFECT_BATON_PASS",
  PURSUIT_EFFECT = "EFFECT_PURSUIT",
  RAPID_SPIN_EFFECT = "EFFECT_RAPID_SPIN",
  MORNING_SUN_EFFECT = "EFFECT_MORNING_SUN",
  SYNTHESIS_EFFECT = "EFFECT_SYNTHESIS",
  MOONLIGHT_EFFECT = "EFFECT_MOONLIGHT",
  HIDDEN_POWER_EFFECT = "EFFECT_HIDDEN_POWER",
  RAIN_DANCE_EFFECT = "EFFECT_RAIN_DANCE",
  SUNNY_DAY_EFFECT = "EFFECT_SUNNY_DAY",
  FUTURE_SIGHT_EFFECT = "EFFECT_FUTURE_SIGHT",
  BEAT_UP_EFFECT = "EFFECT_BEAT_UP",
  MAGNITUDE_EFFECT = "EFFECT_MAGNITUDE",
  -- Prefer Gold natives for weather when present; EXP_* still registered with
  -- BattleCompat.run handlers for Hail / Forecast sync.
  EXP_WEATHER_SUNNY = "EFFECT_SUNNY_DAY",
  EXP_WEATHER_RAINY = "EFFECT_RAIN_DANCE",
  EXP_WEATHER_SANDSTORM = "EFFECT_SANDSTORM",
  EXP_PROTECT_EFFECT = "EFFECT_PROTECT",
  EXP_ENDURE_EFFECT = "EFFECT_ENDURE",
  EXP_ENCORE_EFFECT = "EFFECT_ENCORE",
  EXP_BELLY_DRUM_EFFECT = "EFFECT_BELLY_DRUM",
  EXP_ATTRACT_EFFECT = "EFFECT_ATTRACT",
  EXP_PERISH_SONG_EFFECT = "EFFECT_PERISH_SONG",
  -- Gold natives that already implement the KR EXP effect.
  EXP_CURSE_EFFECT = "EFFECT_CURSE",
  EXP_FALSE_SWIPE_EFFECT = "EFFECT_FALSE_SWIPE",
  EXP_FUTURE_SIGHT_EFFECT = "EFFECT_FUTURE_SIGHT",
  EXP_BATON_PASS_EFFECT = "EFFECT_BATON_PASS",
  EXP_MIRROR_COAT_EFFECT = "EFFECT_MIRROR_COAT",
  EXP_ROLLOUT_EFFECT = "EFFECT_ROLLOUT",
  EXP_FURY_CUTTER_EFFECT = "EFFECT_FURY_CUTTER",
  EXP_SPITE_EFFECT = "EFFECT_SPITE",
}

-- Per-move effect overrides (Gen2 registration only). Used when the KR move
-- table still says NO_ADDITIONAL_EFFECT but we have a Gen2 runner.
Gen2Compat.MOVE_EFFECT_OVERRIDE = {
  EMBARGO = "EXP_EMBARGO_EFFECT",
  HEAL_BLOCK = "EXP_HEAL_BLOCK_EFFECT",
  WAKE_UP_SLAP = "EXP_WAKE_UP_SLAP_EFFECT",
}

function Gen2Compat.effectForMove(moveId, effect)
  return Gen2Compat.MOVE_EFFECT_OVERRIDE[moveId]
    or Gen2Compat.remapMoveEffect(effect)
end

local function ensureEffect(mod, id, record)
  if not id or mod.content.move_effects:get(id) then return false end
  local ok = pcall(function()
    mod.content.move_effects:register(id, record or { kind = "primary" })
  end)
  return ok
end

local function seedGrowth(mod)
  local Growth = require("src.pokemon.Growth")
  local n = 0
  for id, curve in pairs(Growth.CURVES) do
    if not mod.content.growth_rates:get(id) then
      local ok = pcall(function()
        mod.content.growth_rates:register(id, {
          expForLevel = function(level)
            return math.max(0, curve(level))
          end,
        })
      end)
      if ok then n = n + 1 end
    end
  end

  -- Gen 3 curves Gold's cart never had; required for some Hoenn species.
  if not mod.content.growth_rates:get("ERRATIC") then
    pcall(function()
      mod.content.growth_rates:register("ERRATIC", {
        expForLevel = function(n)
          if n < 50 then
            return math.floor(n * n * n * (100 - n) / 50)
          elseif n < 68 then
            return math.floor(n * n * n * (150 - n) / 100)
          elseif n < 98 then
            return math.floor(n * n * n * math.floor((1911 - 10 * n) / 3) / 500)
          end
          return math.floor(n * n * n * (160 - n) / 100)
        end,
      })
      n = n + 1
    end)
  end
  if not mod.content.growth_rates:get("FLUCTUATING") then
    pcall(function()
      mod.content.growth_rates:register("FLUCTUATING", {
        expForLevel = function(n)
          if n < 15 then
            return math.floor(n * n * n * (math.floor((n + 1) / 3) + 24) / 50)
          elseif n < 36 then
            return math.floor(n * n * n * (n + 14) / 50)
          end
          return math.floor(n * n * n * (math.floor(n / 2) + 32) / 50)
        end,
      })
      n = n + 1
    end)
  end
  return n
end

local function seedEvoAliases(mod)
  -- Prefer Gold's own EVOLVE_* records when Builtins seeded them; otherwise
  -- install minimal checks, then alias Gen1 names onto the same handlers.
  local Evolution = require("src.core.gen2.Evolution")
  local n = 0
  for id, record in pairs(Evolution.METHODS) do
    if not mod.content.evolution_methods:get(id) then
      local ok = pcall(function()
        mod.content.evolution_methods:register(id, record)
      end)
      if ok then n = n + 1 end
    end
  end
  for gen1, gen2 in pairs(Gen2Compat.EVO_METHOD) do
    if not mod.content.evolution_methods:get(gen1) then
      local src = mod.content.evolution_methods:get(gen2)
      if src then
        local ok = pcall(function()
          mod.content.evolution_methods:register(gen1, {
            check = src.check,
            requiresLink = src.requiresLink,
            requiresForce = src.requiresForce,
          })
        end)
        if ok then n = n + 1 end
      end
    end
  end
  return n
end

--- Map a KR / Gen1 effect id to a Gold battle effect when possible.
function Gen2Compat.remapMoveEffect(effect)
  if not effect then return effect end
  local mapped = EFFECT_MAP[effect]
  if mapped then
    -- EFFECT_NORMAL_HIT is not a Gold builtin; keep a stub under that name
    -- or fall through with no-run under the Gen1 name.
    if mapped == "EFFECT_NORMAL_HIT" then
      return effect -- stubbed as no-run primary below
    end
    return mapped
  end
  return effect
end

--- Map a KR / Gen1 evolution method id to Gold's EVOLVE_* id.
function Gen2Compat.remapEvoMethod(method)
  if not method then return method end
  return Gen2Compat.EVO_METHOD[method] or method
end

function Gen2Compat.seedMoveEffectStubs(mod, pokemon_data)
  local n = 0
  -- Ensure mapped Gold targets exist (no-op when Builtins already seeded them).
  for _, gen2Id in pairs(EFFECT_MAP) do
    if gen2Id ~= "EFFECT_NORMAL_HIT" then
      if ensureEffect(mod, gen2Id, { kind = "primary" }) then n = n + 1 end
    end
  end
  -- Every effect string KR moves name must exist for cross-ref validation.
  for _, move in pairs((pokemon_data and pokemon_data.moves) or {}) do
    local eff = move.effect
    if eff then
      local target = Gen2Compat.remapMoveEffect(eff)
      if ensureEffect(mod, target, { kind = "primary" }) then n = n + 1 end
      if target ~= eff and ensureEffect(mod, eff, { kind = "primary" }) then
        n = n + 1
      end
    end
  end
  -- Common Gen1 vanilla names even if not in KR move table yet.
  for gen1, _ in pairs(EFFECT_MAP) do
    if ensureEffect(mod, gen1, { kind = "primary" }) then n = n + 1 end
  end
  return n
end

--- Ensure a tileset id exists on Gen2 so custom maps can register without a
-- Gold ROM cache (graphics may be Gen1 stand-ins until Gold is imported).
function Gen2Compat.ensureTileset(mod, preferredId)
  if preferredId and mod.content.tilesets:get(preferredId) then
    return preferredId
  end
  for _, id in ipairs({ preferredId, "TILESET_JOHTO", "TILESET_KANTO", "OVERWORLD" }) do
    if id and mod.content.tilesets:get(id) then return id end
  end

  local Data = require("src.core.Data")
  local src = (Data.tilesets and (Data.tilesets.OVERWORLD or Data.tilesets.CAVERN))
    or nil
  if not src or type(src.blocks) ~= "table" then
    return preferredId or "TILESET_JOHTO"
  end

  local id = preferredId or "TILESET_JOHTO"
  local copy = {
    id = id,
    image = src.image,
    imageWidth = src.imageWidth,
    imageHeight = src.imageHeight,
    tilesPerRow = src.tilesPerRow,
    blocks = src.blocks,
    walkable = src.walkable,
    counterTiles = src.counterTiles,
    doorTiles = src.doorTiles,
    warpTiles = src.warpTiles,
    animation = src.animation,
    trueColor = src.trueColor,
  }
  pcall(function()
    mod.content.tilesets:register(id, copy)
  end)
  if mod.content.tilesets:get(id) then return id end
  return id
end

--- Call once on Gen2 before registering KR moves / Hoenn species.
function Gen2Compat.seedInfra(mod, pokemon_data)
  local g = seedGrowth(mod)
  local e = seedEvoAliases(mod)
  local m = Gen2Compat.seedMoveEffectStubs(mod, pokemon_data)
  Gen2Compat.ensureTileset(mod, "TILESET_JOHTO")
  mod.log:info(
    "Gen2 compat infra: %d growth rates, %d evo methods/aliases, %d move-effect stubs",
    g, e, m
  )
  return g, e, m
end

--- True when Gen2 ROM cache seeded move_effects / Dark type (full import).
function Gen2Compat.gen2DataReady(mod)
  local dark = mod.content.type_chart:get("DARK")
  local sample = mod.content.move_effects:get("EFFECT_BURN")
    or mod.content.move_effects:get("NO_ADDITIONAL_EFFECT")
  return dark ~= nil and sample ~= nil
end

-- Compat alias for older call sites / tests.
Gen2Compat.goldDataReady = Gen2Compat.gen2DataReady

return Gen2Compat
