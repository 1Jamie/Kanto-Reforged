-- Spawn option matrix: dex scope × curated/full/pure × legends, Gen1 + Gen2.
-- Also covers frozen-registry mid-session toggles and PURE RANDOM SPAWN.
return function(T, Data, run, opts)
  opts = opts or {}
  local Host = require("mods.Kanto-Reforged.host")
  local Merge = require("src.mods.Merge")
  local pack = require("mods.Kanto-Reforged.pokemon_data")
  local Encounters = require("mods.Kanto-Reforged.encounters")

  local LEG = {
    ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
    RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
    CELEBI = true, REGIROCK = true, REGICE = true, REGISTEEL = true,
    LATIAS = true, LATIOS = true, KYOGRE = true, GROUDON = true,
    RAYQUAZA = true, JIRACHI = true, DEOXYS = true,
  }

  local function dexOf(sp)
    local d = Data.pokemon and Data.pokemon[sp]
    if d and d.dex then return d.dex end
    local p = pack.species and pack.species[sp]
    return p and p.dex
  end

  if Host.isGen1() and not opts.skipGen1 then
    -- Snapshot true vanilla ROM tables (mod load already mixed Data.encounters).
    local vanilla = dofile("data/generated/encounters.lua")
    local function restore()
      for k in pairs(Data.encounters) do Data.encounters[k] = nil end
      for k, v in pairs(Merge.deepCopy(vanilla)) do Data.encounters[k] = v end
      Encounters.clearBaselines()
    end
    local function frozenApi()
      return {
        id = "Kanto-Reforged",
        log = { info = function() end, warn = function() end },
        content = {
          encounters = {
            get = function(_, id) return Data.encounters[id] end,
            patch = function()
              error("encounters: content is frozen after load")
            end,
          },
        },
      }
    end

    for _, scope in ipairs({ "national", "kanto" }) do
      for _, mode in ipairs({ "curated", "full_random", "pure_random" }) do
        for _, leg in ipairs({ false, true }) do
          restore()
          local label = ("G1 %s/%s/L=%s"):format(scope, mode, tostring(leg))
          Encounters.apply(frozenApi(), pack, mode, {
            speciesScope = scope,
            legendsInMix = leg,
          })
          local maxDex = (scope == "kanto") and 151 or nil
          local over, badRate, shed, unknown = 0, 0, 0, 0
          for mapId, enc in pairs(Data.encounters) do
            local g = enc.grass
            if g then
              if type(g.rate) ~= "number" or g.rate <= 0 then
                badRate = badRate + 1
              end
              for _, s in ipairs(g.slots or {}) do
                local sp = s.species
                local dex = dexOf(sp)
                if maxDex and dex and dex > maxDex then over = over + 1 end
                if sp == "SHEDINJA" then shed = shed + 1 end
                if not dexOf(sp) and not (Data.pokemon and Data.pokemon[sp]) then
                  unknown = unknown + 1
                end
                if not leg and LEG[sp] and mode == "pure_random" then
                  T.check(false, label .. " unexpected legend " .. sp .. " on " .. mapId)
                end
              end
            end
          end
          T.eq(over, 0, label .. " no out-of-scope dex")
          T.eq(badRate, 0, label .. " grass.rate intact")
          T.eq(shed, 0, label .. " no Shedinja")
          T.eq(unknown, 0, label .. " all species known")
        end
      end
    end

    -- Pure random is seeded: same seed → same mix; different seeds remix.
    restore()
    Encounters.apply(frozenApi(), pack, "pure_random", {
      speciesScope = "national", legendsInMix = false, seed = 424242,
    })
    local a = {}
    for i, s in ipairs(Data.encounters.ROUTE_1.grass.slots) do
      a[i] = s.species
    end
    Encounters.apply(frozenApi(), pack, "pure_random", {
      speciesScope = "national", legendsInMix = false, seed = 424242,
    })
    local same = true
    for i, s in ipairs(Data.encounters.ROUTE_1.grass.slots) do
      if s.species ~= a[i] then same = false break end
    end
    T.check(same, "G1 pure_random same seed is stable on ROUTE_1")
    Encounters.apply(frozenApi(), pack, "pure_random", {
      speciesScope = "national", legendsInMix = false, seed = 777001,
    })
    local differ = false
    for i, s in ipairs(Data.encounters.ROUTE_1.grass.slots) do
      if s.species ~= a[i] then differ = true break end
    end
    T.check(differ, "G1 pure_random different seed remixes ROUTE_1")

    -- Pure pool respects kanto scope.
    local poolK = Encounters.buildPurePool(pack, { speciesScope = "kanto" })
    local poolN = Encounters.buildPurePool(pack, { speciesScope = "national" })
    T.check(#poolN > #poolK, "national pure pool larger than kanto")
    local bad = false
    for _, id in ipairs(poolK) do
      local dex = dexOf(id)
      if dex and dex > 151 then bad = true end
    end
    T.check(not bad, "kanto pure pool has no dex>151")

    -- Restore curated national for later suites.
    restore()
    Encounters.apply(frozenApi(), pack, "curated", { speciesScope = "national" })
  end

  if Host.isGen2() and not opts.skipGen2 then
    local EG2 = require("mods.Kanto-Reforged.encounters_gen2")
    -- Headless Gold boots may lack the ROM encounter cache; pull it if present.
    if not (Data.gen2Encounters and Data.gen2Encounters.grass
        and Data.gen2Encounters.grass.ROUTE_29) then
      local home = os.getenv("HOME") or ""
      local path = home .. "/.local/share/love/pokemon-love2d/gold/data/generated/encounters.lua"
      local ok, enc = pcall(dofile, path)
      if ok and enc and enc.grass then
        Data.gen2Encounters = enc
      end
    end
    if not (Data.gen2Encounters and Data.gen2Encounters.grass
        and Data.gen2Encounters.grass.ROUTE_29
        and Data.gen2Encounters.grass.ROUTE_1) then
      T.check(true, "G2 spawn matrix skipped (no Gold encounter cache)")
      return
    end
    -- Ensure pokemon defs exist for Gold natives referenced by the pool.
    do
      local home = os.getenv("HOME") or ""
      local path = home .. "/.local/share/love/pokemon-love2d/gold/data/generated/pokemon.lua"
      local ok, poke = pcall(dofile, path)
      if ok and type(poke) == "table" then
        Data.pokemon = Data.pokemon or {}
        for id, rec in pairs(poke) do
          if not Data.pokemon[id] then Data.pokemon[id] = rec end
        end
      end
    end
    local vanilla = Merge.deepCopy(Data.gen2Encounters)
    local function restore()
      Data.gen2Encounters = Merge.deepCopy(vanilla)
      EG2.clearBaselines()
    end
    local function frozenApi(scope)
      local Host = require("mods.Kanto-Reforged.host")
      local scopeKey = Host.optionKey("species_scope")
      return {
        id = "Kanto-Reforged",
        log = { info = function() end, warn = function() end },
        options = {
          get = function(_, k)
            if k == scopeKey or k == "species_scope" then return scope end
          end,
        },
        content = {
          encounters = {
            get = function(_, kind) return Data.gen2Encounters[kind] end,
            patch = function()
              error("encounters: content is frozen after load")
            end,
          },
          pokemon = {
            each = function() return pairs(Data.pokemon or {}) end,
            get = function(_, id) return Data.pokemon and Data.pokemon[id] end,
          },
        },
      }
    end

    for _, scope in ipairs({ "national", "johto_native" }) do
      for _, mode in ipairs({ "curated", "full_random", "pure_random" }) do
        for _, leg in ipairs({ false, true }) do
          restore()
          local label = ("G2 %s/%s/L=%s"):format(scope, mode, tostring(leg))
          EG2.apply(frozenApi(scope), pack, mode, {
            legendsInMix = leg,
            speciesScope = scope,
          })
          local over, shed, unknown, badLeg = 0, 0, 0, 0
          for mapId, block in pairs(Data.gen2Encounters.grass or {}) do
            local maxDex
            if scope == "johto_native" and not EG2._isKantoMap(mapId) then
              maxDex = 251
            end
            for _, s in ipairs((block.slots and block.slots.DAY) or {}) do
              local sp = s.species
              local dex = dexOf(sp)
              if maxDex and dex and dex > maxDex then over = over + 1 end
              if sp == "SHEDINJA" then shed = shed + 1 end
              if not (Data.pokemon and Data.pokemon[sp])
                  and not (pack.species and pack.species[sp]) then
                unknown = unknown + 1
              end
              if not leg and LEG[sp] and (mode == "full_random" or mode == "pure_random") then
                badLeg = badLeg + 1
              end
            end
          end
          T.eq(over, 0, label .. " Johto scope respected")
          T.eq(shed, 0, label .. " no Shedinja")
          T.eq(unknown, 0, label .. " all species known")
          T.eq(badLeg, 0, label .. " no legends when legends_in_mix off")
        end
      end
    end

    -- Pure random is seeded: same seed stable; different seed remixes.
    restore()
    EG2.apply(frozenApi("national"), pack, "pure_random", {
      legendsInMix = false, seed = 424242,
    })
    local a = {}
    for i, s in ipairs(Data.gen2Encounters.grass.ROUTE_29.slots.DAY) do
      a[i] = s.species
    end
    EG2.apply(frozenApi("national"), pack, "pure_random", {
      legendsInMix = false, seed = 424242,
    })
    local same = true
    for i, s in ipairs(Data.gen2Encounters.grass.ROUTE_29.slots.DAY) do
      if s.species ~= a[i] then same = false break end
    end
    T.check(same, "G2 pure_random same seed is stable on ROUTE_29")
    EG2.apply(frozenApi("national"), pack, "pure_random", {
      legendsInMix = false, seed = 777001,
    })
    local differ = false
    for i, s in ipairs(Data.gen2Encounters.grass.ROUTE_29.slots.DAY) do
      if s.species ~= a[i] then differ = true break end
    end
    T.check(differ, "G2 pure_random different seed remixes ROUTE_29")

    restore()
    EG2.apply(frozenApi("national"), pack, "curated")
  end
end
