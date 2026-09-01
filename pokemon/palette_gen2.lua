-- Map KR's Gen1 4-shade species palettes onto Gold's gen2Palettes.pokemon
-- rows (middle two colors only; white/black are supplied by the GBC).
--
-- On Red, species_palettes registers as named SGB packs (palette = "TREECKO").
-- On Gold, Palettes.monColors looks up gen2Palettes.pokemon[speciesId] —
-- registering Gen1-shaped rows as top-level ids left Hoenn stuck in grayscale.
--
-- assets/gs/palettes/*.json are the source of truth for converted gs art.
-- convert_raw_sprites.py compiles them to pokemon/gs_palettes.lua; that table
-- overrides species_palettes.lua for matching ids (including CASTFORM forms).

local PaletteGen2 = {}

PaletteGen2._merged = nil

-- Gen1 SGB + Gen2 GbcPalette: shade 0 → white, shade 3 → black.  The engine
-- remaps transparent / matte pixels through slot 1 (white); custom colours
-- there paint a background box (e.g. AIPOM cream).
PaletteGen2.SGB_WHITE = { 255, 255, 255 }
PaletteGen2.SGB_BLACK = { 0, 0, 0 }

local function rgb(c)
  if not c then return nil end
  if c.r then return { c.r, c.g, c.b } end
  return { c[1], c[2], c[3] }
end

--- Force SGB white/black anchors; preserve the two middle shades only.
--- When cream sat in slot 1 (shade 0), blind rgb[2]/rgb[3] kept purple in the
--- light-mid slot and painted a peach matte box — pick mids by luma instead.
function PaletteGen2.normalizeFourShade(colors)
  if type(colors) ~= "table" then return nil end
  local list = colors.colors or colors
  if #list < 4 then return nil end
  local function rgb(c)
    if not c then return nil end
    if c.r then return { c.r, c.g, c.b } end
    return { c[1], c[2], c[3] }
  end
  local function luma(t)
    return 0.299 * t[1] + 0.587 * t[2] + 0.114 * t[3]
  end
  local function isWhite(t)
    return t[1] == 255 and t[2] == 255 and t[3] == 255
  end
  local function isBlack(t)
    return t[1] == 0 and t[2] == 0 and t[3] == 0
  end
  local mids = {}
  for i = 1, 4 do
    local t = rgb(list[i])
    if t and not isWhite(t) and not isBlack(t) then
      mids[#mids + 1] = t
    end
  end
  table.sort(mids, function(a, b) return luma(a) > luma(b) end)
  local light = mids[1] or { 170, 170, 170 }
  local dark = mids[2] or { 85, 85, 85 }
  return {
    PaletteGen2.SGB_WHITE,
    light,
    dark,
    PaletteGen2.SGB_BLACK,
  }
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

function PaletteGen2.loadGsPalettes()
  package.loaded["mods.Kanto-Reforged.pokemon.gs_palettes"] = nil
  local ok, t = pcall(require, "mods.Kanto-Reforged.pokemon.gs_palettes")
  if ok and type(t) == "table" then return t end
  return {}
end

--- gs_palettes wins over species_palettes for the same id.
function PaletteGen2.merge(base, overlay)
  local out = {}
  for k, v in pairs(base or {}) do
    out[k] = v
  end
  for k, v in pairs(overlay or {}) do
    out[k] = v
  end
  return out
end

--- Build + cache the runtime palette table (species_palettes ∪ gs_palettes).
function PaletteGen2.prepare(species_palettes)
  local merged = PaletteGen2.merge(species_palettes, PaletteGen2.loadGsPalettes())
  local normalized = {}
  for k, v in pairs(merged) do
    normalized[k] = PaletteGen2.normalizeFourShade(v) or v
  end
  PaletteGen2._merged = normalized
  return normalized
end

function PaletteGen2.colorsFor(id)
  if not id then return nil end
  local colors
  local m = PaletteGen2._merged
  if m and m[id] then
    colors = m[id]
  else
    local gs = PaletteGen2.loadGsPalettes()
    if gs[id] then
      colors = gs[id]
    else
      local ok, pals = pcall(require, "mods.Kanto-Reforged.pokemon.species_palettes")
      if ok and type(pals) == "table" then colors = pals[id] end
    end
  end
  return PaletteGen2.normalizeFourShade(colors) or colors
end

--- Build speciesId → { normal, shiny } for every KR species that has a
-- named palette and is missing from the Gold ROM table.
function PaletteGen2.buildPokemonRows(species_palettes, pokemon_data, existing)
  existing = existing or {}
  local rows = {}
  for speciesId, record in pairs(pokemon_data.species or {}) do
    if existing[speciesId] then
      -- Johto native: only override if the record has a KR custom sprite AND
      -- a KR palette entry. ROM palette is calibrated for ROM sprites; our
      -- custom flat art needs our palette.
      local palName = record.palette or speciesId
      local colors = species_palettes[palName] or species_palettes[speciesId]
      local hasCustomSprite = type(record.spriteFront) == "string"
        and record.spriteFront:find("mods/Kanto%-Reforged") ~= nil
      if colors and hasCustomSprite then
        local pair = PaletteGen2.midPair(colors)
        if pair then
          rows[speciesId] = {
            normal = { pair[1], pair[2] },
            shiny = { pair[2], pair[1] },
          }
        end
      end
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
      mod.content.palettes:register(id, PaletteGen2.normalizeFourShade(colors) or colors)
    end)
    if ok then n = n + 1 end
  end
  if n > 0 then
    mod.log:info("Registered %d species palettes", n)
  end
  return n
end

return PaletteGen2
