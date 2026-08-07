-- Gender rates, DV assignment, save backfill, Attract / Cute Charm infatuation.
return function(T, Data, run)
  local Gender = require("mods.Kanto-Reforged.gender")
  local Abilities = require("mods.Kanto-Reforged.abilities")
  local Status = require("src.battle.Status")
  local Pokemon = require("src.pokemon.Pokemon")

  T.check(Data.pokemon.BULBASAUR.genderRate == 1, "Bulbasaur genderRate 12.5% female")
  T.check(Data.pokemon.NIDORAN_M.genderRate == 0, "Nidoran M always male")
  T.check(Data.pokemon.NIDORAN_F.genderRate == 8, "Nidoran F always female")
  T.check(Data.pokemon.MAGNEMITE.genderRate == -1, "Magnemite genderless")
  T.check(Data.pokemon.JIGGLYPUFF.genderRate == 6, "Jigglypuff 75% female")
  T.check(Data.pokemon.MEW.genderRate == -1, "Mew genderless")
  T.check(Data.link_fields and Data.link_fields.gender ~= nil,
    "gender link_fields registered")

  -- Gen 2 DV thresholds (rate 1 → female if Atk DV < 2)
  T.eq(Gender.fromDVs(Data, "BULBASAUR", { attack = 0 }), "F", "rate1 Atk0 female")
  T.eq(Gender.fromDVs(Data, "BULBASAUR", { attack = 1 }), "F", "rate1 Atk1 female")
  T.eq(Gender.fromDVs(Data, "BULBASAUR", { attack = 2 }), "M", "rate1 Atk2 male")
  -- rate 4 (50%): female if Atk < 8
  T.eq(Gender.fromDVs(Data, "RATTATA", { attack = 7 }), "F", "rate4 Atk7 female")
  T.eq(Gender.fromDVs(Data, "RATTATA", { attack = 8 }), "M", "rate4 Atk8 male")
  T.eq(Gender.fromDVs(Data, "NIDORAN_M", { attack = 0 }), "M", "always male")
  T.eq(Gender.fromDVs(Data, "NIDORAN_F", { attack = 15 }), "F", "always female")
  T.eq(Gender.fromDVs(Data, "MAGNEMITE", { attack = 8 }), nil, "genderless")

  -- Pokemon.new assigns gender
  local newborn = Pokemon.new(Data, "PIKACHU", 5, function(a, b)
    if a == 0 and b == 15 then return 10 end
    return a or 0
  end)
  T.check(newborn.gender == "M" or newborn.gender == "F",
    "Pokemon.new sets gender")
  local fixed = Pokemon.new(Data, "NIDORAN_M", 5)
  T.eq(fixed.gender, "M", "Nidoran M newborn is male")
  local magnet = Pokemon.new(Data, "MAGNEMITE", 5)
  T.eq(magnet.gender, nil, "Magnemite newborn has no gender")

  -- Backfill existing save (party / box / daycare)
  local partyMon = {
    species = "JIGGLYPUFF",
    dvs = { attack = 0, defense = 0, speed = 0, special = 0 },
  }
  local boxMon = {
    species = "RATTATA",
    dvs = { attack = 15, defense = 0, speed = 0, special = 0 },
  }
  local dayMon = {
    species = "BULBASAUR",
    dvs = { attack = 0, defense = 0, speed = 0, special = 0 },
  }
  local day2 = {
    species = "CHARMANDER",
    dvs = { attack = 15, defense = 0, speed = 0, special = 0 },
  }
  local egg = {
    isEgg = true,
    species = "SQUIRTLE",
    dvs = { attack = 0, defense = 0, speed = 0, special = 0 },
  }
  local save = {
    party = { partyMon, egg },
    boxes = { { boxMon } },
    daycare = { mon = dayMon, mon2 = day2 },
  }
  local n = Gender.backfillSave(Data, save)
  T.check(n >= 4, "backfill assigns party/box/daycare mon+mon2")
  T.eq(partyMon.gender, "F", "Jigglypuff Atk0 is female (rate 6)")
  T.eq(boxMon.gender, "M", "Rattata Atk15 is male")
  T.eq(dayMon.gender, "F", "Bulbasaur Atk0 is female")
  T.eq(day2.gender, "M", "daycare mon2 gets gender")
  T.eq(egg.gender, nil, "eggs are not gendered on backfill")
  local g1 = partyMon.gender
  Gender.backfillSave(Data, save)
  T.eq(partyMon.gender, g1, "second backfill is idempotent")

  -- save.loaded (CONTINUE) must backfill the replaced save, not only game.ready
  do
    local continued = {
      party = {
        { species = "PIKACHU",
          dvs = { attack = 0, defense = 0, speed = 0, special = 0 } },
      },
      boxes = {},
    }
    Gender._mod.activeGame = { data = Data, save = continued }
    run.loader.events:emit("save.loaded", { save = continued })
    T.eq(continued.party[1].gender, "F",
      "save.loaded backfills gender on continued party")
  end

  -- Attract: opposite gender → infatuation
  do
    local user = {
      name = "User", isPlayer = true,
      mon = { gender = "M", species = "RATTATA" },
    }
    local foe = {
      name = "Foe", isPlayer = false,
      mon = { gender = "F", species = "JIGGLYPUFF" },
      expInfatuated = nil, confusedTurns = nil,
    }
    local msgs = Data.move_effects.EXP_ATTRACT_EFFECT.run({
      user = user, target = foe, battle = {}, move = Data.moves.ATTRACT,
    })
    T.eq(foe.expInfatuated, true, "Attract sets expInfatuated")
    T.eq(foe.confusedTurns, nil, "Attract does not confuse")
    T.check(msgs and msgs[1] and msgs[1]:find("love", 1, true),
      "Attract announces love")

    local again = Data.move_effects.EXP_ATTRACT_EFFECT.run({
      user = user, target = foe, battle = {}, move = Data.moves.ATTRACT,
    })
    T.check(again and again[1] == "But, it failed!",
      "Attract fails if already infatuated")

    local same = {
      name = "Same", mon = { gender = "M", species = "PIDGEY" },
      expInfatuated = nil,
    }
    local failSame = Data.move_effects.EXP_ATTRACT_EFFECT.run({
      user = user, target = same, battle = {}, move = Data.moves.ATTRACT,
    })
    T.check(failSame and failSame[1] == "But, it failed!",
      "Attract fails same gender")

    local magnetFoe = {
      name = "Magnet", mon = { gender = nil, species = "MAGNEMITE" },
      expInfatuated = nil,
    }
    local failGl = Data.move_effects.EXP_ATTRACT_EFFECT.run({
      user = user, target = magnetFoe, battle = {}, move = Data.moves.ATTRACT,
    })
    T.check(failGl and failGl[1] == "But, it failed!",
      "Attract fails vs genderless")
  end

  -- Cute Charm: 1/3 infatuate opposite on contact (Gen 3 rate)
  do
    Data.pokemon.CLEFAIRY = Data.pokemon.CLEFAIRY or {}
    Data.pokemon.CLEFAIRY.ability = "CUTE_CHARM"
    local cuteTarget = {
      mon = { species = "CLEFAIRY", hp = 40, stats = { hp = 40 }, gender = "F" },
      name = "Clefairy", isPlayer = false,
    }
    local cuteUser = {
      mon = { species = "RATTATA", hp = 40, stats = { hp = 40 }, gender = "M" },
      name = "Rattata", isPlayer = true, expInfatuated = nil, confusedTurns = nil,
    }
    local cuteBattle = {
      data = Data,
      rng = function(a, b)
        if a == 1 and b == 3 then return 1 end
        return a or 0
      end,
      sayNext = function() end,
      applyDamage = function() end,
      onFaint = function() end,
    }
    Abilities.onPostDamage(cuteBattle, cuteUser, cuteTarget,
      { type = "NORMAL", category = "physical", power = 40 }, 10)
    T.eq(cuteUser.expInfatuated, true, "Cute Charm infatuates opposite gender")
    T.eq(cuteUser.confusedTurns, nil, "Cute Charm does not confuse")

    local sameUser = {
      mon = { species = "JIGGLYPUFF", hp = 40, stats = { hp = 40 }, gender = "F" },
      name = "Jiggly", isPlayer = true, expInfatuated = nil,
    }
    Abilities.onPostDamage(cuteBattle, sameUser, cuteTarget,
      { type = "NORMAL", category = "physical", power = 40 }, 10)
    T.eq(sameUser.expInfatuated, nil, "Cute Charm skips same gender")
  end

  -- Captivate: opposite gender only
  do
    T.eq(Data.moves.CAPTIVATE.effect, "EXP_CAPTIVATE_EFFECT", "Captivate effect")
    local user = { mon = { gender = "M" }, name = "User" }
    local foe = {
      mon = { gender = "F" }, name = "Foe",
      stages = { special = 0 },
    }
    local msgs = Data.move_effects.EXP_CAPTIVATE_EFFECT.run({
      user = user, target = foe, battle = { data = Data },
      move = Data.moves.CAPTIVATE,
      changeStage = function(who, stat, delta)
        who.stages[stat] = (who.stages[stat] or 0) + delta
        return { "SpA fell" }
      end,
    })
    T.eq(foe.stages.special, -2, "Captivate drops Special vs opposite gender")
    T.check(#msgs > 0, "Captivate reports the drop")

    local same = {
      mon = { gender = "M" }, name = "Same", stages = { special = 0 },
    }
    local fail = Data.move_effects.EXP_CAPTIVATE_EFFECT.run({
      user = user, target = same, battle = {}, move = Data.moves.CAPTIVATE,
      changeStage = function() return {} end,
    })
    T.check(fail and fail[1] == "But, it failed!",
      "Captivate fails same gender")
  end

  -- Trainer DV overwrite must re-sync gender
  do
    local Gender = require("mods.Kanto-Reforged.gender")
    local mon = {
      species = "RATTATA",
      dvs = { attack = 15, defense = 8, speed = 8, special = 8 },
      gender = "F", -- stale gender from pre-overwrite DVs
    }
    Gender.resync(Data, mon)
    T.eq(mon.gender, "M", "resync derives male from Atk DV 15")
  end

  -- Cute Charm wild: forces opposite when roll says so
  do
    local Gender = require("mods.Kanto-Reforged.gender")
    local wild = {
      species = "RATTATA",
      dvs = { attack = 15 },
      gender = "M",
    }
    local game = {
      data = Data,
      save = { party = { { species = "JIGGLYPUFF", gender = "F",
        dvs = { attack = 0 } } } },
    }
    Data.pokemon.JIGGLYPUFF = Data.pokemon.JIGGLYPUFF or {}
    Data.pokemon.JIGGLYPUFF.ability = "CUTE_CHARM"
    Gender.applyCuteCharmWild(game, wild, function() return 2 end)
    T.eq(wild.gender, "M", "Cute Charm lead female forces male wild")
  end

  -- beforeMove: 50% immobilized when infatuated
  do
    local bat = {
      name = "Lover", mon = { gender = "M" },
      expInfatuated = true,
    }
    local blocked = Status.beforeMove(bat, function() return 0 end, {})
    T.eq(blocked, false, "infatuation can immobilize")
    local free = Status.beforeMove(bat, function() return 1 end, {})
    T.eq(free, true, "infatuation can still allow a move")
  end
end
