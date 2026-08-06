-- Gen 2-style gender from Attack DV + species genderRate (PokéAPI female
-- eighths, -1 = genderless). Assigned on Pokemon.new and backfilled onto
-- existing saves so mid-run parties/PC/daycare stay deterministic.

local Pokemon = require("src.pokemon.Pokemon")
local Status = require("src.battle.Status")
local Strings = require("src.core.Strings")

local Gender = {}

local function displayName(battler)
  if not battler then return "?????" end
  if battler.mon and battler.mon.nickname and battler.mon.nickname ~= "" then
    return battler.mon.nickname
  end
  return battler.name or (battler.mon and battler.mon.species) or "?????"
end

function Gender.rate(data, species)
  local def = data and data.pokemon and data.pokemon[species]
  local rate = def and def.genderRate
  if rate == nil then return -1 end
  return rate
end

-- Gen 2 thresholds: female if attackDV < genderRate * 2 (rates 1..7).
-- 0 = always male, 8 = always female, -1 / missing = genderless.
function Gender.fromDVs(data, species, dvs)
  local rate = Gender.rate(data, species)
  if rate < 0 or rate > 8 then return nil end
  if rate == 0 then return "M" end
  if rate == 8 then return "F" end
  local atk = dvs and dvs.attack
  if type(atk) ~= "number" then return nil end
  if atk < rate * 2 then return "F" end
  return "M"
end

function Gender.of(mon)
  if not mon then return nil end
  local g = mon.gender
  if g == "M" or g == "F" then return g end
  return nil
end

function Gender.areOpposite(a, b)
  local ga, gb = Gender.of(a), Gender.of(b)
  return ga ~= nil and gb ~= nil and ga ~= gb
end

-- Assign gender when missing. Genderless species stay nil. Already M/F
-- are left alone (idempotent for existing saves).
function Gender.ensure(data, mon)
  if not mon or not mon.species then return end
  if mon.isEgg then return end
  if mon.gender == "M" or mon.gender == "F" then return end
  local g = Gender.fromDVs(data, mon.species, mon.dvs)
  if g then mon.gender = g end
end

-- Force gender from current DVs (trainer battles overwrite DVs after Pokemon.new).
function Gender.resync(data, mon)
  if not mon or not mon.species or mon.isEgg then return end
  mon.gender = Gender.fromDVs(data, mon.species, mon.dvs)
end

-- True if this species can be either gender (not fixed / genderless).
function Gender.canBeEither(data, species)
  local rate = Gender.rate(data, species)
  return rate >= 1 and rate <= 7
end

-- Emerald+ Cute Charm: ~2/3 chance wild is opposite gender of the lead.
function Gender.applyCuteCharmWild(game, mon, rng)
  if not game or not mon or not game.save or not game.data then return end
  local lead = game.save.party and game.save.party[1]
  if not lead then return end
  local def = game.data.pokemon[lead.species]
  if not def or def.ability ~= "CUTE_CHARM" then return end
  Gender.ensure(game.data, lead)
  local leadG = Gender.of(lead)
  if not leadG then return end
  if not Gender.canBeEither(game.data, mon.species) then return end
  rng = rng or math.random
  -- 2/3 force opposite (Emerald onwards)
  if rng(1, 3) == 1 then return end
  mon.gender = (leadG == "M") and "F" or "M"
end

function Gender.backfillSave(data, save)
  if not data or not save then return 0 end
  local n = 0
  local function touch(mon)
    if not mon then return end
    local before = mon.gender
    Gender.ensure(data, mon)
    if mon.gender ~= before and (mon.gender == "M" or mon.gender == "F") then
      n = n + 1
    end
  end
  for _, mon in ipairs(save.party or {}) do touch(mon) end
  for _, box in ipairs(save.boxes or {}) do
    for _, mon in ipairs(box or {}) do touch(mon) end
  end
  if save.daycare and type(save.daycare) == "table" then
    touch(save.daycare.mon)
    touch(save.daycare.mon2)
  end
  return n
end

function Gender.glyph(mon)
  local g = Gender.of(mon)
  if g == "M" then return "♂" end
  if g == "F" then return "♀" end
  return ""
end

function Gender.nameWithGlyph(mon, baseName)
  local g = Gender.glyph(mon)
  if g == "" then return baseName end
  return (baseName or "") .. g
end

-- Attract / Cute Charm helpers
function Gender.canInfatuate(userMon, targetMon)
  return Gender.areOpposite(userMon, targetMon)
end

function Gender.applyInfatuation(battle, target, sourceName)
  if not target or target.expInfatuated then return false end
  target.expInfatuated = true
  if battle and battle.sayNext then
    battle:sayNext(Strings("%s fell in\nlove!", displayName(target)))
  end
  return true
end

function Gender.infatuateMessages(target)
  return { Strings("%s fell in\nlove!", displayName(target)) }
end

function Gender.register(mod)
  mod.content.link_fields:register("gender", {
    rev = 1,
    pack = function(mon) return mon.gender end,
    unpack = function(mon, v) mon.gender = v end,
  })
end

function Gender.install(mod)
  Gender._mod = mod

  local original_new = Pokemon.new
  Pokemon.new = function(data, species, level, rng)
    local mon = original_new(data, species, level, rng)
    local g = Gender.fromDVs(data, species, mon.dvs)
    if g then mon.gender = g end
    return mon
  end

  -- Trainer battles replace DVs after Pokemon.new; re-derive gender.
  local BattleState = require("src.battle.BattleState")
  local original_newTrainer = BattleState.newTrainer
  BattleState.newTrainer = function(game, oppClass, partyIndex)
    local battle = original_newTrainer(game, oppClass, partyIndex)
    local data = game and game.data
    if battle and data then
      for _, mon in ipairs(battle.enemyParty or {}) do
        Gender.resync(data, mon)
      end
    end
    return battle
  end

  local original_newWild = BattleState.newWild
  BattleState.newWild = function(game, species, level, opts)
    local battle = original_newWild(game, species, level, opts)
    if battle and battle.enemy and battle.enemy.mon then
      local rng = battle.rng or math.random
      Gender.applyCuteCharmWild(game, battle.enemy.mon, rng)
    end
    return battle
  end

  local original_before = Status.beforeMove
  Status.beforeMove = function(battler, rng, battle)
    local canMove, msgs, selfHit = original_before(battler, rng, battle)
    if not canMove or selfHit then return canMove, msgs, selfHit end
    if battler and battler.expInfatuated then
      msgs = msgs or {}
      msgs[#msgs + 1] = Strings("%s is in love\nwith the foe!", displayName(battler))
      local roll = (rng or math.random)(0, 1)
      if roll == 0 then
        msgs[#msgs + 1] = Strings("%s is immobilized\nby love!", displayName(battler))
        return false, msgs, false
      end
    end
    return canMove, msgs, selfHit
  end

  -- Infatuation ends when the Pokémon that caused it faints (Gen 3).
  mod.events:on("battle.fainted", function(ev)
    if not ev.battle or not ev.battler then return end
    local other = ev.battler.isPlayer and ev.battle.enemy or ev.battle.player
    if other then other.expInfatuated = nil end
  end)

  local function backfillActive(ev)
    local game = (ev and ev.game) or mod.activeGame
    local save = (ev and ev.save) or (game and game.save)
    local data = game and game.data
    if data and save then
      Gender.backfillSave(data, save)
    end
  end

  -- game.ready only sees the new-game skeleton; CONTINUE replaces the save
  -- afterward, so also backfill on save.loaded.
  mod.events:on("game.ready", backfillActive)
  mod.events:on("save.loaded", backfillActive)
end

return Gender
