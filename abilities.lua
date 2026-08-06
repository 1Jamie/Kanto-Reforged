local Strings = require("src.core.Strings")

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

local function displayName(b)
  return b.isPlayer and b.name or ("Enemy " .. b.name)
end

local function abilityOf(battle, battler)
  if not battler or not battler.mon then return nil end
  if battler.expAbilitySuppressed then return nil end
  if battler.expTracedAbility then return battler.expTracedAbility end
  if not battle or not battle.data or not battle.data.pokemon then return nil end
  local def = battle.data.pokemon[battler.mon.species]
  return def and def.ability
end
Abilities.abilityOf = abilityOf

local function setWeather(battle, weather, message)
  if not battle.field then
    battle.field = { weather = nil, tokens = {}, sides = battle.sides }
  end
  if battle.field.weather == weather then return end
  battle.field.weather = weather
  if message then
    battle:sayNext(Strings(message))
  end
  Abilities.updateForecast(battle, battle.player)
  Abilities.updateForecast(battle, battle.enemy)
end

-- Intimidate effect handler
local function triggerIntimidate(battle, source, target)
  if not target or not target.mon or (target.mon.hp and target.mon.hp <= 0) then return end

  -- Intimidate is blocked by Substitute
  if target.substituteHP then return end

  local cur = target.stages.attack or 0
  if cur <= -6 then return end

  target.stages.attack = math.max(-6, cur - 1)
  target.hazeStatReset = nil

  local srcName = displayName(source)
  local tgtName = displayName(target)

  battle:sayNext(Strings("%s's\nINTIMIDATE cuts\n%s's ATTACK!", srcName, tgtName))
end

-- Update Forecast form and types
function Abilities.updateForecast(battle, battler)
  if not battler or not battler.mon then return end
  local def = battle.data.pokemon[battler.mon.species]
  local ability = def and def.ability
  if ability ~= "FORECAST" then return end

  local weather = battle.field and battle.field.weather
  local oldType = battler.curTypes[1]
  local newType = "NORMAL"
  if weather == "SUNNY" then
    newType = "FIRE"
  elseif weather == "RAINY" then
    newType = "WATER"
  elseif weather == "HAIL" or weather == "SNOWY" then
    newType = "ICE"
  end

  if oldType ~= newType then
    battler.curTypes = { newType }
    battle:sayNext(Strings("%s transformed\ninto its weather form!", displayName(battler)))
  end
end

-- Chlorophyll / Swift Swim / Tailwind effective-speed multiplier
function Abilities.speedMult(battle, battler)
  local ability = abilityOf(battle, battler)
  local weather = battle.field and battle.field.weather
  local mult = 1
  if ability == "CHLOROPHYLL" and weather == "SUNNY" then mult = mult * 2 end
  if ability == "SWIFT_SWIM" and weather == "RAINY" then mult = mult * 2 end
  local side = battle.sideOf and battle:sideOf(battler)
  if side and side.expTailwindTurns and side.expTailwindTurns > 0 then
    mult = mult * 2
  end
  return mult
end

-- Entry triggers
function Abilities.onEntry(battle, battler)
  if not battler or not battler.mon then return end
  local ability = abilityOf(battle, battler)

  if ability == "INTIMIDATE" then
    local target = battler.isPlayer and battle.enemy or battle.player
    triggerIntimidate(battle, battler, target)
  elseif ability == "FORECAST" then
    Abilities.updateForecast(battle, battler)
  elseif ability == "DROUGHT" then
    setWeather(battle, "SUNNY", displayName(battler) .. "'s\nDROUGHT intensified\nthe sun!")
  elseif ability == "DRIZZLE" then
    setWeather(battle, "RAINY", displayName(battler) .. "'s\nDRIZZLE made it\nrain!")
  elseif ability == "SAND_STREAM" then
    setWeather(battle, "SANDSTORM", displayName(battler) .. "'s\nSAND STREAM whipped\nup a sandstorm!")
  elseif ability == "AIR_LOCK" then
    setWeather(battle, nil, displayName(battler) .. "'s\nAIR LOCK cleared\nthe weather!")
  elseif ability == "TRACE" then
    local foe = battler.isPlayer and battle.enemy or battle.player
    local foeAbility = abilityOf(battle, foe)
    if foeAbility and foeAbility ~= "TRACE" then
      battler.expTracedAbility = foeAbility
      battle:sayNext(Strings("%s traced\n%s!", displayName(battler), foeAbility:gsub("_", " ")))
      -- Re-trigger entry effects of the copied ability once
      if foeAbility == "INTIMIDATE" then
        local target = battler.isPlayer and battle.enemy or battle.player
        triggerIntimidate(battle, battler, target)
      end
    end
  end
