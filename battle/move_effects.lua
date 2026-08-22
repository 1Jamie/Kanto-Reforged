-- Gen 2/3 move effects the Gen 1 engine does not ship.
-- Moves point at these via pokemon_data.lua (effect = "EXP_...").
-- Stat-change payloads live on the move record (statChanges / statChance /
-- statTarget), which the schema preserves as unknown fields.

local Strings = require("src.core.Strings")
local TypeChart = require("src.battle.TypeChart")

local MoveEffects = {}

local STAT_LABEL = {
  attack = "ATTACK", defense = "DEFENSE", speed = "SPEED",
  special = "SPECIAL", accuracy = "ACCURACY", evasion = "EVADE",
}

-- Gen 3 Hidden Power type order (PSYCHIC_TYPE matches this engine)
local HP_TYPES = {
  "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL",
  "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC_TYPE", "ICE", "DRAGON", "DARK",
}

local function displayName(b)
  return b.isPlayer and b.name or ("Enemy " .. b.name)
end

local function dv(mon, name)
  return (mon.dvs and mon.dvs[name]) or 0
end

local function bit1(n)
  return math.floor((n % 4) / 2)
end

-- Gen 3 formulas; spa/spd both read the Gen1 special DV.
function MoveEffects.hiddenPower(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local mon = BattleCompat.mon(battler) or battler
  local hp = dv(mon, "hp")
  local atk = dv(mon, "attack")
  local def = dv(mon, "defense")
  local spe = dv(mon, "speed")
  local spc = dv(mon, "special")
  if spc == 0 and mon.dvs and mon.dvs.specialAttack then
    spc = mon.dvs.specialAttack
  end
  local a = (hp % 2) + 2 * (atk % 2) + 4 * (def % 2)
      + 8 * (spe % 2) + 16 * (spc % 2) + 32 * (spc % 2)
  local typeIndex = math.floor(a * 15 / 63)
  local b = bit1(hp) + 2 * bit1(atk) + 4 * bit1(def)
      + 8 * bit1(spe) + 16 * bit1(spc) + 32 * bit1(spc)
  local power = math.floor(b * 40 / 63) + 30
  return HP_TYPES[typeIndex + 1] or "FIGHTING", power
end

function MoveEffects.weatherBall(battle)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local weather = BattleCompat.getWeather(battle)
  if weather == "SUNNY" then return "FIRE", 100 end
  if weather == "RAINY" then return "WATER", 100 end
  if weather == "SANDSTORM" then return "ROCK", 100 end
  if weather == "HAIL" or weather == "SNOWY" then return "ICE", 100 end
  return "NORMAL", 50
end

-- Gen 3 Flail / Reversal power from remaining HP fraction
function MoveEffects.flailPower(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local hp = BattleCompat.hp(battler)
  local maxHp = BattleCompat.maxHp(battler)
  local n = math.floor(hp * 48 / math.max(1, maxHp))
  if n < 1 then return 200 end
  if n < 5 then return 150 end
  if n < 10 then return 100 end
  if n < 17 then return 80 end
  if n < 33 then return 40 end
  return 20
end

-- Gen 1 has no friendship; approximate from DVs (max Return ≈ 102)
function MoveEffects.returnPower(battler)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local mon = BattleCompat.mon(battler) or {}
  local dvs = mon.dvs or {}
  local sum = (dvs.hp or 0) + (dvs.attack or 0) + (dvs.defense or 0)
      + (dvs.speed or 0) + (dvs.special or dvs.specialAttack or 0)
  return math.max(1, math.floor(sum * 102 / 75))
end

function MoveEffects.frustrationPower(battler)
  return math.max(1, 102 - MoveEffects.returnPower(battler))
end

-- Gen 2+ sleep: wake in this speed slot and act; still asleep only burns
-- this mon's beat. Sleep Talk / Snore still fire while SLP.
function MoveEffects.sleepBeforeMove(battler, rng, battle)
  local pending = battler.expPendingMove
  battler.sleepTurns = (battler.sleepTurns or 1) - 1
  if battler.sleepTurns <= 0 then
    battler.mon.status = nil
    -- Plain nickname; sayStatusMsg / prefixEnemy adds "Enemy ".
    return true, { Strings("%s\nwoke up!", battler.name) }
  end
  if pending == "SLEEP_TALK" or pending == "SNORE" then
    return true, { Strings("%s\nis fast asleep!", battler.name) }
  end
  return false, { Strings("%s\nis fast asleep!", battler.name) }
end

-- Gen 3 freeze: 20% thaw before the move (and act that turn). Flame Wheel /
-- Sacred Fire thaw the user. Damaging Fire hits thaw the target.
-- Gen 1 otherwise never thaws, which softlocks under Shadow Tag (GH #2).
MoveEffects.FREEZE_THAW_SIDES = 5

MoveEffects.USER_THAW_MOVES = {
  FLAME_WHEEL = true,
  SACRED_FIRE = true,
}

function MoveEffects.isDamagingFireMove(move)
  if not move then return false end
  if move.type ~= "FIRE" then return false end
  return (move.power or 0) > 0
end

function MoveEffects.pendingMoveOf(battler)
  if not battler then return nil end
  return battler.expPendingMove
    or (battler.mon and battler.mon.expPendingMove)
end

local function rollThaw(rng, battle)
  rng = rng or (battle and battle.rng) or math.random
  local ok, n = pcall(rng, 0, MoveEffects.FREEZE_THAW_SIDES - 1)
  if ok and type(n) == "number" then
    return n == 0
  end
  ok, n = pcall(rng, MoveEffects.FREEZE_THAW_SIDES)
  if ok and type(n) == "number" then
    -- 0..n-1 (Gold BattleRandom) or 1..n (love.math.random(n))
    return n == 0 or n == 1
  end
  ok, n = pcall(rng)
  if ok and type(n) == "number" then
    return (n % MoveEffects.FREEZE_THAW_SIDES) == 0
  end
  return false
end

function MoveEffects.freezeBeforeMove(battler, rng, battle)
  local pending = MoveEffects.pendingMoveOf(battler)
  if pending and MoveEffects.USER_THAW_MOVES[pending] then
    battler.mon.status = nil
    return true, { Strings("%s\nthawed out!", battler.name) }
  end
  if rollThaw(rng, battle) then
    battler.mon.status = nil
    return true, { Strings("%s\nthawed out!", battler.name) }
  end
  return false, { Strings("%s\nis frozen solid!", battler.name) }
end

-- Gold status records: beforeMove(battle, mon, name) -> canAct
function MoveEffects.freezeBeforeMoveGen2(battle, mon, name)
  local pending = mon and mon.expPendingMove
  if pending and MoveEffects.USER_THAW_MOVES[pending] then
    mon.status = nil
    battle:emit({ kind = "message", text = name .. " thawed out!" })
    return true
  end
  local roll
  if battle and type(battle.random) == "function" then
    roll = battle.random(MoveEffects.FREEZE_THAW_SIDES)
  else
    roll = math.random(0, MoveEffects.FREEZE_THAW_SIDES - 1)
  end
  if roll == 0 then
    mon.status = nil
    battle:emit({ kind = "message", text = name .. " thawed out!" })
    return true
  end
  battle:emit({ kind = "message", text = name .. " is frozen solid!" })
  return false
end

function MoveEffects.thawTargetFromFire(battle, target, move)
  if not MoveEffects.isDamagingFireMove(move) then return false end
  local mon = (target and target.mon) or target
  if not mon then return false end
  local st = mon.status
  if st ~= "FRZ" and st ~= "freeze" then return false end
  mon.status = nil
  local name
  if target and target.mon then
    name = target.isPlayer and target.name or ("Enemy " .. target.name)
  elseif battle and type(battle.monName) == "function" then
    name = battle:monName(target)
  else
    name = (target and target.name) or "POKéMON"
  end
  local msg = Strings("Fire defrosted\n%s!", name)
  if battle and battle.sayNext then
    battle:sayNext(msg)
  elseif battle and battle.emit then
    battle:emit({ kind = "message", text = msg })
  end
  return true
end

-- Gen 3 Magnitude: power + strength number
function MoveEffects.magnitudePower(rng)
  local r = (rng or math.random)(0, 99)
  if r < 5 then return 10, 4 end
  if r < 15 then return 30, 5 end
  if r < 35 then return 50, 6 end
  if r < 65 then return 70, 7 end
  if r < 85 then return 90, 8 end
  if r < 95 then return 110, 9 end
  return 150, 10
end

local function applyStages(ctx, who, changes, fromEnemy)
  local msgs = {}
  for _, sc in ipairs(changes or {}) do
    local stat = sc.stat
    local delta = sc.change or 0
    if stat and delta ~= 0 and STAT_LABEL[stat] then
      local piece = ctx.changeStage(who, stat, delta, fromEnemy)
      if type(piece) == "table" then
        for _, m in ipairs(piece) do msgs[#msgs + 1] = m end
      elseif piece then
        msgs[#msgs + 1] = piece
      end
    end
  end
  if #msgs == 0 then
    return { Strings("But, it failed!") }
  end
  return msgs
end

local function setWeather(ctx, weather, text)
  if not ctx.battle.field then
    ctx.battle.field = { weather = nil, tokens = {}, sides = ctx.battle.sides }
  end
  ctx.battle.field.weather = weather
  ctx.battle.field.weatherTurns = 5
  return { Strings(text) }
end

local function foeSide(ctx)
  return ctx.side(ctx.target)
end

local function hasType(battler, typeId)
  for _, t in ipairs(battler.curTypes or {}) do
    if t == typeId then return true end
  end
  return false
end

local function abilityOf(battle, battler)
  local def = battle.data.pokemon[battler.mon.species]
  return def and def.ability
end

local function findHazard(side, id)
  for _, h in ipairs(side.hazards or {}) do
    if h.id == id then return h end
  end
  return nil
end

function MoveEffects.applyHazards(battle, battler, side)
  if not battler or not battler.mon or battler.mon.hp <= 0 then return end
  if not side or not side.hazards then return end
  local msgs = {}
  local grounded = not hasType(battler, "FLYING")
      and abilityOf(battle, battler) ~= "LEVITATE"

  for _, h in ipairs(side.hazards) do
    if h.id == "SPIKES" and grounded then
      local layers = h.layers or 1
      local denom = ({ 8, 6, 4 })[math.min(3, layers)] or 8
      local dmg = math.max(1, math.floor(battler.mon.stats.hp / denom))
      battle:applyDamage(battler, dmg)
      msgs[#msgs + 1] = Strings("%s is hurt\nby SPIKES!", displayName(battler))
    elseif h.id == "STEALTH_ROCK" then
      local mult = TypeChart.effectiveness("ROCK", battler.curTypes)
      if mult > 0 then
        local dmg = math.max(1, math.floor(battler.mon.stats.hp * mult / 80))
        battle:applyDamage(battler, dmg)
        msgs[#msgs + 1] = Strings("Pointed stones dug\ninto %s!", displayName(battler))
      end
    elseif h.id == "TOXIC_SPIKES" and grounded then
      if hasType(battler, "POISON") then
        -- Poison types absorb and clear Toxic Spikes
        for i = #side.hazards, 1, -1 do
          if side.hazards[i].id == "TOXIC_SPIKES" then
            table.remove(side.hazards, i)
          end
        end
        msgs[#msgs + 1] = Strings("The poison spikes\ndisappeared!")
      elseif hasType(battler, "STEEL") then
        -- Steel is immune; spikes stay (unlike Poison absorb).
      elseif not battler.mon.status then
        local layers = h.layers or 1
        local opts = { toxic = layers >= 2, source = "TOXIC_SPIKES" }
        local StatusRegistry = require("src.battle.StatusRegistry")
        local inflicted = StatusRegistry.inflict(battle, battler, "PSN", opts)
        -- toxicCounter is set inside PSN.onInflict when opts.toxic; do not
        -- force it when inflict failed (Steel / Immunity / already statused).
        if type(inflicted) == "table" then
          for _, m in ipairs(inflicted) do msgs[#msgs + 1] = m end
        end
      end
    end
    if battler.mon.hp <= 0 then
      battle:onFaint(battler)
      break
    end
  end

  for _, m in ipairs(msgs) do
    if battle.sayNext then battle:sayNext(m) end
  end
  if #msgs > 0 and battle.drainNext then battle:drainNext() end
end

function MoveEffects.register(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    -- Gold-safe weather setters (Drought/Drizzle moves + Hail overlay).
    local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
    local function weatherRun(weather, text)
      return function(battle, attacker)
        local name = BattleCompat.displayName(battle, attacker)
        BattleCompat.setWeather(battle, weather,
          Strings(text, name), 5)
        local Abilities = require("mods.Kanto-Reforged.battle.abilities")
        Abilities.updateForecast(battle, battle.player)
        Abilities.updateForecast(battle, battle.enemy)
      end
    end
    local weathers = {
      EXP_WEATHER_SUNNY = { "SUNNY", "%s's move\nintensified the sun!" },
      EXP_WEATHER_RAINY = { "RAINY", "%s's move\nmade it rain!" },
      EXP_WEATHER_SANDSTORM = { "SANDSTORM", "A sandstorm\nkicked up!" },
      EXP_WEATHER_HAIL = { "HAIL", "It started\nto hail!" },
    }
    for id, row in pairs(weathers) do
      pcall(function()
        local rec = { kind = "primary", run = weatherRun(row[1], row[2]) }
        if mod.content.move_effects:get(id) then
          mod.content.move_effects:override(id, rec)
        else
          mod.content.move_effects:register(id, rec)
        end
      end)
    end
    require("mods.Kanto-Reforged.battle.move_effects_gen2").register(mod)
    return
  end

  -- Sleep: Gen 2+ wake-and-attack. Must be a content patch so the post-entry
  -- merge writes it into Data.statuses (install-time edits of Data are wiped).
  mod.content.statuses:patch("SLP", {
    beforeMove = MoveEffects.sleepBeforeMove,
  })
  mod.content.statuses:patch("FRZ", {
    beforeMove = MoveEffects.freezeBeforeMove,
  })

  -- Gen 2+: Steel (and Poison) cannot be poisoned / badly poisoned.
  local function canPoison(target)
    if not target then return false end
    for _, t in ipairs(target.curTypes or {}) do
      if t == "POISON" or t == "STEEL" then return false end
    end
    return true
  end
  mod.content.statuses:patch("PSN", {
    canInflict = canPoison,
  })

  -- ------- weather (Sunny Day / Rain Dance / Sandstorm / Hail)

  mod.content.move_effects:register("EXP_WEATHER_SUNNY", {
    kind = "primary",
    run = function(ctx)
      return setWeather(ctx, "SUNNY", "The sunlight turned\nharsh!")
    end,
  })
  mod.content.move_effects:register("EXP_WEATHER_RAINY", {
    kind = "primary",
    run = function(ctx)
      return setWeather(ctx, "RAINY", "It started\nto rain!")
    end,
  })
  mod.content.move_effects:register("EXP_WEATHER_SANDSTORM", {
    kind = "primary",
    run = function(ctx)
      return setWeather(ctx, "SANDSTORM", "A sandstorm\nkicked up!")
    end,
  })
  mod.content.move_effects:register("EXP_WEATHER_HAIL", {
    kind = "primary",
    run = function(ctx)
      return setWeather(ctx, "HAIL", "It started\nto hail!")
    end,
  })

  -- ------- Will-O-Wisp

  mod.content.move_effects:register("EXP_BURN_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if ctx.target.substituteHP then
        return { Strings("But, it failed!") }
      end
      local msgs = ctx.inflict(ctx.target, "BRN", {
        moveType = ctx.move.type, source = ctx.move.id,
      })
      if type(msgs) ~= "table" or #msgs == 0 then
        return { Strings("But, it failed!") }
      end
      return msgs
    end,
  })

  -- ------- Protect / Detect (Gen3 successive-use fail: 1/2, 1/4, 1/8…)

  mod.content.move_effects:register("EXP_PROTECT_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local streak = ctx.user.expProtectStreak or 0
      if streak > 0 then
        local denom = 2 ^ math.min(streak, 8)
        local rng = (ctx.battle and ctx.battle.rng) or love.math.random
        local roll = rng(0, denom - 1)
        if roll ~= 0 then
          return { Strings("But, it failed!") }
        end
      end
      ctx.user.expProtected = true
      ctx.user.expProtectStreak = streak + 1
      return { Strings("%s\nprotected itself!", displayName(ctx.user)) }
    end,
  })

  -- ------- Belly Drum

  mod.content.move_effects:register("EXP_BELLY_DRUM_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local mon = ctx.user.mon
      local cost = math.floor(mon.stats.hp / 2)
      if mon.hp <= cost then
        return { Strings("But, it failed!") }
      end
      mon.hp = mon.hp - cost
      ctx.user.stages.attack = 6
      ctx.user.hazeStatReset = nil
      return { Strings("%s cut its own HP\nand maximized\nATTACK!", displayName(ctx.user)) }
    end,
  })

  -- ------- Entry hazards

  mod.content.move_effects:register("EXP_SPIKES_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = foeSide(ctx)
      side.hazards = side.hazards or {}
      local h = findHazard(side, "SPIKES")
      if h then
        if (h.layers or 1) >= 3 then
          return { Strings("But, it failed!") }
        end
        h.layers = (h.layers or 1) + 1
      else
        side.hazards[#side.hazards + 1] = { id = "SPIKES", layers = 1 }
      end
      return { Strings("SPIKES scattered\nall around the\nfoe's side!") }
    end,
  })

  mod.content.move_effects:register("EXP_STEALTH_ROCK_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = foeSide(ctx)
      side.hazards = side.hazards or {}
      if findHazard(side, "STEALTH_ROCK") then
        return { Strings("But, it failed!") }
      end
      side.hazards[#side.hazards + 1] = { id = "STEALTH_ROCK" }
      return { Strings("Pointed stones float\nin the air around\nthe foe's side!") }
    end,
  })

  mod.content.move_effects:register("EXP_TOXIC_SPIKES_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = foeSide(ctx)
      side.hazards = side.hazards or {}
      local h = findHazard(side, "TOXIC_SPIKES")
      if h then
        if (h.layers or 1) >= 2 then
          return { Strings("But, it failed!") }
        end
        h.layers = 2
      else
        side.hazards[#side.hazards + 1] = { id = "TOXIC_SPIKES", layers = 1 }
      end
      return { Strings("Poison spikes were\nscattered around\nthe foe's side!") }
    end,
  })

  -- ------- Encore

  mod.content.move_effects:register("EXP_ENCORE_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local last = ctx.target.lastMove
      if not last or last == "ENCORE" or last == "STRUGGLE"
          or last == "MIRROR_MOVE" or last == "METRONOME"
          or last == "SKETCH" then
        return { Strings("But, it failed!") }
      end
      local has = false
      for _, mv in ipairs(ctx.target.curMoves or {}) do
        if mv.id == last and (mv.pp or 0) > 0 then has = true break end
      end
      if not has then
        return { Strings("But, it failed!") }
      end
      ctx.target.expEncoreMove = last
      ctx.target.expEncoreTurns = ctx.rng(2, 6)
      return { Strings("%s\ngot an ENCORE!", displayName(ctx.target)) }
    end,
  })

  -- ------- Wish (heals half the wisher's max HP at end of next turn)

  mod.content.move_effects:register("EXP_WISH_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = ctx.side(ctx.user)
      for _, tok in ipairs(side.tokens or {}) do
        if tok.id == "EXP_WISH" then
          return { Strings("But, it failed!") }
        end
      end
      side.tokens = side.tokens or {}
      local heal = math.max(1, math.floor(ctx.user.mon.stats.hp / 2))
      side.tokens[#side.tokens + 1] = {
        id = "EXP_WISH",
        turns = 2,
        heal = heal,
        onExpire = function(battle, holder)
          local battler = holder.battlers and holder.battlers[1]
          if not battler or not battler.mon or battler.mon.hp <= 0 then return end
          local mon = battler.mon
          if mon.hp >= mon.stats.hp then return end
          mon.hp = math.min(mon.stats.hp, mon.hp + heal)
          if battle.sayNext then
            battle:sayNext(Strings("%s's WISH\ncame true!", displayName(battler)))
          end
          if battle.drainNext then battle:drainNext() end
        end,
      }
      return { Strings("%s made\na WISH!", displayName(ctx.user)) }
    end,
  })

  -- ------- Generic primary setup / status-stat moves

  mod.content.move_effects:register("EXP_STAT_CHANGES_EFFECT", {
    kind = "primary",
    run = function(ctx)
      return applyStages(ctx, ctx.user, ctx.move.statChanges, false)
    end,
  })

  mod.content.move_effects:register("EXP_STAT_DOWN_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      return applyStages(ctx, ctx.target, ctx.move.statChanges, true)
    end,
  })

  -- ------- Damage + chance to change stats

  mod.content.move_effects:register("EXP_DAMAGE_STAT_SIDE_EFFECT", {
    kind = "secondary",
    run = function(ctx)
      local chance = ctx.move.statChance or 10
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      if Ab.abilityOf(ctx.battle, ctx.user) == "SERENE_GRACE" then
        chance = chance * 2
      end
      local threshold = math.floor(chance * 256 / 100)
      if ctx.rng(0, 255) >= threshold then return {} end
      if ctx.target.substituteHP then return {} end
      local targetSelf = (ctx.move.statTarget or "target") == "user"
      local who = targetSelf and ctx.user or ctx.target
      return applyStages(ctx, who, ctx.move.statChanges, not targetSelf)
    end,
  })

  -- Guaranteed post-hit stage change. Default target is the user (Overheat /
  -- Close Combat); moves may set statTarget = "target" instead. Prefer
  -- EXP_DAMAGE_STAT_SIDE_EFFECT + chance for foe drops like Rock Tomb.
  mod.content.move_effects:register("EXP_DAMAGE_USER_STAT_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      if not ctx.move.statChanges then return end
      local targetSelf = (ctx.move.statTarget or "user") == "user"
      local who = targetSelf and ctx.user or ctx.target
      local msgs = applyStages(ctx, who, ctx.move.statChanges, not targetSelf)
      for _, m in ipairs(msgs) do ctx.say(m) end
    end,
  })

  mod.content.move_effects:register("EXP_FLINCH_SIDE_100", {
    kind = "secondary",
    run = function(ctx)
      if ctx.target.substituteHP then return {} end
      ctx.target.flinched = true
      return {}
    end,
  })

  -- ------- Endure (survive at 1 HP this turn)

  mod.content.move_effects:register("EXP_ENDURE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expEnduring = true
      return { Strings("%s braced\nitself!", displayName(ctx.user)) }
    end,
  })

  -- ------- Brick Break (shatter Reflect / Light Screen)

  mod.content.move_effects:register("EXP_BRICK_BREAK_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      local t = ctx.target
      if t and (t.reflect or t.lightScreen) then
        t.reflect, t.lightScreen = nil, nil
        ctx.say(Strings("The wall shattered!"))
      end
    end,
  })

  -- ------- False Swipe (never KO)

  mod.content.move_effects:register("EXP_FALSE_SWIPE_EFFECT", {
    kind = "full",
    chooseDamage = function(ctx)
      local dmg, info = ctx.computeDamage()
      if dmg and ctx.target and ctx.target.mon and dmg >= ctx.target.mon.hp then
        dmg = math.max(0, ctx.target.mon.hp - 1)
      end
      return dmg, info
    end,
  })

  -- ------- Fury Cutter (consecutive power doubling)

  mod.content.move_effects:register("EXP_FURY_CUTTER_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      local n = ctx.user.expFuryCutter or 0
      ctx.user.expFuryCutter = math.min(4, n + 1)
    end,
    onMiss = function(ctx)
      ctx.user.expFuryCutter = nil
    end,
  })

  -- ------- Future Sight / Doom Desire (delayed damage)

  mod.content.move_effects:register("EXP_FUTURE_SIGHT_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = foeSide(ctx)
      side.tokens = side.tokens or {}
      for _, tok in ipairs(side.tokens) do
        if tok.id == "EXP_FUTURE_SIGHT" then
          return { Strings("But, it failed!") }
        end
      end
      local power = ctx.move.power or 120
      local level = ctx.user.mon.level or 50
      local dmg = math.max(1, math.floor(level * power / 50) + 2)
      local label = ctx.move.name or "FUTURE SIGHT"
      side.tokens[#side.tokens + 1] = {
        id = "EXP_FUTURE_SIGHT",
        turns = 3,
        damage = dmg,
        onExpire = function(battle, holder)
          local battler = holder.battlers and holder.battlers[1]
          if not battler or not battler.mon or battler.mon.hp <= 0 then return end
          if battle.sayNext then
            battle:sayNext(Strings("%s took the\n%s attack!", displayName(battler), label))
          end
          battle:applyDamage(battler, dmg)
          if battler.mon.hp <= 0 then battle:onFaint(battler) end
        end,
      }
      return { Strings("%s foresaw\nan attack!", displayName(ctx.user)) }
    end,
  })

  -- ------- Psych Up (copy foe stages)

  mod.content.move_effects:register("EXP_PSYCH_UP_EFFECT", {
    kind = "primary",
    run = function(ctx)
      if not ctx.target or not ctx.target.stages then
        return { Strings("But, it failed!") }
      end
      ctx.user.stages = ctx.user.stages or {}
      for stat, val in pairs(ctx.target.stages) do
        ctx.user.stages[stat] = val
      end
      ctx.user.hazeStatReset = nil
      return { Strings("%s copied\nthe foe's stats!", displayName(ctx.user)) }
    end,
  })

  -- ------- Lock-On / Mind Reader

  mod.content.move_effects:register("EXP_LOCK_ON_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      ctx.target.expLockedOn = true
      return { Strings("%s took aim\nat %s!", displayName(ctx.user), displayName(ctx.target)) }
    end,
  })

  -- ------- Foresight / Odor Sleuth

  mod.content.move_effects:register("EXP_FORESIGHT_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      ctx.target.expIdentified = true
      return { Strings("%s was\nidentified!", displayName(ctx.target)) }
    end,
  })

  -- ------- Nightmare

  mod.content.move_effects:register("EXP_NIGHTMARE_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if not ctx.target.mon or ctx.target.mon.status ~= "SLP" then
        return { Strings("But, it failed!") }
      end
      if ctx.target.expNightmare then
        return { Strings("But, it failed!") }
      end
      ctx.target.expNightmare = true
      return { Strings("%s began\nhaving a NIGHTMARE!", displayName(ctx.target)) }
    end,
  })

  -- ------- Spite (cut PP of last move)

  mod.content.move_effects:register("EXP_SPITE_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local last = ctx.target.lastMove
      if not last then
        return { Strings("But, it failed!") }
      end
      local cut = 0
      for _, mv in ipairs(ctx.target.curMoves or {}) do
        if mv.id == last and (mv.pp or 0) > 0 then
          local lost = math.min(mv.pp, 4)
          mv.pp = mv.pp - lost
          cut = lost
          break
        end
      end
      if cut <= 0 then
        return { Strings("But, it failed!") }
      end
      return { Strings("Reduced %s's\n%s by %d!", displayName(ctx.target), last, cut) }
    end,
  })

  -- ------- Smelling Salts (×2 vs PAR, then cure)

  mod.content.move_effects:register("EXP_SMELLING_SALTS_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      if ctx.target and ctx.target.mon and ctx.target.mon.status == "PAR" then
        ctx.target.mon.status = nil
        ctx.say(Strings("%s was cured\nof paralysis!", displayName(ctx.target)))
      end
    end,
  })

  -- ------- Rollout / Ice Ball
  -- Up to 5 consecutive forced uses; power doubles each hit (Defense Curl
  -- doubles base via the damage wrap). Miss or finishing the set clears the lock.

  mod.content.move_effects:register("EXP_ROLLOUT_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      local user = ctx.user
      local n = (user.expRollout or 0) + 1
      user.expRolloutMove = ctx.moveInst
      if n >= 5 then
        user.expRollout = nil
        user.expRolloutMove = nil
      else
        user.expRollout = n
      end
    end,
    onMiss = function(ctx)
      ctx.user.expRollout = nil
      ctx.user.expRolloutMove = nil
    end,
  })

  -- ------- Fake Out (first turn on field only + flinch)

  mod.content.move_effects:register("EXP_FAKE_OUT_EFFECT", {
    kind = "full",
    gate = function(ctx)
      if not ctx.user.expJustEntered then
        return false, Strings("But, it failed!")
      end
      return true
    end,
    afterDamage = function(ctx)
      if ctx.target.substituteHP then return end
      ctx.target.flinched = true
    end,
  })

  -- ------- Taunt

  mod.content.move_effects:register("EXP_TAUNT_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if ctx.target.substituteHP then
        return { Strings("But, it failed!") }
      end
      ctx.target.expTauntedTurns = 3
      return { Strings("%s fell for\nthe TAUNT!", displayName(ctx.target)) }
    end,
  })

  -- ------- Yawn (sleep after one full turn)

  mod.content.move_effects:register("EXP_YAWN_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if ctx.target.substituteHP or ctx.target.mon.status
          or ctx.target.expYawnTurns then
        return { Strings("But, it failed!") }
      end
      ctx.target.expYawnTurns = 2
      return { Strings("%s grew\ndrowsy!", displayName(ctx.target)) }
    end,
  })

  -- ------- Heal Bell / Aromatherapy

  mod.content.move_effects:register("EXP_HEAL_BELL_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local battle = ctx.battle
      local function cureMon(mon)
        if mon and mon.status then
          mon.status = nil
        end
      end
      if ctx.user.isPlayer then
        local party = battle.game and battle.game.save and battle.game.save.party
        for _, mon in ipairs(party or {}) do cureMon(mon) end
      else
        for _, mon in ipairs(battle.enemyParty or {}) do cureMon(mon) end
      end
      if ctx.user.mon then
        ctx.user.mon.status = nil
        ctx.user.toxicCounter = nil
      end
      local label = ctx.move.id == "AROMATHERAPY" and "A soothing aroma"
                   or "A bell chimed"
      return { Strings("%s wafted\nthrough the area!", label) }
    end,
  })

  -- ------- Safeguard

  mod.content.move_effects:register("EXP_SAFEGUARD_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = ctx.side(ctx.user)
      if side.expSafeguardTurns and side.expSafeguardTurns > 0 then
        return { Strings("But, it failed!") }
      end
      side.expSafeguardTurns = 5
      return { Strings("%s's team became\ncloaked in a\nmystic veil!", displayName(ctx.user)) }
    end,
  })

  -- ------- Refresh

  mod.content.move_effects:register("EXP_REFRESH_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local st = ctx.user.mon.status
      if st ~= "BRN" and st ~= "PSN" and st ~= "PAR" then
        return { Strings("But, it failed!") }
      end
      ctx.cure(ctx.user)
      return { Strings("%s's status\nreturned to normal!", displayName(ctx.user)) }
    end,
  })

  -- ------- Curse (Ghost vs non-Ghost)

  mod.content.move_effects:register("EXP_CURSE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      if hasType(ctx.user, "GHOST") then
        local cost = math.max(1, math.floor(ctx.user.mon.stats.hp / 2))
        if ctx.user.mon.hp <= cost then
          return { Strings("But, it failed!") }
        end
        if ctx.target.expCursed then
          return { Strings("But, it failed!") }
        end
        ctx.user.mon.hp = ctx.user.mon.hp - cost
        ctx.target.expCursed = true
        return {
          Strings("%s cut its own HP\nand laid a CURSE\non %s!",
            displayName(ctx.user), displayName(ctx.target)),
        }
      end
      local msgs = {}
      local function bump(who, stat, delta, fromEnemy)
        local piece = ctx.changeStage(who, stat, delta, fromEnemy)
        if type(piece) == "table" then
          for _, m in ipairs(piece) do msgs[#msgs + 1] = m end
        elseif piece then
          msgs[#msgs + 1] = piece
        end
      end
      bump(ctx.user, "speed", -1, false)
      bump(ctx.user, "attack", 1, false)
      bump(ctx.user, "defense", 1, false)
      if #msgs == 0 then return { Strings("But, it failed!") } end
      return msgs
    end,
  })

  -- ------- Mean Look / Block / Spider Web

  mod.content.move_effects:register("EXP_MEAN_LOOK_EFFECT", {
    kind = "primary",
    run = function(ctx)
      if ctx.target.expTrapped or hasType(ctx.target, "GHOST") then
        return { Strings("But, it failed!") }
      end
      ctx.target.expTrapped = true
      return { Strings("%s can no\nlonger escape!", displayName(ctx.target)) }
    end,
  })

  -- ------- Pain Split

  mod.content.move_effects:register("EXP_PAIN_SPLIT_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if ctx.target.substituteHP then
        return { Strings("But, it failed!") }
      end
      local avg = math.floor((ctx.user.mon.hp + ctx.target.mon.hp) / 2)
      ctx.user.mon.hp = math.min(ctx.user.mon.stats.hp, avg)
      ctx.target.mon.hp = math.min(ctx.target.mon.stats.hp, avg)
      return { Strings("The battlers shared\ntheir pain!") }
    end,
  })

  -- ------- Endeavor

  mod.content.move_effects:register("EXP_ENDEAVOR_EFFECT", {
    kind = "full",
    chooseDamage = function(ctx)
      local uh, th = ctx.user.mon.hp, ctx.target.mon.hp
      if uh >= th then
        return nil, Strings("But, it failed!")
      end
      return th - uh, { crit = false, typeMult = 10 }
    end,
  })

  -- Variable-power damaging moves (power filled in by battle.damage hook)
  mod.content.move_effects:register("EXP_VARIABLE_POWER_EFFECT", {
    kind = "full",
  })

  -- ------- Rapid Spin (damage + clear hazards / seed / trap + Speed)

  mod.content.move_effects:register("EXP_RAPID_SPIN_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      local side = ctx.side(ctx.user)
      if side and side.hazards and #side.hazards > 0 then
        side.hazards = {}
        ctx.say(Strings("%s blew away\nentry hazards!", displayName(ctx.user)))
      end
      if ctx.user.leechSeeded then
        ctx.user.leechSeeded = nil
        ctx.say(Strings("%s shed\nLEECH SEED!", displayName(ctx.user)))
      end
      if ctx.user.boundTurns or ctx.target.trappingTurns then
        ctx.user.boundTurns = nil
        ctx.target.trappingTurns = nil
        ctx.user.expTrapped = nil
      end
      if ctx.move.statChanges then
        local msgs = applyStages(ctx, ctx.user, ctx.move.statChanges, false)
        for _, m in ipairs(msgs) do ctx.say(m) end
      end
    end,
  })

  -- ------- Perish Song

  mod.content.move_effects:register("EXP_PERISH_SONG_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      for _, b in ipairs({ ctx.user, ctx.target }) do
        if b and b.mon and not b.expPerishTurns then
          if Ab.abilityOf(ctx.battle, b) ~= "SOUNDPROOF" then
            b.expPerishTurns = 4
          end
        end
      end
      return { Strings("All affected POKEMON\nwill faint in three\nturns!") }
    end,
  })

  -- ------- Destiny Bond

  mod.content.move_effects:register("EXP_DESTINY_BOND_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expDestinyBond = true
      return { Strings("%s is trying to\ntake its foe with it!", displayName(ctx.user)) }
    end,
  })

  -- ------- Attract (opposite gender → infatuation; bypasses Substitute)

  mod.content.move_effects:register("EXP_ATTRACT_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local Abilities = require("mods.Kanto-Reforged.battle.abilities")
      local Gender = require("mods.Kanto-Reforged.pokemon.gender")
      if Abilities.abilityOf(ctx.battle, ctx.target) == "OBLIVIOUS" then
        return { Strings("But, it failed!") }
      end
      if ctx.target.expInfatuated then
        return { Strings("But, it failed!") }
      end
      local userMon = ctx.user and ctx.user.mon
      local targetMon = ctx.target and ctx.target.mon
      if not Gender.canInfatuate(userMon, targetMon) then
        return { Strings("But, it failed!") }
      end
      ctx.target.expInfatuated = true
      return Gender.infatuateMessages(ctx.target)
    end,
  })

  -- ------- Captivate (Gen 4: -2 Sp. Atk, opposite gender only)

  mod.content.move_effects:register("EXP_CAPTIVATE_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local Gender = require("mods.Kanto-Reforged.pokemon.gender")
      if not Gender.canInfatuate(ctx.user and ctx.user.mon, ctx.target and ctx.target.mon) then
        return { Strings("But, it failed!") }
      end
      return applyStages(ctx, ctx.target, ctx.move.statChanges or {
        { stat = "special", change = -2 },
      }, true)
    end,
  })

  -- ------- Swagger (+2 Attack on foe, then confuse)

  mod.content.move_effects:register("EXP_SWAGGER_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local target = ctx.target
      if target.substituteHP then
        return { Strings("But, it failed!") }
      end
      if target.confusedTurns then
        return { Strings("But, it failed!") }
      end
      local msgs = applyStages(ctx, target, {
        { stat = "attack", change = 2 },
      }, false)
      local Abilities = require("mods.Kanto-Reforged.battle.abilities")
      if Abilities.abilityOf(ctx.battle, target) == "OWN_TEMPO" then
        if #msgs == 0 then return { Strings("But, it failed!") } end
        return msgs
      end
      -- Use stock confuse so Persim / Own Tempo hooks stay consistent.
      local VanillaME = require("src.battle.MoveEffects")
      local conf = VanillaME.primary.CONFUSION_EFFECT(ctx.battle, ctx.user, target)
      for _, m in ipairs(conf or {}) do
        if m ~= "But, it failed!" then
          msgs[#msgs + 1] = m
        end
      end
      if #msgs == 0 then
        return { Strings("But, it failed!") }
      end
      return msgs
    end,
  })

  -- ------- Ingrain / Aqua Ring

  mod.content.move_effects:register("EXP_INGRAIN_EFFECT", {
    kind = "primary",
    run = function(ctx)
      if ctx.user.expIngrain then
        return { Strings("But, it failed!") }
      end
      ctx.user.expIngrain = true
      ctx.user.expTrapped = true
      return { Strings("%s planted its roots!", displayName(ctx.user)) }
    end,
  })

  mod.content.move_effects:register("EXP_AQUA_RING_EFFECT", {
    kind = "primary",
    run = function(ctx)
      if ctx.user.expAquaRing then
        return { Strings("But, it failed!") }
      end
      ctx.user.expAquaRing = true
      return { Strings("%s surrounded itself\nwith a veil of water!", displayName(ctx.user)) }
    end,
  })

  -- ------- Stockpile / Spit Up / Swallow

  mod.content.move_effects:register("EXP_STOCKPILE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local n = ctx.user.expStockpile or 0
      if n >= 3 then
        return { Strings("But, it failed!") }
      end
      ctx.user.expStockpile = n + 1
      local msgs = applyStages(ctx, ctx.user, {
        { stat = "defense", change = 1 },
        { stat = "special", change = 1 },
      }, false)
      msgs[#msgs + 1] = Strings("%s stockpiled %d!",
        displayName(ctx.user), ctx.user.expStockpile)
      return msgs
    end,
  })

  mod.content.move_effects:register("EXP_SPIT_UP_EFFECT", {
    kind = "full",
    chooseDamage = function(ctx)
      local n = ctx.user.expStockpile or 0
      if n <= 0 then
        return nil, Strings("But, it failed!")
      end
      local power = 100 * n
      ctx.user.expStockpile = nil
      local old = ctx.move.power
      ctx.move.power = power
      local dmg, info = ctx.computeDamage({})
      ctx.move.power = old
      return dmg, info
    end,
  })

  mod.content.move_effects:register("EXP_SWALLOW_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local n = ctx.user.expStockpile or 0
      if n <= 0 then
        return { Strings("But, it failed!") }
      end
      local frac = ({ 4, 2, 1 })[n] or 1
      local heal = math.max(1, math.floor(ctx.user.mon.stats.hp / frac))
      ctx.user.expStockpile = nil
      if (ctx.user.expHealBlockTurns or 0) > 0 then
        return { Strings("%s can't restore HP\nbecause of HEAL BLOCK!",
          displayName(ctx.user)) }
      end
      if ctx.user.mon.hp >= ctx.user.mon.stats.hp then
        return { Strings("But, it failed!") }
      end
      ctx.user.mon.hp = math.min(ctx.user.mon.stats.hp, ctx.user.mon.hp + heal)
      return { Strings("%s regained\nhealth!", displayName(ctx.user)) }
    end,
  })

  -- ------- Mirror Coat (special Counter)

  mod.content.move_effects:register("EXP_MIRROR_COAT_EFFECT", {
    kind = "full",
    chooseDamage = function(ctx)
      local battle = ctx.battle
      local last = battle.expLastSpecialDamage or 0
      if last <= 0 then
        return nil, Strings("%s's\nattack missed!", displayName(ctx.user))
      end
      return math.min(65535, last * 2), { crit = false, typeMult = 10 }
    end,
  })

  -- ------- Focus Punch (fails if hit earlier this turn)

  mod.content.move_effects:register("EXP_FOCUS_PUNCH_EFFECT", {
    kind = "full",
    gate = function(ctx)
      if ctx.user.expTookDamageThisTurn then
        return false, Strings("%s lost its\nconcentration!", displayName(ctx.user))
      end
      return true
    end,
  })

  -- ------- U-turn (damage; voluntary switch signaled for the player)

  mod.content.move_effects:register("EXP_U_TURN_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      if ctx.user.isPlayer and ctx.user.mon.hp > 0 then
        ctx.user.expWantsSwitch = true
        ctx.say(Strings("%s went back to\n%s!", displayName(ctx.user),
          (ctx.battle.game and ctx.battle.game.save and ctx.battle.game.save.player
            and ctx.battle.game.save.player.name) or "the trainer"))
      end
    end,
  })

  -- ------- Baton Pass (switch, keep stages / key volatiles)

  mod.content.move_effects:register("EXP_BATON_PASS_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local battle = ctx.battle
      local party = ctx.user.isPlayer
          and battle.game and battle.game.save and battle.game.save.party
          or battle.enemyParty
      local hasOther = false
      for _, mon in ipairs(party or {}) do
        if mon and mon.hp and mon.hp > 0 and mon ~= ctx.user.mon then
          hasOther = true
          break
        end
      end
      if not hasOther then
        return { Strings("But, it failed!") }
      end
      local stages = {}
      for k, v in pairs(ctx.user.stages or {}) do stages[k] = v end
      ctx.user.expBatonPass = {
        stages = stages,
        confusedTurns = ctx.user.confusedTurns,
        focusEnergy = ctx.user.focusEnergy,
        substituteHP = ctx.user.substituteHP,
        expIngrain = ctx.user.expIngrain,
        expAquaRing = ctx.user.expAquaRing,
        expPerishTurns = ctx.user.expPerishTurns,
        expCursed = ctx.user.expCursed,
        expTrapped = ctx.user.expTrapped,
        leechSeeded = ctx.user.leechSeeded,
      }
      ctx.user.expPendingBatonOpen = true
      return { Strings("%s went back!", displayName(ctx.user)) }
    end,
  })

  -- ------- Sleep Talk (call a random other move while asleep)

  mod.content.move_effects:register("EXP_SLEEP_TALK_EFFECT", {
    kind = "full",
    callsMove = function(ctx)
      if not ctx.user.mon or ctx.user.mon.status ~= "SLP" then
        ctx.say(Strings("But, it failed!"))
        return nil
      end
      local pool = {}
      for _, mv in ipairs(ctx.user.curMoves or {}) do
        if mv.id ~= "SLEEP_TALK" and mv.id ~= "COPYCAT" and mv.id ~= "ASSIST"
            and mv.id ~= "METRONOME" and mv.id ~= "MIRROR_MOVE"
            and mv.id ~= "SKETCH" and (mv.pp or 0) > 0 then
          pool[#pool + 1] = mv.id
        end
      end
      if #pool == 0 then
        ctx.say(Strings("But, it failed!"))
        return nil
      end
      return pool[ctx.rng(1, #pool)]
    end,
  })

  -- ------- Magic Coat (bounce next status move)

  mod.content.move_effects:register("EXP_MAGIC_COAT_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expMagicCoat = true
      return { Strings("%s shrouded\nitself with MAGIC COAT!", displayName(ctx.user)) }
    end,
  })

  -- ------- Uproar (multi-turn; blocks sleep while active)

  mod.content.move_effects:register("EXP_UPROAR_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      local user = ctx.user
      if not user.expUproarTurns then
        user.expUproarTurns = ctx.rng(2, 5)
        user.expUproarMove = ctx.moveInst
        ctx.battle.expUproarActive = true
        ctx.say(Strings("%s caused\nan UPROAR!", displayName(user)))
      else
        user.expUproarTurns = user.expUproarTurns - 1
        if user.expUproarTurns <= 0 then
          user.expUproarTurns, user.expUproarMove = nil, nil
          ctx.battle.expUproarActive = nil
          ctx.say(Strings("%s calmed down!", displayName(user)))
        end
      end
    end,
  })

  -- ------- Present (random damage or heal)

  mod.content.move_effects:register("EXP_PRESENT_EFFECT", {
    kind = "full",
    chooseDamage = function(ctx)
      local r = ctx.rng(0, 255)
      -- Gen 2 weights (approx): heal ~20%, else 40/80/120
      if r < 51 then
        local mon = ctx.target.mon
        local heal = 80
        mon.hp = math.min(mon.stats.hp, mon.hp + heal)
        ctx.say(Strings("%s had its\nHP restored!", displayName(ctx.target)))
        return 0, { crit = false, typeMult = 10 }
      end
      local power = (r < 102) and 40 or (r < 178) and 80 or 120
      local old = ctx.move.power
      ctx.move.power = power
      local dmg, info = ctx.computeDamage()
      ctx.move.power = old
      return dmg, info
    end,
  })

  -- ------- Torment (can't use the same move twice in a row)

  mod.content.move_effects:register("EXP_TORMENT_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if ctx.target.expTormented then
        return { Strings("But, it failed!") }
      end
      ctx.target.expTormented = true
      return { Strings("%s was\nsubjected to TORMENT!", displayName(ctx.target)) }
    end,
  })

  -- ------- Embargo / Heal Block

  mod.content.move_effects:register("EXP_EMBARGO_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if (ctx.target.expEmbargoTurns or 0) > 0 then
        return { Strings("But, it failed!") }
      end
      ctx.target.expEmbargoTurns = 5
      return { Strings("%s can't use\nitems anymore!", displayName(ctx.target)) }
    end,
  })

  mod.content.move_effects:register("EXP_HEAL_BLOCK_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if (ctx.target.expHealBlockTurns or 0) > 0 then
        return { Strings("But, it failed!") }
      end
      ctx.target.expHealBlockTurns = 5
      return { Strings("%s was prevented\nfrom healing!", displayName(ctx.target)) }
    end,
  })

  -- ------- Role Play / Skill Swap / Worry Seed

  mod.content.move_effects:register("EXP_ROLE_PLAY_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      local foeAb = Ab.abilityOf(ctx.battle, ctx.target)
      if not foeAb then return { Strings("But, it failed!") } end
      ctx.user.expTracedAbility = foeAb
      return { Strings("%s copied\n%s's ability!", displayName(ctx.user), displayName(ctx.target)) }
    end,
  })

  mod.content.move_effects:register("EXP_SKILL_SWAP_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      local a = Ab.abilityOf(ctx.battle, ctx.user)
      local b = Ab.abilityOf(ctx.battle, ctx.target)
      if not a and not b then return { Strings("But, it failed!") } end
      ctx.user.expTracedAbility = b
      ctx.target.expTracedAbility = a
      return { Strings("%s swapped\nabilities with its target!", displayName(ctx.user)) }
    end,
  })

  mod.content.move_effects:register("EXP_WORRY_SEED_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      ctx.target.expTracedAbility = "INSOMNIA"
      return { Strings("%s acquired\nINSOMNIA!", displayName(ctx.target)) }
    end,
  })

  -- ------- Mud Sport / Water Sport

  mod.content.move_effects:register("EXP_MUD_SPORT_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.battle.expMudSport = true
      return { Strings("Electricity's power\nwas weakened!") }
    end,
  })

  mod.content.move_effects:register("EXP_WATER_SPORT_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.battle.expWaterSport = true
      return { Strings("Fire's power\nwas weakened!") }
    end,
  })

  -- ------- Grudge (deplete PP of KO move on faint)

  mod.content.move_effects:register("EXP_GRUDGE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expGrudge = true
      return { Strings("%s wants the\nfoe to take a GRUDGE!", displayName(ctx.user)) }
    end,
  })

  -- ------- Acupressure (random +2 stage)

  mod.content.move_effects:register("EXP_ACUPRESSURE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local stats = { "attack", "defense", "speed", "special", "accuracy", "evasion" }
      local pool = {}
      for _, s in ipairs(stats) do
        if (ctx.user.stages[s] or 0) < 6 then pool[#pool + 1] = s end
      end
      if #pool == 0 then return { Strings("But, it failed!") } end
      local pick = pool[ctx.rng(1, #pool)]
      return applyStages(ctx, ctx.user, { { stat = pick, change = 2 } }, false)
    end,
  })

  -- ------- Camouflage (become Normal in this engine)

  mod.content.move_effects:register("EXP_CAMOUFLAGE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.curTypes = { "NORMAL" }
      return { Strings("%s's type\nchanged to NORMAL!", displayName(ctx.user)) }
    end,
  })

  -- ------- Copycat (copy foe's last move)

  mod.content.move_effects:register("EXP_COPYCAT_EFFECT", {
    kind = "full",
    callsMove = function(ctx)
      local last = ctx.target.lastMove
      if not last or last == "COPYCAT" or last == "SLEEP_TALK"
          or last == "ASSIST" or last == "METRONOME" or last == "MIRROR_MOVE"
          or last == "SKETCH" or last == "TRANSFORM" then
        ctx.say(Strings("But, it failed!"))
        return nil
      end
      return last
    end,
  })

  -- ------- Assist (random party move)

  mod.content.move_effects:register("EXP_ASSIST_EFFECT", {
    kind = "full",
    callsMove = function(ctx)
      local battle = ctx.battle
      local party = ctx.user.isPlayer
          and battle.game and battle.game.save and battle.game.save.party
          or battle.enemyParty
      local pool = {}
      local ban = {
        ASSIST = true, SLEEP_TALK = true, COPYCAT = true, METRONOME = true,
        MIRROR_MOVE = true, SKETCH = true, TRANSFORM = true, COUNTER = true,
        MIRROR_COAT = true, PROTECT = true, DETECT = true, ENDURE = true,
        DESTINY_BOND = true, THIEF = true,
      }
      for _, mon in ipairs(party or {}) do
        if mon ~= ctx.user.mon then
          for _, mv in ipairs(mon.moves or {}) do
            if mv.id and not ban[mv.id] then pool[#pool + 1] = mv.id end
          end
        end
      end
      if #pool == 0 then
        ctx.say(Strings("But, it failed!"))
        return nil
      end
      return pool[ctx.rng(1, #pool)]
    end,
  })

  -- ------- Nature Power (calls Earthquake outdoors / default)

  mod.content.move_effects:register("EXP_NATURE_POWER_EFFECT", {
    kind = "full",
    callsMove = function(ctx)
      return "EARTHQUAKE"
    end,
  })

  -- ------- Sketch (permanently learn the foe's last move)

  mod.content.move_effects:register("EXP_SKETCH_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local last = ctx.target.lastMove
      if not last or last == "SKETCH" or last == "STRUGGLE"
          or last == "CHATTER" or last == "SHADOW_FORCE" then
        return { Strings("But, it failed!") }
      end
      local slot
      for _, mv in ipairs(ctx.user.curMoves or {}) do
        if mv.id == "SKETCH" then slot = mv break end
      end
      if not slot then return { Strings("But, it failed!") } end
      local def = ctx.data.moves[last]
      slot.id = last
      slot.pp = def and def.pp or 5
      -- Persist onto the party mon when possible
      if ctx.user.mon and ctx.user.mon.moves then
        for _, mv in ipairs(ctx.user.mon.moves) do
          if mv.id == "SKETCH" then
            mv.id = last
            mv.pp = slot.pp
            break
          end
        end
      end
      return { Strings("%s learned\n%s!", displayName(ctx.user),
        def and def.name or last) }
    end,
  })

  -- ------- Imprison (foe can't use moves you know)

  mod.content.move_effects:register("EXP_IMPRISON_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expImprison = true
      return { Strings("%s sealed\nthe opponent's moves!", displayName(ctx.user)) }
    end,
  })

  -- ------- Snatch (steal the next status move)

  mod.content.move_effects:register("EXP_SNATCH_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expSnatch = true
      return { Strings("%s waits for a\ntarget to make a move!", displayName(ctx.user)) }
    end,
  })

  -- ------- Secret Power (default: 30% chance to paralyze)

  mod.content.move_effects:register("EXP_SECRET_POWER_EFFECT", {
    kind = "secondary",
    run = function(ctx)
      if ctx.target.substituteHP then return {} end
      if ctx.rng(0, 255) >= 77 then return {} end -- ~30%
      return ctx.inflict(ctx.target, "PAR", {
        secondary = true, moveType = ctx.move.type, source = "SECRET_POWER",
      }) or {}
    end,
  })

  -- ------- Gastro Acid (suppress ability)

  mod.content.move_effects:register("EXP_GASTRO_ACID_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      if ctx.target.expAbilitySuppressed then
        return { Strings("But, it failed!") }
      end
      ctx.target.expAbilitySuppressed = true
      ctx.target.expTracedAbility = nil
      return { Strings("%s's ability\nwas suppressed!", displayName(ctx.target)) }
    end,
  })

  -- ------- Simple Beam (ability -> Simple: doubled stage changes)

  mod.content.move_effects:register("EXP_SIMPLE_BEAM_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      ctx.target.expTracedAbility = "SIMPLE"
      ctx.target.expAbilitySuppressed = nil
      return { Strings("%s acquired\nSIMPLE!", displayName(ctx.target)) }
    end,
  })

  -- ------- Entrainment (copy user's ability onto target)

  mod.content.move_effects:register("EXP_ENTRAINMENT_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local Ab = require("mods.Kanto-Reforged.battle.abilities")
      local a = Ab.abilityOf(ctx.battle, ctx.user)
      if not a then return { Strings("But, it failed!") } end
      ctx.target.expTracedAbility = a
      ctx.target.expAbilitySuppressed = nil
      return { Strings("%s made %s\nmatch its ability!",
        displayName(ctx.user), displayName(ctx.target)) }
    end,
  })

  -- ------- Power Trick (swap Attack and Defense)

  mod.content.move_effects:register("EXP_POWER_TRICK_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local s = ctx.user.stages
      s.attack, s.defense = s.defense or 0, s.attack or 0
      local cs = ctx.user.curStats
      cs.attack, cs.defense = cs.defense, cs.attack
      ctx.user.hazeStatReset = nil
      return { Strings("%s swapped its\nATTACK and DEFENSE!", displayName(ctx.user)) }
    end,
  })

  -- ------- Power Swap / Guard Swap / Speed Swap / Heart Swap

  mod.content.move_effects:register("EXP_POWER_SWAP_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local a, b = ctx.user.stages, ctx.target.stages
      a.attack, b.attack = b.attack or 0, a.attack or 0
      a.special, b.special = b.special or 0, a.special or 0
      ctx.user.hazeStatReset, ctx.target.hazeStatReset = nil, nil
      return { Strings("%s swapped all\nchanges to its\nATTACK and SP. ATK!", displayName(ctx.user)) }
    end,
  })

  mod.content.move_effects:register("EXP_GUARD_SWAP_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local a, b = ctx.user.stages, ctx.target.stages
      a.defense, b.defense = b.defense or 0, a.defense or 0
      ctx.user.hazeStatReset, ctx.target.hazeStatReset = nil, nil
      return { Strings("%s swapped all\nchanges to its\nDEFENSE!", displayName(ctx.user)) }
    end,
  })

  mod.content.move_effects:register("EXP_SPEED_SWAP_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local a, b = ctx.user.stages, ctx.target.stages
      a.speed, b.speed = b.speed or 0, a.speed or 0
      local ca, cb = ctx.user.curStats, ctx.target.curStats
      ca.speed, cb.speed = cb.speed, ca.speed
      ctx.user.hazeStatReset, ctx.target.hazeStatReset = nil, nil
      return { Strings("%s swapped\nSPEED with its target!", displayName(ctx.user)) }
    end,
  })

  -- ------- Clear Smog (reset target stages)

  mod.content.move_effects:register("EXP_CLEAR_SMOG_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      if not ctx.target or not ctx.target.stages then return end
      for k in pairs(ctx.target.stages) do
        ctx.target.stages[k] = 0
      end
      ctx.target.hazeStatReset = nil
      ctx.say(Strings("%s's stat changes\nwere removed!", displayName(ctx.target)))
    end,
  })

  -- ------- Charge (SpD up + next Electric move ×2)

  mod.content.move_effects:register("EXP_CHARGE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expCharged = true
      local msgs = applyStages(ctx, ctx.user, { { stat = "special", change = 1 } }, false)
      msgs[#msgs + 1] = Strings("%s began\ncharging power!", displayName(ctx.user))
      return msgs
    end,
  })

  -- ------- Lucky Chant (block crits; singles: protect user)

  mod.content.move_effects:register("EXP_LUCKY_CHANT_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = ctx.side(ctx.user)
      side.expLuckyChantTurns = 5
      return { Strings("The LUCKY CHANT\nshielded %s from\ncritical hits!", displayName(ctx.user)) }
    end,
  })

  -- ------- Tailwind (field Speed ×2 via Abilities.speedMult; no stage bump)

  mod.content.move_effects:register("EXP_TAILWIND_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = ctx.side(ctx.user)
      if (side.expTailwindTurns or 0) > 0 then
        return { Strings("But, it failed!") }
      end
      side.expTailwindTurns = 4
      return { Strings("The Tailwind blew from\nbehind %s!", displayName(ctx.user)) }
    end,
  })

  -- ------- Trick Room (invert turn order for a few turns)

  mod.content.move_effects:register("EXP_TRICK_ROOM_EFFECT", {
    kind = "primary",
    run = function(ctx)
      if ctx.battle.expTrickRoomTurns and ctx.battle.expTrickRoomTurns > 0 then
        ctx.battle.expTrickRoomTurns = nil
        return { Strings("The twisted dimensions\nreturned to normal!") }
      end
      ctx.battle.expTrickRoomTurns = 5
      return { Strings("%s twisted\nthe dimensions!", displayName(ctx.user)) }
    end,
  })

  -- ------- Healing Wish (faint; next switch-in fully healed)

  mod.content.move_effects:register("EXP_HEALING_WISH_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local side = ctx.side(ctx.user)
      side.expHealingWish = true
      ctx.user.mon.hp = 0
      if ctx.battle.onFaint then ctx.battle:onFaint(ctx.user) end
      return { Strings("%s's HEALING WISH\ncame true!", displayName(ctx.user)) }
    end,
  })

  -- ------- Memento (faint; harshly drop foe Atk/SpA)

  mod.content.move_effects:register("EXP_MEMENTO_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local msgs = applyStages(ctx, ctx.target, {
        { stat = "attack", change = -2 },
        { stat = "special", change = -2 },
      }, true)
      ctx.user.mon.hp = 0
      if ctx.battle.onFaint then ctx.battle:onFaint(ctx.user) end
      msgs[#msgs + 1] = Strings("%s went all out\nand fainted!", displayName(ctx.user))
      return msgs
    end,
  })

  -- ------- Conversion 2 (become a type that resists the foe's last move)

  mod.content.move_effects:register("EXP_CONVERSION_2_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local last = ctx.target.lastMove
      local move = last and ctx.data.moves[last]
      if not move or not move.type then
        return { Strings("But, it failed!") }
      end
      local TypeChart = require("src.battle.TypeChart")
      local candidates = {
        "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE", "FIGHTING",
        "POISON", "GROUND", "FLYING", "PSYCHIC_TYPE", "BUG", "ROCK",
        "GHOST", "DRAGON", "DARK", "STEEL",
      }
      local best, bestMult = nil, 10
      for _, t in ipairs(candidates) do
        local m = TypeChart.effectiveness(move.type, { t })
        if m < bestMult then
          bestMult, best = m, t
        end
      end
      if not best or bestMult >= 10 then
        return { Strings("But, it failed!") }
      end
      ctx.user.curTypes = { best }
      return { Strings("%s transformed\ninto the %s type!", displayName(ctx.user), best) }
    end,
  })

  -- ------- Me First (singles stand-in: copy foe's last move at 1.5x)

  mod.content.move_effects:register("EXP_ME_FIRST_EFFECT", {
    kind = "full",
    callsMove = function(ctx)
      local last = ctx.target.lastMove
      if not last or last == "ME_FIRST" or last == "COUNTER"
          or last == "MIRROR_COAT" or last == "PROTECT" or last == "DETECT" then
        ctx.say(Strings("But, it failed!"))
        return nil
      end
      ctx.user.expMeFirst = true
      return last
    end,
  })

  -- ------- Follow Me / Rage Powder (singles stand-in: +2 evasion)

  mod.content.move_effects:register("EXP_FOLLOW_ME_EFFECT", {
    kind = "primary",
    run = function(ctx)
      return applyStages(ctx, ctx.user, { { stat = "evasion", change = 2 } }, false)
    end,
  })

  -- ------- Ally Switch (singles stand-in: Protect this turn)

  mod.content.move_effects:register("EXP_ALLY_SWITCH_EFFECT", {
    kind = "primary",
    run = function(ctx)
      ctx.user.expProtected = true
      return { Strings("%s protected\nitself!", displayName(ctx.user)) }
    end,
  })

  -- ------- Trick / Switcheroo (swap held items)

  mod.content.move_effects:register("EXP_TRICK_EFFECT", {
    kind = "primary",
    accuracyChecked = true,
    run = function(ctx)
      local HeldItems = require("mods.Kanto-Reforged.items.held_items")
      local a = ctx.user.mon
      local b = ctx.target.mon
      if not a or not b then return { Strings("But, it failed!") } end
      if not a.heldItem and not b.heldItem then
        return { Strings("But, it failed!") }
      end
      a.heldItem, b.heldItem = b.heldItem, a.heldItem
      local msgs = { Strings("%s switched\nitems with its target!", displayName(ctx.user)) }
      -- Berry may immediately cure a status the recipient already has.
      HeldItems.tickStatusBerry(ctx.battle, ctx.user)
      HeldItems.tickStatusBerry(ctx.battle, ctx.target)
      return msgs
    end,
  })

  -- ------- Knock Off (remove held item after damage)

  mod.content.move_effects:register("EXP_KNOCK_OFF_EFFECT", {
    kind = "full",
    afterDamage = function(ctx)
      local HeldItems = require("mods.Kanto-Reforged.items.held_items")
      if not ctx.target or not ctx.target.mon or not ctx.target.mon.heldItem then
        return
      end
      if ctx.target.substituteHP then return end
      local id = HeldItems.consume(ctx.target.mon, ctx.target)
      if id then
        local def = HeldItems.def(id)
        ctx.say(Strings("%s knocked off\n%s's %s!",
          displayName(ctx.user), displayName(ctx.target),
          def and def.name or id))
      end
    end,
  })

  -- ------- Recycle (restore last consumed held item)

  mod.content.move_effects:register("EXP_RECYCLE_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local last = ctx.user.expLastConsumedItem
      if not last or (ctx.user.mon and ctx.user.mon.heldItem) then
        return { Strings("But, it failed!") }
      end
      ctx.user.mon.heldItem = last
      ctx.user.expLastConsumedItem = nil
      local HeldItems = require("mods.Kanto-Reforged.items.held_items")
      local def = HeldItems.def(last)
      return { Strings("%s found one\n%s!", displayName(ctx.user), def and def.name or last) }
    end,
  })

  -- ------- Bestow (give held item to foe if they have none)

  mod.content.move_effects:register("EXP_BESTOW_EFFECT", {
    kind = "primary",
    run = function(ctx)
      local a = ctx.user.mon
      local b = ctx.target.mon
      if not a or not a.heldItem or not b or b.heldItem then
        return { Strings("But, it failed!") }
      end
      b.heldItem = a.heldItem
      a.heldItem = nil
      local HeldItems = require("mods.Kanto-Reforged.items.held_items")
      local def = HeldItems.def(b.heldItem)
      local msgs = { Strings("%s gave its\n%s!", displayName(ctx.user), def and def.name or b.heldItem) }
      HeldItems.tickStatusBerry(ctx.battle, ctx.target)
      return msgs
    end,
  })
