return function(T)
  local Rules = require("mods.Kanto-Reforged.battle.core.rules")
  local Capabilities = require("mods.Kanto-Reforged.battle.core.capabilities")

  T.check(Capabilities.gen3Crit, "gen3 crit always on")
  T.check(Capabilities.gen3PartialTrap, "gen3 partial trap always on")
  T.eq(Capabilities.residualAfterMove, false, "no per-move residuals")

  T.eq(Rules.weather.chipAmount(160), 10, "weather chip 1/16")
  T.eq(Rules.partialTrap.chipAmount(160), 10, "trap chip 1/16")
  T.check(Rules.weather.hits({ "ROCK" }, "SANDSTORM") == false, "rock sand immune")
  T.check(Rules.weather.hits({ "NORMAL" }, "SANDSTORM"), "normal sand hit")

  T.check(Rules.substitute.blocks("taunt", { substituteHP = 10 }), "sub blocks taunt")
  T.check(not Rules.substitute.blocks("taunt", { substituteHP = 0 }), "no sub no block")

  local attacker = { focusEnergy = true }
  -- Gen3: Focus Energy +2, high-crit move +1 → stage 3 (cap 4 needs Scope Lens etc.)
  T.eq(Rules.crit.stage(attacker, "SLASH", true), 3, "FE + high-crit is stage 3")
  T.eq(Rules.crit.stage({
    focusEnergy = true,
    mon = { heldItem = "SCOPE_LENS", species = "PERSIAN" },
  }, "SLASH", true), 4, "Scope Lens reaches stage 4")
  T.eq(Rules.crit.stage({
    mon = { heldItem = "LUCKY_PUNCH", species = "CHANSEY" },
  }, "POUND", false), 2, "Lucky Punch on Chansey +2")
  T.eq(Rules.crit.stage({
    mon = { heldItem = "LUCKY_PUNCH", species = "CLEFAIRY" },
  }, "POUND", false), 0, "Lucky Punch ignored off-species")
  T.eq(Rules.crit.stage({
    mon = { heldItem = "STICK", species = "FARFETCHD" },
  }, "SLASH", true), 3, "Stick + high-crit on Farfetch'd")

  -- Gold Battle:roller() is (n) -> 0..n-1. Calling it as (0, den-1) used
  -- to pass n=0 and crit every hit (Weather Ball included).
  local goldRoller = function(n)
    if n == 0 then return 0 end
    return n - 1
  end
  T.eq(Rules.crit.roll({}, "TACKLE", false, goldRoller), false,
    "Gold 1-arg roller at max is not a stage-0 crit")
  local alwaysLow = function(n)
    if n == 0 then return 0 end
    return 0
  end
  T.eq(Rules.crit.roll({}, "TACKLE", false, alwaysLow), true,
    "Gold 1-arg roller 0 is a stage-0 crit (1/16)")
  local twoArg = function(lo, hi)
    if hi == nil then return lo - 1 end
    return hi
  end
  T.eq(Rules.crit.roll({}, "TACKLE", false, twoArg), false,
    "love.math-style (lo,hi) rng still works")
end
