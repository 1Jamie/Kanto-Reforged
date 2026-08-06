-- Slot-2 Exp. Share: respects Gen 1's single XP pool (never prints more than
-- ~100% of a solo share).  While the card toggle is on and party slot 2 is
-- alive on the bench:
--   * Alive fighters split 70% of the pool equally.
--   * Slot 2 gets up to 30%, clamped to 75% of one fighter's share so the
--     bench never outpaces actives (solo 70/30; two fighters ~35/35/26;
--     three ~23/23/23/17).
-- If slot 2 fought, is fainted, or is missing: vanilla equal split of 100%.
-- Gen 1 EXP.ALL is ignored while the toggle is on.  Option key stays
-- modern_xp_share for save compatibility.
--
-- Stock BattleState has no awardExperience hook -- this module installs
-- applyExpShare at runtime and wraps enemyMonFainted so the expansion pack
-- needs zero engine edits.

local Strings = require("src.core.Strings")
local Runtime = require("src.mods.Runtime")

local ModernXpShare = {}

ModernXpShare.OPTION_KEY = "modern_xp_share"
ModernXpShare.OPTION = {
  key = ModernXpShare.OPTION_KEY,
  label = "XP SHARE (SLOT 2)",
  type = "toggle",
  default = true,
}

-- Fraction of the solo (split=1) pool reserved for actives vs bench.
ModernXpShare.ACTIVE_POOL = 0.70
ModernXpShare.BENCH_POOL = 0.30
-- Slot 2 may not exceed this fraction of one fighter's share.
ModernXpShare.BENCH_CAP = 0.75

function ModernXpShare.enabled(mod)
  return mod and mod.options and mod.options:get(ModernXpShare.OPTION_KEY) and true or false
end

-- Returns fighterFrac, benchFrac (each as a share of the solo pool).
-- benchEligible false → full pool split equally among fighters (benchFrac 0).
function ModernXpShare.fractions(nAliveFighters, benchEligible)
  local n = math.max(1, nAliveFighters or 1)
  if not benchEligible then
    return 1 / n, 0
  end
  local fighter = ModernXpShare.ACTIVE_POOL / n
  local bench = math.min(ModernXpShare.BENCH_POOL, fighter * ModernXpShare.BENCH_CAP)
  return fighter, bench
end

-- Pay one party mon its share (and run level-up / move-learn UI).
-- Same shape as the engine's local applyShare inside enemyMonFainted.
-- `split` is Experience's numParticipants divisor (may be fractional).
function ModernXpShare.applyExpShare(battle, mon, split, announce)
  local Experience = require("src.battle.Experience")
  local levels, gained = Experience.apply(battle.data, mon, battle.enemy.def,
                                          battle.enemy.mon.level, battle.kind == "trainer",
                                          split, mon.traded)
  if #levels > 0 then
    battle.leveledUp = battle.leveledUp or {}
    battle.leveledUp[mon] = true
  end
  Runtime.emit("battle.exp_gained", {
    battle = battle, mon = mon, gained = gained, levels = levels,
  })
  local name = mon.nickname or battle.data.pokemon[mon.species].name
  if announce then
    local text = Strings.source("%s gained\n%d EXP. Points!")
    if announce == "expAll" then
      text = Strings.source("%s gained\nwith EXP.ALL,\v%d EXP. Points!")
    elseif mon.traded then
      text = Strings.source("%s gained\na boosted\v%d EXP. Points!")
    end
    battle:sayNext(Strings(text, name, gained))
  end
  local game = battle.game
  for _, lv in ipairs(levels) do
    require("src.world.PikachuFollower")
      .modifyHappiness(game.save, "LEVELUP", mon)
    battle:sayNext(Strings("%s grew\nto level %d!", name, lv))
    battle:uiNext(function()
      require("src.core.Sound").play(game.data, "Level_Up")
      return require("src.battle.BattleState").StatBox.new(game, mon)
    end)
    if mon == battle.player.mon then battle:drainNext() end
    for _, moveId in ipairs(Experience.movesLearnedAt(
        battle.data.pokemon[mon.species], lv)) do
      battle:learnMove(mon, moveId)
    end
  end
  return gained, levels