end

-- Battle wiring: Encore, Taunt, Attract, Fake Out, hazards, Safeguard,
-- Sturdy, Destiny Bond, Perish Song, residuals.
function MoveEffects.install(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2() then
    require("mods.Kanto-Reforged.battle.move_effects_gen2").install(mod)
    return
  end

  local BattleState = require("src.battle.BattleState")
  local StatusRegistry = require("src.battle.StatusRegistry")
  local Strings = require("src.core.Strings")
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")

  local original_fightLocked = BattleState.fightLockedAction
  BattleState.fightLockedAction = function(self, battler)
    local locked = original_fightLocked(self, battler)
    if locked then return locked end
    if battler.expEncoreTurns and battler.expEncoreTurns > 0 and battler.expEncoreMove then
      for _, mv in ipairs(battler.curMoves or {}) do
        if mv.id == battler.expEncoreMove and (mv.pp or 0) > 0 then
          return mv
        end
      end
      battler.expEncoreTurns = nil
      battler.expEncoreMove = nil
    end
    if battler.expUproarTurns and battler.expUproarTurns > 0 and battler.expUproarMove then
      return battler.expUproarMove
    end
    return nil
  end

  -- Rollout / Ice Ball: skip the battle menu like Thrash (forced continuations).
  local original_menuLocked = BattleState.menuLockedAction
  BattleState.menuLockedAction = function(self, battler)
    local locked = original_menuLocked(self, battler)
    if locked then return locked end
    if battler.expRolloutMove and (battler.expRollout or 0) > 0
        and (battler.expRollout or 0) < 5 then
      return battler.expRolloutMove
    end
    return nil
  end

  -- Clear Rollout lock on paralysis / confusion self-hit (same as Thrash).
  -- Also clear invulnerable alongside charging: the engine intentionally
  -- skips the invulnerable clear on full-paralysis interrupts (the famous
  -- Gen 1 Fly/Dig glitch), but that causes a permanent-underground softlock
  -- in this mod.  We always clear both together here so the mon can be hit
  -- normally after the charge is interrupted.
  local original_clearVolatiles = BattleState.clearVolatiles
  BattleState.clearVolatiles = function(self, user, selfHit)
    local wasCharging = user and user.charging
    original_clearVolatiles(self, user, selfHit)
    -- If charging was cleared (i.e. user had it before and lost it), also
    -- clear invulnerable regardless of selfHit so no ghost-underground state.
    if user and wasCharging and not user.charging then
      user.invulnerable = nil
    end
    if user then
      user.expRollout = nil
      user.expRolloutMove = nil
    end
  end

  -- Allow Sleep Talk / Snore while asleep; stash pending move id
  local original_execute = BattleState.executeAction
  BattleState.executeAction = function(self, user, target, action)
    if user and action and action.id then
      user.expPendingMove = action.id
    end
    original_execute(self, user, target, action)
    if user then user.expPendingMove = nil end
  end

  -- Sleep: keep Status.RECORDS in sync (fallback when no battle.data.statuses).
  do
    local Status = require("src.battle.Status")
    if Status.RECORDS and Status.RECORDS.SLP then
      Status.RECORDS.SLP.beforeMove = MoveEffects.sleepBeforeMove
      Status.RECORDS.SLP._expSleepModern = true
      Status.RECORDS.SLP._expSleepTalk = true
    end
    if Status.RECORDS and Status.RECORDS.FRZ then
      Status.RECORDS.FRZ.beforeMove = MoveEffects.freezeBeforeMove
    end
    if Status.RECORDS and Status.RECORDS.PSN then
      Status.RECORDS.PSN.canInflict = function(target)
        if not target then return false end
        for _, t in ipairs(target.curTypes or {}) do
          if t == "POISON" or t == "STEEL" then return false end
        end
        return true
      end
    end
  end

  -- After the loader merge, Data.statuses may still be the pre-patch table
  -- if install ran mid-entry; re-apply once mods finish loading.
  if mod and mod.events and not MoveEffects._expSleepLoadedHook then
    mod.events:on("mods.loaded", function()
      local Data = require("src.core.Data")
      local Status = require("src.battle.Status")
      if Data.statuses and Data.statuses.SLP then
        Data.statuses.SLP.beforeMove = MoveEffects.sleepBeforeMove
      end
      if Status.RECORDS and Status.RECORDS.SLP then
        Status.RECORDS.SLP.beforeMove = MoveEffects.sleepBeforeMove
      end
      if Data.statuses and Data.statuses.FRZ then
        Data.statuses.FRZ.beforeMove = MoveEffects.freezeBeforeMove
      end
      if Status.RECORDS and Status.RECORDS.FRZ then
        Status.RECORDS.FRZ.beforeMove = MoveEffects.freezeBeforeMove
      end
      local function canPoison(target)
        if not target then return false end
        for _, t in ipairs(target.curTypes or {}) do
          if t == "POISON" or t == "STEEL" then return false end
        end
        return true
      end
      if Data.statuses and Data.statuses.PSN then
        Data.statuses.PSN.canInflict = canPoison
      end
      if Status.RECORDS and Status.RECORDS.PSN then
        Status.RECORDS.PSN.canInflict = canPoison
      end
    end)
    MoveEffects._expSleepLoadedHook = true
  end

  -- Hyper Beam recharge path had its own Gen 1 sleep block (always lose the
  -- turn). Match wake-and-attack: still asleep skips; waking continues.
  if not BattleState._expSleepPreRecharge then
    local original_preRecharge = BattleState.preRechargeChecks
    BattleState.preRechargeChecks = function(self, user, target)
      local mon = user and user.mon
      if mon and mon.status == "SLP" then
        user.sleepTurns = (user.sleepTurns or 1) - 1
        if user.sleepTurns <= 0 then
          mon.status = nil
          self:sayNext(Strings("%s\nwoke up!", displayName(user)))
          return false -- woke: continue this speed slot (recharge / move)
        end
        self:statusOnomatopoeia(user, "sleep")
        return true -- still asleep: only this mon's beat is spent
      end
      if mon and mon.status == "FRZ" then
        local canMove, msgs = MoveEffects.freezeBeforeMove(user, self.rng, self)
        for _, m in ipairs(msgs or {}) do
          if self.sayStatusMsg then
            self:sayStatusMsg(user, m)
          else
            self:sayNext(m)
          end
        end
        return not canMove
      end
      return original_preRecharge(self, user, target)
    end
    BattleState._expSleepPreRecharge = true
  end

  local original_perform = BattleState.performMove
  BattleState.performMove = function(self, user, target, moveInst, isCalled)
    local move = self:moveDef(moveInst)
    local function announceFail(msg)
      local enemyUnlimited = not user.isPlayer and self.kind ~= "link"
          and self.ruleset and self.ruleset.enemyUnlimitedPP
      if not isCalled and not enemyUnlimited and not (moveInst and moveInst.struggle) then
        moveInst.pp = math.max(0, (moveInst.pp or 1) - 1)
      end
      self:sayNext(Strings("%s\nused %s!",
        user.isPlayer and user.name or ("Enemy " .. user.name),
        move and move.name or "?"))
      self:sayNext(msg)
    end

    if move and user.expTauntedTurns and user.expTauntedTurns > 0
        and (move.power or 0) == 0 then
      announceFail(Strings("%s can't use\n%s after the TAUNT!",
        user.isPlayer and user.name or ("Enemy " .. user.name), move.name))
      return
    end

    -- Torment: cannot select the same move twice in a row
    if move and user.expTormented and user.expTormentLast == move.id and not isCalled then
      announceFail(Strings("%s can't use the\nsame move twice!",
        user.isPlayer and user.name or ("Enemy " .. user.name)))
      return
    end

    -- Imprison: can't use a move the imprisoner also knows
    if move and target and target.expImprison and not isCalled then
      for _, mv in ipairs(target.curMoves or {}) do
        if mv.id == move.id then
          announceFail(Strings("%s can't use the\nsealed %s!",
            user.isPlayer and user.name or ("Enemy " .. user.name), move.name))
          return
        end
      end
    end
    -- Also check if USER is imprisoned by the foe
    if move and user and not isCalled then
      local foe = user.isPlayer and self.enemy or self.player
      if foe and foe.expImprison then
        for _, mv in ipairs(foe.curMoves or {}) do
          if mv.id == move.id then
            announceFail(Strings("%s can't use the\nsealed %s!",
              user.isPlayer and user.name or ("Enemy " .. user.name), move.name))
            return
          end
        end
      end
    end

    -- Snatch: steal foe's status move
    if move and (move.power or 0) == 0 and target and target.expSnatch and not isCalled
        and move.id ~= "SNATCH" then
      target.expSnatch = nil
      self:sayNext(Strings("%s snatched\n%s's move!",
        target.isPlayer and target.name or ("Enemy " .. target.name),
        user.isPlayer and user.name or ("Enemy " .. user.name)))
      original_perform(self, target, user, moveInst, true)
      return
    end

    -- Damp: block Explosion / Selfdestruct
    if move and (move.effect == "EXPLODE_EFFECT"
        or move.id == "EXPLOSION" or move.id == "SELFDESTRUCT"
        or move.id == "SELF_DESTRUCT") then
      for _, b in ipairs({ self.player, self.enemy }) do
        if Abilities.abilityOf(self, b) == "DAMP" then
          announceFail(Strings("%s cannot use\n%s because of DAMP!",
            user.isPlayer and user.name or ("Enemy " .. user.name),
            move.name))
          return
        end
      end
    end

    -- Soundproof: block sound moves targeting the holder
    if move and target and Abilities.isSoundMove(move.id)
        and Abilities.abilityOf(self, target) == "SOUNDPROOF"
        and user ~= target then
      announceFail(Strings("It doesn't affect\n%s!",
        target.isPlayer and target.name or ("Enemy " .. target.name)))
      return
    end

    -- Magic Coat: bounce status moves
    if move and target and target.expMagicCoat and not isCalled
        and (move.power or 0) == 0 and move.id ~= "MAGIC_COAT"
        and move.id ~= "SKETCH" and move.id ~= "ROLE_PLAY"
        and move.id ~= "SKILL_SWAP" and move.id ~= "PSYCH_UP" then
      target.expMagicCoat = nil
      self:sayNext(Strings("%s bounced the\n%s back!",
        target.isPlayer and target.name or ("Enemy " .. target.name),
        move.name))
      local ppBefore = moveInst and moveInst.pp
      original_perform(self, target, user, moveInst, true)
      if ppBefore and moveInst and moveInst.pp and moveInst.pp == ppBefore
          and not (moveInst.struggle) then
        -- bounced call shouldn't refund; original_perform with isCalled skips PP
        moveInst.pp = math.max(0, (ppBefore or 1) - 1)
      end
      return
    end

    local ppBefore = moveInst and moveInst.pp
    -- Rollout / Ice Ball: PP only on the first hit of a set (like Thrash).
    local rolloutCont = user and moveInst and user.expRolloutMove == moveInst
        and (user.expRollout or 0) > 0
    self.expCurrentMoveDef = move
    original_perform(self, user, target, moveInst, isCalled)
    self.expCurrentMoveDef = nil
    if rolloutCont and moveInst and ppBefore and moveInst.pp and moveInst.pp < ppBefore then
      moveInst.pp = ppBefore
    end

    -- Pressure: extra PP when targeting a Pressure holder
    if ppBefore and moveInst and moveInst.pp and moveInst.pp < ppBefore
        and target and user ~= target and not isCalled
        and Abilities.abilityOf(self, target) == "PRESSURE" then
      moveInst.pp = math.max(0, moveInst.pp - 1)
    end

    -- Torment tracking
    if move and user.expTormented and not isCalled then
      user.expTormentLast = move.id
    end
  end

  local original_inflict = StatusRegistry.inflict
  StatusRegistry.inflict = function(battle, target, status, opts)
    opts = opts or {}
    local side = battle and battle.sideOf and battle:sideOf(target)
    if side and side.expSafeguardTurns and side.expSafeguardTurns > 0 then
      return {}
    end
    local ability = Abilities.abilityOf(battle, target)
    if ability == "INSOMNIA" or ability == "VITAL_SPIRIT" then
      if status == "SLP" then return {} end
    end
    -- Uproar prevents sleep
    if status == "SLP" and battle and battle.expUproarActive then
      return {}
    end
    if ability == "LIMBER" and status == "PAR" then return {} end
    -- Fire / Electric status moves only (not Flame Body / Static secondaries)
    if ability == "FLASH_FIRE" and status == "BRN"
        and opts.moveType == "FIRE" and not opts.secondary then
      return {}
    end
    if ability == "LIGHTNING_ROD" and status == "PAR"
        and opts.moveType == "ELECTRIC" and not opts.secondary then
      return {}
    end
    if ability == "MAGMA_ARMOR" and status == "FRZ" then return {} end
    if ability == "WATER_VEIL" and status == "BRN" then return {} end
    if ability == "IMMUNITY" and status == "PSN" then return {} end
    if ability == "OWN_TEMPO" and status == "CONFUSION" then return {} end

    -- Shield Dust: block secondary statuses from damaging moves
    if opts.secondary and ability == "SHIELD_DUST" then
      return {}
    end

    local msgs = original_inflict(battle, target, status, opts)

    -- Early Bird: halve sleep duration
    if msgs and #msgs > 0 and status == "SLP"
        and Abilities.abilityOf(battle, target) == "EARLY_BIRD"
        and target.sleepTurns then
      target.sleepTurns = math.max(1, math.ceil(target.sleepTurns / 2))
    end

    if msgs and #msgs > 0 and Abilities.abilityOf(battle, target) == "SYNCHRONIZE"
        and (status == "PAR" or status == "BRN" or status == "PSN") then
      local source = opts.expSourceBattler
      if not source and battle then
        source = (target.isPlayer and battle.enemy) or battle.player
      end
      if source and source.mon and not source.mon.status then
        original_inflict(battle, source, status, { secondary = true, source = "SYNCHRONIZE" })
      end
    end
    return msgs
  end

  local original_applyDamage = BattleState.applyDamage
  BattleState.applyDamage = function(self, target, dmg)
    if target and target.mon and not target.substituteHP and dmg and dmg > 0 then
      local ability = Abilities.abilityOf(self, target)
      if ability == "STURDY"
          and target.mon.hp == target.mon.stats.hp
          and dmg >= target.mon.hp then
        dmg = target.mon.hp - 1
        self:sayNext(Strings("%s held on\nusing its STURDY!",
          target.isPlayer and target.name or ("Enemy " .. target.name)))
      elseif target.expEnduring and dmg >= target.mon.hp then
        dmg = target.mon.hp - 1
        self:sayNext(Strings("%s endured\nthe hit!",
          target.isPlayer and target.name or ("Enemy " .. target.name)))
      end
    end
    local beforeHp = target and target.mon and target.mon.hp
    local dealt = original_applyDamage(self, target, dmg)
    if dealt and dealt > 0 and target then
      target.expTookDamageThisTurn = true
      if beforeHp and target.mon and target.mon.hp < beforeHp then
        MoveEffects.thawTargetFromFire(self, target, self.expCurrentMoveDef)
      end
    end
    return dealt
  end

  local original_onFaint = BattleState.onFaint
  BattleState.onFaint = function(self, battler)
    if battler and battler.expGrudge then
      battler.expGrudge = nil
      local foe = battler.isPlayer and self.enemy or self.player
      if foe and foe.lastMove then
        for _, mv in ipairs(foe.curMoves or {}) do
          if mv.id == foe.lastMove then
            mv.pp = 0
            self:sayNext(Strings("%s's %s\nlost all its PP\ndue to the GRUDGE!",
              foe.isPlayer and foe.name or ("Enemy " .. foe.name),
              foe.lastMove))
            break
          end
        end
      end
    end
    if battler and battler.expDestinyBond then
      battler.expDestinyBond = nil
      local foe = battler.isPlayer and self.enemy or self.player
      if foe and foe.mon and foe.mon.hp > 0 and not foe.faintQueued then
        self:sayNext(Strings("%s took\n%s with it!",
          battler.isPlayer and battler.name or ("Enemy " .. battler.name),
          foe.isPlayer and foe.name or ("Enemy " .. foe.name)))
        foe.mon.hp = 0
        original_onFaint(self, foe)
      end
    end
    return original_onFaint(self, battler)
  end

  -- Baton Pass / U-turn: open party after the turn; skip foe free hit on switch
  local original_endOfTurn = BattleState.endOfTurn
  BattleState.endOfTurn = function(self)
    original_endOfTurn(self)
    if self.result then return end
    local p = self.player
    if p and (p.expPendingBatonOpen or p.expWantsSwitch) and p.mon and p.mon.hp > 0 then
      p.expPendingBatonOpen = nil
      self:openParty()
    end
  end

  local original_resolveSwitch = BattleState.resolveSwitch
  BattleState.resolveSwitch = function(self, newMon)
    local skipFree = (self.player and self.player.expBatonPass)
        or (self.player and self.player.expWantsSwitch)
    if self.player then
      self.player.expWantsSwitch = nil
      self.player.expPendingBatonOpen = nil
    end
    if skipFree then
      self.expSkipNextEnemyAction = true
    end
    return original_resolveSwitch(self, newMon)
  end

  -- already wrapped executeAction above; extend skip-free-hit
  local prev_execute = BattleState.executeAction
  BattleState.executeAction = function(self, user, target, action)
    if self.expSkipNextEnemyAction and user and not user.isPlayer then
      self.expSkipNextEnemyAction = nil
      return
    end
    return prev_execute(self, user, target, action)
  end

  -- Clear Body / White Smoke / Hyper Cutter / Keen Eye: block enemy stage drops
  local VanillaME = require("src.battle.MoveEffects")
  local original_changeStage = VanillaME.changeStage
  VanillaME.changeStage = function(battle, who, stat, delta, fromEnemy)
    if fromEnemy and delta < 0 and who and who.mon then
      local ability = Abilities.abilityOf(battle, who)
      if ability == "CLEAR_BODY" or ability == "WHITE_SMOKE" then
        return { Strings("%s's %s\nprevents stat loss!",
          who.isPlayer and who.name or ("Enemy " .. who.name),
          ability:gsub("_", " ")) }
      end
      if ability == "HYPER_CUTTER" and stat == "attack" then
        return { Strings("%s's HYPER CUTTER\nprevents ATTACK loss!",
          who.isPlayer and who.name or ("Enemy " .. who.name)) }
      end
      if ability == "KEEN_EYE" and stat == "accuracy" then
        return { Strings("%s's KEEN EYE\nprevents accuracy loss!",
          who.isPlayer and who.name or ("Enemy " .. who.name)) }
      end
    end
    -- Simple: double stage changes
    if who and Abilities.abilityOf(battle, who) == "SIMPLE" and delta and delta ~= 0 then
      delta = delta * 2
      if delta > 6 then delta = 6 end
      if delta < -6 then delta = -6 end
    end
    return original_changeStage(battle, who, stat, delta, fromEnemy)
  end

  -- Liquid Ooze: drain heals become damage
  local function patchDrain(effectId)
    local Data = require("src.core.Data")
    local rec = Data.move_effects and Data.move_effects[effectId]
    if rec and rec.afterDamage and not rec._expLiquidOoze then
      local old = rec.afterDamage
      rec.afterDamage = function(ctx)
        if Abilities.abilityOf(ctx.battle, ctx.target) == "LIQUID_OOZE" then
          local dmg = math.max(1, math.floor((ctx.rawDamage or 0) / 2))
          ctx.say(Strings("%s sucked up the\nLIQUID OOZE!",
            ctx.user.isPlayer and ctx.user.name or ("Enemy " .. ctx.user.name)))
          ctx.battle:applyDamage(ctx.user, dmg)
          if ctx.user.mon.hp <= 0 then ctx.battle:onFaint(ctx.user) end
          return
        end
        return old(ctx)
      end
      rec._expLiquidOoze = true
    end
  end

  -- Suction Cups: immune to Roar / Whirlwind forced flee
  local function patchSuctionCups()
    local Data = require("src.core.Data")
    local sw = Data.move_effects and Data.move_effects.SWITCH_AND_TELEPORT_EFFECT
    if sw and sw.perform and not sw._expSuctionCups then
      local old = sw.perform
      sw.perform = function(ctx)
        if ctx.move and (ctx.move.id == "ROAR" or ctx.move.id == "WHIRLWIND")
            and Abilities.abilityOf(ctx.battle, ctx.target) == "SUCTION_CUPS" then
          if ctx.battle.cancelMoveAnim then ctx.battle:cancelMoveAnim() end
          ctx.say(Strings("%s anchors itself\nwith SUCTION CUPS!",
            ctx.target.isPlayer and ctx.target.name or ("Enemy " .. ctx.target.name)))
          return
        end
        return old(ctx)
      end
      sw._expSuctionCups = true
    end
  end

  -- Shield Dust / Serene Grace: wrap secondary move-effect runs
  local function patchSecondaries()
    local Data = require("src.core.Data")
    for id, rec in pairs(Data.move_effects or {}) do
      if rec.kind == "secondary" and rec.run and not rec._expShieldSerene then
        local old = rec.run
        local isExp = type(id) == "string" and id:sub(1, 4) == "EXP_"
        rec.run = function(ctx)
          if Abilities.abilityOf(ctx.battle, ctx.target) == "SHIELD_DUST" then
            return {}
          end
          local msgs = old(ctx)
          -- Vanilla secondaries: Serene Grace ≈ true 2× by retrying only when
          -- the first roll produced no effect messages (chance miss).
          -- EXP_* secondaries double their chance parameter themselves.
          if not isExp and (not msgs or #msgs == 0)
              and Abilities.abilityOf(ctx.battle, ctx.user) == "SERENE_GRACE" then
            msgs = old(ctx)
          end
          return msgs or {}
        end
        rec._expShieldSerene = true
      end
    end
  end

  local function patchAbilityEffects()
    patchDrain("DRAIN_HP_EFFECT")
    patchDrain("DREAM_EATER_EFFECT")
    patchSuctionCups()
    patchSecondaries()
  end
  mod.events:on("game.ready", function() patchAbilityEffects() end)
  patchAbilityEffects()

  mod.events:on("battle.battler_switched", function(ev)
    if ev.battle and ev.previous and ev.previous.mon then
      if Abilities.abilityOf(ev.battle, ev.previous) == "NATURAL_CURE" then
        ev.previous.mon.status = nil
      end
      -- Infatuation ends when the Pokémon that caused it leaves.
      local other = ev.previous.isPlayer and ev.battle.enemy or ev.battle.player
      if other then other.expInfatuated = nil end
    end
    if ev.battle and ev.battler then
      local pass = ev.previous and ev.previous.expBatonPass
      if ev.previous then ev.previous.expBatonPass = nil end
      ev.battler.expJustEntered = true
      ev.battler.expTrapped = nil
      ev.battler.expCursed = nil
      ev.battler.expYawnTurns = nil
      ev.battler.expDestinyBond = nil
      ev.battler.expIngrain = nil
      ev.battler.expAquaRing = nil
      ev.battler.expStockpile = nil
      ev.battler.expInfatuated = nil
      ev.battler.expNightmare = nil
      ev.battler.expFuryCutter = nil
      ev.battler.expRollout = nil
      ev.battler.expRolloutMove = nil
      ev.battler.expLockedOn = nil
      ev.battler.expMagicCoat = nil
      ev.battler.expGrudge = nil
      ev.battler.expTormented = nil
      ev.battler.expTormentLast = nil
      ev.battler.expUproarTurns = nil
      ev.battler.expUproarMove = nil
      ev.battler.expImprison = nil
      ev.battler.expSnatch = nil
      ev.battler.expCharged = nil
      ev.battler.expAbilitySuppressed = nil
      ev.battler.expMeFirst = nil
      if pass then
        ev.battler.stages = pass.stages or ev.battler.stages
        ev.battler.confusedTurns = pass.confusedTurns
        ev.battler.focusEnergy = pass.focusEnergy
        ev.battler.substituteHP = pass.substituteHP
        ev.battler.expIngrain = pass.expIngrain
        ev.battler.expAquaRing = pass.expAquaRing
        ev.battler.expPerishTurns = pass.expPerishTurns
        ev.battler.expCursed = pass.expCursed
        ev.battler.expTrapped = pass.expTrapped
        ev.battler.leechSeeded = pass.leechSeeded
      end
      -- Healing Wish: full heal on switch-in
      if ev.side and ev.side.expHealingWish and ev.battler.mon then
        ev.side.expHealingWish = nil
        local mon = ev.battler.mon
        mon.hp = mon.stats.hp
        mon.status = nil
        ev.battler.toxicCounter = nil
        if ev.battle.sayNext then
          ev.battle:sayNext(Strings("The HEALING WISH came true!\n%s recovered!",
            ev.battler.isPlayer and ev.battler.name or ("Enemy " .. ev.battler.name)))
        end
      end
      if ev.side then
        MoveEffects.applyHazards(ev.battle, ev.battler, ev.side)
      end
    end
  end)

  mod.events:on("battle.started", function(ev)
    if not ev.battle then return end
    for _, b in ipairs({ ev.battle.player, ev.battle.enemy }) do
      if b then
        b.expJustEntered = true
        b.expInfatuated = nil
      end
    end
  end)

  mod.events:on("battle.move_used", function(ev)
    if not ev.battle or not ev.user then return end
    local user = ev.user
    user.expDestinyBond = nil -- Destiny Bond lasts until you move again
    if ev.move and ev.move.id == "DESTINY_BOND" then
      user.expDestinyBond = true
    end
    user.expActedThisTurn = true
    if user.expEncoreTurns and user.expEncoreTurns > 0 then
      user.expEncoreTurns = user.expEncoreTurns - 1
      if user.expEncoreTurns <= 0 then
        user.expEncoreTurns = nil
        user.expEncoreMove = nil
      end
    end
    -- Reset Fury Cutter when using a different move
    if ev.move and ev.move.id ~= "FURY_CUTTER" then
      user.expFuryCutter = nil
    end
  end)

  mod.events:on("battle.turn_started", function(ev)
    if not ev.battle then return end
    for _, b in ipairs({ ev.battle.player, ev.battle.enemy }) do
      if b then
        b.expTookDamageThisTurn = nil
        b.expActedThisTurn = nil
        b.expMagicCoat = nil
        -- Inner Focus: clear flinch
        if Abilities.abilityOf(ev.battle, b) == "INNER_FOCUS" then
          b.flinched = nil
        end
      end
    end
  end)

  mod.events:on("battle.turn_ended", function(ev)
    if not ev.battle then return end
    local battle = ev.battle
    local function tickBattler(b)
      if not b or not b.mon then return end
      b.expJustEntered = nil
      if b.expTauntedTurns and b.expTauntedTurns > 0 then
        b.expTauntedTurns = b.expTauntedTurns - 1
        if b.expTauntedTurns <= 0 then b.expTauntedTurns = nil end
      end
      if b.expYawnTurns and b.expYawnTurns > 0 then
        b.expYawnTurns = b.expYawnTurns - 1
        if b.expYawnTurns <= 0 then
          b.expYawnTurns = nil
          if b.mon.hp > 0 and not b.mon.status then
            local msgs = StatusRegistry.inflict(battle, b, "SLP", { source = "YAWN" })
            for _, m in ipairs(msgs or {}) do
              if battle.sayNext then battle:sayNext(m) end
            end
          end
        end
      end
      if b.expCursed and b.mon.hp > 0 then
        local dmg = math.max(1, math.floor(b.mon.stats.hp / 4))
        battle:applyDamage(b, dmg)
        if battle.sayNext then
          battle:sayNext(Strings("%s is afflicted\nby the CURSE!",
            b.isPlayer and b.name or ("Enemy " .. b.name)))
        end
        if b.mon.hp <= 0 then battle:onFaint(b) end
      end
      if b.expNightmare and b.mon.hp > 0 then
        if b.mon.status ~= "SLP" then
          b.expNightmare = nil
        else
          local dmg = math.max(1, math.floor(b.mon.stats.hp / 4))
          battle:applyDamage(b, dmg)
          if battle.sayNext then
            battle:sayNext(Strings("%s is locked\nin a NIGHTMARE!",
              b.isPlayer and b.name or ("Enemy " .. b.name)))
          end
          if b.mon.hp <= 0 then battle:onFaint(b) end
        end
      end
      if b.mon.hp > 0 and (b.expIngrain or b.expAquaRing) then
        if (b.expHealBlockTurns or 0) <= 0 then
          local heal = math.max(1, math.floor(b.mon.stats.hp / 16))
          if b.mon.hp < b.mon.stats.hp then
            b.mon.hp = math.min(b.mon.stats.hp, b.mon.hp + heal)
            if battle.sayNext then
              battle:sayNext(Strings("%s restored a little\nHP!",
                b.isPlayer and b.name or ("Enemy " .. b.name)))
            end
          end
        end
      end
      if b.expEmbargoTurns and b.expEmbargoTurns > 0 then
        b.expEmbargoTurns = b.expEmbargoTurns - 1
        if b.expEmbargoTurns <= 0 then b.expEmbargoTurns = nil end
      end
      if b.expHealBlockTurns and b.expHealBlockTurns > 0 then
        b.expHealBlockTurns = b.expHealBlockTurns - 1
        if b.expHealBlockTurns <= 0 then b.expHealBlockTurns = nil end
      end
      if b.expPerishTurns and b.mon.hp > 0 then
        b.expPerishTurns = b.expPerishTurns - 1
        if battle.sayNext then
          battle:sayNext(Strings("%s's perish count\nfell to %d!",
            b.isPlayer and b.name or ("Enemy " .. b.name),
            math.max(0, b.expPerishTurns)))
        end
        if b.expPerishTurns <= 0 then
          b.mon.hp = 0
          battle:onFaint(b)
        end
      end
      -- Shed Skin
      if b.mon.hp > 0 and b.mon.status
          and Abilities.abilityOf(battle, b) == "SHED_SKIN"
          and (battle.rng or math.random)(0, 99) < 30 then
        b.mon.status = nil
        b.toxicCounter = nil
        if battle.sayNext then
          battle:sayNext(Strings("%s's SHED SKIN\ncured its status!",
            b.isPlayer and b.name or ("Enemy " .. b.name)))
        end
      end
    end
    tickBattler(battle.player)
    tickBattler(battle.enemy)
    for _, side in ipairs(battle.sides or {}) do
      if side.expSafeguardTurns and side.expSafeguardTurns > 0 then
        side.expSafeguardTurns = side.expSafeguardTurns - 1
        if side.expSafeguardTurns <= 0 then side.expSafeguardTurns = nil end
      end
      if side.expLuckyChantTurns and side.expLuckyChantTurns > 0 then
        side.expLuckyChantTurns = side.expLuckyChantTurns - 1
        if side.expLuckyChantTurns <= 0 then side.expLuckyChantTurns = nil end
      end
      if side.expTailwindTurns and side.expTailwindTurns > 0 then
        side.expTailwindTurns = side.expTailwindTurns - 1
        if side.expTailwindTurns <= 0 then side.expTailwindTurns = nil end
      end
    end
    if battle.expTrickRoomTurns and battle.expTrickRoomTurns > 0 then
      battle.expTrickRoomTurns = battle.expTrickRoomTurns - 1
      if battle.expTrickRoomTurns <= 0 then
        battle.expTrickRoomTurns = nil
        if battle.sayNext then
          battle:sayNext(Strings("The twisted dimensions\nreturned to normal!"))
        end
      end
    end
  end)
end

return MoveEffects
