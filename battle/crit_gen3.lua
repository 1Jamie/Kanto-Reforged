local Rules = require("mods.Kanto-Reforged.battle.core.rules")

local CritGen3 = {}

function CritGen3.stage(attacker, moveId, highCrit)
  return Rules.crit.stage(attacker, moveId, highCrit)
end

function CritGen3.roll(ctx)
  return Rules.crit.roll(ctx.attacker, ctx.moveId, ctx.highCrit, ctx.rng or ctx.random)
end

function CritGen3.rulesetWants(_ruleset)
  return Rules.crit.active()
end

return CritGen3
