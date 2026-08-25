-- Host version exclusive injects: every cart gets the wild bases it was missing.
-- luajit mods/Kanto-Reforged/tests/version_exclusives_test.lua
-- Also loaded from Kanto-Reforged_test.lua.
return function(T)
  local GameVersion = require("src.core.GameVersion")
  local Host = require("mods.Kanto-Reforged.core.host")
  local CachePaths = require("mods.Kanto-Reforged.core.cache_paths")
  local VE = require("mods.Kanto-Reforged.world.version_exclusives")
  local Data = require("src.core.Data")
  local Merge = require("src.mods.Merge")

  local prev = GameVersion.get()
  Host.clearForce()

  local function fakeMod()
    return {
      id = "Kanto-Reforged",
      log = { info = function() end, warn = function() end },
      content = {
        encounters = {
          get = function(_, id)
            if Host.isGen2() then
              return Data.gen2Encounters and Data.gen2Encounters[id]
            end
            return Data.encounters and Data.encounters[id]
          end,
          patch = function()
            error("frozen")
          end,
        },
      },
    }
  end

  local function speciesOnGen1Map(mapId, kind, species)
    local enc = Data.encounters and Data.encounters[mapId]
    local slots = enc and enc[kind] and enc[kind].slots
    if not slots then return false end
    for _, s in ipairs(slots) do
      if s.species == species then return true end
    end
    return false
  end

  local function speciesOnGen2(mapId, kind, species)
    local root = Data.gen2Encounters
    if not root then return false end
    if kind == "water" then
      local slots = root.water and root.water[mapId] and root.water[mapId].slots
      if not slots then return false end
      for _, s in ipairs(slots) do
        if s.species == species then return true end
      end
      return false
    end
    local grass = root.grass and root.grass[mapId]
    local day = grass and grass.slots and grass.slots.DAY
    if not day then return false end
    for _, s in ipairs(day) do
      if s.species == species then return true end
    end
    return false
  end

  local function scrubSpeciesGen1(species)
    for _, enc in pairs(Data.encounters or {}) do
      for _, kind in ipairs({ "grass", "water" }) do
        local slots = enc[kind] and enc[kind].slots
        if slots then
          for _, s in ipairs(slots) do
            if s.species == species then s.species = "RATTATA" end
          end
        end
      end
    end
  end

  local function scrubSpeciesGen2(species)
    local root = Data.gen2Encounters
    if not root then return end
    for _, block in pairs(root.grass or {}) do
      for _, tod in ipairs({ "MORN", "DAY", "NITE" }) do
        local slots = block.slots and block.slots[tod]
        if slots then
          for _, s in ipairs(slots) do
            if s.species == species then s.species = "RATTATA" end
          end
        end
      end
    end
    for _, block in pairs(root.water or {}) do
      for _, s in ipairs(block.slots or {}) do
        if s.species == species then s.species = "TENTACOOL" end
      end
    end
  end

  -- Gen1: load red encounters as a shared baseline, then inject per edition.
  local gen1Enc
  do
    local path = (os.getenv("HOME") or "")
        .. "/.local/share/love/pokemon-love2d/red/data/generated/encounters.lua"
    local ok, enc = pcall(dofile, path)
    if not ok or type(enc) ~= "table" then
      ok, enc = pcall(dofile, "data/generated/encounters.lua")
    end
    if ok and type(enc) == "table" then
      gen1Enc = enc
    end
  end

  if gen1Enc then
    for _, vid in ipairs({ "red", "blue", "yellow" }) do
      GameVersion.set(vid)
      Host.clearForce()
      Data.encounters = Merge.deepCopy(gen1Enc)
      for _, sp in ipairs(VE.MISSING[vid]) do scrubSpeciesGen1(sp) end
      local n = VE.apply(fakeMod())
      T.check(n == #VE.MISSING[vid], vid .. " injects all missing bases (" .. n .. ")")
      for _, sp in ipairs(VE.MISSING[vid]) do
        local place = VE.placementFor(sp)
        T.check(
          speciesOnGen1Map(place.map, place.kind, sp),
          vid .. " has " .. sp .. " on " .. place.map)
      end
      -- Red's classic Pinsir home is Safari Center slot 9 (Scyther). Inject
      -- must not erase Scyther — both exclusives stay catchable.
      if vid == "red" then
        T.check(speciesOnGen1Map("SAFARI_ZONE_CENTER", "grass", "SCYTHER")
            or speciesOnGen1Map("SAFARI_ZONE_EAST", "grass", "SCYTHER"),
          "red Pinsir inject keeps wild Scyther")
        T.check(speciesOnGen1Map("SAFARI_ZONE_CENTER", "grass", "PINSIR"),
          "red still gains Pinsir")
      end
    end
  else
    T.check(true, "G1 exclusive inject skipped (no encounter cache)")
  end

  -- Gen2: prefer gold cache; scrub edition-missing species so inject must place them.
  local gen2Enc = CachePaths.loadGenerated("encounters.lua", "gold")
  if gen2Enc and gen2Enc.grass and gen2Enc.grass.ROUTE_30 then
    for _, vid in ipairs({ "gold", "silver", "crystal" }) do
      GameVersion.set(vid)
      Host.clearForce()
      Data.gen2Encounters = Merge.deepCopy(gen2Enc)
      for _, sp in ipairs(VE.MISSING[vid]) do scrubSpeciesGen2(sp) end
      local n = VE.apply(fakeMod())
      T.check(n == #VE.MISSING[vid], vid .. " injects all missing bases (" .. n .. ")")
      for _, sp in ipairs(VE.MISSING[vid]) do
        local place = VE.placementFor(sp)
        T.check(
          speciesOnGen2(place.map, place.kind, sp),
          vid .. " has " .. sp .. " on " .. place.map)
      end
    end
  else
    T.check(true, "G2 exclusive inject skipped (no Gen2 encounter cache)")
  end

  GameVersion.set(prev or "red")
  Host.clearForce()
end
