-- Battle core install: unified residual scheduler on turn_ended.

local Host = require("mods.Kanto-Reforged.core.host")
local Adapters = require("mods.Kanto-Reforged.battle.adapters")
local Residuals = require("mods.Kanto-Reforged.battle.core.residuals")
local ResidualHandlers = require("mods.Kanto-Reforged.battle.core.residual_handlers")
local EffectCtx = require("mods.Kanto-Reforged.battle.core.effect_ctx")
local CoreEffects = require("mods.Kanto-Reforged.battle.core.effects")

local CoreInstall = {}
local installed = false

-- KR-owned side tokens tick in residual_handlers (battle.turn_ended), not engine tickTokens.
local KR_SIDE_TOKEN_IDS = {
  EXP_WISH = true,
  EXP_FUTURE_SIGHT = true,
}

local function installSideTokenOwnership()
  if not Host.isGen1() then return end
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  Gen1Patch.apply(require("src.battle.BattleState"), function(BattleState)
    if BattleState._krSideTokenOwnership then return end
    local origTick = BattleState.tickTokens
    BattleState.tickTokens = function(self)
      local saved = {}
      for _, side in ipairs(self.sides or {}) do
        if side.tokens and side.tokens[1] then
          local kept, removed = {}, {}
          for _, tok in ipairs(side.tokens) do
            if KR_SIDE_TOKEN_IDS[tok.id] then
              removed[#removed + 1] = tok
            else
              kept[#kept + 1] = tok
            end
          end
          if #removed > 0 then
            saved[side] = removed
            side.tokens = kept
          end
        end
      end
      origTick(self)
      for side, removed in pairs(saved) do
        for _, tok in ipairs(removed) do
          side.tokens[#side.tokens + 1] = tok
        end
      end
    end
    BattleState._krSideTokenOwnership = true
  end)
end

function CoreInstall.tryRunEffect(battle, effectId, user, target, move, rng, opts)
  if not CoreEffects.has(effectId) then return false end
  local adapter = Adapters.forBattle(battle)
  if not adapter then return false end
  local ctx = EffectCtx.push(adapter, user, target, move, effectId, rng or adapter:rng(), opts)
  local ok, err = pcall(CoreEffects.run, effectId, ctx)
  EffectCtx.pop()
  if not ok then error(err) end
  return true
end

function CoreInstall.tryRunHook(battle, effectId, hookName, user, target, move, raw)
  if not CoreEffects.hasHooks(effectId) then return nil end
  local spec = CoreEffects.hooks(effectId)
  if not spec or not spec[hookName] then return nil end
  local CtxShim = require("mods.Kanto-Reforged.battle.core.effects._ctx")
  return CtxShim.gen2(battle, effectId, user, target, move, hookName, function(ec, r)
    return CoreEffects.runHook(effectId, hookName, ec, r or raw or {
      battle = battle, user = user, target = target, move = move,
    })
  end)
end

function CoreInstall.install(mod)
  if not installed then
    ResidualHandlers.registerAll()
    installed = true
  end
  installSideTokenOwnership()
  if not mod or not mod.events then return end

  require("mods.Kanto-Reforged.battle.switch_in").install(mod)

  mod.events:on("battle.turn_ended", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    local adapter = Adapters.forBattle(battle)
    if not adapter then return end
    Residuals.runTurn(adapter)
    EffectCtx.reset()
  end)
end

return CoreInstall
