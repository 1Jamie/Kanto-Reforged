local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")

local Abilities = {}

local WEATHER_MOVES = {
  SUNNY_DAY = "SUNNY",
  RAIN_DANCE = "RAINY",
  SANDSTORM = "SANDSTORM",
  HAIL = "HAIL",
}

local STARTER_BOOST = {
  OVERGROW = "GRASS",
  BLAZE = "FIRE",
  TORRENT = "WATER",
  SWARM = "BUG",
}

local ABSORB = {
  VOLT_ABSORB = "ELECTRIC",
  WATER_ABSORB = "WATER",
}

-- Sound moves blocked by Soundproof (Gen 2–3 core set + common later sound moves)
local SOUND_MOVES = {
  GROWL = true, ROAR = true, SING = true, SUPERSONIC = true, SCREECH = true,
  SNORE = true, PERISH_SONG = true, HEAL_BELL = true, UPROAR = true,
  HYPER_VOICE = true, METAL_SOUND = true, GRASS_WHISTLE = true,
  BUG_BUZZ = true, CHATTER = true, ROUND = true, ECHOED_VOICE = true,
  RELIC_SONG = true, BOOMBURST = true, DISARMING_VOICE = true,
  NOBLE_ROAR = true, CONFIDE = true, CLANGING_SCALES = true,
  OVERDRIVE = true, EERIE_SPELL = true, TORCH_SONG = true,
  PSYCHIC_NOISE = true, ALLURING_VOICE = true,
}

function Abilities.isSoundMove(moveId)
  return SOUND_MOVES[moveId] == true
end

local function displayName(battle, b)
  return BattleCompat.displayName(battle, b)
end

local function speciesOf(battler)
  return BattleCompat.species(battler)
end

local function abilityOf(battle, battler)
  if not battler then return nil end
  if battler.expAbilitySuppressed then return nil end
  if battler.expTracedAbility then return battler.expTracedAbility end
  if not battle or not battle.data or not battle.data.pokemon then return nil end
  local species = speciesOf(battler)
  if not species then return nil end
  local def = battle.data.pokemon[species]
  return def and def.ability
end
Abilities.abilityOf = abilityOf
Abilities.speciesOf = speciesOf

--- True when the battler's ability blocks this major status (or confuse).
--- Accepts Gen1 codes (SLP/BRN/…) or Gold ids (sleep/burn/…).
function Abilities.blocksStatus(battle, battler, status, opts)
  if not status or not battler then return false end
  opts = opts or {}
  local ability = abilityOf(battle, battler)
  if not ability then return false end
  local g2 = BattleCompat.toGen2Status(status) or status
  local g1 = BattleCompat.toGen1Status(status) or status

  if (ability == "INSOMNIA" or ability == "VITAL_SPIRIT")
      and (g2 == "sleep" or g1 == "SLP") then
    return true
  end
  if battle and battle.expUproarActive and (g2 == "sleep" or g1 == "SLP") then
    return true
  end
  if ability == "LIMBER" and (g2 == "paralyze" or g1 == "PAR") then
    return true
  end
  if ability == "WATER_VEIL" and (g2 == "burn" or g1 == "BRN") then
    return true
  end
  if ability == "MAGMA_ARMOR" and (g2 == "freeze" or g1 == "FRZ") then
    return true
  end
  if ability == "IMMUNITY"
      and (g2 == "poison" or g2 == "toxic" or g1 == "PSN" or g1 == "TOX") then
    return true
  end
  if ability == "OWN_TEMPO" and (g2 == "confuse" or status == "CONFUSION"
      or status == "confuse") then
    return true
  end
  if ability == "LEAF_GUARD" and (g2 == "sleep" or g1 == "SLP"
      or g2 == "poison" or g2 == "toxic" or g1 == "PSN" or g1 == "TOX"
      or g2 == "burn" or g1 == "BRN" or g2 == "paralyze" or g1 == "PAR"
      or g2 == "freeze" or g1 == "FRZ") then
    local Weather = require("mods.Kanto-Reforged.battle.weather")
    if Weather.current(battle) == "SUNNY" then return true end
  end
  if opts.secondary and not opts.fromAbility and ability == "SHIELD_DUST" then
    return true
  end
  if ability == "FLASH_FIRE" and (g2 == "burn" or g1 == "BRN")
      and opts.moveType == "FIRE" and not opts.secondary then
    return true
  end
  if ability == "LIGHTNING_ROD" and (g2 == "paralyze" or g1 == "PAR")
      and opts.moveType == "ELECTRIC" and not opts.secondary then
    return true
  end
  return false
