-- Gen1 RULESET bridge: KR defaults the engine option to modern_clean once,
-- mirrors it in the mod Manager, and keeps OPTIONS ↔ Manager in sync.
-- Gold has no ruleset dispatch — this module is Gen1-only.

local Host = require("mods.Kanto-Reforged.core.host")

local RulesetOpt = {}

RulesetOpt.OPTION_KEY = "battle_ruleset"
RulesetOpt.SEED_KEY = "battle_ruleset_seeded"
RulesetOpt.MODERN = "modern_clean"
RulesetOpt.FAITHFUL = "gen1_faithful"

RulesetOpt.OPTION = {
  key = RulesetOpt.OPTION_KEY,
  label = "RULESET",
  type = "choice",
  default = RulesetOpt.MODERN,
  choices = {
    { "MODERN", RulesetOpt.MODERN },
    { "GEN 1", RulesetOpt.FAITHFUL },
  },
}

local function bucket(mod)
  local loader = Host.modLoader(mod)
  if not loader then return nil end
  loader.modOptions = loader.modOptions or {}
  loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
  return loader.modOptions[mod.id]
end

local function engineRuleset(game)
  local opts = game and game.save and game.save.options
  if not opts then return nil end
  local id = opts.ruleset
  if id == RulesetOpt.MODERN or id == RulesetOpt.FAITHFUL then
    return id
  end
  return RulesetOpt.FAITHFUL
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

--- Patch display names + Gen3-crit marker on the engine ruleset records.
function RulesetOpt.patchRulesetRecords(mod)
  if not Host.isGen1() then return end
  if not (mod.content and mod.content.rulesets) then return end
  pcall(function()
    mod.content.rulesets:patch(RulesetOpt.MODERN, {
      name = "MODERN",
      krGen3Crit = true,
    })
  end)
  pcall(function()
    mod.content.rulesets:patch(RulesetOpt.FAITHFUL, {
      name = "GEN 1",
    })
  end)
end

--- One-shot seed to modern_clean; later runs only align the mod row.
-- @return true if game options were available
function RulesetOpt.seedAndSync(mod)
  if not Host.isGen1() then return false end
  local game = Host.liveGame(mod)
  if not (game and game.save and game.save.options) then return false end
  local b = bucket(mod)
  if not b then return false end

  if b[RulesetOpt.SEED_KEY] == nil then
    setEngineRuleset(game, RulesetOpt.MODERN)
    b[RulesetOpt.OPTION_KEY] = RulesetOpt.MODERN
    b[RulesetOpt.SEED_KEY] = true
    Host.persistModOptions(mod)
    if mod.log then
      mod.log:info("RULESET seeded to MODERN (modern_clean)")
    end
  else
    local eng = engineRuleset(game)
    setModRuleset(mod, eng)
  end
  return true
end

function RulesetOpt.install(mod)
  if not Host.isGen1() then return end
  RulesetOpt.patchRulesetRecords(mod)
  RulesetOpt.seedAndSync(mod)

  mod.events:on("game.ready", function()
    RulesetOpt.seedAndSync(mod)
  end)

  mod.events:on("mod.options_changed", function(ev)
    if not (ev and ev.mod == mod.id) then return end
    if ev.key ~= RulesetOpt.OPTION_KEY then return end
    local id = ev.value
    if id ~= RulesetOpt.MODERN and id ~= RulesetOpt.FAITHFUL then
      id = RulesetOpt.MODERN
    end
    local b = bucket(mod)
    if b then b[RulesetOpt.SEED_KEY] = true end
    local game = Host.liveGame(mod)
    setEngineRuleset(game, id)
    Host.persistModOptions(mod)
  end)

  -- OPTIONS → RULESET step also updates the mod Manager choice.
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    rows = next(game, rows)
    if type(rows) ~= "table" then return rows end
    for _, row in ipairs(rows) do
      if row and row.id == "ruleset" and type(row.step) == "function"
          and not row._krRulesetSync then
        local old = row.step
        row.step = function(g, dir)
          local ok = old(g, dir)
          local eng = engineRuleset(g)
          if eng then
            local b = bucket(mod)
            if b then b[RulesetOpt.SEED_KEY] = true end
            setModRuleset(mod, eng)
          end
          return ok
        end
        row._krRulesetSync = true
      end
    end
    return rows
  end)
end

return RulesetOpt
