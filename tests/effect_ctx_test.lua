return function(T)
  local EffectCtx = require("mods.Kanto-Reforged.battle.core.effect_ctx")
  local CoreEffects = require("mods.Kanto-Reforged.battle.core.effects")

  EffectCtx.reset()
  T.eq(EffectCtx.depth(), 0, "starts empty")

  local adapter = {
    foeSide = function() return { hazards = {} } end,
    say = function() end,
  }
  local parentMove = "SLEEP_TALK"
  local ctx1 = EffectCtx.push(adapter, {}, {}, { id = parentMove }, parentMove)
  T.eq(ctx1.moveId, parentMove, "parent ctx moveId")
  T.eq(EffectCtx.depth(), 1, "depth after push")

  local ctx2 = EffectCtx.push(adapter, {}, {}, { id = "BODY_SLAM" }, "BODY_SLAM")
  T.eq(EffectCtx.depth(), 2, "nested depth")
  EffectCtx.pop()
  T.eq(EffectCtx.current().moveId, parentMove, "parent preserved after nested pop")
  EffectCtx.pop()
  T.eq(EffectCtx.depth(), 0, "stack empty")

  local side = { hazards = {} }
  adapter.foeSide = function() return side end
  local ctx = EffectCtx.push(adapter, {}, { _side = side }, {}, "EXP_SPIKES_EFFECT")
  CoreEffects.run("EXP_SPIKES_EFFECT", ctx)
  EffectCtx.pop()
  T.eq(side.hazards[1].id, "SPIKES", "core spikes via ctx stack")

  -- Gen1 performMove prints returned msgs; adapter:say must not also ctx.say.
  local CtxShim = require("mods.Kanto-Reforged.battle.core.effects._ctx")
  local said = {}
  local gen1Ctx = {
    battle = { field = {}, sides = {}, player = {}, enemy = {}, data = {} },
    user = { name = "Castform", isPlayer = true },
    target = {},
    move = { id = "SUNNY_DAY" },
    say = function(text) said[#said + 1] = text end,
  }
  local msgs = CtxShim.runPrimary("EXP_WEATHER_SUNNY", gen1Ctx, function(ec)
    CoreEffects.run("EXP_WEATHER_SUNNY", ec)
  end)
  T.eq(#said, 0, "Sunny Day does not call ctx.say from adapter:say")
  T.eq(#msgs, 1, "Sunny Day returns one line for performMove")
  for _, m in ipairs(msgs) do gen1Ctx.say(m) end
  T.eq(#said, 1, "performMove path prints the weather line once")
  T.check(said[1] and said[1]:find("sunlight", 1, true),
    "Sunny Day text mentions sunlight")
end
