-- Gen3 learnset parity checks (loaded from Kanto-Reforged_test.lua).
return function(T, Data)
  local Pokemon = require("src.pokemon.Pokemon")

  local function learnsetLevel(species, move)
    for _, entry in ipairs(Data.pokemon[species].learnset or {}) do
      if entry.move == move then return entry.level end
    end
    return nil
  end

  local function level1Has(species, move)
    for _, mv in ipairs(Data.pokemon[species].level1Moves or {}) do
      if mv == move then return true end
    end
    return false
  end

  local function tmhmKnown(species)
    for _, mv in ipairs(Data.pokemon[species].tmhm or {}) do
      T.check(Data.moves[mv] ~= nil, species .. " tmhm move registered: " .. mv)
    end
  end

  local function tmhmHas(species, move)
    for _, mv in ipairs(Data.pokemon[species].tmhm or {}) do
      if mv == move then return true end
    end
    return false
  end

  -- Emerald timing (not ROM L19 Dig / L15 Growl)
  T.eq(learnsetLevel("DIGLETT", "GROWL"), 5, "Diglett Growl L5 (Gen3)")
  T.eq(learnsetLevel("DIGLETT", "MAGNITUDE"), 9, "Diglett Magnitude L9")
  T.eq(learnsetLevel("DIGLETT", "DIG"), 17, "Diglett Dig L17 (not ROM L19)")
  T.check(level1Has("DIGLETT", "SCRATCH"), "Diglett L1 Scratch")

  local digMoves = Pokemon.movesAtLevel(Data.pokemon.DIGLETT, 19)
  local digHasScratch, digHasMag = false, false
  for _, id in ipairs(digMoves) do
    if id == "SCRATCH" then digHasScratch = true end
    if id == "MAGNITUDE" then digHasMag = true end
  end
  T.check(digHasScratch and digHasMag, "Diglett L19 movesAtLevel includes Scratch + Magnitude")

  T.eq(learnsetLevel("PIKACHU", "IRON_TAIL"), 30, "Pikachu Iron Tail L30 backport")
  T.eq(learnsetLevel("CHIKORITA", "RAZOR_LEAF"), 8, "Chikorita Razor Leaf L8 (Emerald)")
  T.eq(learnsetLevel("CHARMANDER", "SMOKESCREEN"), 13, "Charmander Smokescreen L13 (Emerald)")

  -- No FRLG-only Metal Claw on Charmander in Emerald-first table
  T.check(learnsetLevel("CHARMANDER", "METAL_CLAW") == nil,
    "Charmander has no Metal Claw level-up (Emerald, not FRLG)")

  tmhmKnown("DIGLETT")
  tmhmKnown("PIKACHU")

  -- Host TM items teach that generation's moves. Overlaying Emerald's machine
  -- list must not drop them (Crystal TM31 Mud-Slap / Red TM01 Mega Punch).
  if Data.moves.MEGA_PUNCH then
    T.check(tmhmHas("PIKACHU", "MEGA_PUNCH"),
      "Pikachu keeps Red TM01 Mega Punch after Gen3 tmhm overlay")
  end
  T.check(tmhmHas("PIKACHU", "THUNDERBOLT") or tmhmHas("PIKACHU", "THUNDER"),
    "Pikachu still has Gen3 electric TM compatibility")

  -- ApplyGen3 folds evolutionMoves into Gen1 level1Moves when present
  local ApplyGen3 = require("mods.Kanto-Reforged.pokemon.apply_gen3_learnsets")
  local folded = ApplyGen3.gen1Level1({
    level1Moves = { "TACKLE" },
    evolutionMoves = { "BITE" },
    learnset = {},
  })
  local hasBite = false
  for _, mv in ipairs(folded) do
    if mv == "BITE" then hasBite = true end
  end
  T.check(hasBite, "gen1Level1 folds evolutionMoves into level1Moves")

  local g2 = ApplyGen3.toLevelMoves({
    level1Moves = { "TACKLE" },
    evolutionMoves = { "BITE" },
    learnset = { { level = 10, move = "SLASH" } },
  })
  T.eq(g2[1].move, "BITE", "toLevelMoves puts evolution move first at L1")

  -- Gen2 HM06 Whirlpool restore (Gen3 stripped machine compatibility)
  local restored = ApplyGen3.ensureGen2Whirlpool(
    { "SURF", "WATERFALL" },
    { dex = 7, types = { "WATER" }, tmhm = { "SURF", "WHIRLPOOL" } }
  )
  local hasWhirl = false
  for _, mv in ipairs(restored) do
    if mv == "WHIRLPOOL" then hasWhirl = true end
  end
  T.check(hasWhirl, "Gen2 stock Whirlpool learner keeps HM06 after Gen3 tmhm")

  local slow = ApplyGen3.ensureGen2Whirlpool(
    { "SURF", "WATERFALL" },
    { dex = 79, types = { "WATER", "PSYCHIC_TYPE" }, tmhm = { "SURF" } }
  )
  local slowWhirl = false
  for _, mv in ipairs(slow) do
    if mv == "WHIRLPOOL" then slowWhirl = true end
  end
  T.check(not slowWhirl, "Gen2 Surf-only Water types stay without Whirlpool")

  local mudkip = ApplyGen3.ensureGen2Whirlpool(
    { "SURF", "WATERFALL", "DIVE" },
    { dex = 258, types = { "WATER" }, tmhm = { "SURF" } }
  )
  local mudWhirl = false
  for _, mv in ipairs(mudkip) do
    if mv == "WHIRLPOOL" then mudWhirl = true end
  end
  T.check(mudWhirl, "Hoenn Water+Surf gets Gen2 Whirlpool HM compatibility")

  local furret = ApplyGen3.ensureGen2Whirlpool(
    { "SURF", "CUT" },
    { dex = 162, types = { "NORMAL" }, tmhm = { "SURF" } }
  )
  local furWhirl = false
  for _, mv in ipairs(furret) do
    if mv == "WHIRLPOOL" then furWhirl = true end
  end
  T.check(not furWhirl, "non-Water Gen2 Surf users do not gain Whirlpool")

  local unioned = ApplyGen3.unionHostTmhm(
    { "FACADE", "PROTECT", "TOXIC" },
    { tmhm = { "HEADBUTT", "MUD_SLAP", "PROTECT", "TOXIC" } }
  )
  local hasHead, hasMud, hasFacade, hasProtect = false, false, false, false
  for _, mv in ipairs(unioned) do
    if mv == "HEADBUTT" then hasHead = true end
    if mv == "MUD_SLAP" then hasMud = true end
    if mv == "FACADE" then hasFacade = true end
    if mv == "PROTECT" then hasProtect = true end
  end
  T.check(hasHead and hasMud, "union keeps Crystal TM02 Headbutt and TM31 Mud-Slap")
  T.check(hasFacade and hasProtect, "union keeps Gen3 TMs alongside host TMs")

  local function tmSet(list)
    local got = {}
    for _, mv in ipairs(list or {}) do got[mv] = true end
    return got
  end

  local function runApply(isGen2, existingById, gen3Species)
    local patched = {}
    local known = { GROWL = true, TACKLE = true }
    local function mark(list)
      for _, mv in ipairs(list or {}) do known[mv] = true end
    end
    for _, row in pairs(existingById) do mark(row.tmhm) end
    for _, row in pairs(gen3Species) do
      mark(row.level1Moves)
      mark(row.tmhm)
      for _, entry in ipairs(row.learnset or {}) do mark({ entry.move }) end
    end
    local fakeMod = {
      content = {
        moves = {
          get = function(_, id) return known[id] and { id = id } or nil end,
        },
        pokemon = {
          get = function(_, id) return existingById[id] end,
          patch = function(_, id, partial) patched[id] = partial end,
        },
      },
    }
    local n = ApplyGen3.apply(fakeMod, { isGen2 = function() return isGen2 end }, {
      species = gen3Species,
    })
    return n, patched
  end

  -- Gold/Silver/Crystal: same Host.isGen2() path. Keep Gen2-only machines
  -- (Headbutt, Mud-Slap, DynamicPunch, Whirlpool, …) plus Emerald TMs.
  do
    local gen3Tm = { "FACADE", "SURF", "TOXIC", "WATERFALL", "WATER_PULSE" }
    local n, patched = runApply(true, {
      SQUIRTLE = {
        dex = 7, types = { "WATER" },
        tmhm = {
          "CURSE", "DYNAMICPUNCH", "HEADBUTT", "ICY_WIND", "MUD_SLAP",
          "ROLLOUT", "SURF", "TOXIC", "WATERFALL", "WHIRLPOOL",
        },
      },
      MUDKIP = {
        dex = 258, types = { "WATER" },
        tmhm = { "SURF", "WATERFALL" },
      },
      FURRET = {
        dex = 162, types = { "NORMAL" },
        tmhm = { "CUT", "HEADBUTT", "SURF" },
      },
    }, {
      SQUIRTLE = {
        level1Moves = { "TACKLE" }, learnset = {}, evolutionMoves = {},
        tmhm = gen3Tm,
      },
      MUDKIP = {
        level1Moves = { "TACKLE" }, learnset = {}, evolutionMoves = {},
        tmhm = gen3Tm,
      },
      FURRET = {
        level1Moves = { "TACKLE" }, learnset = {}, evolutionMoves = {},
        tmhm = { "CUT", "FACADE", "SURF" },
      },
    })
    T.eq(n, 3, "apply patches Squirtle/Mudkip/Furret on Gen2 host")
    local squirtle = tmSet(patched.SQUIRTLE and patched.SQUIRTLE.tmhm)
    T.check(squirtle.WHIRLPOOL,
      "Gen2 apply keeps HM06 Whirlpool on stock learners (Squirtle)")
    T.check(squirtle.HEADBUTT and squirtle.MUD_SLAP and squirtle.DYNAMICPUNCH
        and squirtle.CURSE and squirtle.ROLLOUT and squirtle.ICY_WIND,
      "Gen2 apply keeps Gen2-only TMs (Headbutt/Mud-Slap/DynamicPunch/…)")
    T.check(squirtle.FACADE and squirtle.SURF,
      "Gen2 apply still adds Gen3 TM compatibility on Squirtle")
    local mudkip = tmSet(patched.MUDKIP and patched.MUDKIP.tmhm)
    T.check(mudkip.WHIRLPOOL,
      "Gen2 apply grants HM06 Whirlpool to Hoenn Water+Surf (Mudkip)")
    local furret = tmSet(patched.FURRET and patched.FURRET.tmhm)
    T.check(furret.HEADBUTT, "Gen2 apply keeps Furret's stock Headbutt")
    T.check(not furret.WHIRLPOOL,
      "Gen2 apply does not grant Whirlpool to non-Water Surf users")
  end

  -- Red/Blue: same overlay bug (TM01 Mega Punch, Body Slam, Substitute).
  -- Whirlpool grant must not run on Gen1.
  do
    local n, patched = runApply(false, {
      PIKACHU = {
        dex = 25,
        tmhm = { "BODY_SLAM", "MEGA_PUNCH", "SUBSTITUTE", "THUNDERBOLT", "TOXIC" },
      },
    }, {
      PIKACHU = {
        level1Moves = { "GROWL" }, learnset = {}, evolutionMoves = {},
        tmhm = { "FACADE", "THUNDERBOLT", "TOXIC" },
      },
    })
    T.eq(n, 1, "apply patches Pikachu on Gen1 host")
    local pika = tmSet(patched.PIKACHU and patched.PIKACHU.tmhm)
    T.check(pika.MEGA_PUNCH and pika.BODY_SLAM and pika.SUBSTITUTE,
      "Gen1 apply keeps Red TM01 Mega Punch / Body Slam / Substitute")
    T.check(pika.FACADE and pika.THUNDERBOLT,
      "Gen1 apply still adds Gen3 TM compatibility")
    T.check(not pika.WHIRLPOOL, "Gen1 apply does not inject Whirlpool")
  end
end
