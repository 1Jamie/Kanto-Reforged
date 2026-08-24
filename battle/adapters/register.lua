-- Host-level move-effect registry install (engine API surfaces differ per gen).
-- Gen1: mod.content.move_effects with ctx.run (EffectRegistry pipeline).
-- Gen2: mod.content.move_effects with battle+mons run shims (Battle.lua dispatch).

local Host = require("mods.Kanto-Reforged.core.host")

local Register = {}

function Register.installContent(mod)
  if Host.isGen2() then
    require("mods.Kanto-Reforged.battle.move_effects_gen2").register(mod)
  else
    require("mods.Kanto-Reforged.battle.move_effects").register(mod)
  end
end

function Register.installRuntime(mod)
  if Host.isGen2() then
    require("mods.Kanto-Reforged.battle.move_effects_gen2").install(mod)
  else
    require("mods.Kanto-Reforged.battle.move_effects").install(mod)
  end
end

return Register