end

local function setWeather(battle, weather, message, opts)
  BattleCompat.setWeather(battle, weather, message and Strings(message) or nil,
    nil, opts)
  Abilities.updateForecast(battle, battle.player)
  Abilities.updateForecast(battle, battle.enemy)
end

-- Intimidate effect handler
local function triggerIntimidate(battle, source, target)
  local mon = BattleCompat.mon(target)
  if not mon or (mon.hp and mon.hp <= 0) then return end
  if target.substituteHP then return end

  local stages = BattleCompat.stages(battle, target)
  if not stages then return end
  local cur = stages.attack or 0
  if cur <= -6 then return end
  stages.attack = math.max(-6, cur - 1)
  target.hazeStatReset = nil

  BattleCompat.say(battle, Strings("%s's\nINTIMIDATE cuts\v%s's ATTACK!",
    displayName(battle, source), displayName(battle, target)))
end

-- Update Forecast form and types (Castform)
function Abilities.updateForecast(battle, battler)
  if not BattleCompat.mon(battler) then return end
  if abilityOf(battle, battler) ~= "FORECAST" then return end

  local Weather = require("mods.Kanto-Reforged.battle.weather")
  local weather = Weather.current(battle)
  local types = BattleCompat.types(battler)
  local oldType = types[1]
  local newType = "NORMAL"
  if weather == "SUNNY" then
    newType = "FIRE"
  elseif weather == "RAINY" then
    newType = "WATER"
  elseif weather == "HAIL" or weather == "SNOWY" then
    newType = "ICE"
  end

  local suffix = BattleCompat.castformSuffix(weather)
  local mon = BattleCompat.mon(battler)

  if oldType ~= newType then
    BattleCompat.setTypes(battler, { newType })
    BattleCompat.say(battle, Strings("%s\ntransformed!",
      displayName(battle, battler)))
    local CastformFx = require("mods.Kanto-Reforged.battle.castform_fx")
    CastformFx.play(battle, battler, oldType)
    -- Gen2: _krCastformForm is committed when the morph finishes.
    if mon and not BattleCompat.isGen2(battle) then
      mon._krCastformForm = suffix
    end
  elseif mon then
    mon._krCastformForm = suffix
  end
end

-- Chlorophyll / Swift Swim / Tailwind effective-speed multiplier
function Abilities.speedMult(battle, battler)
  local ability = abilityOf(battle, battler)
  local Weather = require("mods.Kanto-Reforged.battle.weather")
  local weather = Weather.current(battle)
  local mult = 1
  if ability == "CHLOROPHYLL" and weather == "SUNNY" then mult = mult * 2 end
  if ability == "SWIFT_SWIM" and weather == "RAINY" then mult = mult * 2 end
  local side = battle.sideOf and battle:sideOf(battler)
  if type(side) == "table" and side.expTailwindTurns and side.expTailwindTurns > 0 then
    mult = mult * 2
  elseif battle.sides then
    for _, s in ipairs(battle.sides) do
      if s and s.expTailwindTurns and s.expTailwindTurns > 0 then
        -- Gen1 sideOf returns side table; Gen2 returns "player"/"enemy" keys.
      end
    end
  end
  if type(side) == "string" and battle.sides and battle.sides[side]
      and battle.sides[side].expTailwindTurns
      and battle.sides[side].expTailwindTurns > 0 then
    mult = mult * 2
  end
  return mult
end

