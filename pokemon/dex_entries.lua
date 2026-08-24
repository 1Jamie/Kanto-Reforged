-- Pokédex flavor text bridge for Kanto Reforged species.
--
-- Gen1: DexEntryMenu looks up `game.data.text[dexEntry.text]`. The generator
-- embeds PokéAPI paragraphs inline, so a bare prose string → "Data unknown."
-- We wrap to Gen1 length, register a `_EXP_*_DexEntry` key, and dual-write
-- into Data.text (content registry alone can miss when routed / frozen).
-- Render-time fallback also recovers when the key exists but game.data.text
-- is missing the body (empty / partial text tables).
--
-- Gen2: Gold's PokedexMenu reads `Data.gen2Pokedex.entries[species]` with
-- inline `text` / `text2` (`<NEXT>` line breaks). Hoenn species are absent
-- from the ROM sheet — we fill those rows. NEW / A-Z orders are rebuilt from
-- Johto wild availability (see johto_dex.lua). Catch → NewPokedexEntry forces
-- OLD when the species is off the current NEW/A–Z list.
--
-- Weights in pokemon_data are kilograms (PokéAPI). Both Gen1 and Gen2 UIs
-- expect tenths of a pound (Pikachu = 130 → 13.0 lb).

local DexEntries = {}

local COLS = 18
local MAX_LINES = 6
-- 1 kg = 2.20462262185 lb; UI stores lb × 10.
local KG_TO_TENTHS_LB = 22.0462262185

local Overrides = require("mods.Kanto-Reforged.pokemon.dex_text_overrides")

local function isTextKey(s)
  return type(s) == "string" and s:match("^_[%w_]+$") ~= nil
end

function DexEntries.kgToTenthsLb(kg)
  if type(kg) ~= "number" then return 0 end
  return math.max(0, math.floor(kg * KG_TO_TENTHS_LB + 0.5))
end

-- Idempotent: pack stores kg; after this, entry.weight is tenths-of-lb.
-- Flag lives in a weak side table — dexEntry schema rejects unknown fields.
local weightConverted = setmetatable({}, { __mode = "k" })
local function ensureWeightTenths(entry)
  if not entry or weightConverted[entry] then return end
  if type(entry.weight) ~= "number" then return end
  entry.weight = DexEntries.kgToTenthsLb(entry.weight)
  weightConverted[entry] = true
end

