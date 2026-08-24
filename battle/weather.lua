-- Gen 3 weather on top of existing battle primitives.
-- Gold already has HandleWeather / ANIM_IN_SANDSTORM / sun+rain type mods;
-- this module does not replace that path.  It overlays 1/16 chip, ability
-- weather, hail, Gen 1 residuals, and 18-tile-safe residual text.

local Strings = require("src.core.Strings")
local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
local Rules = require("mods.Kanto-Reforged.battle.core.rules")

local Weather = {}

Weather.MOVE_TURNS = 5
Weather.SAND_IMMUNE = { ROCK = true, GROUND = true, STEEL = true }
Weather.HAIL_IMMUNE = { ICE = true }
-- Back-compat alias used by tests.
Weather.IMMUNE = Weather.SAND_IMMUNE

Weather.CONTINUE_TEXT = {
  SUNNY = "The sunlight is\nstrong.",
  RAINY = "Rain continues\nto fall.",
  SANDSTORM = "The sandstorm\nrages.",
  HAIL = "Hail continues\nto fall.",
  SNOWY = "Hail continues\nto fall.",
}

Weather.END_TEXT = {
  SUNNY = "The sunlight\nfaded.",
  RAINY = "The rain stopped.",
  SANDSTORM = "The sandstorm\nsubsided.",
  HAIL = "The hail stopped.",
  SNOWY = "The hail stopped.",
}

Weather.TYPE_MODS = {
  SUNNY = { FIRE = 1.5, WATER = 0.5 },
  RAINY = { WATER = 1.5, FIRE = 0.5 },
}

Weather.TICK_ANIM = "IN_SANDSTORM"
Weather.FIELD_ANIM = {
  SANDSTORM = "IN_SANDSTORM",
  RAINY = "IN_RAIN",
  HAIL = "IN_HAIL",
  SNOWY = "IN_HAIL",
  SUNNY = "IN_SUN",
}
-- Gold field residuals use ANIM_* ids (AnimRunner), not Gen1 IN_* seq clips.
Weather.FIELD_ANIM_GEN2 = {
  SANDSTORM = "ANIM_IN_SANDSTORM",
  HAIL = "ANIM_IN_HAIL",
  SNOWY = "ANIM_IN_HAIL",
}

local WEATHER_HEAL = {
  SYNTHESIS = true, MORNING_SUN = true, MOONLIGHT = true,
}

function Weather.chipAmount(maxHp)
  return Rules.weather.chipAmount(maxHp)
end

-- 18-tile battle box. Keep the name on its own line so
-- "Enemy TAILLOW is buffeted..." cannot clip mid-word.
function Weather.chipText(name, kind)
  name = name or "POKéMON"
  if kind == "HAIL" or kind == "SNOWY" then
    return Strings("%s\nis pelted by\vthe hail!", name)
  end
  return Strings("%s\nis buffeted by\vthe sandstorm!", name)
end

function Weather.rewrittenChipText(text)
  if type(text) ~= "string" then return text end
  local name = text:match("^(.*) is buffeted by the sandstorm!")
  if name then return Weather.chipText(name, "SANDSTORM") end
  name = text:match("^(.*) is pelted by the hail!")
  if name then return Weather.chipText(name, "HAIL") end
  return text
end

function Weather.current(battle)
  if Weather.suppressed(battle) then return nil end
  return BattleCompat.getWeather(battle)
end

function Weather.suppressed(battle)
  if not battle then return false end
  local ok, Abilities = pcall(require, "mods.Kanto-Reforged.battle.abilities")
  if not ok or not Abilities or not Abilities.abilityOf then return false end
  local a = Abilities.abilityOf(battle, battle.player)
  local b = Abilities.abilityOf(battle, battle.enemy)
  return a == "AIR_LOCK" or a == "CLOUD_NINE" or b == "AIR_LOCK" or b == "CLOUD_NINE"
end

function Weather.typeModifier(battle, moveType)
  return Rules.weather.typeModifier(Weather.current(battle), moveType)
end

function Weather.neverMiss(battle, move)
  if not move then return false end
  return Rules.weather.neverMiss(Weather.current(battle), move.id)
end

function Weather.instantCharge(battle, move)
  if not move then return false end
  return Rules.weather.instantCharge(Weather.current(battle), move.id)
end

function Weather.healFraction(battle)
  return Rules.weather.healFraction(Weather.current(battle))
end

function Weather.isWeatherHeal(moveId)
  return WEATHER_HEAL[moveId] == true
end

local function vanished(battle, battler)
  if battler.invulnerable then return true end
  if battle and BattleCompat.isGen2(battle) and type(battle.volatile) == "function" then
    local ok, vol = pcall(function() return battle:volatile(battler) end)
    if ok and vol and vol.vanished then return true end
  end
  return false