-- Entry triggers
function Abilities.onEntry(battle, battler)
  if not BattleCompat.mon(battler) then return end
  local ability = abilityOf(battle, battler)
  local name = displayName(battle, battler)

  if ability == "INTIMIDATE" then
    -- Gen2 battlers lack isPlayer; compare identity to battle.player.
    local target = (battler == battle.player or battler.isPlayer)
      and battle.enemy or battle.player
    triggerIntimidate(battle, battler, target)
  elseif ability == "FORECAST" then
    Abilities.updateForecast(battle, battler)
  elseif ability == "DROUGHT" then
    setWeather(battle, "SUNNY", Strings("%s's\nDROUGHT flared\vthe sun!", name),
      { fromAbility = true })
  elseif ability == "DRIZZLE" then
    setWeather(battle, "RAINY", Strings("%s's\nDRIZZLE made\vit rain!", name),
      { fromAbility = true })
  elseif ability == "SAND_STREAM" then
    setWeather(battle, "SANDSTORM", Strings("%s's\nSAND STREAM made\va sandstorm!", name),
      { fromAbility = true })
  elseif ability == "AIR_LOCK" or ability == "CLOUD_NINE" then
    -- Gen 3: suppress weather effects; do not delete the weather.
    local abilityName = ability == "AIR_LOCK" and "AIR LOCK" or "CLOUD NINE"
    BattleCompat.say(battle, Strings("%s's\n%s stopped\vthe weather!", name, abilityName))
    local Weather = require("mods.Kanto-Reforged.battle.weather")
    Abilities.updateForecast(battle, battle.player)
    Abilities.updateForecast(battle, battle.enemy)
  elseif ability == "TRACE" then
    local foe = (battler == battle.player or battler.isPlayer) and battle.enemy or battle.player
    local foeAbility = abilityOf(battle, foe)
    if foeAbility and foeAbility ~= "TRACE" then
      battler.expTracedAbility = foeAbility
      BattleCompat.say(battle, Strings("%s\ntraced %s!", name, foeAbility:gsub("_", " ")))
      if foeAbility == "INTIMIDATE" then
        triggerIntimidate(battle, battler, foe)
      elseif foeAbility == "FORECAST" then
        Abilities.updateForecast(battle, battler)
      elseif foeAbility == "AIR_LOCK" or foeAbility == "CLOUD_NINE" then
        local abilityName = foeAbility == "AIR_LOCK" and "AIR LOCK" or "CLOUD NINE"
        BattleCompat.say(battle, Strings("%s's\n%s stopped\vthe weather!", name, abilityName))
        Abilities.updateForecast(battle, battle.player)
        Abilities.updateForecast(battle, battle.enemy)
      elseif foeAbility == "DROUGHT" then
        setWeather(battle, "SUNNY", Strings("%s's\nDROUGHT flared\vthe sun!", name),
          { fromAbility = true })
      elseif foeAbility == "DRIZZLE" then
        setWeather(battle, "RAINY", Strings("%s's\nDRIZZLE made\vit rain!", name),
          { fromAbility = true })
      elseif foeAbility == "SAND_STREAM" then
        setWeather(battle, "SANDSTORM", Strings("%s's\nSAND STREAM made\va sandstorm!", name),
          { fromAbility = true })
      end
    end
  end
end

-- Lead abilities with dialog (Intimidate, weather, Trace, …) must run after
-- both sides are sent out — not when battle.started fires.
function Abilities.runBattleStartEntries(battle)
  if not battle then return end
  Abilities.onEntry(battle, battle.player)
  Abilities.onEntry(battle, battle.enemy)
end

--- Queue entry abilities for the correct beat after battle.started.
--- Gen1: enter() already built the intro queue; act appends after send-outs.
--- Gen2: Battle.new emits started before the UI intro exists — flag for flush.
function Abilities.scheduleBattleStartEntries(battle)
  if not battle then return end
  if type(battle.act) == "function" then
    -- sayNext inserts at nextInsert; a sync onEntry would land at queue[1]
    -- (before "wants to fight!" / "Go!"). act resets nextInsert so dialog
    -- follows the already-queued intro.
    battle:act(function()
      Abilities.runBattleStartEntries(battle)
    end)
    return
  end
  battle._krPendingEntryAbilities = true
end

--- Gen2 BattleState.new: intro is already in ui.queue; append ability events.
function Abilities.flushPendingBattleStartEntries(ui)
  local battle = ui and ui.battle
  if not battle or not battle._krPendingEntryAbilities then return end
  battle._krPendingEntryAbilities = nil
  Abilities.runBattleStartEntries(battle)
  if type(ui.pushAll) == "function" and type(battle.takeEvents) == "function" then
    ui:pushAll(battle:takeEvents())
  end
end