end

-- Weather-setting moves (Sunny Day / Rain Dance / Sandstorm / Hail)
function Abilities.onMoveUsed(battle, user, move)
  if not battle or not move then return end
  local weather = WEATHER_MOVES[move.id]
  if weather then
    setWeather(battle, weather)
  end
  Abilities.updateForecast(battle, battle.player)
  Abilities.updateForecast(battle, battle.enemy)
end

-- Turn start triggers (Truant)
function Abilities.onTurnStart(battle, battler)
  if not battler or not battler.mon then return end
  local ability = abilityOf(battle, battler)
  if ability == "TRUANT" then
    if battler.loafing then
      battler.loafing = false
      battler.skipMove = true
      battle:sayNext(Strings("%s is\nloafing around!", displayName(battler)))
    else
      battler.loafing = true
    end
  end
end

-- End of turn (Speed Boost)
function Abilities.onTurnEnded(battle, battler)
  if not battler or not battler.mon or battler.mon.hp <= 0 then return end
  if abilityOf(battle, battler) ~= "SPEED_BOOST" then return end
  local cur = battler.stages.speed or 0
  if cur >= 6 then return end
  battler.stages.speed = cur + 1
  battler.hazeStatReset = nil
  battle:sayNext(Strings("%s's SPEED\nrose!", displayName(battler)))
end

-- Damage pipeline triggers
function Abilities.onDamage(next, ctx)
  local move = ctx.move
  local user = ctx.user
  local target = ctx.target

  local targetAbility = abilityOf(ctx.battle, target)
  local userAbility = abilityOf(ctx.battle, user)

  -- 1. Levitate: Ground moves have no effect
  if targetAbility == "LEVITATE" and move.type == "GROUND" then
    return 0, { crit = false, typeMult = 0 }
  end

  -- Flash Fire: Fire moves have no effect (Gen 1-style type immunity)
  if targetAbility == "FLASH_FIRE" and move.type == "FIRE"
      and move.power and move.power > 0 then
    ctx.battle:sayNext(Strings("%s's FLASH FIRE\nmade it immune!", displayName(target)))
    return 0, { crit = false, typeMult = 0 }
  end

  -- Lightning Rod: Electric moves have no effect (singles Gen 1 stand-in)
  if targetAbility == "LIGHTNING_ROD" and move.type == "ELECTRIC"
      and move.power and move.power > 0 then
    ctx.battle:sayNext(Strings("%s's LIGHTNING ROD\ntook the attack!", displayName(target)))
    return 0, { crit = false, typeMult = 0 }
  end

  -- 1b. Soundproof: immune to sound moves
  if targetAbility == "SOUNDPROOF" and SOUND_MOVES[move.id] then
    return 0, { crit = false, typeMult = 0 }
  end

  -- 2. Wonder Guard: only super-effective damaging moves land
  if targetAbility == "WONDER_GUARD" and move.power and move.power > 0 then
    local TypeChart = require("src.battle.TypeChart")
    local mult = TypeChart.effectiveness(move.type, target.curTypes)
    if mult <= 10 then
      return 0, { crit = false, typeMult = 0 }
    end
  end

  -- 3. Volt Absorb / Water Absorb
  local absorbType = ABSORB[targetAbility]
  if absorbType and move.type == absorbType and move.power and move.power > 0 then
    local heal = math.max(1, math.floor(target.mon.stats.hp / 4))
    target.mon.hp = math.min(target.mon.stats.hp, target.mon.hp + heal)
    ctx.battle:sayNext(Strings("%s restored HP\nusing its %s!",
      displayName(target), targetAbility:gsub("_", " ")))
    return 0, { crit = false, typeMult = 0 }
  end

  local TypeChart = require("src.battle.TypeChart")
  local category = move.category or TypeChart.category(move.type) or "physical"
  local isPhysical = category == "physical"

  -- 4. Overgrow / Blaze / Torrent / Swarm: 1.5x when HP ≤ 1/3
  local boostType = STARTER_BOOST[userAbility]
  local boostedStat, oldStat
  if boostType and move.type == boostType and user.mon.hp * 3 <= user.mon.stats.hp then
    local key = isPhysical and "attack" or "special"
    boostedStat = key
    oldStat = user.curStats[key]
    user.curStats[key] = math.floor(oldStat * 1.5)
  end

  -- Pure Power / Huge Power: double Attack for physical moves
  local pureBoost, pureOld
  if (userAbility == "PURE_POWER" or userAbility == "HUGE_POWER") and isPhysical then
    pureBoost = true
    pureOld = user.curStats.attack
    user.curStats.attack = pureOld * 2
  end

  -- Hustle: 1.5x physical Attack
  local hustleBoost, hustleOld
  if userAbility == "HUSTLE" and isPhysical then
    hustleBoost = true
    hustleOld = user.curStats.attack
    user.curStats.attack = math.floor(hustleOld * 1.5)
  end

  -- Plus / Minus: singles stand-in for the doubles SpA link — 1.5x Special
  local plusBoost, plusOld
  if (userAbility == "PLUS" or userAbility == "MINUS") and not isPhysical then
    plusBoost = true
    plusOld = user.curStats.special
    user.curStats.special = math.floor(plusOld * 1.5)
  end

  -- Marvel Scale: 1.5x Defense when statused
  local marvelOld
  if targetAbility == "MARVEL_SCALE" and target.mon.status and isPhysical then
    marvelOld = target.curStats.defense
    target.curStats.defense = math.floor(marvelOld * 1.5)
  end

  local function restoreBoosts()
    if boostedStat then user.curStats[boostedStat] = oldStat end
    if pureBoost then user.curStats.attack = pureOld end
    if hustleBoost then user.curStats.attack = hustleOld end
    if plusBoost then user.curStats.special = plusOld end
    if marvelOld then target.curStats.defense = marvelOld end
  end

  local function applyFieldMods(damage)
    if not damage or damage <= 0 then return damage end
    if targetAbility == "THICK_FAT"
        and (move.type == "FIRE" or move.type == "ICE") then
      damage = math.max(1, math.floor(damage / 2))
    end
    if ctx.battle.expMudSport and move.type == "ELECTRIC" then
      damage = math.max(1, math.floor(damage / 3))
    end
    if ctx.battle.expWaterSport and move.type == "FIRE" then
      damage = math.max(1, math.floor(damage / 3))
    end
    return damage
  end

  -- 5. Guts: +50% physical Attack when statused (cancels burn cut)
  if userAbility == "GUTS" and isPhysical and user.mon.status then
    local oldAttack = user.curStats.attack
    local factor = 1.5
    if user.mon.status == "BRN" then
      factor = 3.0
    end
    user.curStats.attack = math.floor(oldAttack * factor)

    local damage, info = next(ctx)

    user.curStats.attack = oldAttack
    restoreBoosts()
    return applyFieldMods(damage), info
  end

  local damage, info = next(ctx)
  restoreBoosts()
  return applyFieldMods(damage), info
