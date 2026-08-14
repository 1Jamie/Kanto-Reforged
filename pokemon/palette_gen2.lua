-- Map KR's Gen1 4-shade species palettes onto Gold's gen2Palettes.pokemon
-- rows (middle two colors only; white/black are supplied by the GBC).
--
-- On Red, species_palettes registers as named SGB packs (palette = "TREECKO").
-- On Gold, Palettes.monColors looks up gen2Palettes.pokemon[speciesId] —
-- registering Gen1-shaped rows as top-level ids left Hoenn stuck in grayscale.

local PaletteGen2 = {}

local function rgb(c)
  if not c then return nil end
  if c.r then return { c.r, c.g, c.b } end
  return { c[1], c[2], c[3] }
end

--- Convert a 4-shade SGB palette {white, light, dark, black} → Gen2 mid pair.
function PaletteGen2.midPair(colors)
  if type(colors) ~= "table" then return nil end
  local list = colors.colors or colors
  if #list < 4 then return nil end
  local light, dark = rgb(list[2]), rgb(list[3])
  if not (light and dark) then return nil end
  return { light, dark }
end

--- Build speciesId → { normal, shiny } for every KR species that has a
-- named palette and is missing from the Gold ROM table.
function PaletteGen2.buildPokemonRows(species_palettes, pokemon_data, existing)
  existing = existing or {}
  local rows = {}
  for speciesId, record in pairs(pokemon_data.species or {}) do
    if existing[speciesId] then
      -- Keep Gold ROM (or prior) colors for Johto natives.
    else
      local palName = record.palette or speciesId
      local colors = species_palettes[palName] or species_palettes[speciesId]
      local pair = PaletteGen2.midPair(colors)
      if pair then
        rows[speciesId] = {
          normal = { pair[1], pair[2] },
          -- Mild shiny: swap mids so it's visibly distinct without art.
          shiny = { pair[2], pair[1] },
        }
      end
    end
  end
  return rows
end

--- Register / patch onto gen2Palettes.pokemon. No-op on Gen1 hosts.
function PaletteGen2.apply(mod, species_palettes, pokemon_data)
  if not require("mods.Kanto-Reforged.core.host").isGen2() then
    return 0
  end
  if type(species_palettes) ~= "table" or type(pokemon_data) ~= "table" then
    return 0
  end

  local existing = mod.content.palettes:get("pokemon") or {}
  local rows = PaletteGen2.buildPokemonRows(species_palettes, pokemon_data, existing)
  local n = 0
  for _ in pairs(rows) do n = n + 1 end
  if n == 0 then
    mod.log:info("Gen2 species palettes: nothing new to add")
    return 0
  end

  local ok, err = pcall(function()
    mod.content.palettes:patch("pokemon", rows)
  end)
  if not ok then
    mod.log:warn("Gen2 species palette patch failed: %s", tostring(err))
    return 0
  end
  mod.log:info("Gen2 species palettes: added %d (Hoenn / missing)", n)
  return n
end

--- Gen1 path: named SGB packs (unchanged).
function PaletteGen2.applyGen1(mod, species_palettes)
  if require("mods.Kanto-Reforged.core.host").isGen2() then
    return 0
  end
  local n = 0
  for id, colors in pairs(species_palettes or {}) do
    local ok = pcall(function()
      mod.content.palettes:register(id, colors)
    end)
    if ok then n = n + 1 end
  end
  if n > 0 then
    mod.log:info("Registered %d species palettes", n)
  end
  return n
end

return PaletteGen2