function Abilities.install(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not (Host.isGen2 and Host.isGen2()) then return end
  local ok, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not ok or not BattleState or not BattleState.new then return end
  if BattleState._krEntryAbilityWrap then return end
  local originalNew = BattleState.new
  BattleState.new = function(game, opts)
    local self = originalNew(game, opts)
    Abilities.flushPendingBattleStartEntries(self)
    return self
  end
  BattleState._krEntryAbilityWrap = true
end

-- Weather-setting moves (Sunny Day / Rain Dance / Sandstorm / Hail)
function Abilities.onMoveUsed(battle, user, move)
  if not battle or not move then return end
  local weather = WEATHER_MOVES[move.id]
  if weather then
    -- Gold emits move_used before StartSandstorm/StartSun/StartRain.
    -- Pre-setting weather makes those effects see the storm already up
    -- and fail ("But it failed!"), so the first residual never runs.
    local okH, Host = pcall(require, "mods.Kanto-Reforged.core.host")
    local goldNative = weather == "SANDSTORM" or weather == "SUNNY"
      or weather == "RAINY"
    if not (okH and Host and Host.isGen2 and Host.isGen2() and goldNative) then
      setWeather(battle, weather)
      Abilities.updateForecast(battle, battle.player)
      Abilities.updateForecast(battle, battle.enemy)
    end
    -- Gold StartSun/StartRain/StartSandstorm run AFTER move_used. Forecast
    -- is invoked from Weather.install's MOVE_EFFECTS wrap once weather is up
    -- (FRLG: weather string, then AbilityBattleEffects ON_WEATHER).
    return
  end
  -- FRLG Forecast is weather-change / switch-in only. Re-running it on every
  -- move_used reverted Castform mid-attack when the live weather read missed.
end

-- Turn start triggers (Truant)
function Abilities.onTurnStart(battle, battler)
  if not BattleCompat.mon(battler) then return end
  local ability = abilityOf(battle, battler)
  if ability == "TRUANT" then
    if battler.loafing then
      battler.loafing = false
      battler.skipMove = true
      BattleCompat.say(battle, Strings("%s\nis loafing around!", displayName(battle, battler)))
    else
      battler.loafing = true
    end
  end
end

-- End of turn (Speed Boost)
function Abilities.onTurnEnded(battle, battler)
  local mon = BattleCompat.mon(battler)
  if not mon or (mon.hp or 0) <= 0 then return end
  if abilityOf(battle, battler) ~= "SPEED_BOOST" then return end
  local stages = BattleCompat.stages(battle, battler)
  if not stages then return end
  local cur = stages.speed or 0
  if cur >= 6 then return end
  stages.speed = cur + 1
  battler.hazeStatReset = nil
  BattleCompat.say(battle, Strings("%s's\nSPEED rose!", displayName(battle, battler)))
end

-- Damage pipeline triggers (Gen1 curStats + Gen2 ctx.opts)
function Abilities.onDamage(next, ctx)
  local move = ctx.move
  local user = ctx.user
  local target = ctx.target
  local battle = ctx.battle

  local targetAbility = abilityOf(battle, target)
  local userAbility = abilityOf(battle, user)
  local userMon = BattleCompat.mon(user)
  local targetMon = BattleCompat.mon(target)

  if targetAbility == "LEVITATE" and move.type == "GROUND" then
    return 0, { crit = false, typeMult = 0, effectiveness = 0 }
  end

  if targetAbility == "FLASH_FIRE" and move.type == "FIRE"
      and move.power and move.power > 0 then
    target.expFlashFire = true
    BattleCompat.say(battle, Strings("%s's\nFLASH FIRE took\vthe attack!",
      displayName(battle, target)))
    return 0, { crit = false, typeMult = 0, effectiveness = 0 }
  end

  if targetAbility == "LIGHTNING_ROD" and move.type == "ELECTRIC"
      and move.power and move.power > 0 then
    BattleCompat.say(battle, Strings("%s's\nLIGHTNING ROD took\vthe attack!",
      displayName(battle, target)))
    return 0, { crit = false, typeMult = 0, effectiveness = 0 }
  end

  if targetAbility == "SOUNDPROOF" and SOUND_MOVES[move.id] then
    return 0, { crit = false, typeMult = 0, effectiveness = 0 }
  end

  if targetAbility == "WONDER_GUARD" and move.power and move.power > 0 then
    local TypeChart = require("src.battle.TypeChart")
    local mult = TypeChart.effectiveness(move.type, BattleCompat.types(target))
    if mult <= 10 then
      return 0, { crit = false, typeMult = 0, effectiveness = 0 }
    end
  end

  local absorbType = ABSORB[targetAbility]
  if absorbType and move.type == absorbType and move.power and move.power > 0
      and targetMon then
    local heal = math.max(1, math.floor(BattleCompat.maxHp(target) / 4))
    BattleCompat.heal(target, heal)
    BattleCompat.say(battle, Strings("%s\nrestored HP with\vits %s!",
      displayName(battle, target), targetAbility:gsub("_", " ")))
    return 0, { crit = false, typeMult = 0, effectiveness = 0 }
  end

  local TypeChart = require("src.battle.TypeChart")
  local category = move.category or TypeChart.category(move.type) or "physical"
  local isPhysical = category == "physical"
  local restores = {}

  local function pushRestore(fn)
    if fn then restores[#restores + 1] = fn end
  end

  local boostType = STARTER_BOOST[userAbility]
  if boostType and move.type == boostType and userMon
      and BattleCompat.hp(user) * 3 <= BattleCompat.maxHp(user) then
    pushRestore(BattleCompat.scaleOffense(ctx, user, isPhysical, 1.5))
  end

  if (userAbility == "PURE_POWER" or userAbility == "HUGE_POWER") and isPhysical then
    pushRestore(BattleCompat.scaleOffense(ctx, user, true, 2))
  end

  if userAbility == "HUSTLE" and isPhysical then
    pushRestore(BattleCompat.scaleOffense(ctx, user, true, 1.5))
  end

  -- Plus / Minus only boost SpA with the opposite ally in doubles.
  -- KR battles are singles — leave them as no-ops here.

  if userAbility == "FLASH_FIRE" and user.expFlashFire
      and move.type == "FIRE" and move.power and move.power > 0 then
    pushRestore(BattleCompat.scaleOffense(ctx, user, isPhysical, 1.5))
  end

  if targetAbility == "MARVEL_SCALE" and BattleCompat.hasStatus(target,
        "BRN", "PSN", "PAR", "SLP", "FRZ", "TOX",
        "burn", "poison", "paralyze", "sleep", "freeze", "toxic")
      and isPhysical then
    pushRestore(BattleCompat.scaleDefense(ctx, target, true, 1.5))
  end

  local function restoreBoosts()
    for i = #restores, 1, -1 do restores[i]() end
  end

  local function applyFieldMods(damage)
    if not damage or damage <= 0 then return damage end
    if targetAbility == "THICK_FAT"
        and (move.type == "FIRE" or move.type == "ICE") then
      damage = math.max(1, math.floor(damage / 2))
    end
    if battle and battle.expMudSport and move.type == "ELECTRIC" then
      damage = math.max(1, math.floor(damage / 3))
    end
    if battle and battle.expWaterSport and move.type == "FIRE" then
      damage = math.max(1, math.floor(damage / 3))
    end
    return damage
  end

  if userAbility == "GUTS" and isPhysical and BattleCompat.status(user) then
    local factor = 1.5
    if BattleCompat.hasStatus(user, "BRN", "burn") then
      factor = 3.0
    end
    pushRestore(BattleCompat.scaleOffense(ctx, user, true, factor))
    local damage, info = next(ctx)
    restoreBoosts()
    return applyFieldMods(damage), info
  end

  local damage, info = next(ctx)
  restoreBoosts()
  return applyFieldMods(damage), info
end

local function chance100(battle, percent)
  local rng = battle and battle.rng
  local roll
  if type(rng) == "function" then
    roll = rng(0, 255)
    if type(roll) ~= "number" then return false end
    if roll ~= math.floor(roll) then return false end
    roll = math.floor(roll) % 100
  elseif battle and type(battle.random) == "function" then
    roll = battle.random(100)
    if type(roll) ~= "number" then return false end
  else
    roll = math.random(0, 99)
  end
  return roll < percent
end

function Abilities.onPostDamage(battle, user, target, move, damage)
  local targetMon = BattleCompat.mon(target)
  if not targetMon or (targetMon.hp and targetMon.hp <= 0) then return end
  local targetAbility = abilityOf(battle, target)
  local userAbility = abilityOf(battle, user)
  local userMon = BattleCompat.mon(user)

  local types = BattleCompat.types(target)
  if targetAbility == "COLOR_CHANGE" and damage > 0 and move.type ~= types[1] then
    BattleCompat.setTypes(target, { move.type })
    BattleCompat.say(battle, Strings("%s's\ntype changed to\v%s!",
      displayName(battle, target), move.type))
  end

  local TypeChart = require("src.battle.TypeChart")
  local category = move.category or TypeChart.category(move.type) or "physical"
  if category ~= "physical" or not damage or damage <= 0 then return end
  if target.substituteHP then return end
  if user == target then return end

  if targetAbility == "ROUGH_SKIN" and userMon and (userMon.hp or 0) > 0 then
    local dmg = math.max(1, math.floor(BattleCompat.maxHp(user) / 8))
    BattleCompat.applyHpLoss(battle, user, dmg)
    BattleCompat.say(battle, Strings("%s\nwas hurt by\vROUGH SKIN!",
      displayName(battle, user)))
    if BattleCompat.hp(user) <= 0 and battle.onFaint and user.mon then
      battle:onFaint(user)
    end
  end

  -- Contact status abilities.
  if not userMon or (userMon.hp or 0) <= 0 then return end

  if userAbility == "STENCH" and BattleCompat.hp(target) > 0 and chance100(battle, 10) then
    if battle.volatile then
      local vol = battle:volatile(target)
      if vol then vol.flinched = true end
    else
      target.flinched = true
    end
  end

  if targetAbility == "CURSED_BODY" and BattleCompat.hp(user) > 0
      and move and move.id and not user.disabledSlot
      and chance100(battle, 30) then
    local moves = user.curMoves or user.moves or {}
    local slot
    for i, mv in ipairs(moves) do
      if (mv.id or mv) == move.id then
        slot = i
        break
      end
    end
    if slot then
      user.disabledSlot = slot
      local turnRoll = battle.rng and battle.rng(2, 5) or math.random(2, 5)
      user.disabledTurns = turnRoll
      if battle.volatile then
        local vol = battle:volatile(user)
        if vol then
          vol.disabled = move.id
          vol.disabledTurns = turnRoll
        end
      end
      local moveName = (battle.data and battle.data.moves and battle.data.moves[move.id]
        and battle.data.moves[move.id].name) or move.id
      BattleCompat.say(battle, Strings("%s's\n%s was\vdisabled!",
        displayName(battle, user), moveName))
    end
  end

  if targetAbility == "STATIC" and chance100(battle, 30)
      and not BattleCompat.status(user) then
    BattleCompat.applyStatus(battle, user, "paralyze", target, { fromAbility = true })
  elseif targetAbility == "POISON_POINT" and chance100(battle, 30)
      and not BattleCompat.status(user) then
    BattleCompat.applyStatus(battle, user, "poison", target, { fromAbility = true })
  elseif targetAbility == "FLAME_BODY" and chance100(battle, 30)
      and not BattleCompat.status(user) then
    BattleCompat.applyStatus(battle, user, "burn", target, { fromAbility = true })
  elseif targetAbility == "EFFECT_SPORE" and chance100(battle, 30)
      and not BattleCompat.status(user) then
    local pick = ({ "sleep", "poison", "paralyze" })[
      (battle.rng and battle.rng(1, 3) or math.random(1, 3))]
    BattleCompat.applyStatus(battle, user, pick, target, { fromAbility = true })
  elseif targetAbility == "CUTE_CHARM"
      and not user.expInfatuated
      and chance100(battle, 33) then
    local ua = abilityOf(battle, user)
    if ua ~= "OBLIVIOUS" then
      local okG, Gender = pcall(require, "mods.Kanto-Reforged.pokemon.gender")
      if okG and Gender.canInfatuate and Gender.canInfatuate(targetMon, userMon) then
        Gender.applyInfatuation(battle, user)
      end
    end
  end
end

function Abilities.modifyRecoil(battle, user, amount)
  if abilityOf(battle, user) == "ROCK_HEAD" then return 0 end
  return amount
end

local PICKUP_TABLE = {
  "POTION", "ANTIDOTE", "SUPER_POTION", "AWAKENING", "BURN_HEAL",
  "ICE_HEAL", "PARLYZ_HEAL", "REPEL", "SUPER_REPEL", "GREAT_BALL",
  "NUGGET", "FULL_HEAL", "HYPER_POTION",
}

function Abilities.tryPickup(game, party, rng)
  if not game or not game.save or not party then return end
  rng = rng or math.random
  local okBag, Bag = pcall(require, "src.inventory.Bag")
  if not okBag then return end
  for _, mon in ipairs(party) do
    if mon and mon.hp and mon.hp > 0 then
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      if def and def.ability == "PICKUP" and rng(0, 99) < 10 then
        local item = PICKUP_TABLE[rng(1, #PICKUP_TABLE)]
        if item and Bag.add and Bag.add(game.save, item, 1) then
          return item, mon
        end
      end
    end
  end
end

function Abilities.illuminateRateMult(game)
  local lead = game and game.save and game.save.party and game.save.party[1]
  if not lead then return 1 end
  local def = game.data and game.data.pokemon and game.data.pokemon[lead.species]
  if def and def.ability == "ILLUMINATE" then return 1.5 end
  return 1
end

return Abilities
