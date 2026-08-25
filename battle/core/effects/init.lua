local Hazards = require("mods.Kanto-Reforged.battle.core.effects.hazards")
local Screens = require("mods.Kanto-Reforged.battle.core.effects.screens")
local Stats = require("mods.Kanto-Reforged.battle.core.effects.stats")
local Status = require("mods.Kanto-Reforged.battle.core.effects.status")
local Healing = require("mods.Kanto-Reforged.battle.core.effects.healing")
local Setup = require("mods.Kanto-Reforged.battle.core.effects.setup")
local Weather = require("mods.Kanto-Reforged.battle.core.effects.weather")
local Volatiles = require("mods.Kanto-Reforged.battle.core.effects.volatiles")
local Damaging = require("mods.Kanto-Reforged.battle.core.effects.damaging")
local Calls = require("mods.Kanto-Reforged.battle.core.effects.calls")
local Items = require("mods.Kanto-Reforged.battle.core.effects.items")

local CoreEffects = {}
local registry = {}
local hooks = {}

local function reg(id, fn)
  registry[id] = fn
end

local function hook(id, t)
  hooks[id] = t
end

-- Primary handlers
reg("EXP_SPIKES_EFFECT", Hazards.spikes)
reg("EXP_STEALTH_ROCK_EFFECT", Hazards.stealthRock)
reg("EXP_TOXIC_SPIKES_EFFECT", Hazards.toxicSpikes)
reg("EXP_SAFEGUARD_EFFECT", Screens.safeguard)
reg("EXP_TAILWIND_EFFECT", Screens.tailwind)
reg("EXP_TRICK_ROOM_EFFECT", Screens.trickRoom)
reg("EXP_LUCKY_CHANT_EFFECT", Screens.luckyChant)
reg("EXP_STAT_CHANGES_EFFECT", Stats.statChanges)
reg("EXP_STAT_DOWN_EFFECT", Stats.statDown)
reg("EXP_SWAGGER_EFFECT", Stats.swagger)
reg("EXP_BURN_EFFECT", Status.burn)
reg("EXP_TAUNT_EFFECT", Status.taunt)
reg("EXP_YAWN_EFFECT", Status.yawn)
reg("EXP_REFRESH_EFFECT", Healing.refresh)
reg("EXP_INGRAIN_EFFECT", Healing.ingrain)
reg("EXP_AQUA_RING_EFFECT", Healing.aquaRing)
reg("EXP_MEAN_LOOK_EFFECT", Setup.meanLook)
reg("EXP_FORESIGHT_EFFECT", Setup.foresight)
reg("EXP_LOCK_ON_EFFECT", Setup.lockOn)
reg("EXP_NIGHTMARE_EFFECT", Setup.nightmare)
reg("EXP_DESTINY_BOND_EFFECT", Setup.destinyBond)
reg("EXP_EMBARGO_EFFECT", Setup.embargo)
reg("EXP_HEAL_BLOCK_EFFECT", Setup.healBlock)
reg("EXP_WEATHER_SUNNY", Weather.sunny)
reg("EXP_WEATHER_RAINY", Weather.rainy)
reg("EXP_WEATHER_SANDSTORM", Weather.sandstorm)
reg("EXP_WEATHER_HAIL", Weather.hail)
reg("EXP_PROTECT_EFFECT", Volatiles.protect)
reg("EXP_ENDURE_EFFECT", Volatiles.endure)
reg("EXP_ENCORE_EFFECT", Volatiles.encore)
reg("EXP_PERISH_SONG_EFFECT", Volatiles.perishSong)
reg("EXP_ATTRACT_EFFECT", Volatiles.attract)
reg("EXP_BELLY_DRUM_EFFECT", Healing.bellyDrum)
reg("EXP_WISH_EFFECT", Healing.wish)
reg("EXP_HEAL_BELL_EFFECT", Healing.healBell)
reg("EXP_PAIN_SPLIT_EFFECT", Healing.painSplit)
reg("EXP_SWALLOW_EFFECT", Healing.swallow)
reg("EXP_HEALING_WISH_EFFECT", Healing.healingWish)
reg("EXP_PSYCH_UP_EFFECT", Stats.psychUp)
reg("EXP_FUTURE_SIGHT_EFFECT", Setup.futureSight)
reg("EXP_MAGIC_COAT_EFFECT", Setup.magicCoat)
reg("EXP_GRUDGE_EFFECT", Setup.grudge)
reg("EXP_CURSE_EFFECT", Setup.curse)
reg("EXP_MUD_SPORT_EFFECT", Setup.mudSport)
reg("EXP_WATER_SPORT_EFFECT", Setup.waterSport)
reg("EXP_ROLE_PLAY_EFFECT", Setup.rolePlay)
reg("EXP_SKILL_SWAP_EFFECT", Setup.skillSwap)
reg("EXP_WORRY_SEED_EFFECT", Setup.worrySeed)
reg("EXP_SPITE_EFFECT", Volatiles.spite)
reg("EXP_TORMENT_EFFECT", Volatiles.torment)
reg("EXP_CAPTIVATE_EFFECT", Stats.captivate)
reg("EXP_STOCKPILE_EFFECT", Stats.stockpile)
reg("EXP_ACUPRESSURE_EFFECT", Stats.acupressure)
reg("EXP_CAMOUFLAGE_EFFECT", Setup.camouflage)
reg("EXP_SKETCH_EFFECT", Setup.sketch)
reg("EXP_IMPRISON_EFFECT", Setup.imprison)
reg("EXP_SNATCH_EFFECT", Setup.snatch)
reg("EXP_GASTRO_ACID_EFFECT", Setup.gastroAcid)
reg("EXP_SIMPLE_BEAM_EFFECT", Setup.simpleBeam)
reg("EXP_ENTRAINMENT_EFFECT", Setup.entrainment)
reg("EXP_POWER_TRICK_EFFECT", Stats.powerTrick)
reg("EXP_POWER_SWAP_EFFECT", Stats.powerSwap)
reg("EXP_GUARD_SWAP_EFFECT", Stats.guardSwap)
reg("EXP_SPEED_SWAP_EFFECT", Stats.speedSwap)
reg("EXP_CHARGE_EFFECT", Stats.charge)
reg("EXP_MEMENTO_EFFECT", Stats.memento)
reg("EXP_CONVERSION_2_EFFECT", Stats.conversion2)
reg("EXP_FOLLOW_ME_EFFECT", Setup.helpingHand) -- singles: fail (was evasion stand-in)
reg("EXP_ALLY_SWITCH_EFFECT", Setup.helpingHand) -- singles: fail (was Protect stand-in)
reg("EXP_HELPING_HAND_EFFECT", Setup.helpingHand)
reg("EXP_BATON_PASS_EFFECT", Setup.batonPass)
reg("EXP_TRICK_EFFECT", Items.trick)
reg("EXP_RECYCLE_EFFECT", Items.recycle)
reg("EXP_BESTOW_EFFECT", Items.bestow)

