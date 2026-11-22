-- Gen 3 (FireRed / LeafGreen) evolution overrides & stone bypasses.
-- 1. Injects Moon Stone / Sun Stone / Water Stone evolutions for trade species & RTC bypasses.
-- 2. Bypasses FRLG vanilla National Dex evolution blocks (Evolution.nationalAllows).

local EvolutionGame3 = {}

local STONE_EVOLUTIONS = {
  -- Canonical Hold Items Used Directly
  { from = "SCYTHER", item = 199, to = "SCIZOR" },      -- Metal Coat (199)
  { from = "ONIX", item = 199, to = "STEELIX" },         -- Metal Coat (199)
  { from = "SEADRA", item = 201, to = "KINGDRA" },       -- Dragon Scale (201)
  { from = "PORYGON", item = 218, to = "PORYGON2" },     -- Up-Grade (218)
  { from = "POLIWHIRL", item = 187, to = "POLITOED" },   -- King's Rock (187)
  { from = "SLOWPOKE", item = 187, to = "SLOWKING" },     -- King's Rock (187)
  { from = "CLAMPERL", item = 192, to = "HUNTAIL" },     -- DeepSeaTooth (192)
  { from = "CLAMPERL", item = 193, to = "GOREBYSS" },    -- DeepSeaScale (193)

  -- Moon Stone (Trade & RTC Fallbacks)
  { from = "KADABRA", item = 94, to = "ALAKAZAM" },
  { from = "MACHOKE", item = 94, to = "MACHAMP" },
  { from = "GRAVELER", item = 94, to = "GOLEM" },
  { from = "HAUNTER", item = 94, to = "GENGAR" },
  { from = "ONIX", item = 94, to = "STEELIX" },
  { from = "SCYTHER", item = 94, to = "SCIZOR" },
  { from = "POLIWHIRL", item = 94, to = "POLITOED" },
  { from = "SLOWPOKE", item = 94, to = "SLOWKING" },
  { from = "PORYGON", item = 94, to = "PORYGON2" },
  { from = "SEADRA", item = 94, to = "KINGDRA" },
  { from = "EEVEE", item = 94, to = "UMBREON" },
  { from = "CLAMPERL", item = 94, to = "GOREBYSS" },

  -- Sun Stone (RTC Bypass)
  { from = "EEVEE", item = 93, to = "ESPEON" },

  -- Water Stone (Branch / Alternate)
  { from = "CLAMPERL", item = 97, to = "HUNTAIL" },
  { from = "SEADRA", item = 97, to = "KINGDRA" },
}

local DIRECT_EVO_ITEMS = {
  [187] = true, -- KING'S ROCK (187)
  [192] = true, -- DEEP SEA TOOTH (192)
  [193] = true, -- DEEP SEA SCALE (193)
  [199] = true, -- METAL COAT (199)
  [201] = true, -- DRAGON SCALE (201)
  [218] = true, -- UP-GRADE (218)
}

local installed = false

local GBA_SPECIES_IDS = {
  KADABRA = 64, ALAKAZAM = 65,
  MACHOKE = 67, MACHAMP = 68,
  GRAVELER = 75, GOLEM = 76,
  HAUNTER = 93, GENGAR = 94,
  ONIX = 95, STEELIX = 208,
  SCYTHER = 123, SCIZOR = 212,
  POLIWHIRL = 61, POLITOED = 186,
  SLOWPOKE = 79, SLOWKING = 199,
  PORYGON = 137, PORYGON2 = 233,
  SEADRA = 117, KINGDRA = 230,
  EEVEE = 133, ESPEON = 196, UMBREON = 197,
  CLAMPERL = 373, HUNTAIL = 374, GOREBYSS = 375,
}

local function resolveSpeciesId(nameOrId)
  if type(nameOrId) == "number" then return nameOrId end
  local clean = tostring(nameOrId):upper():gsub("[%s%-]+", "_")
  local spKey = clean:find("^SPECIES_") and clean or ("SPECIES_" .. clean)
  local okFr, FrSpecies = pcall(require, "src.core.game3.constants.firered.species")
  if okFr and FrSpecies and FrSpecies[spKey] then
    return FrSpecies[spKey]
  end
  return GBA_SPECIES_IDS[clean]
end

