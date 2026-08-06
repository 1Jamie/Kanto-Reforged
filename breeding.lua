-- Gen 3-style breeding helpers mapped onto Gen 1 DVs / genderRate / abilities.
-- Daycare UI and overworld step hooks live in daycare.lua.

local Gender = require("mods.expansion_pack.gender")
local Growth = require("src.pokemon.Growth")
local Pokemon = require("src.pokemon.Pokemon")
local Stats = require("src.pokemon.Stats")

local Breeding = {}

Breeding.HATCH_LEVEL = 5
Breeding.STEPS_PER_CYCLE = 256

-- Gen 3 same-OT egg chances (we have no distinct OT on boarded mons).
local CHANCE_SAME_SPECIES = 50
local CHANCE_DIFF_SPECIES = 20

-- Gen 3 incense babies: without the held incense, breed the non-baby form.
-- (We do not ship Sea/Lax Incense yet.) PokéAPI always names the incense baby.
local INCENSE_ONLY_BABIES = {
  AZURILL = "MARILL",
  WYNAUT = "WOBBUFFET",
}

local function defOf(data, species)
  return data and data.pokemon and data.pokemon[species]
end

local function eggGroupsOf(data, species)
  local def = defOf(data, species)
  local groups = def and def.eggGroups
  if type(groups) ~= "table" then return {} end
  return groups
end

local function hasGroup(groups, id)
  for _, g in ipairs(groups) do
    if g == id then return true end
  end
  return false
end

local function isDitto(species)
  return species == "DITTO"
end

local function isUndiscovered(data, species)
  return hasGroup(eggGroupsOf(data, species), "UNDISCOVERED")
end

function Breeding.shareEggGroup(data, a, b)
  local ga, gb = eggGroupsOf(data, a), eggGroupsOf(data, b)
  for _, g in ipairs(ga) do
    if g ~= "DITTO" and g ~= "UNDISCOVERED" and hasGroup(gb, g) then
      return true
    end
  end
  return false
end

-- Returns "none" | "low" | "high" (Gen 3 daycare man tiers, same-OT).
function Breeding.compatibility(data, monA, monB)
  if not monA or not monB then return "none" end
  -- Deposit/legacy saves may lack mon.gender; derive it before the check.
  Gender.ensure(data, monA)
  Gender.ensure(data, monB)
  local sa, sb = monA.species, monB.species
  if not sa or not sb then return "none" end
  if isDitto(sa) and isDitto(sb) then return "none" end
  if isUndiscovered(data, sa) or isUndiscovered(data, sb) then
    return "none"
  end

  local dittoA, dittoB = isDitto(sa), isDitto(sb)
  if dittoA or dittoB then
    local other = dittoA and monB or monA
    if isUndiscovered(data, other.species) then return "none" end
    -- Ditto breeds with anything breedable (including genderless).
    return "low"
  end

  local ga, gb = Gender.of(monA), Gender.of(monB)
  if not ga or not gb or ga == gb then return "none" end
  if not Breeding.shareEggGroup(data, sa, sb) then return "none" end
  if sa == sb then return "high" end
  return "low"
end

function Breeding.eggChance(compat)
  if compat == "high" then return CHANCE_SAME_SPECIES end
  if compat == "low" then return CHANCE_DIFF_SPECIES end
  return 0
end

function Breeding.compatibilityLine(compat)
  if compat == "high" then
    return "The two prefer to\nplay with each\nother more than\nwith other POKéMON."
  elseif compat == "low" then
    return "The two don't seem\nto like each other\nmuch."
  end
  return "The two prefer to\nplay with other\nPOKéMON than each\nother."
end

-- Mother (female) or non-Ditto parent when breeding with Ditto.
function Breeding.speciesParent(monA, monB)
  if not monA or not monB then return nil end
  if isDitto(monA.species) then return monB end
  if isDitto(monB.species) then return monA end
  if Gender.of(monA) == "F" then return monA end
  if Gender.of(monB) == "F" then return monB end
  return monA
end

function Breeding.fatherParent(monA, monB)
  if not monA or not monB then return nil end
  if isDitto(monA.species) then return monB end
  if isDitto(monB.species) then return monA end
  if Gender.of(monA) == "M" then return monA end
  if Gender.of(monB) == "M" then return monB end
  return monA
