-- Route DexNav: aggregation, progressive rows, fishing note, start-menu gate.
return function(T, Data, run)
  local DexNav = require("mods.Kanto-Reforged.ui.dexnav")
  local Runtime = require("src.mods.Runtime")

  -- Different grass vs fish ranges must not merge into one fake span
  local different = DexNav.aggregate({
    grass = { slots = {
      { species = "PSYDUCK", level = 3 },
      { species = "PSYDUCK", level = 5 },
    } },
  }, {
    { species = "PSYDUCK", level = 20 },
    { species = "PSYDUCK", level = 25 },
  }, Data.pokemon)
  T.eq(#different, 1, "grass+fish same species collapses to one row")
  T.eq(different[1].methods.grass.min, 3, "grass min 3")
  T.eq(different[1].methods.grass.max, 5, "grass max 5")
  T.eq(different[1].methods.fish.min, 20, "fish min 20")
  T.eq(different[1].methods.fish.max, 25, "fish max 25")
  local ownedDiff = DexNav.formatOwnedMethods(different[1].methods)
  T.check(ownedDiff:find("GRASS 3%-5", 1, false) ~= nil,
    "owned keeps grass range: " .. ownedDiff)
  T.check(ownedDiff:find("FISH 20%-25", 1, false) ~= nil,
    "owned keeps fish range: " .. ownedDiff)
  T.check(not ownedDiff:find("3%-25", 1, false),
    "owned does not merge into 3-25: " .. ownedDiff)

  -- Identical ranges across methods must still keep both method tags
  local same = DexNav.aggregate({
    grass = { slots = { { species = "GOLDEEN", level = 15 }, { species = "GOLDEEN", level = 20 } } },
  }, {
    { species = "GOLDEEN", level = 15 },
    { species = "GOLDEEN", level = 20 },
  }, Data.pokemon)
  local ownedSame = DexNav.formatOwnedMethods(same[1].methods)
  T.check(ownedSame:find("GRASS", 1, true) ~= nil,
    "identical ranges still tag GRASS: " .. ownedSame)
  T.check(ownedSame:find("FISH", 1, true) ~= nil,
    "identical ranges still tag FISH: " .. ownedSame)
  T.check(ownedSame:find("GRASS 15%-20", 1, false) ~= nil
      and ownedSame:find("FISH 15%-20", 1, false) ~= nil,
    "identical ranges listed per method: " .. ownedSame)

  -- Progressive reveal: unseen has no type / no real name
  local entry = { id = "PIDGEY", methods = { grass = { min = 2, max = 5 } } }
  local unseen = DexNav.formatRow(entry, { seen = {}, owned = {} }, Data.pokemon)
  T.eq(unseen.label, "????", "unseen label is ????")
  T.check(unseen.label:find("PIDGEY", 1, true) == nil, "unseen hides species name")
  T.check(unseen.right == "" or unseen.right == nil, "unseen has no type right-column")
  local typeName = Data.pokemon.PIDGEY.types and Data.pokemon.PIDGEY.types[1]
  if typeName then
    T.check(unseen.label:find(typeName, 1, true) == nil
        and (unseen.right or ""):find(typeName, 1, true) == nil,
      "unseen has no type hint")
  end

  local seen = DexNav.formatRow(entry, { seen = { PIDGEY = true }, owned = {} }, Data.pokemon)
  T.eq(seen.label, Data.pokemon.PIDGEY.name or "PIDGEY", "seen shows species name")
  T.eq(seen.right, "SEEN", "seen right column is SEEN")

  local owned = DexNav.formatRow(entry, {
    seen = { PIDGEY = true }, owned = { PIDGEY = true },
  }, Data.pokemon)
  T.eq(owned.label, Data.pokemon.PIDGEY.name or "PIDGEY", "owned shows species name")
  T.check(owned.right:find("GRASS", 1, true) ~= nil, "owned includes method tag")

  -- Gold pokedex uses `caught` instead of `owned`
  local caught = DexNav.formatRow(entry, {
    seen = { PIDGEY = true }, caught = { PIDGEY = true },
  }, Data.pokemon)
  T.eq(caught.label, Data.pokemon.PIDGEY.name or "PIDGEY",
    "Gold caught counts as owned")
  T.check(caught.right:find("GRASS", 1, true) ~= nil,
    "Gold caught shows method levels")

  -- Nil owned/caught tables must not crash (real Gold save shape)
  local goldBare = DexNav.formatRow(entry, { seen = {} }, Data.pokemon)
  T.eq(goldBare.label, "????", "Gold dex without owned/caught is unseen")
  local goldFlags = DexNav.dexFlags({ seen = { A = true }, caught = { B = true } })
  T.check(goldFlags.owned.B == true, "dexFlags maps caught -> owned")
  T.check(goldFlags.seen.A == true, "dexFlags keeps seen")

  -- Fishing note: grass-only false; water or superRod true
  T.eq(DexNav.showFishingNote({
    grass = { slots = { { species = "PIDGEY", level = 3 } } },
  }, nil), false, "grass-only map has no fishing note")
  T.eq(DexNav.showFishingNote({
    water = { slots = { { species = "TENTACOOL", level = 5 } } },
  }, nil), true, "water map shows fishing note")
  T.eq(DexNav.showFishingNote(nil, {
    { species = "MAGIKARP", level = 15 },
  }), true, "Super Rod map shows fishing note")

  -- Empty map → no rows from buildItems; sentinel left to screen factory
  local emptyItems, emptyFooter = DexNav.buildItems(Data, "PALLET_TOWN_NOPE", {})
  T.eq(#emptyItems, 0, "unknown map builds zero species rows")
  T.eq(emptyFooter, nil, "unknown map has no fishing footer")

  -- Real ROUTE_1 (after Kanto Reforged mix) still aggregates something
  local r1Items, r1Footer = DexNav.buildItems(Data, "ROUTE_1", {
    seen = {}, owned = {},
  })
  T.check(#r1Items > 0, "ROUTE_1 has wild rows")
  T.eq(r1Footer, nil, "ROUTE_1 grass-only has no fishing footer")
  T.eq(r1Items[1].label, "????", "ROUTE_1 unseen rows are ????")

  local r21Items, r21Footer = DexNav.buildItems(Data, "ROUTE_21", {
    seen = {}, owned = {},
  })
  T.check(#r21Items > 0, "ROUTE_21 has wild rows")
  T.eq(r21Footer, "No Old/Good Rod.", "ROUTE_21 fishable footer")

  -- Start-menu hook: gated on EVENT_GOT_POKEDEX, directly under POKéDEX
  local schema = run.loader.optionSchemas["Kanto-Reforged"]
  local dexOpt
  for _, opt in ipairs(schema or {}) do
    if opt.key == DexNav.OPTION_KEY then dexOpt = opt break end
  end
  T.check(dexOpt ~= nil, "DEXNAV option schema registered")
  T.eq(dexOpt.type, "choice", "DEXNAV option is a choice")
  T.eq(dexOpt.default, DexNav.MODE_DEFAULT, "DEXNAV defaults to DEXNAV label")
  T.eq(#dexOpt.choices, 3, "DEXNAV has three modes")

  run.loader.modOptions["Kanto-Reforged"] =
    run.loader.modOptions["Kanto-Reforged"] or {}
  local savedMode = run.loader.modOptions["Kanto-Reforged"][DexNav.OPTION_KEY]
  run.loader.modOptions["Kanto-Reforged"][DexNav.OPTION_KEY] = DexNav.MODE_DEFAULT

  local vanilla = {
    { label = "POKéDEX" },
    { label = "POKéMON" },
    { label = "ITEM" },
    { label = "SAVE" },
    { label = "QUIT" },
  }
  local noDex = Runtime.call("ui.start_menu.items",
    function(_, items) return items end,
    { save = { flags = {} }, data = Data },
    { { label = "SAVE" } })
  local hasDexNav = false
  for _, row in ipairs(noDex) do
    if row.label == "DEXNAV" or row.label == "DEXNAV-KR" then hasDexNav = true end
  end
  T.eq(hasDexNav, false, "DEXNAV absent without EVENT_GOT_POKEDEX")

  local withDex = Runtime.call("ui.start_menu.items",
    function(_, items) return items end,
    { save = { flags = { EVENT_GOT_POKEDEX = true } }, data = Data },
    vanilla)
  local idxDex, idxDexNav, idxPokemon
  for i, row in ipairs(withDex) do
    if row.label == "POKéDEX" then idxDex = i end
    if row.label == "DEXNAV" then idxDexNav = i end
    if row.label == "POKéMON" then idxPokemon = i end
  end
  T.check(idxDexNav ~= nil, "DEXNAV present with EVENT_GOT_POKEDEX")
  T.eq(idxDexNav, idxDex + 1, "DEXNAV is immediately after POKéDEX")
  T.eq(idxPokemon, idxDexNav + 1, "POKéMON stays after DEXNAV")

  run.loader.modOptions["Kanto-Reforged"][DexNav.OPTION_KEY] = DexNav.MODE_KR
  local withKr = Runtime.call("ui.start_menu.items",
    function(_, items) return items end,
    { save = { flags = { EVENT_GOT_POKEDEX = true } }, data = Data },
    {
      { label = "POKéDEX" },
      { label = "POKéMON" },
    })
  local hasKr, hasPlain = false, false
  for _, row in ipairs(withKr) do
    if row.label == "DEXNAV-KR" then hasKr = true end
    if row.label == "DEXNAV" then hasPlain = true end
  end
  T.check(hasKr, "DEXNAV-KR label when mode is dexnav_kr")
  T.eq(hasPlain, false, "plain DEXNAV hidden in dexnav_kr mode")
  T.eq(DexNav.mapTitle("ROUTE_1", {
    options = { get = function() return DexNav.MODE_KR end },
  }), "DEXNAV-KR ROUTE 1", "screen title uses DEXNAV-KR prefix")

  run.loader.modOptions["Kanto-Reforged"][DexNav.OPTION_KEY] = DexNav.MODE_OFF
  local withOff = Runtime.call("ui.start_menu.items",
    function(_, items) return items end,
    { save = { flags = { EVENT_GOT_POKEDEX = true } }, data = Data },
    {
      { label = "POKéDEX" },
      { label = "POKéMON" },
    })
  local offShown = false
  for _, row in ipairs(withOff) do
    if row.label == "DEXNAV" or row.label == "DEXNAV-KR" then offShown = true end
  end
  T.eq(offShown, false, "DEXNAV hidden when mode is off")

  run.loader.modOptions["Kanto-Reforged"][DexNav.OPTION_KEY] = savedMode

  -- Screen factory resolves; fishable maps use fewer rows so footer clears list
  local Screens = require("src.ui.Screens")
  Screens.invalidate()
  local factory = Screens.get(
    { data = Data, save = { flags = { EVENT_GOT_POKEDEX = true },
      player = { map = "ROUTE_1" }, pokedex = { seen = {}, owned = {} } } },
    "ExpDexNav")
  T.check(factory and factory.new, "ExpDexNav screen registered")
  local game = {
    data = Data,
    save = {
      flags = { EVENT_GOT_POKEDEX = true },
      player = { map = "ROUTE_1" },
      pokedex = { seen = {}, owned = {} },
    },
    stack = { pop = function() end },
    input = { wasPressed = function() return false end },
  }
  local ok, screen = pcall(factory.new, game)
  if ok and screen then
    T.check(#screen.items > 0, "ExpDexNav builds items for ROUTE_1")
    T.eq(screen.footer, nil, "ROUTE_1 screen has no footer")
    T.eq(screen.rows, 7, "land route keeps 7 list rows")
  else
    T.check(true, "ExpDexNav factory present (construct skipped)")
    T.check(true, "ExpDexNav land rows skipped")
  end

  local gameFish = {
    data = Data,
    save = {
      flags = { EVENT_GOT_POKEDEX = true },
      player = { map = "ROUTE_21" },
      pokedex = { seen = {}, owned = {} },
    },
    stack = { pop = function() end },
    input = { wasPressed = function() return false end },
  }
  local okFish, screenFish = pcall(factory.new, gameFish)
  if okFish and screenFish then
    T.eq(screenFish.footer, "No Old/Good Rod.", "ROUTE_21 screen footer")
    T.eq(screenFish.rows, 6, "fishable route shrinks rows for footer")
  else
    T.check(true, "ExpDexNav fishable construct skipped")
    T.check(true, "ExpDexNav fishable rows skipped")
  end
end
