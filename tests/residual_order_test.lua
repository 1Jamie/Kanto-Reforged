return function(T)
  local Residuals = require("mods.Kanto-Reforged.battle.core.residuals")
  local Rules = require("mods.Kanto-Reforged.battle.core.rules")
  local order = {}

  Residuals.clear()
  for _, phase in ipairs(Rules.phaseOrder()) do
    Residuals.register(phase, function(ctx)
      order[#order + 1] = (ctx.opts and ctx.opts.phase) or phase
    end)
  end

  local adapter = { _fainted = {} }
  function adapter.activeBattlers()
    return { { id = "a" }, { id = "b" } }
  end
  function adapter.isFainted(_, b)
    return adapter._fainted[b.id]
  end
  function adapter.isBattleDecided()
    return false
  end
  function adapter.emitFaint(_, b)
    adapter._fainted[b.id] = true
  end
  function adapter.rng()
    return math.random
  end

  Residuals.runTurn(adapter)
  -- 3 field weather phases + 7 per-battler phases × 2 battlers = 17
  T.eq(#order, 17, "field + per-battler phase count")
  T.eq(order[1], "weather_continue", "first phase")

  -- Restore production handlers after the isolated order probe.
  Residuals.clear()
  require("mods.Kanto-Reforged.battle.core.residual_handlers").registerAll()
end
