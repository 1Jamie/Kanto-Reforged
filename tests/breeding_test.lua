-- Breeding compatibility, inheritance, hatch, two-slot daycare save shape.
return function(T, Data, run)
  local Breeding = require("mods.Kanto-Reforged.pokemon.breeding")
  local Gender = require("mods.Kanto-Reforged.pokemon.gender")
  local Party = require("src.pokemon.Party")

  local function slotCount(dc)
    local n = 0
    if dc and dc.mon then n = n + 1 end
    if dc and dc.mon2 then n = n + 1 end
    return n
  end

  T.check(Data.pokemon.BULBASAUR.eggGroups ~= nil, "Bulbasaur has eggGroups")
  T.check(Data.pokemon.BULBASAUR.hatchCounter ~= nil, "Bulbasaur has hatchCounter")
  T.eq(Data.pokemon.VENUSAUR.babySpecies, "BULBASAUR", "Venusaur baby is Bulbasaur")
  T.eq(Data.pokemon.PIKACHU.babySpecies, "PICHU", "Pikachu baby is Pichu")
  T.check(Data.pokemon.MEW.eggGroups[1] == "UNDISCOVERED", "Mew is Undiscovered")
  T.check(Data.pokemon.DITTO.eggGroups[1] == "DITTO", "Ditto egg group")

  local function mon(species, gender, dvs, moves)
    return {
      species = species,
      gender = gender,
      level = 20,
      dvs = dvs or { attack = 8, defense = 10, speed = 5, special = 12 },
      moves = moves or { { id = "TACKLE", pp = 35 } },
      exp = 0,
      statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    }
  end

  T.eq(Breeding.compatibility(Data, mon("BULBASAUR", "F"), mon("CHARMANDER", "M")),
    "low", "opposite gender shared Monster group")
  T.eq(Breeding.compatibility(Data, mon("BULBASAUR", "F"), mon("BULBASAUR", "M")),
    "high", "same species opposite gender")
  T.eq(Breeding.compatibility(Data, mon("BULBASAUR", "M"), mon("CHARMANDER", "M")),
    "none", "same gender incompatible")
  T.eq(Breeding.compatibility(Data, mon("DITTO", nil), mon("BULBASAUR", "M")),
    "low", "Ditto + breedable")
  T.eq(Breeding.compatibility(Data, mon("DITTO", nil), mon("DITTO", nil)),
    "none", "two Ditto incompatible")
  T.eq(Breeding.compatibility(Data, mon("MEW", nil), mon("DITTO", nil)),
    "none", "Undiscovered + Ditto incompatible")
  T.eq(Breeding.compatibility(Data, mon("MAGNEMITE", nil), mon("DITTO", nil)),
    "low", "genderless + Ditto ok")

  local mother = mon("VENUSAUR", "F")
  local father = mon("CHARIZARD", "M")
  T.eq(Breeding.speciesParent(mother, father), mother, "female is species parent")
  T.eq(Breeding.babySpecies(Data, "VENUSAUR"), "BULBASAUR", "baby of Venusaur")
  T.eq(Breeding.babySpecies(Data, "PIKACHU"), "PICHU", "Pikachu → Pichu")
  T.eq(Breeding.babySpecies(Data, "CHANSEY"), "CHANSEY",
    "Chansey stays Chansey (no Happiny in pack)")
  T.eq(Breeding.babySpecies(Data, "MARILL"), "MARILL",
    "Marill without incense is Marill not Azurill")
  T.eq(Breeding.babySpecies(Data, "WOBBUFFET"), "WOBBUFFET",
    "Wobbuffet without incense is Wobbuffet not Wynaut")
  T.eq(Breeding.babySpecies(Data, "SNORLAX"), "SNORLAX",
    "Snorlax stays Snorlax (no Munchlax in pack)")

  -- Nidoran♀ / Illumise species coin-flip
  do
    local mom = mon("NIDORAN_F", "F")
    local dad = mon("NIDORAN_M", "M")
    local sawF, sawM = false, false
    for i = 1, 40 do
      local sp = Breeding.offspringSpecies(Data, mom, dad, function()
        return (i % 2) + 1
      end)
      if sp == "NIDORAN_F" then sawF = true end
      if sp == "NIDORAN_M" then sawM = true end
    end
    T.check(sawF and sawM, "Nidoran♀ mother can yield either Nidoran")
    local ditto = mon("DITTO", nil)
    local male = mon("NIDORAN_M", "M")
    T.eq(Breeding.offspringSpecies(Data, ditto, male, function() return 1 end),
      "NIDORAN_M", "Nidoran♂ + Ditto stays male in Gen 3")
    local ill = mon("ILLUMISE", "F")
    local vol = mon("VOLBEAT", "M")
    local sawI, sawV = false, false
    for i = 1, 40 do
      local sp = Breeding.offspringSpecies(Data, ill, vol, function()
        return (i % 2) + 1
      end)
      if sp == "ILLUMISE" then sawI = true end
      if sp == "VOLBEAT" then sawV = true end
    end
    T.check(sawI and sawV, "Illumise mother can yield Illumise or Volbeat")
  end

  local ditto = mon("DITTO", nil)
  local male = mon("CHARIZARD", "M")
  T.eq(Breeding.speciesParent(ditto, male), male, "Ditto pair uses non-Ditto")
  T.eq(Breeding.babySpecies(Data, "CHARIZARD"), "CHARMANDER", "baby of Charizard")

  local ivParent = mon("BULBASAUR", "M", {
    attack = 1, defense = 14, speed = 2, special = 9,
  })
  local seq = { 3, 7 }
  local ri = 0
  local function rng(a, b)
    if a == 0 and b == 1 then return 0 end
    if a == 0 and b == 15 then
      ri = ri + 1
      return seq[ri] or 0
    end
    return a or 0
  end
  local dvs = Breeding.inheritDVs(ivParent, rng)
  T.eq(dvs.defense, 14, "inherits defense DV")
  T.eq(dvs.special, 9, "inherits special DV")
  T.eq(dvs.attack, 3, "attack DV randomized")
  T.eq(dvs.speed, 7, "speed DV randomized")
  T.eq(dvs.hp, (3 % 2) * 8 + (14 % 2) * 4 + (7 % 2) * 2 + (9 % 2),
    "HP DV derived from the four")

  local egg, err = Breeding.createEgg(Data, mother, father, {
    rng = function(a, b)
      if a == 0 and b == 1 then return 0 end
      if a == 0 and b == 15 then return 8 end
      return a or 0
    end,
    otName = "RED",
  })
  T.check(egg ~= nil, "createEgg succeeds (" .. tostring(err) .. ")")
  T.check(egg.isEgg == true, "payload marked isEgg")
  T.eq(egg.species, "BULBASAUR", "egg hatches to Bulbasaur")
  T.eq(egg.nickname, "EGG", "egg nickname")
  T.check((egg.eggCycles or 0) > 0, "egg has cycles")

  local baby = Breeding.hatch(Data, egg)
  T.check(baby ~= nil, "hatch produces a mon")
  T.check(not baby.isEgg, "hatched mon is not an egg")
  T.eq(baby.level, 5, "hatch level 5")
  T.eq(baby.species, "BULBASAUR", "hatched species")
  T.check(baby.gender == "M" or baby.gender == "F", "hatched gender assigned")
  T.eq(baby.statExp.attack, 0, "hatched statExp zeroed")

  local mom = mon("BULBASAUR", "F", nil, {
    { id = "TACKLE", pp = 35 }, { id = "GROWL", pp = 40 },
  })
  local dad = mon("BULBASAUR", "M", nil, {
    { id = "TACKLE", pp = 35 }, { id = "GROWL", pp = 40 },
  })
  local moves = Breeding.inheritMoves(Data, "BULBASAUR", mom, dad)
  local hasGrowl = false
  for _, mv in ipairs(moves) do
    if mv.id == "GROWL" then hasGrowl = true end
  end
  T.check(hasGrowl, "shared level-up GROWL inherited")

  local save = {
    party = {
      {
        isEgg = true,
        species = "BULBASAUR",
        eggCycles = 1,
        dvs = { attack = 8, defense = 8, speed = 8, special = 8, hp = 0 },
        moves = { { id = "TACKLE", pp = 35 } },
        nickname = "EGG",
        level = 5,
        hp = 0,
      },
    },
    player = { name = "RED" },
  }
  local hatched = Breeding.tickPartyEggs(Data, save, 1)
  T.eq(#hatched, 1, "one egg hatched")
  T.check(not Breeding.isEgg(save.party[1]), "party slot replaced")
  T.eq(save.party[1].level, 5, "party hatch level 5")

  local dcSave = {
    daycare = {
      mon = mon("BULBASAUR", "F"),
      mon2 = mon("BULBASAUR", "M"),
      breedSteps = 0,
    },
    player = { name = "RED" },
  }
  local ok = Breeding.tryCreateDaycareEgg(Data, dcSave, {
    rng = function(a, b)
      if a == 1 and b == 100 then return 1 end
      if a == 150 and b == 255 then return 200 end
      return a or 0
    end,
  })
  T.check(ok == true, "daycare egg created on successful roll")
  T.check(dcSave.daycare.egg and dcSave.daycare.egg.isEgg, "egg stored on daycare")

  local party = {
    { isEgg = true, species = "BULBASAUR", hp = 1,
      stats = { hp = 1, attack = 1, defense = 1, speed = 1, special = 1 } },
    { species = "RATTATA", hp = 20, level = 5 },
  }
  local lead, idx = Party.firstHealthy(party)
  if Party._expEggHealthyPatch then
    T.eq(idx, 2, "firstHealthy skips egg lead")
    T.eq(lead.species, "RATTATA", "healthy non-egg selected")
  end

  local day2 = {
    species = "RATTATA",
    dvs = { attack = 15, defense = 0, speed = 0, special = 0 },
  }
  local gsave = { party = {}, boxes = {}, daycare = { mon2 = day2 } }
  Gender.backfillSave(Data, gsave)
  T.eq(day2.gender, "M", "mon2 gender backfilled")

  local legacy = { mon = mon("PIDGEY", "M"), steps = 10, depositLevel = 5 }
  T.eq(legacy.mon2, nil, "legacy daycare has no mon2")
  T.eq(slotCount(legacy), 1, "one slot occupied")

  -- Interior + Day-Care Lady map patch
  local Daycare = require("mods.Kanto-Reforged.daycare")
  local MapScripts = require("src.script.MapScripts")
  local daycareMap = Data.maps.DAYCARE
  T.eq(#daycareMap.blocks, 16, "DAYCARE still 4×4 blocks")
  T.eq(daycareMap.blocks[6], 1, "table L")
  T.eq(daycareMap.blocks[7], 2, "table R")
  T.eq(daycareMap.blocks[10], 12, "stools L")
  T.eq(daycareMap.blocks[11], 13, "stools R")
  T.eq(daycareMap.blocks[14], 11, "single doormat")
  T.eq(daycareMap.blocks[15], 15, "floor beside mat (not a second mat)")
  local man, lady
  for _, obj in ipairs(daycareMap.objects or {}) do
    if obj.name == "DAYCARE_GENTLEMAN" then man = obj end
    if obj.name == Daycare.LADY_NAME or obj.text == Daycare.LADY_TEXT then
      lady = obj
    end
  end
  T.check(man ~= nil, "daycare gentleman present")
  T.check(lady ~= nil, "daycare lady present")
  T.eq(lady.sprite, "SPRITE_MIDDLE_AGED_WOMAN", "lady sprite")
  T.eq(man.x, Daycare.GENTLEMAN.x, "gentleman left of table")
  T.eq(lady.x, Daycare.LADY.x, "lady on right side")
  local scripts = MapScripts.get("DAYCARE")
  T.check(scripts and scripts.talk and scripts.talk.TEXT_DAYCARE_GENTLEMAN,
    "gentleman talk script")
  T.check(scripts.talk[Daycare.LADY_TEXT], "lady talk script")
  T.eq(#(daycareMap.warps or {}), 2, "exit warps unchanged")
end
