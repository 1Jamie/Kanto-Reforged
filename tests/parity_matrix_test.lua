return function(T)
  local Parity = require("mods.Kanto-Reforged.battle.core.parity")
  local CoreEffects = require("mods.Kanto-Reforged.battle.core.effects")

  local all = Parity.allEffectIds()
  T.check(#all >= 90, "parity matrix lists effects")

  for _, id in ipairs({
    "EXP_SPIKES_EFFECT", "EXP_STEALTH_ROCK_EFFECT", "EXP_SAFEGUARD_EFFECT",
  }) do
    local found = false
    for _, eid in ipairs(all) do
      if eid == id then found = true break end
    end
    T.check(found, "parity includes " .. id)
  end

  T.check(CoreEffects.has("EXP_SPIKES_EFFECT"), "core migrated spikes")
  T.check(CoreEffects.has("EXP_SAFEGUARD_EFFECT"), "core migrated safeguard")

  T.eq(#Parity.RESIDUAL_PHASES, 10, "residual phase count")
  T.check(Parity.FAINT_HALT.weather_chip, "sand chip halts battler")
end