end

function Weather.hits(battle, battler, kind)
  if not battler then return false end
  local mon = BattleCompat.mon(battler)
  if not mon or (mon.hp or 0) <= 0 then return false end
  if vanished(battle, battler) then return false end
  kind = kind or "SANDSTORM"
  local types = BattleCompat.types(battler, battle and battle.data)
  return Rules.weather.hits(types, kind)
end

function Weather.tickSeq(kind)
  kind = kind or "SANDSTORM"
  if kind == "SUNNY" then
    return {
      { effect = "SE_LIGHT_SCREEN_PALETTE" },
      { effect = "SE_SPIRAL_BALLS_INWARD" },
      { effect = "SE_RESET_SCREEN_PALETTE" },
    }
  end
  if kind == "RAINY" then
    return { { effect = "SE_WATER_DROPLETS_EVERYWHERE" } }
  end
  if kind == "HAIL" or kind == "SNOWY" then
    return {
      { subanim = 47, tileset = 0, delay = 6, sound = "ICE_BEAM" },
      { effect = "SE_DARK_SCREEN_FLASH" },
    }
  end
  return {
    { subanim = 40, tileset = 0, delay = 4, sound = "SAND_ATTACK" },
    { effect = "SE_SHAKE_SCREEN" },
  }
end

function Weather.registerAnims(mod)
  if not (mod and mod.content and mod.content.battle_anims) then return end
  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen2From(mod) then
    -- Hail field residual: MoveAnims.registerGen2 patches ANIM_IN_HAIL.
    return
  end
  local recs = {
    IN_SANDSTORM = { seq = Weather.tickSeq("SANDSTORM"), source = "custom:in_sandstorm" },
    IN_RAIN = { seq = Weather.tickSeq("RAINY"), source = "custom:in_rain" },
    IN_HAIL = { seq = Weather.tickSeq("HAIL"), source = "custom:in_hail" },
    IN_SUN = { seq = Weather.tickSeq("SUNNY"), source = "custom:in_sun" },
  }
  for id, rec in pairs(recs) do
    pcall(function()
      mod.content.battle_anims:register(id, rec)
    end)
  end
end

function Weather.playTickAnim(battle, kind)
  kind = kind or "SANDSTORM"
  if BattleCompat.isGen2(battle) then
    local animId = Weather.FIELD_ANIM_GEN2[kind]
    if animId and battle and type(battle.emit) == "function" then
      local mon = battle.enemy
      local hp = mon and (mon.hp or BattleCompat.hp(mon)) or 0
      battle:emit({
        kind = "damage", side = "enemy", amount = 0, hp = hp, anim = animId,
      })
    end
    return
  end
  local id = Weather.FIELD_ANIM[kind] or Weather.TICK_ANIM
  if battle and type(battle.animNext) == "function" then
    battle:animNext(id, true)
  end
end

function Weather.refreshSprite(battle, battler)
  if not battle or not battler then return end
  if BattleCompat.isGen2(battle) then return end -- Gold pic() is live each frame
  if BattleCompat.species(battler) ~= "CASTFORM" then return end
  local isPlayer = battler.isPlayer or battler == battle.player
  if type(battle.speciesSprite) == "function" then
    local ok, spr = pcall(function() return battle:speciesSprite("CASTFORM", isPlayer) end)
    if ok and spr then
      battler.sprite = spr
      return
    end
  end
  local okS, Sprites = pcall(require, "src.pokemon.Sprites")
  if not okS or not Sprites or not Sprites.path then return end
  local path = select(1, Sprites.path(battle.data, "CASTFORM",
    isPlayer and "back" or "front",
    { mon = BattleCompat.mon(battler), kind = "battle" }))
  if not path then return end
  pcall(function()
    if love and love.graphics and love.graphics.newImage then
      battler.sprite = love.graphics.newImage(path)
    end
  end)
end

-- Gen 3 residual runs only while both active mons are still in the
-- fight.  After a KO the faint/EXP script owns the queue; weather must
-- not keep chipping there (Ruby/Sapphire end the turn script on a
-- decided wild/trainer sweep).
function Weather.shouldResidual(battle)
  if not battle then return false end
  if battle.result or battle.over then return false end
  if BattleCompat.hp(battle.player) <= 0 then return false end
  if BattleCompat.hp(battle.enemy) <= 0 then return false end
  return true
end

