return function(T)
  local Residuals = require("mods.Kanto-Reforged.battle.core.residuals")
  local Rules = require("mods.Kanto-Reforged.battle.core.rules")

  Residuals.clear()
  local phasesRun = {}
  Residuals.register("weather_chip", function()
    phasesRun[#phasesRun + 1] = "weather_chip"
  end)
  Residuals.register("leech_seed", function()
    phasesRun[#phasesRun + 1] = "leech_seed"
  end)
  Residuals.register("held_items", function()
    phasesRun[#phasesRun + 1] = "held_items"
  end)

  local mon = { id = "victim", hp = 0 }
  local adapter = {
    activeBattlers = function() return { mon } end,
    isFainted = function(_, b) return (b.hp or 0) <= 0 end,
    isBattleDecided = function() return false end,
    emitFaint = function() end,
    rng = function() return math.random end,
  }

  Residuals.register("weather_chip", function(ctx)
    if not adapter:isFainted(mon) then
      mon.hp = 0
      phasesRun[#phasesRun + 1] = "chip_killed"
    end
  end)

  Residuals.clear()
  phasesRun = {}
  Residuals.register("weather_chip", function()
    mon.hp = 0
    phasesRun[#phasesRun + 1] = "weather_chip"
  end)
  Residuals.register("leech_seed", function()
    phasesRun[#phasesRun + 1] = "leech_seed"
  end)

  mon.hp = 10
  Residuals.runTurn(adapter)
  T.check(not phasesRun[2], "no leech_seed after faint in same sweep path")
  T.check(Rules.shouldHaltBattlerOnFaint("weather_chip"), "weather chip halts")
end
