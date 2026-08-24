-- Machine-readable battle mechanics parity matrix (Phase 0).
-- Used by tests/parity_matrix_test.lua to guard completeness.

local Parity = {}

Parity.GEN1_ONLY = {
  "EXP_ATTRACT_EFFECT",
  "EXP_BATON_PASS_EFFECT",
  "EXP_BELLY_DRUM_EFFECT",
  "EXP_CURSE_EFFECT",
  "EXP_ENCORE_EFFECT",
  "EXP_ENDURE_EFFECT",
  "EXP_FURY_CUTTER_EFFECT",
  "EXP_FUTURE_SIGHT_EFFECT",
  "EXP_MIRROR_COAT_EFFECT",
  "EXP_PERISH_SONG_EFFECT",
  "EXP_PROTECT_EFFECT",
  "EXP_ROLLOUT_EFFECT",
  "EXP_SPITE_EFFECT",
  "EXP_VARIABLE_POWER_EFFECT",
  "EXP_WEATHER_HAIL",
  "EXP_WEATHER_RAINY",
  "EXP_WEATHER_SANDSTORM",
  "EXP_WEATHER_SUNNY",
}

Parity.GEN2_ONLY = {
  "EXP_WAKE_UP_SLAP_EFFECT",
}

Parity.SEMANTIC_MISMATCH = {
  EXP_BURN_EFFECT = { "substitute_guard", "status_id" },
  EXP_BRICK_BREAK_EFFECT = { "screen_target" },
  EXP_ENDEAVOR_EFFECT = { "damage_path" },
  EXP_FAKE_OUT_EFFECT = { "kind", "expJustEntered" },
  EXP_HEAL_BELL_EFFECT = { "toxic_counter" },
  EXP_MEAN_LOOK_EFFECT = { "ghost_immunity" },
  EXP_PAIN_SPLIT_EFFECT = { "substitute_guard" },
  EXP_PRESENT_EFFECT = { "heal_block" },
  EXP_RAPID_SPIN_EFFECT = { "clear_scope", "kind" },
  EXP_REFRESH_EFFECT = { "status_aliases" },
  EXP_SMELLING_SALTS_EFFECT = { "timing", "power_mod" },
  EXP_SPIKES_EFFECT = { "side_spikes_flag" },
  EXP_STAT_DOWN_EFFECT = { "accuracy_checked" },
  EXP_SWAGGER_EFFECT = { "substitute_confusion" },
  EXP_TAUNT_EFFECT = { "substitute_guard" },
  EXP_U_TURN_EFFECT = { "switch_prompt" },
  EXP_YAWN_EFFECT = { "substitute_guard" },
}

Parity.RESIDUAL_PHASES = {
  "weather_continue",
  "weather_chip",
  "weather_tick",
  "status_chip",
  "leech_seed",
  "partial_trap_chip",
  "partial_trap_tick",
  "volatiles",
  "held_items",
  "abilities_eot",
}

-- Per battler: skip remaining phases when fainted after a chip phase.
Parity.FAINT_HALT = {
  weather_chip = true,
  status_chip = true,
  leech_seed = true,
  partial_trap_chip = true,
  volatiles = true,
}

Parity.REENTRANT_EFFECTS = {
  "EXP_SLEEP_TALK_EFFECT",
  "EXP_ASSIST_EFFECT",
  "EXP_COPYCAT_EFFECT",
  "EXP_NATURE_POWER_EFFECT",
  "EXP_ME_FIRST_EFFECT",
  "EXP_MIRROR_MOVE_EFFECT",
  "EXP_MAGIC_COAT_EFFECT",
  "EXP_SNATCH_EFFECT",
}

Parity.INTEGRATION = {
  events = {
    "battle.started", "battle.ended", "battle.battler_switched",
    "battle.turn_started", "battle.turn_ended", "battle.move_used",
    "battle.damage_dealt", "battle.fainted", "battle.status_inflicted",
    "battle.exp_gained", "battle.ball_thrown",
  },
  hooks = {
    "battle.damage", "battle.accuracy", "battle.crit",
    "battle.turn_order", "battle.run", "battle.enemy_action",
  },
}