end

-- Opposite-gender parent, or Ditto, for Crystal-style DV inheritance.
function Breeding.ivParent(monA, monB)
  if not monA or not monB then return nil end
  if isDitto(monA.species) then return monA end
  if isDitto(monB.species) then return monB end
  -- Inherit from the opposite-gender parent of the offspring's species line:
  -- Crystal: Defense/Special from the non-female? Actually Crystal inherits
  -- from the opposite-gender parent relative to... Gen 2: "the other parent"
  -- meaning Defense and Special from one parent (the one that isn't the
  -- species parent for gender?). Crystal FAQ: Defense + Special from the
  -- opposite-gender parent (or Ditto). Species parent is female / non-Ditto;
  -- IV parent is the other one.
  local speciesParent = Breeding.speciesParent(monA, monB)
  if speciesParent == monA then return monB end
  return monA
end

-- Lowest existing evolution stage for breeding. Clamps Gen 4 incense babies
-- (Happiny, etc.) that PokéAPI names but this pack does not ship, and remaps
-- Gen 3 incense-only babies (Azurill/Wynaut) to Marill/Wobbuffet when no
-- incense item is in play.
function Breeding.babySpecies(data, parentSpecies)
  if not parentSpecies then return nil end
  local cur = parentSpecies
  -- Walk evolvesFrom while the pre-evo exists in this pack.
  while true do
    local def = defOf(data, cur)
    local from = def and def.evolvesFrom
    if type(from) == "string" and defOf(data, from) then
      cur = from
    else
      break
    end
  end
  if INCENSE_ONLY_BABIES[cur] then
    cur = INCENSE_ONLY_BABIES[cur]
  end
  if not defOf(data, cur) then return parentSpecies end
  return cur
end

-- Gen 3 Nidoran♀ / Illumise: egg species is a 50/50 coin flip.
-- Male Nidoran line + Ditto and Volbeat + Ditto stay single-species in Gen 3.
function Breeding.applySpeciesFlip(speciesParent, baby, rng)
  rng = rng or love.math.random
  if not baby then return baby end
  if baby == "NIDORAN_F" and Gender.of(speciesParent) == "F" then
    return rng(1, 2) == 1 and "NIDORAN_F" or "NIDORAN_M"
  end
  if speciesParent and speciesParent.species == "ILLUMISE" then
    return rng(1, 2) == 1 and "ILLUMISE" or "VOLBEAT"
  end
  return baby
end

function Breeding.offspringSpecies(data, monA, monB, rng)
  local speciesParent = Breeding.speciesParent(monA, monB)
  if not speciesParent then return nil end
  local baby = Breeding.babySpecies(data, speciesParent.species)
  return Breeding.applySpeciesFlip(speciesParent, baby, rng)
end

