-- Gen 3 sandstorm: 1/16 chip, type immunity, Sand Stream, Sand Veil.
return function(T, Data, run)
  local Weather = require("mods.Kanto-Reforged.battle.weather")
  local Abilities = require("mods.Kanto-Reforged.battle.abilities")
  local BattleCompat = require("mods.Kanto-Reforged.battle.battle_compat")
  local Runtime = require("src.mods.Runtime")
  local Host = require("mods.Kanto-Reforged.core.host")

  T.eq(Weather.chipAmount(80), 5, "sandstorm chips 1/16 max HP")
  T.eq(Weather.chipAmount(15), 1, "sandstorm chip is at least 1")
  T.eq(Weather.TICK_ANIM, "IN_SANDSTORM", "Gen 1 residual is a field weather clip")
  local tickSeq = Weather.tickSeq()
  T.eq(tickSeq[1].subanim, 40, "sand tick uses Sand-Attack subanim")
  T.eq(tickSeq[2].effect, "SE_SHAKE_SCREEN", "tick shakes the screen")
  T.check(not tickSeq[1].effect,
    "sand tick is not rain droplets")

  local sunTick = Weather.tickSeq("SUNNY")
  T.eq(sunTick[1].effect, "SE_LIGHT_SCREEN_PALETTE", "sun tick brightens the screen")
  T.eq(sunTick[2].effect, "SE_SPIRAL_BALLS_INWARD", "sun tick spirals light inward")
  T.eq(sunTick[3].effect, "SE_RESET_SCREEN_PALETTE", "sun tick restores palette")

  local hailTick = Weather.tickSeq("HAIL")
  T.eq(hailTick[1].subanim, 47, "hail tick uses Ice Beam subanim")
  T.eq(hailTick[2].effect, "SE_DARK_SCREEN_FLASH", "hail tick flashes cold")

  local sandLine = Weather.chipText("Enemy TAILLOW", "SANDSTORM")
  T.check(not sandLine:find("TAILLOW is bu", 1, true),
    "chip text does not clip 'buffeted' on the name line")
  T.check(sandLine:find("\n", 1, true), "chip text breaks after the name")
  T.eq(Weather.rewrittenChipText("Enemy TAILLOW is buffeted by the sandstorm!"),
    sandLine, "Gold one-liner is rewritten to boxed lines")

  T.eq(Weather.typeModifier({ field = { weather = "SUNNY" } }, "FIRE"), 1.5,
    "sun boosts Fire")
  T.eq(Weather.typeModifier({ field = { weather = "SUNNY" } }, "WATER"), 0.5,
    "sun cuts Water")
  T.eq(Weather.typeModifier({ field = { weather = "RAINY" } }, "WATER"), 1.5,
    "rain boosts Water")
  T.check(Weather.neverMiss({ field = { weather = "RAINY" } }, { id = "THUNDER" }),
    "Thunder never misses in rain")
  T.check(Weather.neverMiss({ field = { weather = "HAIL" } }, { id = "BLIZZARD" }),
    "Blizzard never misses in hail")
  T.check(Weather.instantCharge({ field = { weather = "SUNNY" } }, { id = "SOLARBEAM" }),
    "Solar Beam skips charge in sun")
  T.eq(Weather.healFraction({ field = { weather = "SUNNY" } }), 2 / 3,
    "Synthesis heals 2/3 in sun")
  T.eq(Weather.healFraction({ field = { weather = "RAINY" } }), 1 / 4,
    "Synthesis heals 1/4 in rain")

  local function fakeMon(species, hp, types)
    local def = Data.pokemon[species]
    return {
      species = species,
      hp = hp,
      stats = { hp = hp },
      types = types or (def and def.types) or { "NORMAL" },
    }
  end

  local msgs, anims, drains = {}, {}, {}
  local function battleOf(player, enemy, weather, turns)
    msgs, anims, drains = {}, {}, {}
    return {
      data = Data,
      field = { weather = weather, weatherTurns = turns },
      player = player,
      enemy = enemy,
      sayNext = function(_, text) msgs[#msgs + 1] = text end,
      animNext = function(_, name) anims[#anims + 1] = name end,
      drainNext = function(_, who) drains[#drains + 1] = who end,
    }
  end

  -- Type immunity (Rock / Ground / Steel); Grass takes chip.
  local rattata = {
    isPlayer = false, name = "RATTATA",
    mon = fakeMon("RATTATA", 32, { "NORMAL" }),
  }
  local golem = {
    isPlayer = true, name = "GOLEM",
    mon = fakeMon("GOLEM", 80, { "ROCK", "GROUND" }),
  }
  local b = battleOf(golem, rattata, "SANDSTORM", 5)
  T.check(not Weather.hits(b, golem), "Rock/Ground is immune to sandstorm")
  T.check(Weather.hits(b, rattata), "Normal is hit by sandstorm")
  rattata.invulnerable = true
  T.check(not Weather.hits(b, rattata), "underground Dig skips sandstorm")
  rattata.invulnerable = nil

  Weather.tick(b)
  T.eq(golem.mon.hp, 80, "immune side takes no sandstorm chip")
  T.eq(rattata.mon.hp, 30, "1/16 of 32 is 2 HP")
  T.eq(#anims, 1, "field weather plays once, not per battler")
  T.eq(anims[1], "IN_SANDSTORM", "chip plays the field sandstorm clip")
  T.check(#drains > 0, "chip queues an HP drain")
  T.eq(b.field.weather, "SANDSTORM", "storm still up after first end-of-turn")
  T.eq(b.field.weatherTurns, 4, "Gen 3 residual chips, then the turn counter")
  T.check(msgs[2] and msgs[2]:find("buffeted", 1, true)
      and not msgs[2]:find("is buffeted\nby", 1, true),
    "live chip message keeps buffeted off the name line")

  do
    local ended = {
      data = Data,
      result = "win",
      field = { weather = "SANDSTORM", weatherTurns = 5 },
      player = golem,
      enemy = {
        isPlayer = false, name = "RATTATA",
        mon = fakeMon("RATTATA", 32, { "NORMAL" }),
      },
    }
    Weather.tick(ended)
    T.eq(ended.enemy.mon.hp, 32, "weather does not chip after the battle is won")
    local ko = {
      data = Data,
      field = { weather = "SANDSTORM", weatherTurns = 5 },
      player = golem,
      enemy = {
        isPlayer = false, name = "RATTATA",
        mon = fakeMon("RATTATA", 0, { "NORMAL" }),
      },
    }
    Weather.tick(ko)
    T.eq(golem.mon.hp, 80, "weather does not chip during faint/EXP")
    T.check(Weather.shouldResidual(b), "live both-sides fight still residuals")
    T.check(not Weather.shouldResidual(ended), "decided battle skips residual")
  end

  -- Hail: Ice immune, others take 1/16, field clip.
  do
    local ice = {
      isPlayer = true, name = "JYNX",
      mon = fakeMon("JYNX", 64, { "ICE", "PSYCHIC_TYPE" }),
    }
    local bird = {
      isPlayer = false, name = "PIDGEY",
      mon = fakeMon("PIDGEY", 32, { "NORMAL", "FLYING" }),
    }
    local hb = battleOf(ice, bird, "HAIL", 5)
    T.check(not Weather.hits(hb, ice, "HAIL"), "Ice is immune to hail")
    T.check(Weather.hits(hb, bird, "HAIL"), "non-Ice is hit by hail")
    Weather.tick(hb)
    T.eq(ice.mon.hp, 64, "Ice takes no hail chip")
    T.eq(bird.mon.hp, 30, "hail chips 1/16")
    T.eq(anims[1], "IN_HAIL", "hail uses the field hail clip")
  end

  for _ = 1, 4 do Weather.tick(b) end
  T.eq(b.field.weather, nil, "5-turn sandstorm chips on the fifth tick then ends")
  T.eq(rattata.mon.hp, 22, "five 2 HP chips land, including the fade turn")

  -- Sand Stream: infinite until replaced.
  if Data.pokemon.TYRANITAR then
    Data.pokemon.TYRANITAR.ability = "SAND_STREAM"
    local tara = {
      isPlayer = true, name = "TARA",
      mon = fakeMon("TYRANITAR", 100, Data.pokemon.TYRANITAR.types),
    }
    local foe = {
      isPlayer = false, name = "RATTATA",
      mon = fakeMon("RATTATA", 48, { "NORMAL" }),
    }
    local sb = battleOf(tara, foe)
    Abilities.onEntry(sb, tara)
    T.eq(BattleCompat.getWeather(sb), "SANDSTORM", "Sand Stream sets sandstorm")
    T.check(sb._krAbilityWeather, "Sand Stream is ability weather")
    local hp = foe.mon.hp
    for _ = 1, 8 do Weather.tick(sb) end
    T.eq(BattleCompat.getWeather(sb), "SANDSTORM",
      "ability sandstorm does not expire after 5 turns")
    T.check(foe.mon.hp < hp, "ability sandstorm still chips")
    T.check(tara.mon.hp == 100, "Tyranitar is Rock-type immune")

    -- A weather move replaces ability weather with a 5-turn clock.
    BattleCompat.setWeather(sb, "SUNNY")
    T.check(not sb._krAbilityWeather, "Sunny Day clears ability weather")
    T.eq(BattleCompat.getWeather(sb), "SUNNY", "Sunny Day overwrites sand")
  end

  -- Sand Veil: extra 20% miss in sand (Gen 3 4/5 accuracy).
  do
    local rolls = { 10 } -- 0-99; <20 forces the Sand Veil miss
    local i = 0
    local hit = Runtime.call("battle.accuracy", function() return true end, {
      battle = {
        field = { weather = "SANDSTORM" },
        data = Data,
        rng = function()
          i = i + 1
          return rolls[i] or 99
        end,
      },
      user = { mon = fakeMon("RATTATA", 20, { "NORMAL" }) },
      target = { mon = fakeMon("SANDSHREW", 20, { "GROUND" }) },
      move = { id = "TACKLE", type = "NORMAL", accuracy = 100, category = "physical" },
    })
    if Data.pokemon.SANDSHREW and Data.pokemon.SANDSHREW.ability == "SAND_VEIL" then
      T.eq(hit, false, "Sand Veil 20% check can force a miss")
    end
  end

  -- Gold keeps native HandleWeather; we only overlay 1/16.
  if Host.isGen2() then
    local Effects = require("src.battle.gen2.Effects")
    T.eq(Effects.sandstormDamage(80), 5, "Gold sandstormDamage overlay is 1/16")
  else
    local ok, Effects = pcall(require, "src.battle.gen2.Effects")
    if ok and Effects and Effects._krGen3SandChip then
      T.eq(Effects.sandstormDamage(80), 5, "sandstormDamage primitive is 1/16")
    end
  end

  -- =========================================================================
  -- Castform, Forecast, Weather Ball, and Weather Suppression (Air Lock / Cloud Nine)
  -- =========================================================================
  do
    local MoveEffects = require("mods.Kanto-Reforged.battle.move_effects")

    -- 1. Forecast transformations in all weathers
    local castformMon = fakeMon("CASTFORM", 70, { "NORMAL" })
    Data.pokemon.CASTFORM = Data.pokemon.CASTFORM or {}
    Data.pokemon.CASTFORM.ability = "FORECAST"
    local castformBattler = {
      isPlayer = true, name = "CASTFORM", mon = castformMon, curTypes = { "NORMAL" },
    }
    local foeMon = fakeMon("RATTATA", 50, { "NORMAL" })
    local foeBattler = {
      isPlayer = false, name = "RATTATA", mon = foeMon, curTypes = { "NORMAL" },
    }

    local cb = battleOf(castformBattler, foeBattler, nil, 0)

    -- Clear weather -> NORMAL
    Abilities.updateForecast(cb, castformBattler)
    T.eq(castformBattler.curTypes[1], "NORMAL", "Castform is NORMAL in clear weather")
    local t, p = MoveEffects.weatherBall(cb)
    T.eq(t, "NORMAL", "Weather Ball is NORMAL in clear weather")
    T.eq(p, 50, "Weather Ball is 50 power in clear weather")

    -- Sun -> FIRE, Weather Ball FIRE / 100
    BattleCompat.setWeather(cb, "SUNNY")
    Abilities.updateForecast(cb, castformBattler)
    T.eq(castformBattler.curTypes[1], "FIRE", "Forecast transforms Castform to FIRE in SUNNY")
    t, p = MoveEffects.weatherBall(cb)
    T.eq(t, "FIRE", "Weather Ball is FIRE in SUNNY")
    T.eq(p, 100, "Weather Ball is 100 power in SUNNY")
    T.eq(BattleCompat.castformSuffix("SUNNY"), "sunny", "castformSuffix is sunny in SUNNY")

    -- Rain -> WATER, Weather Ball WATER / 100
    BattleCompat.setWeather(cb, "RAINY")
    Abilities.updateForecast(cb, castformBattler)
    T.eq(castformBattler.curTypes[1], "WATER", "Forecast transforms Castform to WATER in RAINY")
    t, p = MoveEffects.weatherBall(cb)
    T.eq(t, "WATER", "Weather Ball is WATER in RAINY")
    T.eq(p, 100, "Weather Ball is 100 power in RAINY")
    T.eq(BattleCompat.castformSuffix("RAINY"), "rainy", "castformSuffix is rainy in RAINY")

    -- Hail -> ICE, Weather Ball ICE / 100
    BattleCompat.setWeather(cb, "HAIL")
    Abilities.updateForecast(cb, castformBattler)
    T.eq(castformBattler.curTypes[1], "ICE", "Forecast transforms Castform to ICE in HAIL")
    t, p = MoveEffects.weatherBall(cb)
    T.eq(t, "ICE", "Weather Ball is ICE in HAIL")
    T.eq(p, 100, "Weather Ball is 100 power in HAIL")
    T.eq(BattleCompat.castformSuffix("HAIL"), "snowy", "castformSuffix is snowy in HAIL")

    -- Sandstorm -> NORMAL, Weather Ball ROCK / 100
    BattleCompat.setWeather(cb, "SANDSTORM")
    Abilities.updateForecast(cb, castformBattler)
    T.eq(castformBattler.curTypes[1], "NORMAL", "Forecast leaves Castform NORMAL in SANDSTORM")
    t, p = MoveEffects.weatherBall(cb)
    T.eq(t, "ROCK", "Weather Ball is ROCK in SANDSTORM")
    T.eq(p, 100, "Weather Ball is 100 power in SANDSTORM")
    T.eq(BattleCompat.castformSuffix("SANDSTORM"), nil, "castformSuffix is nil in SANDSTORM")

    -- Gold party mons are the battler (no .mon wrapper). Forecast type must
    -- survive a second sync the way a follow-up Weather Ball would.
    local goldCastform = { species = "CASTFORM", types = { "NORMAL" } }
    local goldBattle = battleOf(goldCastform, { species = "RATTATA" }, "SUNNY", 5)
    goldBattle.weather = "sun"
    goldBattle.weatherTurns = 5
    goldBattle.player = goldCastform
    Abilities.updateForecast(goldBattle, goldCastform)
    T.eq(goldCastform.curTypes[1], "FIRE", "Forecast stores curTypes on a Gold party mon")
    T.eq(BattleCompat.types(goldCastform)[1], "FIRE", "types() reads Forecast curTypes")
    Abilities.updateForecast(goldBattle, goldCastform)
    T.eq(goldCastform.curTypes[1], "FIRE", "second Forecast sync does not revert")

    -- 2. Weather Suppression (Air Lock / Cloud Nine)
    Data.pokemon.RAYQUAZA = Data.pokemon.RAYQUAZA or {}
    Data.pokemon.RAYQUAZA.ability = "AIR_LOCK"
    Data.pokemon.GOLDUCK = Data.pokemon.GOLDUCK or {}
    Data.pokemon.GOLDUCK.ability = "CLOUD_NINE"

    local rayMon = fakeMon("RAYQUAZA", 100, { "DRAGON", "FLYING" })
    local rayBattler = {
      isPlayer = false, name = "RAYQUAZA", mon = rayMon, curTypes = { "DRAGON", "FLYING" },
    }

    -- Start with Sun, Castform transformed
    BattleCompat.setWeather(cb, "SUNNY")
    Abilities.updateForecast(cb, castformBattler)
    T.eq(castformBattler.curTypes[1], "FIRE", "Castform is FIRE in Sun before Air Lock enters")

    -- Rayquaza enters with Air Lock
    cb.enemy = rayBattler
    Abilities.onEntry(cb, rayBattler)
    T.check(Weather.suppressed(cb), "Weather is suppressed when Air Lock is on field")
    T.eq(Weather.current(cb), nil, "Weather.current returns nil when suppressed")
    T.eq(BattleCompat.getWeather(cb), "SUNNY", "Underlying field weather remains SUNNY")
    T.eq(castformBattler.curTypes[1], "NORMAL", "Castform reverts to NORMAL under Air Lock")
    t, p = MoveEffects.weatherBall(cb)
    T.eq(t, "NORMAL", "Weather Ball is NORMAL under Air Lock suppression")
    T.eq(p, 50, "Weather Ball power is 50 under Air Lock suppression")

    -- Rayquaza switches out -> Rattata enters -> weather suppression lifts
    cb.enemy = foeBattler
    Abilities.onEntry(cb, foeBattler)
    Abilities.updateForecast(cb, castformBattler)
    T.check(not Weather.suppressed(cb), "Weather is no longer suppressed after Air Lock leaves")
    T.eq(Weather.current(cb), "SUNNY", "Weather.current returns SUNNY after Air Lock leaves")
    T.eq(castformBattler.curTypes[1], "FIRE", "Castform restores FIRE form after Air Lock leaves")
    t, p = MoveEffects.weatherBall(cb)
    T.eq(t, "FIRE", "Weather Ball returns to FIRE after Air Lock leaves")
    T.eq(p, 100, "Weather Ball returns to 100 power after Air Lock leaves")

    -- Cloud Nine suppression
    local duckMon = fakeMon("GOLDUCK", 80, { "WATER" })
    local duckBattler = {
      isPlayer = false, name = "GOLDUCK", mon = duckMon, curTypes = { "WATER" },
    }
    cb.enemy = duckBattler
    Abilities.onEntry(cb, duckBattler)
    T.check(Weather.suppressed(cb), "Weather is suppressed when Cloud Nine is on field")
    T.eq(castformBattler.curTypes[1], "NORMAL", "Castform reverts to NORMAL under Cloud Nine")

    -- 3. Thunder accuracy in Sun check
    local thunderAccCtx = {
      battle = { field = { weather = "SUNNY" }, data = Data },
      user = foeBattler,
      target = castformBattler,
      move = { id = "THUNDER", type = "ELECTRIC", accuracy = 70, category = "special" },
    }
    local hitThunder = Runtime.call("battle.accuracy", function(ctx)
      return ctx.move.accuracy
    end, thunderAccCtx)
    T.eq(hitThunder, 50, "Thunder accuracy is modified to 50% in harsh sunlight")

    -- 4. Dialogue and Text Layout Engine Tests
    local Dialogue = require("mods.Kanto-Reforged.core.dialogue")

    -- UTF-8 glyph counting tests
    T.eq(Dialogue.glyphLen("FERALIGATR"), 10, "ASCII glyph length is 10")
    T.eq(Dialogue.glyphLen("FERALIGATR♂"), 11, "FERALIGATR♂ visual glyph length is 11 (not 13 byte count)")
    T.eq(Dialogue.glyphLen("FERALIGATR♀"), 11, "FERALIGATR♀ visual glyph length is 11 (not 13 byte count)")
    T.eq(Dialogue.glyphLen("POKéMON"), 7, "POKéMON visual glyph length is 7 (not 8 byte count)")
    T.eq(Dialogue.glyphLen("Enemy FERALIGATR♂"), 17, "Enemy FERALIGATR♂ visual glyph length is exactly 17")

    -- Battle format wrapping on extreme edge-cases
    -- 1. "Enemy FERALIGATR♂ used EXTREMESPEED!"
    local bText1 = Dialogue.battle("Enemy %s used %s!", "FERALIGATR♂", "EXTREMESPEED")
    -- Line 1 must be "Enemy FERALIGATR♂", Line 2 must be "used", Line 3 must be "EXTREMESPEED!"
    for line in (bText1 .. "\n"):gmatch("([^\n\v]+)") do
      T.check(Dialogue.glyphLen(line) <= 17, "Battle line <= 17 columns: " .. line)
    end
    T.eq(bText1, "Enemy FERALIGATR♂\nused\vEXTREMESPEED!", "Dialogue correctly wrapped 17-col edge case with \\v")

    -- 2. Multi-sentence ability and weather suppression
    local bText2 = Dialogue.battle("%s's %s suppressed the weather!", "Enemy RAYQUAZA", "AIR LOCK")
    for line in (bText2 .. "\n"):gmatch("([^\n\v]+)") do
      T.check(Dialogue.glyphLen(line) <= 17, "Battle line <= 17 columns: " .. line)
    end
    T.check(bText2:find("\n") ~= nil, "Battle line 2 uses \\n")

    -- 3. Overworld format wrapping with \f page breaks
    local owText = Dialogue.overworld("Welcome to the Cinnabar Island Pokémon Gym! Here is some important advice for your journey ahead.")
    local owPages = {}
    for p in (owText .. "\f"):gmatch("([^\f]+)") do
      table.insert(owPages, p)
      for line in (p .. "\n"):gmatch("([^\n]+)") do
        T.check(Dialogue.glyphLen(line) <= 18, "Overworld line <= 18 columns: " .. line)
      end
    end
    T.check(#owPages >= 2, "Overworld text paginated with \\f page breaks")
  end

  -- Castform morph: fade between weather sprites (not an instant swap).
  do
    local CastformFx = require("mods.Kanto-Reforged.battle.castform_fx")
    CastformFx.install({ path = "mods/Kanto-Reforged" })
    T.eq(CastformFx.TOTAL, 36, "Castform morph is a short fade")
    T.check(CastformFx.assetPath({ path = "mods/Kanto-Reforged" }, "front", "sunny")
      :find("castform_sunny_front", 1, true), "Castform sunny asset path")
    local BS = require("src.battle.BattleState")
    T.check(type(BS.startPicMorph) == "function",
      "Gen1 BattleState exposes startPicMorph")
    local morphMon = fakeMon("CASTFORM", 70, { "NORMAL" })
    local morphBattler = {
      isPlayer = true, name = "CASTFORM", mon = morphMon,
      curTypes = { "NORMAL" }, sprite = { form = "normal" },
    }
    local morphBattle = battleOf(morphBattler, foeBattler, "SUNNY", 5)
    morphBattle.waitNext = function() end
    morphBattle.startPicMorph = function(self, battler, newSprite, opts)
      self.picMorph = self.picMorph or {}
      self.picMorph[battler] = {
        t = 0,
        newSprite = newSprite,
        oldSprite = opts and opts.oldSprite,
      }
    end
    morphBattle.speciesSprite = function()
      return { form = "sunny" }
    end
    CastformFx.play(morphBattle, morphBattler, "NORMAL")
    T.check(morphBattle.picMorph and morphBattle.picMorph[morphBattler],
      "Forecast triggers a pic morph on Gen1")

    -- Gen2: same TOTAL-frame hold via a queued event; morph ticks only while held.
    do
      local ok, err = xpcall(function()
        Host.force(2)
        package.loaded["mods.Kanto-Reforged.battle.castform_fx"] = nil
        local CastformFx2 = require("mods.Kanto-Reforged.battle.castform_fx")
        CastformFx2._mod = { path = "mods/Kanto-Reforged" }
        local events = {}
        local goldMorph = {
          species = "CASTFORM", types = { "FIRE" }, curTypes = { "FIRE" },
        }
        local g2MorphBattle = {
          player = goldMorph,
          enemy = { species = "RATTATA" },
          emit = function(_, ev) events[#events + 1] = ev end,
        }
        -- isGen2 via Host.force; BattleCompat.isGen2 reads Host.
        CastformFx2.play(g2MorphBattle, goldMorph, "NORMAL")
        T.check(g2MorphBattle._krCastformMorph
          and g2MorphBattle._krCastformMorph.player,
          "Forecast arms a Gen2 pic morph")
        T.eq(g2MorphBattle._krCastformMorph.player.holding, false,
          "Gen2 morph does not tick until the queue hold starts")
        T.eq(g2MorphBattle._krCastformMorph.player.t, 0,
          "Gen2 morph starts at frame 0")
        local hold = nil
        for _, ev in ipairs(events) do
          if ev.kind == "kr-castform-morph" then hold = ev end
        end
        T.check(hold, "Gen2 morph emits a queue hold event")
        T.eq(hold.frames, CastformFx2.TOTAL,
          "Gen2 morph hold matches Gen1 waitNext length")
      end, debug.traceback)
      Host.clearForce()
      package.loaded["mods.Kanto-Reforged.battle.castform_fx"] = nil
      require("mods.Kanto-Reforged.battle.castform_fx").install(
        { path = "mods/Kanto-Reforged" })
      if not ok then error(err) end
    end

    -- Gen2 hail residual uses ANIM_IN_HAIL (AnimRunner id), not Gen1 IN_HAIL.
    do
      local ok, err = xpcall(function()
        Host.force(2)
        local events = {}
        local g2Hail = {
          player = { species = "JYNX", hp = 64, types = { "ICE" } },
          enemy = { species = "PIDGEY", hp = 32, types = { "NORMAL", "FLYING" } },
          emit = function(_, ev) events[#events + 1] = ev end,
        }
        Weather.playTickAnim(g2Hail, "HAIL")
        T.eq(#events, 1, "Gen2 hail residual emits one field anim")
        T.eq(events[1].anim, "ANIM_IN_HAIL", "Gen2 hail residual is ANIM_IN_HAIL")
        T.eq(Weather.FIELD_ANIM_GEN2.HAIL, "ANIM_IN_HAIL",
          "FIELD_ANIM_GEN2 maps hail to the Gold field id")
      end, debug.traceback)
      Host.clearForce()
      if not ok then error(err) end
    end

    local ctx = {
      species = "CASTFORM",
      side = "front",
      kind = "battle",
      trueColor = false,
    }
    local sunnyBattle = { _krWeather = "SUNNY" }
    local resolved = CastformFx.resolveSprite(
      "mods/Kanto-Reforged/assets/castform_front.png", ctx, sunnyBattle,
      { path = "mods/Kanto-Reforged" })
    T.check(resolved:find("castform_sunny_front", 1, true),
      "pokemon.sprite resolves Castform's sunny form")
    T.eq(ctx.trueColor, true,
      "Gen2 pic() skips GBC remap for Castform weather art")

    local clearCtx = {
      species = "CASTFORM", side = "front", kind = "battle", trueColor = false,
    }
    local clearPath = "mods/Kanto-Reforged/assets/castform_front.png"
    T.eq(CastformFx.resolveSprite(clearPath, clearCtx, { field = {} },
      { path = "mods/Kanto-Reforged" }),
      clearPath, "clear weather keeps the default Castform pic")
    T.eq(clearCtx.trueColor, false, "default Castform pic does not force trueColor")

    -- Hoenn battleScaleBack 1.5 must not resize the trainer intro pic when
    -- Castform (or any KR mon) is the lead.
    do
      local ok, err = xpcall(function()
        Host.force(2)
        local Scale = require("mods.Kanto-Reforged.battle.battle_sprite_scale")
        Scale.install({ loader = { generation = 2 } })
        local BS = require("src.ui.gen2.BattleState")
        T.check(BS._krTrainerPicScale,
          "Gen2 trainer intro ignores lead mon battleScale*")
        local view = {
          showPlayerTrainer = true,
          showEnemyTrainer = false,
          pokemon = { CASTFORM = { battleScaleBack = 1.5, battleScaleFront = 1 } },
          imageScale = function() return nil end,
        }
        setmetatable(view, { __index = BS })
        T.eq(view:picScale("assets/chris_back.png", { species = "CASTFORM" }, true),
          1, "Castform lead does not 1.5x the player trainer back")
        view.showPlayerTrainer = false
        T.eq(view:picScale("mods/Kanto-Reforged/assets/castform_back.png",
            { species = "CASTFORM" }, true),
          1.5, "Castform back still uses Hoenn battleScaleBack after send-out")
        view.showEnemyTrainer = true
        T.eq(view:picScale("assets/youngster.png", { species = "RATTATA" }, false),
          1, "enemy trainer front ignores foe mon battleScale*")
      end, debug.traceback)
      Host.clearForce()
      if not ok then error(err) end
    end

    -- Gen2 Weather.tick is wired from battle.turn_ended AFTER takeEvents.
    -- Emitting Forecast there deferred "transformed!" to the next turn.
    do
      local Host = require("mods.Kanto-Reforged.core.host")
      local ok, err = xpcall(function()
        Host.force(2)
        local events = {}
        local goldCf = {
          species = "CASTFORM", types = { "NORMAL" }, curTypes = { "NORMAL" },
        }
        local g2b = {
          weather = "sun", weatherTurns = 3,
          player = goldCf,
          enemy = { species = "RATTATA" },
          data = Data,
          emit = function(_, ev) events[#events + 1] = ev end,
        }
        Data.pokemon.CASTFORM = Data.pokemon.CASTFORM or {}
        Data.pokemon.CASTFORM.ability = "FORECAST"
        Weather.tick(g2b)
        local deferred = false
        for _, ev in ipairs(events) do
          if type(ev.text) == "string" and ev.text:find("transformed", 1, true) then
            deferred = true
          end
        end
        T.check(not deferred,
          "Gen2 Weather.tick (turn_ended) does not defer Forecast text")
        T.eq(goldCf.curTypes[1], "NORMAL",
          "Gen2 turn_ended tick leaves Forecast to live tickWeather/MOVE_EFFECTS")
      end, debug.traceback)
      Host.clearForce()
      if not ok then error(err) end
    end

    -- Gold weather moves dispatch via MOVE_EFFECT_RECORDS; Forecast must
    -- queue after the weather start event (not only at end-of-turn tick).
    do
      local ok, err = xpcall(function()
        Host.force(2)
        local Battle = require("src.battle.gen2.Battle")
        Weather.install({
          path = "mods/Kanto-Reforged",
          content = { move_effects = { get = function() end } },
          log = { info = function() end, warn = function() end },
        })
        local rec = Battle.MOVE_EFFECT_RECORDS.EFFECT_SUNNY_DAY
        T.check(rec and type(rec.run) == "function",
          "Gold Sunny Day has a MOVE_EFFECT_RECORDS runner")
        T.check(Weather._krWeatherForecastWraps
            and Weather._krWeatherForecastWraps[rec.run] == rec.run,
          "Sunny Day runner is wrapped to Forecast after StartSun")

        local events = {}
        Data.pokemon.CASTFORM = Data.pokemon.CASTFORM or {}
        Data.pokemon.CASTFORM.ability = "FORECAST"
        local cf = { species = "CASTFORM", types = { "NORMAL" }, curTypes = { "NORMAL" } }
        local b = {
          weather = nil, weatherTurns = 0,
          player = cf,
          enemy = { species = "RATTATA" },
          data = Data,
          emit = function(self, ev)
            events[#events + 1] = ev
            return ev
          end,
          monName = function(_, mon) return mon.species or "MON" end,
        }
        rec.run(b, cf, b.enemy)
        local weatherAt, transformAt
        for i, ev in ipairs(events) do
          if ev.kind == "weather" and ev.weather == "sun" then weatherAt = i end
          if type(ev.text) == "string" and ev.text:find("transformed", 1, true) then
            transformAt = i
          end
        end
        T.check(weatherAt, "StartSun emits a weather event")
        T.check(transformAt, "Forecast emits transformed after StartSun")
        T.check(transformAt > weatherAt,
          "transformed! is queued after the weather start event")
        T.eq(cf.curTypes[1], "FIRE", "Forecast applies during the weather move")
      end, debug.traceback)
      Host.clearForce()
      if not ok then error(err) end
    end
  end
end
