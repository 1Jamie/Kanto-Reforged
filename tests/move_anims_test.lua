-- Gen 1 stock anim reuse + custom compositions for Gen 2+ moves.
return function(T, Data, run)
  local MoveAnims = require("mods.Kanto-Reforged.battle.move_anims")

  -- Custom compositions take priority over whole-clip aliases
  T.eq(MoveAnims.pickAlias({ id = "SHADOW_BALL", type = "GHOST", power = 80 }),
    nil, "Shadow Ball uses a custom composition")
  T.check(MoveAnims.CUSTOM.SHADOW_BALL ~= nil, "SHADOW_BALL custom exists")
  T.check(MoveAnims.CUSTOM.NIGHT_SHADE == nil,
    "Night Shade stays stock (not overridden)")

  local sb = MoveAnims.CUSTOM.SHADOW_BALL.seq
  T.check(#sb >= 4, "Shadow Ball seq has several rows")
  local hasSpiral, hasSwiftSub, hasDark = false, false, false
  for _, row in ipairs(sb) do
    if row.effect == "SE_SPIRAL_BALLS_INWARD" then hasSpiral = true end
    if row.effect == "SE_DARK_SCREEN_PALETTE" then hasDark = true end
    if row.subanim == 63 then hasSwiftSub = true end
  end
  T.check(hasDark and hasSpiral and hasSwiftSub,
    "Shadow Ball mixes dark palette + swift stars + spiral balls")

  T.check(MoveAnims.CUSTOM.DARK_PULSE ~= nil, "DARK_PULSE custom exists")
  T.check(MoveAnims.CUSTOM.SHADOW_BALL.source ~= MoveAnims.CUSTOM.DARK_PULSE.source,
    "Shadow Ball and Dark Pulse are distinct customs")

  -- Alias path still works for moves without customs
  T.eq(MoveAnims.pickAlias({ id = "SOME_NEW_FIRE", type = "FIRE", power = 40 }),
    "EMBER", "weak Fire defaults to Ember")
  T.eq(MoveAnims.pickAlias({ id = "SOME_BIG_FIRE", type = "FIRE", power = 110 }),
    "FLAMETHROWER", "strong Fire defaults to Flamethrower")
  T.eq(MoveAnims.pickAlias({ id = "SOME_STATUS", type = "PSYCHIC_TYPE", power = 0, category = "status" }),
    "MEDITATE", "Psychic status defaults to Meditate")
  T.eq(MoveAnims.pickAlias({ id = "MAGNITUDE", type = "GROUND", power = 0, category = "physical" }),
    "EARTHQUAKE", "Magnitude (variable power) is not Sand-Attack")
  T.eq(MoveAnims.pickAlias({ id = "FLAIL", type = "NORMAL", power = 0, category = "physical" }),
    "TACKLE", "Flail (variable power) uses damage anim")
  T.eq(MoveAnims.pickAlias({ id = "REVERSAL", type = "FIGHTING", power = 0, category = "physical" }),
    "LOW_KICK", "Reversal (variable power) uses damage anim")
  T.eq(MoveAnims.pickAlias({ id = "VAR_GROUND", type = "GROUND", power = 0, category = "physical" }),
    "BONE_CLUB", "unlisted variable-power Ground uses damage default")

  -- Weather moves: custom compositions, not type-default status clips
  T.eq(MoveAnims.pickAlias({ id = "SUNNY_DAY", type = "FIRE", power = 0, category = "status" }),
    nil, "Sunny Day uses a custom composition")
  T.check(MoveAnims.CUSTOM.SUNNY_DAY ~= nil, "SUNNY_DAY custom exists")
  T.eq(MoveAnims.CUSTOM.SUNNY_DAY.seq[1].effect, "SE_LIGHT_SCREEN_PALETTE",
    "Sunny Day opens with light palette (not Smokescreen sand)")
  T.check(MoveAnims.CUSTOM.SUNNY_DAY.seq[2].subanim == 46,
    "Sunny Day uses Solarbeam gather subanim")
  T.eq(MoveAnims.pickAlias({ id = "MORNING_SUN", type = "NORMAL", power = 0, category = "status" }),
    nil, "Morning Sun uses a custom composition")
  T.check(MoveAnims.CUSTOM.MORNING_SUN ~= nil, "MORNING_SUN custom exists")
  T.eq(MoveAnims.CUSTOM.SANDSTORM.seq[1].subanim, 40,
    "Sandstorm cast uses Sand-Attack subanim")
  T.eq(MoveAnims.CUSTOM.HAIL.seq[1].subanim, 56,
    "Hail cast uses Blizzard subanim")

  -- Ghost/Dark type defaults no longer collapse onto the same clip
  T.eq(MoveAnims.pickAlias({ id = "WEAK_GHOST", type = "GHOST", power = 40 }),
    "LICK", "weak Ghost defaults to Lick (not Night Shade)")
  T.eq(MoveAnims.pickAlias({ id = "STRONG_DARK", type = "DARK", power = 90 }),
    "SUPER_FANG", "strong Dark defaults to Super Fang (not Night Shade)")

  -- Every Gen 2+ damaging move with power 0/nil gets a non-status alias
  local pd = require("mods.Kanto-Reforged.pokemon.pokemon_data")
  local statusAnims = {
    GROWL = true, SMOKESCREEN = true, WITHDRAW = true, GROWTH = true,
    THUNDER_WAVE = true, MIST = true, FOCUS_ENERGY = true, POISONPOWDER = true,
    SAND_ATTACK = true, DOUBLE_TEAM = true, MEDITATE = true, STRING_SHOT = true,
    HARDEN = true, CONFUSE_RAY = true, LEER = true, LOVELY_KISS = true,
  }
  local bad = 0
  for id, m in pairs(pd.moves) do
    if (m.power == nil or m.power == 0)
        and (m.category == "physical" or m.category == "special") then
      if MoveAnims.CUSTOM[id] then
        -- custom compositions are fine
      else
        local alias = MoveAnims.pickAlias(m)
        if statusAnims[alias] then
          bad = bad + 1
          T.check(false, id .. " variable-power mapped to status anim " .. alias)
        end
      end
    end
  end
  T.eq(bad, 0, "no variable-power damaging move uses a status anim")

  T.check(Data.battle_anims and Data.battle_anims.moveAnims, "battle_anims loaded")

  -- Custom registrations land in Data with the custom source tag
  local shadow = Data.battle_anims.moveAnims.SHADOW_BALL
  T.check(shadow ~= nil and shadow.seq ~= nil, "SHADOW_BALL has anim seq")
  T.eq(shadow.source, "custom:shadow_ball", "SHADOW_BALL source tagged custom")
  T.check(shadow.seq ~= Data.battle_anims.moveAnims.NIGHT_SHADE.seq,
    "SHADOW_BALL no longer shares Night Shade seq table")

  local rollout = Data.battle_anims.moveAnims.ROLLOUT
  T.check(rollout ~= nil and rollout.seq ~= nil, "ROLLOUT has anim seq")
  T.eq(rollout.source, "custom:rollout", "ROLLOUT source tagged custom")
  T.check(Data.battle_anims.moveAnims.ICE_BALL ~= nil, "ICE_BALL registered")
  T.check(Data.battle_anims.moveAnims.LEAF_BLADE ~= nil, "LEAF_BLADE registered")
  T.eq(Data.battle_anims.moveAnims.LEAF_BLADE.source, "custom:leaf_blade",
    "LEAF_BLADE is composed")

  -- Alias registrations still share stock seq tables
  local pursuit = Data.battle_anims.moveAnims.PURSUIT
  local qa = Data.battle_anims.moveAnims.QUICK_ATTACK
  T.check(pursuit and qa and pursuit.seq == qa.seq,
    "PURSUIT still aliases Quick Attack seq")
  T.eq(pursuit.source, "alias:QUICK_ATTACK", "PURSUIT source tagged as alias")

  T.eq(MoveAnims.ALIAS_BY_ID.SHADOW_BALL, "custom:shadow_ball",
    "ALIAS_BY_ID records custom source for Shadow Ball")
  T.eq(MoveAnims.ALIAS_BY_ID.PURSUIT, "QUICK_ATTACK",
    "ALIAS_BY_ID records stock alias for Pursuit")

  -- Every CUSTOM entry for a Gen 2+ move is registered and playable
  local AnimPlayer = require("src.battle.AnimPlayer")
  local player = AnimPlayer.new(Data.battle_anims)
  local unplayable = 0
  for id, c in pairs(MoveAnims.CUSTOM) do
    if pd.moves[id] then
      local registered = Data.battle_anims.moveAnims[id]
      if not (registered and registered.seq and registered.source == c.source) then
        unplayable = unplayable + 1
        T.check(false, id .. " custom not registered with expected source")
      else
        player:start(id, true)
        if not (player.steps and #player.steps > 0) then
          unplayable = unplayable + 1
          T.check(false, id .. " AnimPlayer built no steps")
        end
      end
    end
  end
  T.eq(unplayable, 0, "all Gen 2+ CUSTOM anims register and play")

  -- Spot-check a few more compositions
  player:start("ROLLOUT", true)
  T.check(player.steps and #player.steps > 0, "AnimPlayer builds steps for ROLLOUT")
  player:start("PSYSHOCK", true)
  T.check(player.steps and #player.steps > 0, "AnimPlayer builds steps for PSYSHOCK")
  player:start("MOONBLAST", true)
  T.check(player.steps and #player.steps > 0, "AnimPlayer builds steps for MOONBLAST")

  -- Gen2 Hail primitives: alias onto stock Powder Snow / ANIM_IN_SANDSTORM.
  do
    local Host = require("mods.Kanto-Reforged.core.host")
    local ok, err = xpcall(function()
      Host.force(2)
      local patchedMoves, patchedIds = nil, nil
      local fakeMod = {
        log = { info = function() end, warn = function() end },
        content = {
          battle_anims = {
            get = function(_, key)
              if key == "moves" then
                return {
                  POWDER_SNOW = "6e7b",
                  BLIZZARD = "5883",
                  HAIL = patchedMoves and patchedMoves.HAIL or nil,
                }
              end
              if key == "ids" then
                return {
                  ANIM_IN_SANDSTORM = "54ce",
                  ANIM_IN_HAIL = patchedIds and patchedIds.ANIM_IN_HAIL or nil,
                }
              end
            end,
            patch = function(_, key, partial)
              if key == "moves" then patchedMoves = partial end
              if key == "ids" then patchedIds = partial end
            end,
          },
        },
      }
      local n = MoveAnims.registerGen2(fakeMod)
      T.check(n >= 2, "Gen2 register maps Hail move + field residual")
      T.eq(patchedMoves.HAIL, "6e7b", "HAIL aliases Powder Snow's script pointer")
      T.eq(patchedIds.ANIM_IN_HAIL, "54ce",
        "ANIM_IN_HAIL aliases ANIM_IN_SANDSTORM's script pointer")
    end, debug.traceback)
    Host.clearForce()
    if not ok then error(err) end
  end
end
