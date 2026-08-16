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
  T.eq(tickSeq[1].effect, "SE_WATER_DROPLETS_EVERYWHERE",
    "tick uses the rain/sand droplet primitive")
  T.eq(tickSeq[2].effect, "SE_SHAKE_SCREEN", "tick shakes the screen")
  T.check(not tickSeq[1].sound and not tickSeq[1].subanim,
    "tick is not a targeted Sand-Attack")

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
end