end

-- Pool-respecting slot-2 payout.  Returns false when the toggle is off.
function ModernXpShare.award(mod, battle)
  if not ModernXpShare.enabled(mod) then return false end

  local party = battle.game.save.party
  local flagged = battle.participants or {}
  local participants, alive = {}, {}
  for _, mon in ipairs(party) do
    if flagged[mon] then
      participants[#participants + 1] = mon
      if mon.hp > 0 then alive[#alive + 1] = mon end
    end
  end
  if #participants == 0 and battle.player.mon.hp > 0 then
    participants = { battle.player.mon }
    alive = { battle.player.mon }
  end
  if #alive == 0 then return true end

  local fought = {}
  for _, mon in ipairs(alive) do fought[mon] = true end

  local slot2 = party[2]
  local benchEligible = slot2 ~= nil and slot2.hp > 0 and not fought[slot2]

  if not benchEligible then
    -- Vanilla Gen 1: equal split of the full pool among alive fighters.
    for _, mon in ipairs(alive) do
      battle:applyExpShare(mon, #alive, true)
    end
    return true
  end

  local fighterFrac, benchFrac = ModernXpShare.fractions(#alive, true)
  local fighterSplit = 1 / fighterFrac
  for _, mon in ipairs(alive) do
    battle:applyExpShare(mon, fighterSplit, true)
  end
  battle:applyExpShare(slot2, 1 / benchFrac, true)
  return true
end

local function looksLikeExpText(text)
  if type(text) ~= "string" then return false end
  -- GainedText / GrewLevelText from the stock applyShare path we are skipping.
  return text:find("EXP", 1, true) ~= nil
      or text:find("grew", 1, true) ~= nil
end

-- Run stock enemyMonFainted after share award, without a second XP pass.
local function runFaintTailWithoutExp(battle, original)
  local Experience = require("src.battle.Experience")
  local oldApply = Experience.apply
  local oldSay = battle.sayNext
  Experience.apply = function() return {}, 0 end
  battle.sayNext = function(self, text, ...)
    if looksLikeExpText(text) then return end
    return oldSay(self, text, ...)
  end
  local ok, err = xpcall(function() original(battle) end, debug.traceback)
  Experience.apply = oldApply
  battle.sayNext = oldSay
  if not ok then error(err, 0) end
end

function ModernXpShare.install(mod)
  local BattleState = require("src.battle.BattleState")
  if BattleState._expansionModernXpShare then return end

  -- Live method so award() and tests can call battle:applyExpShare(...)
  BattleState.applyExpShare = function(self, mon, split, announce)
    return ModernXpShare.applyExpShare(self, mon, split, announce)
  end

  local originalFainted = BattleState.enemyMonFainted
  BattleState.enemyMonFainted = function(self)
    if ModernXpShare.award(mod, self) then
      runFaintTailWithoutExp(self, originalFainted)
      return
    end
    return originalFainted(self)
  end

  -- Test / tooling helper: payout only (no faint/send-out tail).
  BattleState.awardExperience = function(self)
    if ModernXpShare.award(mod, self) then return end
    -- Vanilla Gen 1 split, using the installed applyExpShare.
    local participants, alive = 0, {}
    for _, mon in ipairs(self.game.save.party) do
      if self.participants and self.participants[mon] then
        participants = participants + 1
        if mon.hp > 0 then table.insert(alive, mon) end
      end
    end
    if participants == 0 and self.player.mon.hp > 0 then
      participants, alive = 1, { self.player.mon }
    end
    local expAll = (self.game.save.inventory.EXP_ALL or 0) > 0
    for _, mon in ipairs(alive) do
      self:applyExpShare(mon, participants * (expAll and 2 or 1), true)
    end
    if expAll then
      for _, mon in ipairs(self.game.save.party) do
        if mon.hp > 0 then
          self:applyExpShare(mon,
            math.max(1, participants) * #self.game.save.party * 2, "expAll")
        end
      end
    end
  end

  BattleState._expansionModernXpShare = true
end

return ModernXpShare
