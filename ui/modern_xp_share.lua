-- Slot-2 Exp. Share: respects Gen 1's single XP pool (never prints more than
-- ~100% of a solo share).  While the card toggle is on and party slot 2 is
-- alive on the bench:
--   * Alive fighters split 70% of the pool equally.
--   * Slot 2 gets up to 30%, clamped to 75% of one fighter's share so the
--     bench never outpaces actives (solo 70/30; two fighters ~35/35/26;
--     three ~23/23/23/17).
-- If slot 2 fought, is fainted, is an egg, or is missing: equal split of 100%
-- among alive fighters.
-- Gen 1 EXP.ALL / Gen 2 item EXP.SHARE double-pass are skipped while the
-- toggle is on (we replace vanilla via battle.exp_award).  Option key stays
-- modern_xp_share for save compatibility.

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

-- Gen2 Battle owns `.party`; Gen1 uses playerPartyView (link-safe) / save.party.
-- Prefer `.party` only when present so Gen1 nil does not mask the save party.
local function partyOf(battle)
  if battle == nil then return {} end
  if battle.party ~= nil and type(battle.party) == "table" then
    return battle.party
  end
  if type(battle.playerPartyView) == "function" then
    return battle:playerPartyView() or {}
  end
  if battle.game and battle.game.save and type(battle.game.save.party) == "table" then
    return battle.game.save.party
  end
  return {}
end

-- Pay one mon through the engine helper.  Gen2's applyShare closes over
-- `halved` from any live EXP.SHARE *item* holder; while our toggle replaces
-- vanilla we must not keep that tax (and we also skip the holders pass).
local function payShare(ctx, mon, split, announce)
  local battle = ctx.battle
  if ctx.halved and ctx.loser and battle
      and type(battle.giveExperiencePass) == "function"
      and type(battle.speciesDef) == "function" then
    for index, candidate in ipairs(battle.party or {}) do
      if candidate == mon then
        local def = battle:speciesDef(ctx.loser)
        return battle:giveExperiencePass(
          ctx.loser, def, { index }, math.max(1, split or 1), false, not announce)
      end
    end
    return
  end
  return ctx.applyShare(mon, split, announce)
end

-- Pool-respecting slot-2 payout via the engine's applyShare helper.
-- Returns true when the toggle handled the award (caller must not run vanilla).
function ModernXpShare.awardFromCtx(mod, ctx)
  if not ModernXpShare.enabled(mod) then return false end
  if not ctx or type(ctx.applyShare) ~= "function" then return false end

  local alive = ctx.alive or {}
  if #alive == 0 then return true end

  local fought = {}
  for _, mon in ipairs(alive) do fought[mon] = true end

  local slot2 = partyOf(ctx.battle)[2]
  local benchEligible = slot2 ~= nil
    and (slot2.hp or 0) > 0
    and not slot2.isEgg
    and not fought[slot2]

  if not benchEligible then
    for _, mon in ipairs(alive) do
      payShare(ctx, mon, #alive, true)
    end
    return true
  end

  local fighterFrac, benchFrac = ModernXpShare.fractions(#alive, true)
  local fighterSplit = 1 / fighterFrac
  for _, mon in ipairs(alive) do
    payShare(ctx, mon, fighterSplit, true)
  end
  payShare(ctx, slot2, 1 / benchFrac, true)
  return true
end

function ModernXpShare.install(mod)
  if ModernXpShare._installed then return end
  ModernXpShare._installed = true
  ModernXpShare._mod = mod

  mod.hooks:wrap("battle.exp_award", function(next, ctx)
    if ModernXpShare.awardFromCtx(mod, ctx) then
      return
    end
    return next(ctx)
  end)
end

return ModernXpShare