function Parity.allEffectIds()
  local seen = {}
  local out = {}
  local function add(id)
    if not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  for _, id in ipairs(Parity.GEN1_ONLY) do add(id) end
  for _, id in ipairs(Parity.GEN2_ONLY) do add(id) end
  for id in pairs(Parity.SEMANTIC_MISMATCH) do add(id) end
  -- Shared registered effects (both gens unless gen1/gen2 only).
  local shared = {
    "EXP_ACUPRESSURE_EFFECT", "EXP_ALLY_SWITCH_EFFECT", "EXP_AQUA_RING_EFFECT",
    "EXP_ASSIST_EFFECT", "EXP_BATON_PASS_EFFECT", "EXP_BELLY_DRUM_EFFECT",
    "EXP_BESTOW_EFFECT", "EXP_BRICK_BREAK_EFFECT", "EXP_BURN_EFFECT",
    "EXP_CAMOUFLAGE_EFFECT", "EXP_CAPTIVATE_EFFECT", "EXP_CHARGE_EFFECT",
    "EXP_CLEAR_SMOG_EFFECT", "EXP_CONVERSION_2_EFFECT", "EXP_COPYCAT_EFFECT",
    "EXP_CURSE_EFFECT", "EXP_DAMAGE_STAT_SIDE_EFFECT", "EXP_DAMAGE_USER_STAT_EFFECT",
    "EXP_DESTINY_BOND_EFFECT", "EXP_EMBARGO_EFFECT", "EXP_ENCORE_EFFECT",
    "EXP_ENDEAVOR_EFFECT", "EXP_ENDURE_EFFECT", "EXP_ENTRAINMENT_EFFECT",
    "EXP_FAKE_OUT_EFFECT", "EXP_FALSE_SWIPE_EFFECT", "EXP_FLINCH_SIDE_100",
    "EXP_FOCUS_PUNCH_EFFECT", "EXP_FOLLOW_ME_EFFECT", "EXP_FORESIGHT_EFFECT",
    "EXP_FUTURE_SIGHT_EFFECT", "EXP_FURY_CUTTER_EFFECT", "EXP_GASTRO_ACID_EFFECT",
    "EXP_GRUDGE_EFFECT", "EXP_GUARD_SWAP_EFFECT", "EXP_HEALING_WISH_EFFECT",
    "EXP_HEAL_BELL_EFFECT", "EXP_HEAL_BLOCK_EFFECT", "EXP_IMPRISON_EFFECT",
    "EXP_INGRAIN_EFFECT", "EXP_KNOCK_OFF_EFFECT", "EXP_LOCK_ON_EFFECT",
    "EXP_LUCKY_CHANT_EFFECT", "EXP_MAGIC_COAT_EFFECT", "EXP_MEAN_LOOK_EFFECT",
    "EXP_MEMENTO_EFFECT", "EXP_ME_FIRST_EFFECT", "EXP_MIRROR_COAT_EFFECT",
    "EXP_MUD_SPORT_EFFECT", "EXP_NATURE_POWER_EFFECT", "EXP_NIGHTMARE_EFFECT",
    "EXP_PAIN_SPLIT_EFFECT", "EXP_PERISH_SONG_EFFECT", "EXP_POWER_SWAP_EFFECT",
    "EXP_POWER_TRICK_EFFECT", "EXP_PRESENT_EFFECT", "EXP_PROTECT_EFFECT",
    "EXP_PSYCH_UP_EFFECT", "EXP_RAPID_SPIN_EFFECT", "EXP_RECYCLE_EFFECT",
    "EXP_REFRESH_EFFECT", "EXP_ROLE_PLAY_EFFECT", "EXP_ROLLOUT_EFFECT",
    "EXP_SAFEGUARD_EFFECT", "EXP_SECRET_POWER_EFFECT", "EXP_SIMPLE_BEAM_EFFECT",
    "EXP_SKETCH_EFFECT", "EXP_SKILL_SWAP_EFFECT", "EXP_SLEEP_TALK_EFFECT",
    "EXP_SMELLING_SALTS_EFFECT", "EXP_SNATCH_EFFECT", "EXP_SPEED_SWAP_EFFECT",
    "EXP_SPIKES_EFFECT", "EXP_SPIT_UP_EFFECT", "EXP_SPITE_EFFECT",
    "EXP_STAT_CHANGES_EFFECT", "EXP_STAT_DOWN_EFFECT", "EXP_STEALTH_ROCK_EFFECT",
    "EXP_STOCKPILE_EFFECT", "EXP_SWAGGER_EFFECT", "EXP_SWALLOW_EFFECT",
    "EXP_TAILWIND_EFFECT", "EXP_TAUNT_EFFECT", "EXP_TORMENT_EFFECT",
    "EXP_TOXIC_SPIKES_EFFECT", "EXP_TRICK_EFFECT", "EXP_TRICK_ROOM_EFFECT",
    "EXP_UPROAR_EFFECT", "EXP_U_TURN_EFFECT", "EXP_VARIABLE_POWER_EFFECT",
    "EXP_WAKE_UP_SLAP_EFFECT", "EXP_WATER_SPORT_EFFECT", "EXP_WEATHER_HAIL",
    "EXP_WEATHER_RAINY", "EXP_WEATHER_SANDSTORM", "EXP_WEATHER_SUNNY",
    "EXP_WISH_EFFECT", "EXP_WORRY_SEED_EFFECT", "EXP_YAWN_EFFECT",
  }
  for _, id in ipairs(shared) do add(id) end
  table.sort(out)
  return out
end

return Parity