function Breeding.inheritDVs(ivParent, rng)
  rng = rng or love.math.random
  local parentDvs = (ivParent and ivParent.dvs) or {}
  local dvs = {
    attack = rng(0, 15),
    defense = parentDvs.defense or rng(0, 15),
    speed = rng(0, 15),
    special = parentDvs.special or rng(0, 15),
  }
  -- Crystal: Special may flip ±8 half the time.
  if parentDvs.special ~= nil and rng(0, 1) == 1 then
    local sp = dvs.special
    if sp < 8 then
      dvs.special = sp + 8
    else
      dvs.special = sp - 8
    end
  end
  dvs.hp = (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4
    + (dvs.speed % 2) * 2 + (dvs.special % 2)
  return dvs
end

local function moveId(slot)
  if type(slot) == "table" then return slot.id end
  return slot
end

local function parentKnows(mon, move)
  if not mon or not mon.moves then return false end
  for _, mv in ipairs(mon.moves) do
    if moveId(mv) == move then return true end
  end
  return false
end

local function canLearnTm(def, move)
  if not def or not def.tmhm then return false end
  for _, m in ipairs(def.tmhm) do
    if m == move then return true end
  end
  return false
end

local function isEggMove(def, move)
  if not def or not def.eggMoves then return false end
  for _, m in ipairs(def.eggMoves) do
    if m == move then return true end
  end
  return false
end

local function learnsetMovesUpTo(def, level)
  local out = {}
  if not def then return out end
  for _, m in ipairs(def.level1Moves or {}) do
    out[#out + 1] = m
  end
  for _, entry in ipairs(def.learnset or {}) do
    if entry.level <= level then
      out[#out + 1] = entry.move
    end
  end
  return out
end

local function isLevelUpMove(def, move)
  for _, m in ipairs(def and def.level1Moves or {}) do
    if m == move then return true end
  end
  for _, entry in ipairs(def and def.learnset or {}) do
    if entry.move == move then return true end
  end
  return false
end

local function moveExists(data, move)
  return data and data.moves and data.moves[move] ~= nil
end

-- Build the baby's initial 4 moves (Gen 3 father-centric inheritance).
function Breeding.inheritMoves(data, babySpecies, mother, father)
  local def = defOf(data, babySpecies)
  local ordered = {}
  local seen = {}

  local function push(move)
    if not move or seen[move] or not moveExists(data, move) then return end
    seen[move] = true
    ordered[#ordered + 1] = move
  end

  -- 1) Default level ≤ 5 moves
  for _, m in ipairs(learnsetMovesUpTo(def, Breeding.HATCH_LEVEL)) do
    push(m)
  end

  -- 2) Shared level-up moves both parents know
  if mother and father then
    for _, mv in ipairs(mother.moves or {}) do
      local id = moveId(mv)
      if parentKnows(father, id) and isLevelUpMove(def, id) then
        push(id)
      end
    end
  end

  -- 3) Father TM/HM if baby can learn
  if father then
    for _, mv in ipairs(father.moves or {}) do
      local id = moveId(mv)
      if canLearnTm(def, id) then push(id) end
    end
  end

  -- 4) Father egg moves
  if father then
    for _, mv in ipairs(father.moves or {}) do
      local id = moveId(mv)
      if isEggMove(def, id) then push(id) end
    end
  end

  -- Keep the most recent 4 (like learnset overflow).
  while #ordered > 4 do
    table.remove(ordered, 1)
  end

  local slots = {}
  for _, id in ipairs(ordered) do
    local mdef = data.moves[id]
    slots[#slots + 1] = { id = id, pp = mdef and mdef.pp or 0 }
  end
  return slots
end

function Breeding.hatchCounter(data, species)
  local def = defOf(data, species)
  local n = def and def.hatchCounter
  if type(n) ~= "number" or n < 1 then return 20 end
  return n
end

function Breeding.createEgg(data, monA, monB, opts)
  opts = opts or {}
  local compat = Breeding.compatibility(data, monA, monB)
  if compat == "none" then return nil, "incompatible" end

  local speciesParent = Breeding.speciesParent(monA, monB)
  local father = Breeding.fatherParent(monA, monB)
  local ivParent = Breeding.ivParent(monA, monB)
  local rng = opts.rng or love.math.random
  local baby = Breeding.offspringSpecies(data, monA, monB, rng)
  if not baby or not defOf(data, baby) then return nil, "unknown baby" end

  local dvs = Breeding.inheritDVs(ivParent, rng)
  local moves = Breeding.inheritMoves(data, baby, speciesParent, father)

  return {
    isEgg = true,
    species = baby,
    eggCycles = Breeding.hatchCounter(data, baby),
    nickname = "EGG",
    dvs = dvs,
    moves = moves,
    otName = opts.otName,
    level = Breeding.HATCH_LEVEL,
    -- hp>0 so the party menu does not stamp FNT; firstHealthy skips isEgg.
    hp = 1,
    exp = 0,
    statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    stats = { hp = 1, attack = 1, defense = 1, speed = 1, special = 1 },
    status = nil,
  }
end

function Breeding.hatch(data, egg, opts)
  if not egg or not egg.isEgg then return nil end
  local species = egg.species
  local def = defOf(data, species)
  if not def then return nil end
  opts = opts or {}

  local level = Breeding.HATCH_LEVEL
  local dvs = egg.dvs or Stats.randomDVs(opts.rng)
  local statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }
  local stats = Stats.calc(def, level, dvs, statExp)
  local moves = egg.moves
  if type(moves) ~= "table" or #moves == 0 then
    moves = {}
    for _, id in ipairs(Pokemon.movesAtLevel(def, level)) do
      local mdef = data.moves[id]
      moves[#moves + 1] = { id = id, pp = mdef and mdef.pp or 0 }
    end
  end

  local mon = {
    species = species,
    level = level,
    exp = Growth.expForLevel(def.growthRate, level),
    dvs = dvs,
    statExp = statExp,
    stats = stats,
    hp = stats.hp,
    catchRate = def.catchRate,
    status = nil,
    moves = moves,
    otName = egg.otName,
  }
  Gender.ensure(data, mon)
  return mon
end

function Breeding.isEgg(mon)
  return type(mon) == "table" and mon.isEgg == true
end

-- Flame Body / Magma Armor in party: Gen 3 halves remaining cycles per tick.
function Breeding.partyHasHatchBooster(data, party)
  for _, mon in ipairs(party or {}) do
    if mon and not Breeding.isEgg(mon) then
      local def = defOf(data, mon.species)
      local ab = def and def.ability
      if ab == "FLAME_BODY" or ab == "MAGMA_ARMOR" then
        return true
      end
    end
  end
  return false
end

-- Advance party egg cycles after STEPS_PER_CYCLE walking steps.
-- Gen 2/3 only hatch the first ready egg in party order per check; later
-- eggs keep their drained cycles but wait for the next 256-step window.
-- Returns list of { index, mon } that hatched this tick (0 or 1 entries).
function Breeding.tickPartyEggs(data, save, cyclesToDrain)
  cyclesToDrain = cyclesToDrain or 1
  if Breeding.partyHasHatchBooster(data, save.party) then
    cyclesToDrain = cyclesToDrain * 2
  end
  local hatched = {}
  for i, mon in ipairs(save.party or {}) do
    if Breeding.isEgg(mon) then
      mon.eggCycles = math.max(0, (mon.eggCycles or 1) - cyclesToDrain)
      if mon.eggCycles <= 0 and #hatched == 0 then
        local baby = Breeding.hatch(data, mon)
        if baby then
          save.party[i] = baby
          hatched[#hatched + 1] = { index = i, mon = baby }
        end
      end
    end
  end
  return hatched
end

function Breeding.resetBreedCountdown(dc, rng)
  rng = rng or love.math.random
  if not dc then return end
  dc.breedSteps = rng(150, 255)
end

-- After breedSteps hits 0, roll for an egg. Returns true if an egg was created.
function Breeding.tryCreateDaycareEgg(data, save, opts)
  local dc = save and save.daycare
  if not dc or dc.egg then return false end
  if not dc.mon or not dc.mon2 then return false end
  local compat = Breeding.compatibility(data, dc.mon, dc.mon2)
  local chance = Breeding.eggChance(compat)
  if chance <= 0 then return false end
  local rng = (opts and opts.rng) or love.math.random
  if rng(1, 100) > chance then
    Breeding.resetBreedCountdown(dc, rng)
    return false
  end
  local otName = opts and opts.otName
  if not otName and save.player then otName = save.player.name end
  local egg, err = Breeding.createEgg(data, dc.mon, dc.mon2, {
    rng = rng, otName = otName,
  })
  if not egg then
    Breeding.resetBreedCountdown(dc, rng)
    return false, err
  end
  dc.egg = egg
  dc.breedSteps = nil
  return true
end

function Breeding.applyPatches(mod, patches)
  if not patches or not patches.species then return 0 end
  local n = 0
  for speciesId, row in pairs(patches.species) do
    mod.content.pokemon:patch(speciesId, {
      eggGroups = row.eggGroups,
      hatchCounter = row.hatchCounter,
      babySpecies = row.babySpecies,
      evolvesFrom = row.evolvesFrom,
      eggMoves = row.eggMoves,
    })
    n = n + 1
  end
  -- Deoxys form alias used by the expansion pack
  if patches.species.DEOXYS then
    local row = patches.species.DEOXYS
    mod.content.pokemon:patch("DEOXYS_NORMAL", {
      eggGroups = row.eggGroups,
      hatchCounter = row.hatchCounter,
      babySpecies = row.babySpecies or "DEOXYS",
      eggMoves = row.eggMoves,
    })
  end
  return n
end

function Breeding.register(mod)
  -- patches applied from main.lua after pokemon_data load
end

function Breeding.install(mod)
  Breeding._mod = mod
end

return Breeding
