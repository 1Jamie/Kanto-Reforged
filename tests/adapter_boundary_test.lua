-- Smoke the core package under the mod sandbox (io is unavailable to mods).
-- Engine-leak string scans are done host-side / in CI, not via require("io").
return function(T)
  local ok, err = pcall(require, "mods.Kanto-Reforged.battle.core.effects")
  T.check(ok, "core effects load: " .. tostring(err))

  ok, err = pcall(require, "mods.Kanto-Reforged.battle.core.rules")
  T.check(ok, "core rules load: " .. tostring(err))

  ok, err = pcall(require, "mods.Kanto-Reforged.battle.core.residuals")
  T.check(ok, "core residuals load: " .. tostring(err))

  local Adapters = require("mods.Kanto-Reforged.battle.adapters")
  T.check(Adapters ~= nil, "adapters load")

  local g1Battle = {
    player = { mon = { hp = 50, stats = { hp = 50 } }, name = "A" },
    enemy = { mon = { hp = 30, stats = { hp = 30 } }, name = "B" },
    sides = { player = {}, enemy = {} },
    data = {},
  }
  local g1 = Adapters.forBattle(g1Battle)
  T.check(g1 ~= nil, "gen1 adapter created")
  T.eq(g1._host, "gen1", "gen1 battle routes to gen1 adapter")

  local g2Battle = {
    weatherTurns = 0,
    player = { hp = 50, species = "PIDGEY", name = "A" },
    enemy = { hp = 30, species = "RATTATA", name = "B" },
    sides = { player = {}, enemy = {} },
    sideOf = function(_, mon)
      return mon.species == "PIDGEY" and "player" or "enemy"
    end,
    data = {},
    emit = function() end,
  }
  local g2 = Adapters.forBattle(g2Battle)
  T.check(g2 ~= nil, "gen2 adapter created")
  T.eq(g2._host, "gen2", "gen2 battle routes to gen2 adapter")
  T.check(g2:isGen2(), "gen2 adapter reports isGen2")

  T.check(Adapters.hostFor(g2Battle).id == "gen2", "hostFor picks gen2 module")
  T.check(Adapters.hostFor(g1Battle).id == "gen1", "hostFor picks gen1 module")

  local partyMon = { species = "PIKACHU", moves = { { id = "THUNDERBOLT", pp = 10 } } }
  g1Battle.game = { save = { party = { partyMon } } }
  T.eq(#g1:partyMons(g1Battle.player), 1, "gen1 partyMons reads save party")
  T.eq(g1:preparedMoves({ curMoves = { { id = "TACKLE", pp = 35 } } })[1].id,
    "TACKLE", "preparedMoves prefers curMoves")

  g2Battle.party = {
    { species = "PIDGEY", moves = { { id = "GUST", pp = 35 } } },
    partyMon,
  }
  g2Battle.volatile = function(_, mon)
    if mon.species == "RATTATA" then
      return { lastMove = "BITE" }
    end
  end
  T.eq(#g2:partyMons(g2Battle.player), 2, "gen2 partyMons reads battle.party")
  T.eq(g2:lastMoveOf(g2Battle.enemy), "BITE", "gen2 lastMoveOf reads volatile.lastMove")

  local Volatiles = require("mods.Kanto-Reforged.battle.core.effects.volatiles")
  local target = {
    species = "RATTATA",
    curMoves = { { id = "BITE", pp = 20 } },
  }
  local encoreCtx = {
    adapter = g2,
    user = g2Battle.player,
    target = target,
    rng = function() return 3 end,
  }
  Volatiles.encore(encoreCtx)
  T.eq(target.expEncoreMove, "BITE", "Encore uses adapter lastMoveOf on Gen2")
end