-- Full / secondary hook handlers
hook("EXP_DAMAGE_STAT_SIDE_EFFECT", { kind = "secondary", run = Damaging.damageStatSide })
hook("EXP_DAMAGE_USER_STAT_EFFECT", { kind = "full", afterDamage = Damaging.damageUserStatAfter })
hook("EXP_FLINCH_SIDE_100", { kind = "secondary", run = Damaging.flinchSecondary })
hook("EXP_SECRET_POWER_EFFECT", { kind = "secondary", run = Damaging.secretPowerSecondary })
hook("EXP_BRICK_BREAK_EFFECT", { kind = "full", afterDamage = Damaging.brickBreakAfter })
hook("EXP_FALSE_SWIPE_EFFECT", { kind = "full", chooseDamage = Damaging.falseSwipeChoose })
hook("EXP_FURY_CUTTER_EFFECT", {
  kind = "full",
  afterDamage = Damaging.furyCutterAfter,
  onMiss = Damaging.furyCutterMiss,
})
hook("EXP_SMELLING_SALTS_EFFECT", { kind = "full", afterDamage = Damaging.smellingSaltsAfter })
hook("EXP_ROLLOUT_EFFECT", {
  kind = "full",
  afterDamage = Damaging.rolloutAfter,
  onMiss = Damaging.rolloutMiss,
})
hook("EXP_FAKE_OUT_EFFECT", {
  kind = "full",
  gate = Damaging.fakeOutGate,
  afterDamage = Damaging.fakeOutAfter,
})
hook("EXP_SUCKER_PUNCH_EFFECT", { kind = "full", gate = Damaging.suckerPunchGate })
hook("EXP_WAKE_UP_SLAP_EFFECT", { kind = "full", afterDamage = Damaging.wakeUpSlapAfter })
hook("EXP_METAL_BURST_EFFECT", { kind = "full", chooseDamage = Damaging.metalBurstChoose })
hook("EXP_FINAL_GAMBIT_EFFECT", { kind = "full", chooseDamage = Damaging.finalGambitChoose })
hook("EXP_LAST_RESORT_EFFECT", { kind = "full", gate = Damaging.lastResortGate })
hook("EXP_BELCH_EFFECT", { kind = "full", gate = Damaging.belchGate })
hook("EXP_NATURAL_GIFT_EFFECT", {
  kind = "full",
  gate = Damaging.naturalGiftGate,
  afterDamage = Damaging.naturalGiftAfter,
})
hook("EXP_FLING_EFFECT", {
  kind = "full",
  gate = Damaging.flingGate,
  afterDamage = Damaging.flingAfter,
})
hook("EXP_ENDEAVOR_EFFECT", { kind = "full", chooseDamage = Damaging.endeavorChoose })
hook("EXP_VARIABLE_POWER_EFFECT", { kind = "full" })
hook("EXP_RAPID_SPIN_EFFECT", { kind = "full", afterDamage = Damaging.rapidSpinAfter })
hook("EXP_SPIT_UP_EFFECT", { kind = "full", chooseDamage = Damaging.spitUpChoose })
hook("EXP_MIRROR_COAT_EFFECT", { kind = "full", chooseDamage = Damaging.mirrorCoatChoose })
hook("EXP_FOCUS_PUNCH_EFFECT", { kind = "full", gate = Damaging.focusPunchGate })
hook("EXP_U_TURN_EFFECT", { kind = "full", afterDamage = Damaging.uTurnAfter })
hook("EXP_SLEEP_TALK_EFFECT", { kind = "full", callsMove = Calls.sleepTalk })
hook("EXP_UPROAR_EFFECT", { kind = "full", afterDamage = Damaging.uproarAfter })
hook("EXP_PRESENT_EFFECT", { kind = "full", chooseDamage = Damaging.presentChoose })
hook("EXP_COPYCAT_EFFECT", { kind = "full", callsMove = Calls.copycat })
hook("EXP_ASSIST_EFFECT", { kind = "full", callsMove = Calls.assist })
hook("EXP_NATURE_POWER_EFFECT", { kind = "full", callsMove = Calls.naturePower })
hook("EXP_ME_FIRST_EFFECT", { kind = "full", callsMove = Calls.meFirst })
hook("EXP_CLEAR_SMOG_EFFECT", { kind = "full", afterDamage = Damaging.clearSmogAfter })
hook("EXP_KNOCK_OFF_EFFECT", { kind = "full", afterDamage = Damaging.knockOffAfter })

function CoreEffects.has(id)
  return registry[id] ~= nil
end

function CoreEffects.hasHooks(id)
  return hooks[id] ~= nil
end

function CoreEffects.hooks(id)
  return hooks[id]
end

function CoreEffects.run(id, ctx)
  local fn = registry[id]
  if not fn then return false end
  fn(ctx)
  return true
end

function CoreEffects.runHook(id, hookName, ec, raw)
  local h = hooks[id]
  if not h or not h[hookName] then return nil end
  return h[hookName](ec, raw)
end

function CoreEffects.register(id, fn)
  registry[id] = fn
end

function CoreEffects.all()
  local out = {}
  for id in pairs(registry) do out[#out + 1] = id end
  table.sort(out)
  return out
end

function CoreEffects.allHookIds()
  local out = {}
  for id in pairs(hooks) do out[#out + 1] = id end
  table.sort(out)
  return out
end

return CoreEffects
