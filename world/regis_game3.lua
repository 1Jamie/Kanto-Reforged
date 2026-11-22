-- The Hoenn Regis in Tanoby Ruins for FRLG in Kanto Reforged.
-- Unlocks Regirock, Regice, and Registeel inside the underutilized Tanoby chambers:
-- 1) Regirock (species 401, lv 50) in Scufib Chamber
-- 2) Regice (species 402, lv 50) in Dilford Chamber
-- 3) Registeel (species 403, lv 50) in Viapois Chamber
-- Requires Tanoby Key to be solved (FLAG_SYS_UNLOCKED_TANOBY_RUINS = 0x849).
-- Persistent despawn flags ensure caught/defeated Regis do not respawn.

local RegisGame3 = {}

RegisGame3.SPECIES_REGIROCK = 401
RegisGame3.SPECIES_REGICE = 402
RegisGame3.SPECIES_REGISTEEL = 403

RegisGame3.FLAG_SYS_UNLOCKED_TANOBY_RUINS = 0x849

RegisGame3.CHAMBERS = {
  SCUFIB = {
    map = "FR_SEVEN_ISLAND_TANOBY_RUINS_SCUFIB_CHAMBER",
    alias = "SevenIsland_TanobyRuins_ScufibChamber",
    species = 401,
    name = "REGIROCK",
    saveKey = "kr_defeated_regirock",
    pos = { x = 4, y = 3 },
    wakeMsg = "A primordial rumbling echoes through the chamber...\n\nThe ancient stone titan awakens!",
  },
  DILFORD = {
    map = "FR_SEVEN_ISLAND_TANOBY_RUINS_DILFORD_CHAMBER",
    alias = "SevenIsland_TanobyRuins_DilfordChamber",
    species = 402,
    name = "REGICE",
    saveKey = "kr_defeated_regice",
    pos = { x = 4, y = 3 },
    wakeMsg = "A freezing chill sweeps across the chamber...\n\nThe ancient iceberg titan awakens!",
  },
  VIAPOIS = {
    map = "FR_SEVEN_ISLAND_TANOBY_RUINS_VIAPOIS_CHAMBER",
    alias = "SevenIsland_TanobyRuins_ViapoisChamber",
    species = 403,
    name = "REGISTEEL",
    saveKey = "kr_defeated_registeel",
    pos = { x = 4, y = 3 },
    wakeMsg = "A metallic clang reverberates through the hollow hall...\n\nThe ancient iron titan awakens!",
  },
}

local function hasFlag(storeOrSession, flagId)
  local okFlags, Flags = pcall(require, "src.core.game3.scripting.flags")
  if okFlags and Flags and Flags.getFlag then
    if Flags.getFlag(storeOrSession, nil, flagId) then return true end
  end
  if type(storeOrSession) == "table" and storeOrSession.flags then
    if storeOrSession.flags[flagId] or storeOrSession.flags[tostring(flagId)] then return true end
  end
  return false
end

local function showMsg(game, msg, done)
  local okM, Message = pcall(require, "src.ui.game3.message")
  if okM and Message and Message.show then
    Message.show(msg, done)
    return
  end
  local okBox, TextBox = pcall(require, "src.render.TextBox")
  if okBox and TextBox and game and game.stack then
    game.stack:push(TextBox.new(game, msg, done))
    return
  end
  if done then done() end
end

function RegisGame3.startRegiBattle(game, mod, chamber)
  local okBridge, BattleBridge = pcall(require, "src.core.game3.battle_bridge")
  local foe = {
    species = chamber.species,
    level = 50,
    wildScripted = true,
    legendary = true,
  }
  if okBridge and BattleBridge and BattleBridge.startWild then
    BattleBridge.startWild(mod, game, foe, {
      wildScripted = true,
      legendary = true,
      done = function(result)
        if result == "win" or result == "caught" or result == 1 or result == 7 then
          if mod and mod.save then
            mod.save:set(chamber.saveKey, true)
          end
        end
      end
    })
  else
    -- Fallback for test runner or headless mock
    if mod and mod.save then
      mod.save:set(chamber.saveKey, true)
    end
  end
end

function RegisGame3.interactPedestal(game, mod, session, chamber)
  if mod and mod.save and mod.save:get(chamber.saveKey, false) then
    showMsg(game, "The ancient pedestal is quiet.")
    return
  end

  if not hasFlag(session, RegisGame3.FLAG_SYS_UNLOCKED_TANOBY_RUINS) then
    showMsg(game, "A mysterious ancient pedestal is carved into the stone...\n\n"
      .. "It remains cold and unresponsive.\n"
      .. "An ancient mechanism elsewhere in Sevault Canyon\n"
      .. "must be unlocked first.")
    return
  end

  showMsg(game, chamber.wakeMsg, function()
    RegisGame3.startRegiBattle(game, mod, chamber)
  end)
end

function RegisGame3.install(mod)
  RegisGame3._mod = mod

  local okFld, Field = pcall(require, "src.core.game3.field")
  if okFld and Field and Field.interact and not Field._regisInteractWrapped then
    local origInteract = Field.interact
    Field.interact = function(game)
      game = game or Field._game
      local session = (game and game.session) or Field._session
      local curMap = (session and session.map)
      local Map = package.loaded["src.core.game3.map"]
      curMap = curMap or (Map and Map.current)

      local P = package.loaded["src.core.game3.player"]
      if P and not P.moving then
        local fx, fy
        if P.facing == "up" then fx, fy = P.cellX, P.cellY - 1
        elseif P.facing == "down" then fx, fy = P.cellX, P.cellY + 1
        elseif P.facing == "left" then fx, fy = P.cellX - 1, P.cellY
        elseif P.facing == "right" then fx, fy = P.cellX + 1, P.cellY
        end

        for _, chamber in pairs(RegisGame3.CHAMBERS) do
          if (curMap == chamber.map or curMap == chamber.alias) and (fx == chamber.pos.x and fy == chamber.pos.y) then
            RegisGame3.interactPedestal(game, mod, session, chamber)
            return true
          end
        end
      end

      return origInteract(game)
    end
    Field._regisInteractWrapped = true
  end
end

return RegisGame3