function Weather.chipBattler(battle, battler, kind)
  kind = kind or "SANDSTORM"
  if not Weather.hits(battle, battler, kind) then return 0 end
  local dmg = Weather.chipAmount(BattleCompat.maxHp(battler))
  local mon = BattleCompat.mon(battler)
  mon.hp = math.max(0, (mon.hp or 0) - dmg)
  BattleCompat.say(battle, Weather.chipText(
    BattleCompat.displayName(battle, battler), kind))
  if battle and type(battle.drainNext) == "function" then
    battle:drainNext(battler, mon.hp)
  end
  if mon.hp <= 0 and battle and type(battle.onFaint) == "function" then
    battle:onFaint(battler)
  end
  return dmg
end

local function forecast(battle)
  local ok, Abilities = pcall(require, "mods.Kanto-Reforged.battle.abilities")
  if not ok or not Abilities then return end
  Abilities.updateForecast(battle, battle.player)
  Abilities.updateForecast(battle, battle.enemy)
end

local function expireWeather(battle, kind)
  BattleCompat.say(battle, Strings(Weather.END_TEXT[kind] or "The weather subsided."))
  BattleCompat.setWeather(battle, nil)
  forecast(battle)
end

local function continueWeather(battle, kind)
  local cont = Weather.CONTINUE_TEXT[kind]
  if cont then BattleCompat.say(battle, Strings(cont)) end
  local chipKind = (kind == "HAIL" or kind == "SNOWY") and "HAIL"
    or (kind == "SANDSTORM" and "SANDSTORM") or nil
  local needAnim = kind == "SUNNY" or kind == "RAINY" or chipKind
  if chipKind then
    needAnim = Weather.hits(battle, battle.player, chipKind)
      or Weather.hits(battle, battle.enemy, chipKind)
  end
  if needAnim then Weather.playTickAnim(battle, kind) end
  if chipKind then
    Weather.chipBattler(battle, battle.player, chipKind)
    Weather.chipBattler(battle, battle.enemy, chipKind)
  end
end

local function readTurns(battle)
  local field = battle.field
  return (field and field.weatherTurns) or battle.weatherTurns
end

local function writeTurns(battle, turns)
  battle.field = battle.field or {}
  battle.field.weatherTurns = turns
  battle.weatherTurns = turns
end

-- Gen 3: residual (chip / continue text) first, then the duration
-- counter.  Decrement-first (Gold) spends the turn weather was set
-- before any chip, so the first end-of-turn hit never lands, and the
-- fifth turn fades without damaging.
local function tickDuration(battle, kind)
  if battle._krAbilityWeather then
    continueWeather(battle, kind)
    return
  end
  local turns = readTurns(battle)
  if type(turns) ~= "number" or turns <= 0 then
    turns = Weather.MOVE_TURNS
  end
  continueWeather(battle, kind)
  turns = turns - 1
  writeTurns(battle, turns)
  if turns <= 0 then
    expireWeather(battle, kind)
  end
end

function Weather.tick(battle)
  if not battle then return end
  if not Weather.shouldResidual(battle) then
    return
  end
  if Weather.suppressed(battle) then
    forecast(battle)
    return
  end

  -- Gold: HandleWeather (+ our Battle.tickWeather wrap) owns continue/chip/
  -- Forecast while the event queue is still live. battle.turn_ended runs
  -- AFTER takeEvents, so emitting "transformed!" here shows up at the start
  -- of the next turn instead of with the weather line.
  if BattleCompat.isGen2(battle) then
    return
  end

  local kind = BattleCompat.getWeather(battle)
  if not kind then
    forecast(battle)
    return
  end

  tickDuration(battle, kind)
end