local function softLines(text, cols, maxLines)
  cols = cols or COLS
  maxLines = maxLines or MAX_LINES
  if type(text) ~= "string" or text == "" then return {} end

  local source = text
  if text:find("\n", 1, true) or text:find("\f", 1, true)
      or text:find("<NEXT>", 1, true) then
    source = text:gsub("<NEXT>", " "):gsub("[\n\f\v]", " ")
  end

  local words = {}
  for w in source:gmatch("%S+") do words[#words + 1] = w end
  local lines, line = {}, ""
  for _, word in ipairs(words) do
    if line == "" then
      line = word
    elseif #line + 1 + #word <= cols then
      line = line .. " " .. word
    else
      lines[#lines + 1] = line
      line = word
      if #lines >= maxLines then
        line = nil
        break
      end
    end
  end
  if line and #lines < maxLines then
    lines[#lines + 1] = line
  end
  while #lines > maxLines do
    lines[#lines] = nil
  end
  return lines
end

-- Soft-wrap like Gen 1 dex pages (~18 cols, \n between lines, \f every 3 lines).
-- Note: Gen 1 DexEntryMenu unconditionally appends a period '.' to the final line,
-- so we strip trailing periods from the source text to prevent double/triple dots.
function DexEntries.wrap(text, cols, maxLines)
  local clean = tostring(text or ""):gsub("%s*%.+$", "")
  local Dialogue = require("mods.Kanto-Reforged.core.dialogue")
  local pages = Dialogue.dexPages(clean, cols or COLS)
  local chunks = {}
  for pi, pageLines in ipairs(pages) do
    if maxLines and (pi - 1) * 3 >= maxLines then break end
    local pageChunk = table.concat(pageLines, "\n")
    chunks[#chunks + 1] = pageChunk
  end
  return table.concat(chunks, "\f")
end

-- Gen2 entry pages: three `<NEXT>`-joined lines (~18 cols) per page.
function DexEntries.wrapGen2(text, cols)
  local clean = tostring(text or "")
  if not clean:match("[%?!%.]$") then
    clean = clean .. "."
  end
  local Dialogue = require("mods.Kanto-Reforged.core.dialogue")
  local pages = Dialogue.dexGen2(clean, cols or COLS)
  return pages[1] or "", pages[2] or "", pages
end

function DexEntries.textKey(speciesId)
  return "_EXP_" .. speciesId .. "_DexEntry"
end

function DexEntries.sourceText(speciesId, entry)
  if Overrides[speciesId] then
    return Overrides[speciesId]
  end
  if entry and type(entry.text) == "string" and not isTextKey(entry.text) then
    return entry.text
  end
  -- After Gen1 bind, prose lives under Data.text[key].
  if entry and isTextKey(entry.text) then
    local ok, Data = pcall(require, "src.core.Data")
    local body = ok and Data and Data.text and Data.text[entry.text]
    if type(body) == "string" and body ~= "" then
      return body
    end
  end
  return nil
end

local function writeDataText(key, body)
  local ok, Data = pcall(require, "src.core.Data")
  if ok and Data then
    Data.text = Data.text or {}
    Data.text[key] = body
  end
end

-- Rewrite one species record in place; register the body on mod.content.text
-- and mirror into Data.text so Gen1 lookup cannot miss after merge/routing.
function DexEntries.bind(mod, speciesId, record)
  local entry = record and record.dexEntry
  if not entry then return false end

  ensureWeightTenths(entry)

  local prose = DexEntries.sourceText(speciesId, entry)
  if not prose or prose == "" then
    -- Already a key with no override; leave alone (weight still normalized).
    return false
  end

  local key = DexEntries.textKey(speciesId)
  local body = DexEntries.wrap(prose)
  if mod and mod.content and mod.content.text and mod.content.text.register then
    pcall(function()
      mod.content.text:register(key, body)
    end)
  end
  writeDataText(key, body)
  entry.text = key
  return true
end

function DexEntries.bindAll(mod, speciesTable)
  local n = 0
  for id, record in pairs(speciesTable or {}) do
    if DexEntries.bind(mod, id, record) then
      n = n + 1
    end
  end
  return n
end

-- Ensure DexEntryMenu can resolve e.text → body on game.data.text.
-- Handles inline prose, missing keys, and Data.text / Overrides recovery.
function DexEntries.ensureDexText(game, def)
  local e = def and def.dexEntry
  if not (game and e) then return false end
  -- Do not convert weight here: bindAll already wrote tenths onto pack rows
  -- before register, and Data.pokemon holds copies. Re-converting would
  -- treat tenths as kg.
  game.data = game.data or {}
  game.data.text = game.data.text or {}

  local function publish(key, body)
    if type(key) ~= "string" or type(body) ~= "string" or body == "" then
      return false
    end
    game.data.text[key] = body
    writeDataText(key, body)
    e.text = key
    return true
  end

  if type(e.text) == "string" and game.data.text[e.text] then
    return true
  end

  if type(e.text) == "string" and not isTextKey(e.text) then
    local key = DexEntries.textKey((def and def.id) or "UNKNOWN")
    return publish(key, DexEntries.wrap(e.text))
  end

  local key = isTextKey(e.text) and e.text
    or DexEntries.textKey((def and def.id) or "UNKNOWN")
  local ok, Data = pcall(require, "src.core.Data")
  local body = ok and Data and Data.text and Data.text[key]
  if type(body) ~= "string" or body == "" then
    local prose = DexEntries.sourceText(def and def.id, e)
      or (def and def.id and Overrides[def.id])
    if prose and prose ~= "" then
      body = DexEntries.wrap(prose)
    end
  end
  return publish(key, body)
end

local function gen2Kind(kind)
  if type(kind) ~= "string" then return "" end
  return (kind
    :gsub("%s*POKéMON%s*$", "")
    :gsub("%s*POKEMON%s*$", "")
    :gsub("%s*POKMON%s*$", "")
    :gsub("%s+$", ""))
end

function DexEntries.toGen2Entry(speciesId, record)
  local entry = record and record.dexEntry
  if not entry then return nil end
  local prose = DexEntries.sourceText(speciesId, entry)
  if (not prose or prose == "") and type(entry.text) == "string" then
    -- Bound Gen1 key: recover override / leave nil (ROM should own Johto).
    prose = Overrides[speciesId]
  end
  if not prose or prose == "" then return nil end

  local text, text2, pages = DexEntries.wrapGen2(prose)
  local ft = entry.heightFt or 0
  local inch = entry.heightIn or 0
  ensureWeightTenths(entry)
  return {
    id = speciesId,
    dex = record.dex or 0,
    kind = gen2Kind(entry.kind),
    height = ft * 100 + inch,
    weight = entry.weight or 0,
    text = text,
    text2 = text2 or "",
    pages = pages,
  }
end

-- Fill missing Gold dex rows (Hoenn / any KR species absent from the ROM sheet).
-- Does NOT append Gen3 onto newOrder — JohtoDex.rebuildOrders owns NEW / A-Z
-- from live Johto availability after spawn tables apply.
function DexEntries.bindGen2Pokedex(mod, speciesTable)
  local JohtoDex = require("mods.Kanto-Reforged.pokemon.johto_dex")
  local data = JohtoDex._liveData(mod)
  local ok, Data = pcall(require, "src.core.Data")
  if not data then
    if not ok or not Data then return 0 end
    data = Data
  end
  data.gen2Pokedex = data.gen2Pokedex or {}
  local dex = data.gen2Pokedex
  dex.entries = dex.entries or {}
  dex.newOrder = dex.newOrder or {}
  dex.alphabeticalOrder = dex.alphabeticalOrder or {}
  -- Freeze ROM Johto order before any later rebuild mutates newOrder.
  JohtoDex.snapshotVanillaNewOrder(mod)

  local n = 0
  for id, record in pairs(speciesTable or {}) do
    if not dex.entries[id] then
      local row = DexEntries.toGen2Entry(id, record)
      if row then
        dex.entries[id] = row
        n = n + 1
      end
    end
  end

  if ok and Data and Data ~= data then
    Data.gen2Pokedex = dex
  end

  if mod and mod.log and n > 0 then
    mod.log:info("Gold Pokédex: filled %d missing entries (Gen3+)", n)
  end
  return n
end

-- Safety net: DexEntryMenu looks up game.data.text[e.text]. Recover inline
-- prose and missing key bodies so owned entries never fall through to
-- "Data unknown."
function DexEntries.installInlineTextFallback(mod)
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local ok, DEM = pcall(require, "src.ui.DexEntryMenu")
  if not ok or not DEM or DEM._krInlineText then return end
  Gen1Patch.apply(DEM, function(DexEntryMenu)
    if DexEntryMenu._krInlineText then return end
    local orig = DexEntryMenu.render
    if type(orig) ~= "function" then return end
    DexEntryMenu.render = function(game, def, sprite, forceOwned, trueColor, page, ...)
      DexEntries.ensureDexText(game, def)
      return orig(game, def, sprite, forceOwned, trueColor, page, ...)
    end
    local origNew = DexEntryMenu.new
    if type(origNew) == "function" then
      DexEntryMenu.new = function(game, speciesOrOpts, onDone)
        local species = speciesOrOpts
        if type(speciesOrOpts) == "table" then
          species = speciesOrOpts.species or speciesOrOpts.id
        end
        local def = game and game.data and game.data.pokemon
          and species and game.data.pokemon[species]
        DexEntries.ensureDexText(game, def)
        return origNew(game, speciesOrOpts, onDone)
      end
    end
    DexEntryMenu._krInlineText = true
  end)
  if mod and mod.log then
    mod.log:info("Dex entries: Gen1 text resolve fallback for DexEntryMenu")
  end
end

-- NewPokedexEntry opens on entrySpecies, but rebuild() only lists the current
-- mode order. Hoenn (and other KR fills) are often absent from NEW/A–Z — land
-- on OLD (national) so the catch popup still shows the entry.
function DexEntries.installGen2CatchEntryFix(mod)
  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  local ok, PM = pcall(require, "src.ui.gen2.PokedexMenu")
  if not ok or not PM or PM._krCatchEntry then return end
  Gen1Patch.apply(PM, function(PokedexMenu)
    if PokedexMenu._krCatchEntry then return end
    local origNew = PokedexMenu.new
    if type(origNew) ~= "function" then return end
    PokedexMenu.new = function(game, opts)
      local self = origNew(game, opts)
      opts = opts or {}
      local species = opts.entrySpecies
      if not species or self.view == "entry" then
        return self
      end
      for i, name in ipairs(PokedexMenu.MODES or { "NEW", "OLD", "A-Z" }) do
        if name == "OLD" then
          self.modeIndex = i
          break
        end
      end
      self:rebuild()
      for index, row in ipairs(self.rows or {}) do
        if row.species == species then
          self.index = index
          self.view = "entry"
          self.page = 1
          if self.ensureVisible then self:ensureVisible() end
          if opts.newEntry then
            self.newEntry = true
            if self.playCry then pcall(function() self:playCry(species) end) end
          end
          break
        end
      end
      return self
    end

    local origUpdate = PokedexMenu.update
    if type(origUpdate) == "function" then
      PokedexMenu.update = function(self, dt)
        if self.view == "entry" then
          local row = self.current and self:current()
          local entry = row and self.dex and self.dex.entries and self.dex.entries[row.species]
          local pageCount = (entry and entry.pages and #entry.pages) or (entry and entry.text2 and 2 or 1)
          local input = self.game and self.game.input
          if self.newEntry and input and (input:wasPressed("a") or input:wasPressed("b")) then
            if self.page < pageCount then
              self.page = self.page + 1
              return
            else
              self:close()
              return
            end
          end
          if not self.newEntry and input and input:wasPressed("a") then
            local ENTRY_ACTIONS = { "PAGE", "AREA", "CRY", "PRNT" }
            local action = ENTRY_ACTIONS[self.entryAction or 1]
            if action == "PAGE" and pageCount > 1 then
              self.page = (self.page % pageCount) + 1
              return
            end
          end
        end
        return origUpdate(self, dt)
      end
    end

    local origDrawBody = PokedexMenu.drawEntryBody
    if type(origDrawBody) == "function" then
      PokedexMenu.drawEntryBody = function(self, row, entry)
        if entry and entry.pages and entry.pages[self.page] then
          local savedText = entry.text
          local savedText2 = entry.text2
          if self.page == 1 then
            entry.text = entry.pages[1]
          else
            entry.text2 = entry.pages[self.page]
          end
          local ok, err = pcall(origDrawBody, self, row, entry)
          entry.text = savedText
          entry.text2 = savedText2
          if not ok then error(err, 0) end
          return
        end
        return origDrawBody(self, row, entry)
      end
    end

    PokedexMenu._krCatchEntry = true
  end)
  -- Re-bind dex sync AFTER this wrap so rebuild/totals still force party
  -- backfill (this file's new() calls rebuild() after construction).
  local SpeciesScope = require("mods.Kanto-Reforged.pokemon.species_scope")
  SpeciesScope.ensureGen2PokedexSync(mod)
  if mod and mod.log then
    mod.log:info("Dex entries: Gen2 multi-page and NewPokedexEntry fallback installed")
  end
end

return DexEntries