function EvolutionGame3.applyEvolutions()
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if not (okP and Pokemon) then return end

  if not Pokemon._evolutions and not EvolutionGame3._inInstall then
    EvolutionGame3._inInstall = true
    pcall(Pokemon.install, Pokemon._cache)
    EvolutionGame3._inInstall = false
  end
  Pokemon._evolutions = Pokemon._evolutions or {}

  local okE, Evolution = pcall(require, "src.core.game3.evolution")
  local EVO_ITEM = (okE and Evolution and Evolution.EVO_ITEM) or 7

  for _, row in ipairs(STONE_EVOLUTIONS) do
    local fromId = resolveSpeciesId(row.from)
    local toId = resolveSpeciesId(row.to)
    if fromId and toId then
      local pairsToInject = { { from = fromId, to = toId } }
      if row.from == "CLAMPERL" then
        local toNat = (row.to == "HUNTAIL") and 367 or 368
        pairsToInject[#pairsToInject + 1] = { from = 366, to = toNat }
      end
      for _, p in ipairs(pairsToInject) do
        local list = Pokemon._evolutions[p.from] or {}
        local exists = false
        for _, evo in ipairs(list) do
          local m = tonumber(evo.method or evo[1])
          local prm = tonumber(evo.param or evo[2])
          local t = tonumber(evo.target or evo[3])
          if m == EVO_ITEM and prm == row.item and t == p.to then
            exists = true
            break
          end
        end
        if not exists then
          list[#list + 1] = { method = EVO_ITEM, param = row.item, target = p.to }
          Pokemon._evolutions[p.from] = list
        end
      end
    end
  end
end

function EvolutionGame3.install(mod)
  if installed then return end
  installed = true

  -- 1. Unconditionally bypass vanilla pre-National Dex evolution block
  local okE, Evolution = pcall(require, "src.core.game3.evolution")
  if okE and Evolution then
    function Evolution.nationalAllows(species, session)
      return true
    end
  end

  -- 2. Hook ItemsData.fieldUseKind so hold evolution items are recognized as "evo"
  local okId, ItemsData = pcall(require, "src.core.game3.items_data")
  if okId and ItemsData and ItemsData.fieldUseKind then
    local origFieldUseKind = ItemsData.fieldUseKind
    function ItemsData.fieldUseKind(id)
      local num = tonumber(id)
      if not num and ItemsData.toNumericId then
        local ok, n = pcall(ItemsData.toNumericId, id)
        if ok and n then num = n end
      end
      if not num and type(id) == "string" then
        local clean = id:upper():gsub("^ITEM_", "")
        local byName = {
          METAL_COAT = 198,
          DRAGON_SCALE = 199,
          KINGS_ROCK = 187,
          UP_GRADE = 200,
          DEEP_SEA_TOOTH = 201,
          DEEP_SEA_SCALE = 202,
        }
        num = byName[clean]
      end
      if num and DIRECT_EVO_ITEMS[num] then
        return "evo"
      end
      return origFieldUseKind(id)
    end
  end

  -- 3. Inject stone & item evolutions into species tables
  local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okP and Pokemon then
    EvolutionGame3.applyEvolutions()
    if type(Pokemon.onReload) == "function" then
      Pokemon.onReload(EvolutionGame3.applyEvolutions)
    end
  end

  -- 4. Hook Marts.itemsFor to guarantee Sea Incense (220) and Lax Incense (221) at Celadon Dept Store & Sevii/Four Island Marts
  local okM, Marts = pcall(require, "src.core.game3.marts")
  if okM and Marts and Marts.itemsFor then
    local origItemsFor = Marts.itemsFor
    function Marts.itemsFor(key)
      local items, e = origItemsFor(key)
      if items and type(items) == "table" then
        local hasStone = false
        local hasIceHeal = false
        local hasSea = false
        local hasLax = false
        for _, it in ipairs(items) do
          local id = tonumber(it)
          if id == 95 or id == 96 or id == 97 or id == 98 or id == 93 or id == 94 then hasStone = true end
          if id == 22 then hasIceHeal = true end
          if id == 220 then hasSea = true end
          if id == 221 then hasLax = true end
        end
        if (hasStone or hasIceHeal) and not (hasSea and hasLax) then
          local copy = {}
          for _, it in ipairs(items) do copy[#copy + 1] = it end
          if not hasSea then copy[#copy + 1] = 220 end
          if not hasLax then copy[#copy + 1] = 221 end
          return copy, e
        end
      end
      return items, e
    end
  end

  if mod and mod.log then
    mod.log:info("Gen 3 trade evolution bypasses & direct item evolution installed")
  end
end

return EvolutionGame3