function Weather.install(mod)
  Weather.registerAnims(mod)
  pcall(function()
    require("mods.Kanto-Reforged.battle.castform_fx").install(mod)
  end)

  local okE, Effects = pcall(require, "src.battle.gen2.Effects")
  if okE and Effects and not Effects._krGen3SandChip then
    Effects.sandstormDamage = Weather.chipAmount
    Effects._krGen3SandChip = true
  end

  local Host = require("mods.Kanto-Reforged.core.host")
  if Host.isGen1() then
    local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
    pcall(function()
      Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
        if BattleState._krSunCharge then return end
        local orig = BattleState.performMove
        if type(orig) ~= "function" then return end
        BattleState.performMove = function(self, user, target, moveInst, isCalled)
          local move = self.moveDef and self:moveDef(moveInst)
          if Weather.instantCharge(self, move) and user and moveInst then
            user.charging = moveInst
            user.chargeReady = true
          end
          return orig(self, user, target, moveInst, isCalled)
        end
        BattleState._krSunCharge = true
      end)
    end)
    pcall(function()
      local MoveEffects = require("src.battle.MoveEffects")
      local rec = MoveEffects.HEAL_EFFECT
      if type(rec) == "function" and not MoveEffects._krWeatherHeal then
        local orig = rec
        MoveEffects.HEAL_EFFECT = function(battle, user, target, move)
          if move and Weather.isWeatherHeal(move.id) and user and user.mon then
            local mon = user.mon
            if mon.hp == mon.stats.hp then
              return orig(battle, user, target, move)
            end
            local frac = Weather.healFraction(battle)
            mon.hp = math.min(mon.stats.hp,
              mon.hp + math.max(1, math.floor(mon.stats.hp * frac)))
            local Strings_ = require("src.core.Strings")
            return { Strings_("%s\nregained health!", user.name or "POKéMON") }
          end
          return orig(battle, user, target, move)
        end
        MoveEffects._krWeatherHeal = true
      end
    end)
  end

  if not Host.isGen2() then return end

  local okB, Battle = pcall(require, "src.battle.gen2.Battle")
  if not (okB and Battle and type(Battle.tickWeather) == "function") then return end

  if not Battle._krAbilityWeatherTick then
    local origTick = Battle.tickWeather
    Battle.tickWeather = function(self)
      -- Native HandleWeather still runs inside takeTurn; skip it when the
      -- battle is already decided so EXP/faint text is not interleaved with
      -- sandstorm chip (not Gen 3).
      if not Weather.shouldResidual(self) then return end
      if self._krAbilityWeather and self.weather then
        self.weatherTurns = math.max(self.weatherTurns or Weather.MOVE_TURNS,
                                     Weather.MOVE_TURNS)
      end
      local emit = self.emit
      if type(emit) == "function" then
        self.emit = function(s, ev)
          if ev and ev.kind == "message" then
            ev.text = Weather.rewrittenChipText(ev.text)
          end
          return emit(s, ev)
        end
      end
      local ok, err = xpcall(origTick, debug.traceback, self)
      if emit then self.emit = emit end
      if not ok then error(err) end
      -- Hail is KR-only (Gold has no HandleWeather arm). Run it here so chip /
      -- fade / Forecast land in the same takeEvents drain as sun/rain/sand.
      local kind = BattleCompat.getWeather(self)
      if kind == "HAIL" or kind == "SNOWY" then
        tickDuration(self, kind)
      else
        -- Native expiry clears weather without Forecast; revert Castform now.
        forecast(self)
      end
    end
    Battle._krAbilityWeatherTick = true
  end

  -- Gold dispatches weather moves through MOVE_EFFECT_RECORDS / merged
  -- gen2MoveEffects, not the live MOVE_EFFECTS table (records are snapshotted
  -- at Battle.lua load). Wrapping only MOVE_EFFECTS left Forecast to the
  -- end-of-turn tickWeather path — transform after the whole move/turn.
  local wrappedRuns = Weather._krWeatherForecastWraps
  if not wrappedRuns then
    wrappedRuns = {}
    Weather._krWeatherForecastWraps = wrappedRuns
  end

  local function wrapWeatherRun(run)
    if type(run) ~= "function" then return run end
    local existing = wrappedRuns[run]
    if existing then return existing end
    local wrapped = function(self, attacker, defender, ...)
      self._krAbilityWeather = nil
      local result = run(self, attacker, defender, ...)
      -- FRLG: weather start line is already emitted; Forecast next.
      forecast(self)
      return result
    end
    wrappedRuns[run] = wrapped
    wrappedRuns[wrapped] = wrapped
    return wrapped
  end

  local okE2, Effects2 = pcall(require, "src.battle.gen2.Effects")
  local weatherEffects = (okE2 and Effects2 and Effects2.WEATHER)
    or (Effects and Effects.WEATHER)

  if weatherEffects then
    for effect, _ in pairs(weatherEffects) do
      if Battle.MOVE_EFFECTS and type(Battle.MOVE_EFFECTS[effect]) == "function" then
        Battle.MOVE_EFFECTS[effect] = wrapWeatherRun(Battle.MOVE_EFFECTS[effect])
      end
      local rec = Battle.MOVE_EFFECT_RECORDS and Battle.MOVE_EFFECT_RECORDS[effect]
      if rec and type(rec.run) == "function" then
        rec.run = wrapWeatherRun(rec.run)
      end
    end
  end

  if mod and mod.content and mod.content.move_effects
      and type(mod.content.move_effects.get) == "function" then
    for effect, _ in pairs(weatherEffects or {}) do
      local rec = mod.content.move_effects:get(effect)
      if rec and type(rec.run) == "function" then
        local wrapped = wrapWeatherRun(rec.run)
        if wrapped ~= rec.run then
          pcall(function()
            mod.content.move_effects:override(effect, {
              kind = rec.kind or "primary",
              run = wrapped,
            })
          end)
        end
      end
    end
  end
end

return Weather
