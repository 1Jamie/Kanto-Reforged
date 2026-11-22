package.path = package.path .. ";../../?.lua;../?.lua;./?.lua"

local Host = require("mods.Kanto-Reforged.core.host")
local RegisGame3 = require("mods.Kanto-Reforged.world.regis_game3")

Host.force(3)
assert(Host.isGen3(), "Host must be forced to Gen 3")

local saveStore = {}
local mockMod = {
  save = {
    get = function(self, k, default)
      if saveStore[k] ~= nil then return saveStore[k] end
      return default
    end,
    set = function(self, k, v)
      saveStore[k] = v
    end,
  },
}

local Message = require("src.ui.game3.message")
local BattleBridge = require("src.core.game3.battle_bridge")
BattleBridge.startWild = function(mod, game, foe, opts)
  if opts and opts.done then opts.done("win") end
end
local session = { flags = {} }
local lastPushed = nil
Message.show = function(msg, done)
  lastPushed = msg
  if done then done() end
end

local mockGame = {
  stack = {
    push = function(self, box)
      lastPushed = box and (box.text or (box.pages and box.pages[1])) or "text"
      if box and box.opts and box.opts.choice then box.opts.choice(true) end
      if box and box.done then box.done() end
      if box and box.onDone then box.onDone() end
    end
  }
}

-- 1. Test Unlocked Check: Before Tanoby Key (0x849), pedestal must be inactive
assert(not session.flags[RegisGame3.FLAG_SYS_UNLOCKED_TANOBY_RUINS], "Tanoby Key not yet solved")
RegisGame3.interactPedestal(mockGame, mockMod, session, RegisGame3.CHAMBERS.SCUFIB)
assert(not mockMod.save:get("kr_defeated_regirock"), "Regirock should not be triggered before Tanoby Key")

-- 2. Unlock Tanoby Key
session.flags[RegisGame3.FLAG_SYS_UNLOCKED_TANOBY_RUINS] = true

-- 3. Test Scufib Chamber -> Regirock (401)
RegisGame3.interactPedestal(mockGame, mockMod, session, RegisGame3.CHAMBERS.SCUFIB)
assert(mockMod.save:get("kr_defeated_regirock") == true, "Regirock battle must mark defeated flag")

-- Subsequent interaction should report quiet
lastPushed = nil
RegisGame3.interactPedestal(mockGame, mockMod, session, RegisGame3.CHAMBERS.SCUFIB)
assert(lastPushed and lastPushed:find("quiet"), "Subsequent interaction must indicate pedestal is quiet")

-- 4. Test Dilford Chamber -> Regice (402)
RegisGame3.interactPedestal(mockGame, mockMod, session, RegisGame3.CHAMBERS.DILFORD)
assert(mockMod.save:get("kr_defeated_regice") == true, "Regice battle must mark defeated flag")

-- 5. Test Viapois Chamber -> Registeel (403)
RegisGame3.interactPedestal(mockGame, mockMod, session, RegisGame3.CHAMBERS.VIAPOIS)
assert(mockMod.save:get("kr_defeated_registeel") == true, "Registeel battle must mark defeated flag")

print("game3_regis_test passed cleanly!")
