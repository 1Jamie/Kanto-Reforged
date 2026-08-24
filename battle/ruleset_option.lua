-- Gen1 RULESET bridge: KR always uses Gen3 MODERN (modern_clean).

local Host = require("mods.Kanto-Reforged.core.host")
local Capabilities = require("mods.Kanto-Reforged.battle.core.capabilities")

local RulesetOpt = {}

RulesetOpt.OPTION_KEY = "battle_ruleset"
RulesetOpt.SEED_KEY = "battle_ruleset_seeded"
RulesetOpt.MODERN = "modern_clean"
RulesetOpt.FAITHFUL = "gen1_faithful"

local function bucket(mod)
  local loader = Host.modLoader(mod)
  if not loader then return nil end
  loader.modOptions = loader.modOptions or {}
  loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
  return loader.modOptions[mod.id]
end

local function setEngineRuleset(game, id)
  if not (game and game.save and game.save.options) then return end
  if game.save.options.ruleset == id then return end
  game.save.options.ruleset = id
  if type(game.writeOptions) == "function" then
    pcall(function() game:writeOptions() end)
  end
end

local function setModRuleset(mod, id)
  local b = bucket(mod)
  if not b then return end
  if b[RulesetOpt.OPTION_KEY] == id then return end
  b[RulesetOpt.OPTION_KEY] = id
  Host.persistModOptions(mod)
end

--- Patch display names + Gen3 markers on the engine ruleset records.
function RulesetOpt.patchRulesetRecords(mod)
  if not Host.isGen1() then return end
  if not (mod.content and mod.content.rulesets) then return end
  pcall(function()
    mod.content.rulesets:patch(RulesetOpt.MODERN, {
      name = "MODERN",
      krGen3Crit = Capabilities.gen3Crit,
      krGen3PartialTrap = Capabilities.gen3PartialTrap,
      residualAfterMove = Capabilities.residualAfterMove,
    })
  end)
end

--- One-shot seed to modern_clean; migrate faithful saves.
function RulesetOpt.seedAndSync(mod)
  if not Host.isGen1() then return false end
  local game = Host.liveGame(mod)
  if not (game and game.save and game.save.options) then return false end
  local b = bucket(mod)
  if not b then return false end

  -- Always force MODERN; faithful ruleset removed.
  setEngineRuleset(game, RulesetOpt.MODERN)
  b[RulesetOpt.OPTION_KEY] = RulesetOpt.MODERN
  b[RulesetOpt.SEED_KEY] = true
  Host.persistModOptions(mod)
  return true
end

function RulesetOpt.install(mod)
  if not Host.isGen1() then return end
  RulesetOpt.patchRulesetRecords(mod)
  RulesetOpt.seedAndSync(mod)

  mod.events:on("game.ready", function()
    RulesetOpt.seedAndSync(mod)
  end)
end

return RulesetOpt