end

-- Post damage triggers (Color Change + contact abilities)
function Abilities.onPostDamage(battle, user, target, move, damage)
  if not target or not target.mon or (target.mon.hp and target.mon.hp <= 0) then return end
  local targetAbility = abilityOf(battle, target)
  local userAbility = abilityOf(battle, user)

  if targetAbility == "COLOR_CHANGE" and damage > 0 and move.type ~= target.curTypes[1] then
    target.curTypes = { move.type }
    battle:sayNext(Strings("%s's type\nchanged to %s!", displayName(target), move.type))
  end

  -- Physical moves approximate "contact" for Gen 1 engine
  local TypeChart = require("src.battle.TypeChart")
  local category = move.category or TypeChart.category(move.type) or "physical"
  if category ~= "physical" or not damage or damage <= 0 then return end
  if target.substituteHP then return end

  if targetAbility == "ROUGH_SKIN" and user and user.mon and user.mon.hp > 0 then
    local dmg = math.max(1, math.floor(user.mon.stats.hp / 8))
    battle:applyDamage(user, dmg)
    battle:sayNext(Strings("%s was hurt by\nROUGH SKIN!", displayName(user)))
    if user.mon.hp <= 0 then battle:onFaint(user) end
  end

  local StatusRegistry = require("src.battle.StatusRegistry")
  local roll = (battle.rng or math.random)(0, 99)

  -- Stench: attacker's stink can flinch (Gen 1 secondary-flinch feel, ~10%)
  if userAbility == "STENCH" and target.mon.hp > 0
      and (battle.rng or math.random)(0, 99) < 10 then
    target.flinched = true
  end

  -- Cursed Body: Disable the move that hit you (Gen 1 Disable)
  if targetAbility == "CURSED_BODY" and user and user.mon and user.mon.hp > 0
      and move and move.id and not user.disabledSlot
      and (battle.rng or math.random)(0, 99) < 30 then
    local slot
    for i, mv in ipairs(user.curMoves or {}) do
      if mv.id == move.id then
        slot = i
        break
      end
    end
    if slot then
      user.disabledSlot = slot
      user.disabledTurns = (battle.rng or math.random)(2, 5)
      local moveName = (battle.data and battle.data.moves and battle.data.moves[move.id]
        and battle.data.moves[move.id].name) or move.id
      battle:sayNext(Strings("%s's\n%s was\ndisabled!", displayName(user), moveName))
    end
  end

  if targetAbility == "STATIC" and roll < 30 and user and user.mon and not user.mon.status then
    local msgs = StatusRegistry.inflict(battle, user, "PAR", {
      secondary = true, moveType = "ELECTRIC", source = "STATIC",
      expSourceBattler = target,
    })
    for _, m in ipairs(msgs or {}) do battle:sayNext(m) end
  elseif targetAbility == "POISON_POINT" and roll < 30
      and user and user.mon and not user.mon.status then
    local msgs = StatusRegistry.inflict(battle, user, "PSN", {
      secondary = true, moveType = "POISON", source = "POISON_POINT",
      expSourceBattler = target,
    })
    for _, m in ipairs(msgs or {}) do battle:sayNext(m) end
  elseif targetAbility == "FLAME_BODY" and roll < 30
      and user and user.mon and not user.mon.status then
    local msgs = StatusRegistry.inflict(battle, user, "BRN", {
      secondary = true, moveType = "FIRE", source = "FLAME_BODY",
      expSourceBattler = target,
    })
    for _, m in ipairs(msgs or {}) do battle:sayNext(m) end
  elseif targetAbility == "EFFECT_SPORE" and roll < 30
      and user and user.mon and not user.mon.status then
    local pick = ({ "SLP", "PSN", "PAR" })[(battle.rng or math.random)(1, 3)]
    local msgs = StatusRegistry.inflict(battle, user, pick, {
      secondary = true, source = "EFFECT_SPORE",
      expSourceBattler = target,
    })
    for _, m in ipairs(msgs or {}) do battle:sayNext(m) end
  elseif targetAbility == "CUTE_CHARM"
      and user and user.mon and not user.expInfatuated
      and (battle.rng or math.random)(1, 3) == 1 then
    -- Gen 3 Cute Charm is 1/3 (Gen 4+ lowered it to 30%).
    local ua = abilityOf(battle, user)
    if ua ~= "OBLIVIOUS" then
      local Gender = require("mods.expansion_pack.gender")
      if Gender.canInfatuate(target.mon, user.mon) then
        Gender.applyInfatuation(battle, user)
      end
    end
  end
