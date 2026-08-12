-- Species scope toggle: schema, stash/restore, daycare, bag count, fossils.
return function(T, Data, run)
  local SpeciesScope = require("mods.Kanto-Reforged.species_scope")
  local Host = require("mods.Kanto-Reforged.host")
  local Pokemon = require("src.pokemon.Pokemon")
  local Boxes = require("src.pokemon.Boxes")
  local Merge = require("src.mods.Merge")
  local Bag = require("src.inventory.Bag")

  local mod = SpeciesScope._mod or (run.api)
  T.check(mod ~= nil, "mod handle present for species_scope tests")
  T.check(mod.save ~= nil, "mod.save API present")

  -- Schema
  local schema = run.loader.optionSchemas["Kanto-Reforged"]
  local scopeOpt
  for _, opt in ipairs(schema or {}) do
    if opt.key == SpeciesScope.OPTION_KEY then scopeOpt = opt break end
  end
  T.check(scopeOpt ~= nil, "species_scope option registered")
  T.eq(scopeOpt.type, "choice", "species_scope is a choice")
  T.eq(scopeOpt.default, SpeciesScope.MODE_NATIONAL, "species_scope defaults national")
  T.eq(scopeOpt.label, "DEX SCOPE", "Gen1 DEX SCOPE label")

  -- Helpers to stub a minimal game/save around the loaded Data
  local function freshSave()
    return {
      party = {},
      boxes = nil,
      inventory = {},
      bagOrder = {},
      flags = {},
      daycare = nil,
      money = 5000,
      pokedex = { owned = {}, seen = {} },
      options = { modOptions = { ["Kanto-Reforged"] = {} } },
    }
  end

  local function makeGame(save)
    return {
      data = Data,
      save = save,
      stack = { items = {} },
      battle = nil,
    }
  end

  -- Ensure option store exists
  run.loader.modOptions = run.loader.modOptions or {}
  run.loader.modOptions["Kanto-Reforged"] =
    run.loader.modOptions["Kanto-Reforged"] or {}
  local opts = run.loader.modOptions["Kanto-Reforged"]
  local savedMode = opts[SpeciesScope.OPTION_KEY]
  local savedApplied = mod.save:get(SpeciesScope.APPLIED_KEY, nil)
  local savedStash = mod.save:get(SpeciesScope.STASH_KEY, nil)

  SpeciesScope._mod = mod
  SpeciesScope._ignoreOptionEvent = true

  local function setMode(mode)
    opts[SpeciesScope.OPTION_KEY] = mode
  end

  -- maxDex / allows
  setMode(SpeciesScope.MODE_KANTO)
  T.eq(SpeciesScope.mode(mod), SpeciesScope.MODE_KANTO, "mode reads kanto")
  T.eq(SpeciesScope.maxDexForMap(mod, "ROUTE_1"), 151, "Gen1 kanto maxDex 151")
  T.check(SpeciesScope.allowsSpeciesId(mod, "PIKACHU", nil), "Pikachu allowed in kanto")
  T.check(not SpeciesScope.allowsSpeciesId(mod, "TREECKO", nil), "Treecko blocked in kanto")

  setMode(SpeciesScope.MODE_NATIONAL)
  T.check(SpeciesScope.allowsSpeciesId(mod, "TREECKO", nil), "Treecko allowed in national")

  -- Stash round-trip
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)

    local save = freshSave()
    local pika = Pokemon.new(Data, "PIKACHU", 10)
    local tree = Pokemon.new(Data, "TREECKO", 10)
    save.party = { pika, tree }
    Boxes.ensure(save)
    local game = makeGame(save)
    SpeciesScope._game = game

    setMode(SpeciesScope.MODE_KANTO)
    local ok, err, msg = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO)
    T.eq(ok, true, "stash transition ok: " .. tostring(msg or err))
    T.eq(#save.party, 1, "only Pikachu remains in party")
    T.eq(save.party[1].species, "PIKACHU", "remaining mon is Pikachu")
    local stash = mod.save:get(SpeciesScope.STASH_KEY, nil)
    T.check(stash and stash.entries and #stash.entries >= 1, "Treecko in stash")
    local found = false
    for _, e in ipairs(stash.entries) do
      if e.mon and e.mon.species == "TREECKO" then found = true end
    end
    T.check(found, "stash contains TREECKO")

    setMode(SpeciesScope.MODE_NATIONAL)
    ok, err, msg = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_NATIONAL)
    T.eq(ok, true, "restore transition ok")
    local hasTree = false
    for _, mon in ipairs(save.party) do
      if mon.species == "TREECKO" then hasTree = true end
    end
    if not hasTree then
      for bi = 1, Boxes.COUNT do
        for _, mon in ipairs(save.boxes[bi] or {}) do
          if mon.species == "TREECKO" then hasTree = true end
        end
      end
    end
    T.check(hasTree, "Treecko restored from stash")
  end

  -- Pokédex seen/owned for Gen2+ must survive KANTO → NATIONAL.
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    local save = freshSave()
    save.party = { Pokemon.new(Data, "PIKACHU", 10) }
    save.pokedex.owned.PIKACHU = true
    save.pokedex.seen.PIKACHU = true
    save.pokedex.owned.TREECKO = true
    save.pokedex.seen.TREECKO = true
    save.pokedex.owned.CHIKORITA = true
    save.pokedex.seen.CHIKORITA = true
    Boxes.ensure(save)
    local game = makeGame(save)
    SpeciesScope._game = game

    setMode(SpeciesScope.MODE_KANTO)
    T.eq(SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO), true,
      "dex-flag stash enter kanto")
    -- Simulate validate wiping post-151 flags while Kanto-locked.
    save.pokedex.owned.TREECKO = nil
    save.pokedex.seen.TREECKO = nil
    save.pokedex.owned.CHIKORITA = nil
    save.pokedex.seen.CHIKORITA = nil
    T.eq(save.pokedex.owned.PIKACHU, true, "Kanto owned flag kept during wipe sim")

    setMode(SpeciesScope.MODE_NATIONAL)
    T.eq(SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_NATIONAL), true,
      "dex-flag restore national")
    T.eq(save.pokedex.owned.TREECKO, true, "TREECKO owned restored after NATIONAL")
    T.eq(save.pokedex.seen.TREECKO, true, "TREECKO seen restored after NATIONAL")
    T.eq(save.pokedex.owned.CHIKORITA, true, "CHIKORITA owned restored after NATIONAL")
    T.eq(save.pokedex.owned.PIKACHU, true, "PIKACHU owned still set")
    T.eq(Data.constants.dexSize >= 252, true, "dexSize restored past Johto")
  end

  -- Refuse empty party (only Gen3, empty PC)
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    local save = freshSave()
    save.party = { Pokemon.new(Data, "TREECKO", 5) }
    Boxes.ensure(save)
    local game = makeGame(save)
    SpeciesScope._game = game
    setMode(SpeciesScope.MODE_KANTO)
    local ok, err, msg = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO)
    T.eq(ok, false, "empty in-scope party aborts")
    T.eq(err, "empty_party", "empty_party err code")
    T.check(tostring(msg or ""):find("KANTO", 1, true) ~= nil, "empty party message mentions KANTO")
    T.eq(#save.party, 1, "party unchanged on abort")
    T.eq(save.party[1].species, "TREECKO", "Treecko still in party after abort")
  end

  -- Held items: strip + counted bag abort
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    local save = freshSave()
    local tree = Pokemon.new(Data, "TREECKO", 10)
    tree.heldItem = "LEFTOVERS"
    save.party = { Pokemon.new(Data, "PIKACHU", 10), tree }
    Boxes.ensure(save)
    local game = makeGame(save)
    SpeciesScope._game = game
    setMode(SpeciesScope.MODE_KANTO)
    local ok = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO)
    T.eq(ok, true, "held item strip succeeds")
    T.eq(save.inventory.LEFTOVERS, 1, "Leftovers returned to bag")

    -- Bag full abort with count
    setMode(SpeciesScope.MODE_NATIONAL)
    SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    save = freshSave()
    tree = Pokemon.new(Data, "TREECKO", 10)
    tree.heldItem = "FOCUS_BAND"
    save.party = { Pokemon.new(Data, "PIKACHU", 10), tree }
    local cap = Bag.capacity(Data)
    for i = 1, cap do
      local fake = "KR_SCOPE_FILL_" .. i
      Data.items = Data.items or {}
      if not Data.items[fake] then
        Data.items[fake] = { id = fake, name = fake, price = 0 }
      end
      save.inventory[fake] = 1
      save.bagOrder[#save.bagOrder + 1] = fake
    end
    Boxes.ensure(save)
    game = makeGame(save)
    SpeciesScope._game = game
    setMode(SpeciesScope.MODE_KANTO)
    local ok2, err2, msg2 = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO)
    T.eq(ok2, false, "bag full aborts transition")
    T.eq(err2, "bag_full", "bag_full err code")
    T.check(tostring(msg2 or ""):find("%d") ~= nil, "bag full message includes count")
  end

  -- Daycare evacuate at deposit level, no fee
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    local save = freshSave()
    save.money = 9999
    local mon = Pokemon.new(Data, "TREECKO", 15)
    mon.level = 20 -- grown above deposit
    save.daycare = {
      mon = mon,
      depositLevel = 15,
      steps = 500,
    }
    save.party = { Pokemon.new(Data, "PIKACHU", 10) }
    Boxes.ensure(save)
    local game = makeGame(save)
    SpeciesScope._game = game
    setMode(SpeciesScope.MODE_KANTO)
    local ok = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO)
    T.eq(ok, true, "daycare evacuate ok")
    T.eq(save.money, 9999, "daycare evacuate does not charge")
    T.check(not save.daycare or not save.daycare.mon, "daycare cleared")
    local stash = mod.save:get(SpeciesScope.STASH_KEY, nil)
    local stashed
    for _, e in ipairs((stash and stash.entries) or {}) do
      if e.from == "daycare" then stashed = e.mon end
    end
    T.check(stashed ~= nil, "daycare mon stashed")
    T.eq(stashed.level, 15, "stashed daycare mon at deposit level")
  end

  -- Fossil async revert
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    local save = freshSave()
    save.flags.MOD_LAB_GEN3_HANDING = true
    mod.save:set("lab_gen3_species", "ANORITH")
    save.party = { Pokemon.new(Data, "PIKACHU", 10) }
    Boxes.ensure(save)
    local game = makeGame(save)
    SpeciesScope._game = game
    setMode(SpeciesScope.MODE_KANTO)
    local ok = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO)
    T.eq(ok, true, "fossil revert transition ok")
    T.eq(save.flags.MOD_LAB_GEN3_HANDING, nil, "HANDING cleared")
    T.eq(mod.save:get("lab_gen3_species", nil), nil, "lab species cleared")
    T.eq(save.inventory.CLAW_FOSSIL, 1, "CLAW_FOSSIL returned")
  end

  -- Dex % clamp helper
  do
    setMode(SpeciesScope.MODE_KANTO)
    local save = freshSave()
    for i = 1, 200 do
      save.pokedex.owned["FAKE_" .. i] = true
    end
    -- Mark real Gen1 + Gen3
    save.pokedex.owned.PIKACHU = true
    save.pokedex.owned.TREECKO = true
    Data.pokemon.FAKE_1 = Data.pokemon.FAKE_1 or { id = "FAKE_1", dex = 200 }
    -- countOwnedInScope only counts known dex ≤ 151
    local game = makeGame(save)
    SpeciesScope._game = game
    local n, maxDex = SpeciesScope.countOwnedInScope(game, mod)
    T.eq(maxDex, 151, "kanto maxDex for owned count")
    T.check(n <= maxDex, "owned in scope never exceeds dexSize")
  end

  -- Egg cycle preserve
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    local save = freshSave()
    local egg = {
      species = "TREECKO",
      isEgg = true,
      eggCycles = 12,
      hatchCounter = 12,
      level = 1,
    }
    save.party = { Pokemon.new(Data, "PIKACHU", 10), egg }
    Boxes.ensure(save)
    local game = makeGame(save)
    SpeciesScope._game = game
    setMode(SpeciesScope.MODE_KANTO)
    T.eq(SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO), true, "egg stash ok")
    setMode(SpeciesScope.MODE_NATIONAL)
    T.eq(SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_NATIONAL), true, "egg restore ok")
    local restored
    for _, mon in ipairs(save.party) do
      if mon.isEgg or mon.species == "TREECKO" then restored = mon end
    end
    if not restored then
      for bi = 1, Boxes.COUNT do
        for _, mon in ipairs(save.boxes[bi] or {}) do
          if mon.isEgg or (mon.species == "TREECKO" and mon.eggCycles) then
            restored = mon
          end
        end
      end
    end
    T.check(restored ~= nil, "egg restored")
    T.eq(restored.eggCycles, 12, "egg cycles preserved")
  end

  -- Battle clubs Gen1 kanto parties
  do
    setMode(SpeciesScope.MODE_KANTO)
    SpeciesScope._mod = mod
    local BattleClubs = require("mods.Kanto-Reforged.battle_clubs")
    BattleClubs.refreshScope(mod, SpeciesScope.MODE_KANTO)
    local club = (mod.content.trainers:get("OPP_EXP_BATTLE_CLUB"))
      or (Data.trainers and Data.trainers.OPP_EXP_BATTLE_CLUB)
    T.check(club and club.parties, "club parties present")
    local allOk = true
    for _, party in ipairs(club.parties or {}) do
      for _, slot in ipairs(party) do
        if not SpeciesScope.allowsSpeciesId(mod, slot.species, nil) then
          allOk = false
        end
      end
    end
    T.check(allOk, "club parties dex≤151 under kanto")
  end

  -- Evo strip: Onix has no STEELIX under kanto
  do
    setMode(SpeciesScope.MODE_KANTO)
    SpeciesScope.applyEvoScope(mod, SpeciesScope.MODE_KANTO)
    local onix = mod.content.pokemon:get("ONIX")
    local hasSteelix = false
    for _, evo in ipairs((onix and onix.evolutions) or {}) do
      local target = evo.species or evo.into
      if target == "STEELIX" then hasSteelix = true end
    end
    T.check(not hasSteelix, "Onix has no STEELIX edge under kanto")
    setMode(SpeciesScope.MODE_NATIONAL)
    SpeciesScope.applyEvoScope(mod, SpeciesScope.MODE_NATIONAL)
  end

  -- Battle / menu hard-lock
  do
    local save = freshSave()
    save.party = { Pokemon.new(Data, "PIKACHU", 10) }
    local game = makeGame(save)
    SpeciesScope._game = game
    local okBattle = select(1, SpeciesScope.canChangeScope(game))
    T.eq(okBattle, true, "idle overworld can change scope")
    game.battle = { kind = "wild" }
    local okBusy, reason = SpeciesScope.canChangeScope(game)
    T.eq(okBusy, false, "battle blocks scope change")
    T.check(tostring(reason or ""):find("battle", 1, true) ~= nil,
      "battle lock mentions battle")
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    setMode(SpeciesScope.MODE_KANTO)
    local okT, errT = SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO)
    T.eq(okT, false, "applyTransition refuses during battle")
    T.eq(errT, "busy", "busy err during battle")
    game.battle = nil
    game.stack.items = { { __name = "PartyMenu" } }
    local okMenu, menuReason = SpeciesScope.canChangeScope(game)
    T.eq(okMenu, false, "party menu blocks scope change")
    T.check(tostring(menuReason or ""):find("menu", 1, true) ~= nil,
      "menu lock mentions menu")
    game.stack.items = { { screenId = "ManagerState", isManager = true } }
    T.eq(select(1, SpeciesScope.canChangeScope(game)), true,
      "ManagerState allows scope change")
  end

  -- Owned count for gates ignores out-of-scope flags
  do
    setMode(SpeciesScope.MODE_KANTO)
    local save = freshSave()
    save.pokedex.owned.PIKACHU = true
    save.pokedex.owned.TREECKO = true
    local game = makeGame(save)
    local n = SpeciesScope.ownedCountForGates(game, mod)
    T.eq(n, 1, "ownedCountForGates counts only Pikachu under kanto")
  end

  -- PC scatter warning on restore
  do
    setMode(SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    mod.save:set(SpeciesScope.STASH_KEY, nil)
    local save = freshSave()
    save.party = { Pokemon.new(Data, "PIKACHU", 10) }
    local boxes = Boxes.ensure(save)
    -- Park Treecko in box 1 slot 1, then stash it, then occupy that slot
    -- so restore cannot reclaim the original BOX slot.
    boxes[1][1] = Pokemon.new(Data, "TREECKO", 10)
    local game = makeGame(save)
    SpeciesScope._game = game
    setMode(SpeciesScope.MODE_KANTO)
    T.eq(SpeciesScope.applyTransition(mod, game, SpeciesScope.MODE_KANTO), true,
      "stash box Treecko before scatter restore")
    -- Fill party and every box except leave nowhere matching original slot
    while #save.party < (require("src.pokemon.Party").MAX or 6) do
      save.party[#save.party + 1] = Pokemon.new(Data, "RATTATA", 5)
    end
    boxes = Boxes.ensure(save)
    for bi = 1, Boxes.COUNT do
      boxes[bi] = boxes[bi] or {}
      while #boxes[bi] < Boxes.CAPACITY do
        boxes[bi][#boxes[bi] + 1] = Pokemon.new(Data, "RATTATA", 5)
      end
    end
    -- Free one party slot so restore can place (as scatter from box)
    table.remove(save.party)
    setMode(SpeciesScope.MODE_NATIONAL)
    local restored, scattered, stillStored, msg =
      SpeciesScope._applyRestoreNational(mod, game)
    T.check(restored >= 1, "scatter restore placed at least one mon")
    T.check(scattered >= 1 or stillStored >= 1,
      "restore marks scatter or still-stored")
    if scattered >= 1 then
      T.check(tostring(msg or ""):find("BOX", 1, true) ~= nil
          or tostring(msg or ""):find("PC", 1, true) ~= nil,
        "scatter message mentions BOX/PC")
    end
    -- Keep applied/mode coherent for later tests
    mod.save:set(SpeciesScope.APPLIED_KEY, SpeciesScope.MODE_NATIONAL)
    setMode(SpeciesScope.MODE_NATIONAL)
  end

  -- Link eligible reason copy
  do
    setMode(SpeciesScope.MODE_KANTO)
    SpeciesScope._game = makeGame(freshSave())
    local Protocol = require("src.link.Protocol")
    local party = { { species = "TREECKO", level = 10 } }
    local myRec = { TREECKO = "hashA", PIKACHU = "hashB" }
    local theirRec = { PIKACHU = "hashB" } -- peer missing Treecko
    local _, reasons = Protocol.eligibleParty(party, myRec, theirRec)
    T.check(reasons and reasons[1], "eligibleParty returns a reason")
    T.check(tostring(reasons[1]):find("KANTO", 1, true) ~= nil,
      "post-151 missing peer uses KANTO scope reason")
  end

  -- Gen1 kanto wild pool excludes Gen3
  do
    setMode(SpeciesScope.MODE_KANTO)
    local Encounters = require("mods.Kanto-Reforged.encounters")
    local pokemon_data = require("mods.Kanto-Reforged.pokemon_data")
    local index = Encounters.apply(mod, pokemon_data, "curated", {
      speciesScope = "kanto",
    })
    T.check(not (index.meta and index.meta.TREECKO),
      "kanto encounter index drops Treecko")
    local anyOver = false
    for id in pairs(index.meta or {}) do
      local spec = pokemon_data.species and pokemon_data.species[id]
      local dex = spec and spec.dex
      if dex and dex > 151 then anyOver = true end
    end
    T.check(not anyOver, "kanto encounter index has no dex>151 guests")
    -- Live field patch for a known route should also stay in-scope
    local field = Data.field and Data.field.encounters and Data.field.encounters.ROUTE_1
    if field and field.grass and field.grass.slots then
      local allOk = true
      for _, slot in ipairs(field.grass.slots) do
        if slot.species and not SpeciesScope.allowsSpeciesId(mod, slot.species, "ROUTE_1") then
          allOk = false
        end
      end
      T.check(allOk, "ROUTE_1 grass slots all in kanto scope after apply")
    end
  end

  -- Map scrub: out-of-scope pokemon= objects fail the visibility gate
  do
    setMode(SpeciesScope.MODE_KANTO)
    T.check(not SpeciesScope.allowsSpeciesId(mod, "GROUDON", "POKEMON_MANSION_B1F"),
      "Groudon blocked under kanto (map scrub target)")
    T.check(SpeciesScope.allowsSpeciesId(mod, "MEWTWO", "CERULEAN_CAVE_B1F")
        or SpeciesScope.allowsSpeciesId(mod, "ARTICUNO", nil),
      "Gen1 legends still allowed under kanto")
  end

  -- Breeding: Gen2 baby (Pichu) refused under Gen1 kanto
  do
    setMode(SpeciesScope.MODE_KANTO)
    SpeciesScope._mod = mod
    local Breeding = require("mods.Kanto-Reforged.breeding")
    Breeding._mod = mod
    local function mon(species, gender)
      return {
        species = species,
        gender = gender,
        level = 20,
        dvs = { attack = 8, defense = 10, speed = 5, special = 12 },
        moves = { { id = "TACKLE", pp = 35 } },
        exp = 0,
        statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
      }
    end
    local dcSave = {
      daycare = {
        mon = mon("PIKACHU", "F"),
        mon2 = mon("PIKACHU", "M"),
        breedSteps = 0,
      },
      player = { name = "RED" },
    }
    local okEgg, errEgg = Breeding.tryCreateDaycareEgg(Data, dcSave, {
      rng = function(a, b)
        if a == 1 and b == 100 then return 1 end
        if a == 150 and b == 255 then return 200 end
        return a or 0
      end,
    })
    T.eq(okEgg, false, "Pikachu egg refused under kanto (Pichu out of scope)")
    T.eq(errEgg, "scope", "scope err from breeding gate")
    T.check(not (dcSave.daycare and dcSave.daycare.egg), "no egg stored under kanto")
    setMode(SpeciesScope.MODE_NATIONAL)
    okEgg = Breeding.tryCreateDaycareEgg(Data, dcSave, {
      rng = function(a, b)
        if a == 1 and b == 100 then return 1 end
        if a == 150 and b == 255 then return 200 end
        return a or 0
      end,
    })
    T.check(okEgg == true, "Pikachu egg allowed under national")
  end

  -- Gen2 Johto vs Kanto map maxDex (force Gen2 host briefly)
  do
    Host.force(2)
    setMode(SpeciesScope.MODE_JOHTO_NATIVE)
    T.eq(SpeciesScope.maxDexForMap(mod, "ROUTE_30"), 251, "Johto map capped at 251")
    T.eq(SpeciesScope.maxDexForMap(mod, "ROUTE_1"), nil, "Kanto map uncapped under johto_native")
    Host.clearForce()
    setMode(SpeciesScope.MODE_NATIONAL)
  end

  -- Restore prior option state + live national surface for later suites
  opts[SpeciesScope.OPTION_KEY] = savedMode or SpeciesScope.MODE_NATIONAL
  setMode(SpeciesScope.MODE_NATIONAL)
  SpeciesScope.applyTransition(mod, makeGame(freshSave()), SpeciesScope.MODE_NATIONAL)
  SpeciesScope.applyDexSize(mod, SpeciesScope.MODE_NATIONAL)
  SpeciesScope.applyEvoScope(mod, SpeciesScope.MODE_NATIONAL)
  mod.save:set(SpeciesScope.APPLIED_KEY, savedApplied)
  mod.save:set(SpeciesScope.STASH_KEY, savedStash)
  SpeciesScope._ignoreOptionEvent = false
  SpeciesScope._game = nil
  Host.clearForce()
end
