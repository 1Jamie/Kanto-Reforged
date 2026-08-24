-- Register all core move effects on the Gen1 content table.

local CoreEffects = require("mods.Kanto-Reforged.battle.core.effects")

local Install = {}

function Install.allPrimary()
  return CoreEffects.all()
end

function Install.allHooks()
  return CoreEffects.allHookIds()
end

function Install.isCore(id)
  return CoreEffects.has(id) or CoreEffects.hasHooks(id)
end

return Install