end

-- Rock Head: zero recoil amounts
function Abilities.modifyRecoil(battle, user, amount)
  if abilityOf(battle, user) == "ROCK_HEAD" then return 0 end
  return amount
end

-- Pickup: ~10% chance to find a common item after winning a battle
local PICKUP_TABLE = {
  "POTION", "ANTIDOTE", "SUPER_POTION", "AWAKENING", "BURN_HEAL",
  "ICE_HEAL", "PARLYZ_HEAL", "REPEL", "SUPER_REPEL", "GREAT_BALL",
  "NUGGET", "FULL_HEAL", "HYPER_POTION",
}

function Abilities.tryPickup(game, party, rng)
  if not game or not game.save or not party then return end
  rng = rng or math.random
  local Bag = require("src.inventory.Bag")
  for _, mon in ipairs(party) do
    if mon and mon.hp and mon.hp > 0 then
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      if def and def.ability == "PICKUP" and rng(0, 99) < 10 then
        local item = PICKUP_TABLE[rng(1, #PICKUP_TABLE)]
        if item and Bag.add(game.save, item, 1) then
          return item, mon
        end
      end
    end
  end
end

-- Illuminate: wild encounter rate multiplier (1.5x when lead has it)
function Abilities.illuminateRateMult(game)
  local lead = game and game.save and game.save.party and game.save.party[1]
  if not lead then return 1 end
  local def = game.data and game.data.pokemon and game.data.pokemon[lead.species]
  if def and def.ability == "ILLUMINATE" then return 1.5 end
  return 1
end

return Abilities
