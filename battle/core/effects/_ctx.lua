-- Bridge engine move-effect ctx ↔ adapter effect context.

local Adapters = require("mods.Kanto-Reforged.battle.adapters")
local EffectCtx = require("mods.Kanto-Reforged.battle.core.effect_ctx")

local CtxShim = {}

function CtxShim.buildAdapter(ctx, id)
  local adapter = Adapters.forBattle(ctx.battle or {})
  local msgs = {}
  local function collect(text)
    if text then msgs[#msgs + 1] = text end
  end
  if ctx.side then
    adapter.foeSide = function()
      return ctx.side(ctx.target)
    end
    adapter.ownSide = function(_, who)
      return ctx.side(who or ctx.user)
    end
  end
  -- Gen1 performMove prints returned msgs once; calling ctx.say here too
  -- duplicated every adapter:say line (Sunny Day, etc.).
  adapter.say = function(_, text) collect(text) end
  if type(ctx.changeStage) == "function" then
    adapter.changeStages = function(_, battler, changes)
      local any = false
      for _, sc in ipairs(changes or {}) do
        local piece = ctx.changeStage(battler, sc.stat, sc.change)
        if type(piece) == "table" then
          for _, m in ipairs(piece) do collect(m) any = true end
        elseif piece then collect(piece) any = true end
      end
      return any
    end
  end
  local opts = {
    computeDamage = ctx.computeDamage,
    moveInst = ctx.moveInst,
    data = ctx.data,
    inflict = ctx.inflict,
    say = ctx.say,
    changeStage = ctx.changeStage,
  }
  if type(ctx.inflict) == "function" then opts.inflict = ctx.inflict end
  if type(ctx.cure) == "function" then opts.cure = ctx.cure end
  return adapter, opts, msgs
end

function CtxShim.runPrimary(id, raw, fn)
  local adapter, opts, msgs = CtxShim.buildAdapter(raw, id)
  local ec = EffectCtx.push(adapter, raw.user, raw.target, raw.move, id,
    raw.rng or adapter:rng(), opts)
  local ok, err = pcall(fn, ec)
  EffectCtx.pop()
  if not ok then error(err) end
  return msgs
end

function CtxShim.with(id, raw, fn)
  local adapter, opts, msgs = CtxShim.buildAdapter(raw, id)
  local ec = EffectCtx.push(adapter, raw.user, raw.target, raw.move, id,
    raw.rng or adapter:rng(), opts)
  local packed = table.pack(pcall(fn, ec, raw))
  EffectCtx.pop()
  if not packed[1] then error(packed[2]) end
  return table.unpack(packed, 2, packed.n)
end

function CtxShim.gen2(battle, id, user, target, move, _hookName, fn)
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  BattleCompat.prepareAiBattler(battle, user)
  BattleCompat.prepareAiBattler(battle, target)
  local adapter = Adapters.forBattle(battle)
  local ec = EffectCtx.push(adapter, user, target, move, id,
    battle.rng or battle.random or math.random, {})
  local packed = table.pack(pcall(fn, ec, {
    battle = battle, user = user, target = target, move = move,
  }))
  EffectCtx.pop()
  if not packed[1] then error(packed[2]) end
  return table.unpack(packed, 2, packed.n)
end

return CtxShim
