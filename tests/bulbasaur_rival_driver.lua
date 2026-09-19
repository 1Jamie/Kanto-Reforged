-- Driver: Oak's lab Bulbasaur pick -> Rival battle
return function(game)
  local U = dofile("/home/autumn/src/gen1recomp/tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Commands = require("src.script.Commands")

  U.log("--- Starting Bulbasaur Starter Test Driver ---")
  local ow = game.overworld

  local function idle()
    return game.stack:top() == ow and not ow.runner:isRunning()
           and #ow.scriptMoves == 0 and not ow.transitioning
           and not ow.emote
  end

  local function mashUntil(cond, label, cap)
    for _ = 1, cap or 400 do
      if cond() then return true end
      if game.stack:top() ~= ow then
        U.tap(game, "a")
      end
      U.wait(4)
    end
    U.log("TIMEOUT waiting for " .. label)
    return false
  end

  -- Teleport into Oak's lab after Oak escort
  U.teleport(game, "OAKS_LAB", 5, 3, "down")
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB_2 = true
  game.save.player.name = "RED"
  game.save.player.rival = "BLUE"

  local ctx = { game = game, save = game.save, overworld = ow }
  Commands.show_object(ctx, "OAKS_LAB", "OAKSLAB_OAK1")
  Commands.show_object(ctx, "OAKS_LAB", "OAKSLAB_RIVAL")
  Commands.show_object(ctx, "OAKS_LAB", "OAKSLAB_CHARMANDER_POKE_BALL")
  Commands.show_object(ctx, "OAKS_LAB", "OAKSLAB_SQUIRTLE_POKE_BALL")
  Commands.show_object(ctx, "OAKS_LAB", "OAKSLAB_BULBASAUR_POKE_BALL")
  U.wait(10)

  U.log("Player at desk:", ow.player.cellX, ow.player.cellY)

  -- Move to Bulbasaur ball at (8,3) -> stand at (8,4) facing up
  U.hold(game, "down", 18)
  U.wait(10)
  U.hold(game, "right", 52)
  U.wait(20)
  U.tap(game, "up")
  U.wait(10)
  U.log("At Bulbasaur ball:", ow.player.cellX, ow.player.cellY, ow.player.facing)

  -- Interact with ball
  U.tap(game, "a")
  U.wait(40)
  -- Answer YES to prompt
  U.tap(game, "a")
  mashUntil(function() return #game.save.party > 0 end, "receive starter", 300)
  U.log("Received starter:", game.save.party[1] and game.save.party[1].species)

  -- Step down away from table
  U.hold(game, "down", 20)
  mashUntil(idle, "rival pick done", 400)
  U.log("Rival finished taking ball. Player at:", ow.player.cellX, ow.player.cellY)

  -- Walk to exit: left to column 4, then down to y=6
  for _ = 1, 4 do
    U.hold(game, "left", 16)
    U.wait(12)
  end
  U.log("Player at column:", ow.player.cellX, ow.player.cellY)
  U.hold(game, "down", 120)
  U.wait(30)

  U.log("Player walked down. Checking battle trigger...")
  local battleSeen = false
  for frame = 1, 600 do
    local top = game.stack:top()
    if top ~= ow and top and top.kind == "trainer" then
      battleSeen = true
      U.log("BATTLE STARTED! Top of stack:", tostring(top), "kind:", top.kind, "oppClass:", top.oppClass, "partyIndex:", top.partyIndex)
      break
    end
    if game.stack:top() ~= ow then
      U.tap(game, "a")
    end
    U.wait(2)
  end

  if not battleSeen then
    U.log("FAIL: Battle NEVER started! Player at:", ow.player.cellX, ow.player.cellY, "runner isRunning:", ow.runner:isRunning())
  else
    U.log("PASS: Battle successfully started!")
  end

  U.wait(60)
  love.event.quit()
end
