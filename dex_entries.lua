-- Pokédex flavor text bridge for Kanto Reforged species.
--
-- Gen1: DexEntryMenu looks up `game.data.text[dexEntry.text]`. The generator
-- embeds PokéAPI paragraphs inline, so a bare prose string → "Data unknown."
-- We wrap to Gen1 length, register a `_EXP_*_DexEntry` key, and dual-write
-- into Data.text (content registry alone can miss when routed / frozen).
--
-- Gen2: Gold's PokedexMenu reads `Data.gen2Pokedex.entries[species]` with
-- inline `text` / `text2` (`<NEXT>` line breaks). Hoenn species are absent
-- from the ROM sheet — we fill those rows (and append them to the orders).

local DexEntries = {}

local COLS = 18
local MAX_LINES = 6

local Overrides = require("mods.Kanto-Reforged.dex_text_overrides")

local function isTextKey(s)
  return type(s) == "string" and s:match("^_[%w_]+$") ~= nil
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

-- Soft-wrap like Gen 1 dex pages (~18 cols, \n between lines, \f every 3).
-- Hard-capped at MAX_LINES so nothing overflows DexEntryMenu (y 72..122).
function DexEntries.wrap(text, cols, maxLines)
  local lines = softLines(text, cols, maxLines)
  local chunks = {}
  for i, L in ipairs(lines) do
    chunks[#chunks + 1] = L
    if i < #lines then
      if i % 3 == 0 then
        chunks[#chunks + 1] = "\f"
      else
        chunks[#chunks + 1] = "\n"
      end
    end
  end
  return table.concat(chunks)
end

-- Gen2 entry pages: two pages of three `<NEXT>`-joined lines (~18 cols).
function DexEntries.wrapGen2(text, cols)
  local lines = softLines(text, cols or COLS, 6)
  local function page(from, to)
    local parts = {}
    for i = from, to do
      if lines[i] then parts[#parts + 1] = lines[i] end
    end
    return table.concat(parts, "<NEXT>")
  end
  return page(1, 3), page(4, 6)
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

  local prose = DexEntries.sourceText(speciesId, entry)
  if not prose or prose == "" then
    -- Already a key with no override; leave alone.
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

  local text, text2 = DexEntries.wrapGen2(prose)
  local ft = entry.heightFt or 0
  local inch = entry.heightIn or 0
  return {
    id = speciesId,
    dex = record.dex or 0,
    kind = gen2Kind(entry.kind),
    height = ft * 100 + inch,
    weight = entry.weight or 0,
    text = text,
    text2 = text2 or "",
  }
end

local function listHas(list, id)
  for _, s in ipairs(list or {}) do
    if s == id then return true end
  end
  return false
end

-- Fill missing Gold dex rows (Hoenn / any KR species absent from the ROM sheet).
function DexEntries.bindGen2Pokedex(mod, speciesTable)
  local ok, Data = pcall(require, "src.core.Data")
  if not ok or not Data then return 0 end
  Data.gen2Pokedex = Data.gen2Pokedex or {}
  local dex = Data.gen2Pokedex
  dex.entries = dex.entries or {}
  dex.newOrder = dex.newOrder or {}
  dex.alphabeticalOrder = dex.alphabeticalOrder or {}

  local added = {}
  local n = 0
  for id, record in pairs(speciesTable or {}) do
    if not dex.entries[id] then
      local row = DexEntries.toGen2Entry(id, record)
      if row then
        dex.entries[id] = row
        added[#added + 1] = { id = id, dex = row.dex or 0, name = record.name or id }
        n = n + 1
      end
    end
  end

  table.sort(added, function(a, b)
    if a.dex ~= b.dex then return a.dex < b.dex end
    return a.id < b.id
  end)
  for _, row in ipairs(added) do
    if not listHas(dex.newOrder, row.id) then
      dex.newOrder[#dex.newOrder + 1] = row.id
    end
  end

  table.sort(added, function(a, b)
    return tostring(a.name) < tostring(b.name)
  end)
  for _, row in ipairs(added) do
    if not listHas(dex.alphabeticalOrder, row.id) then
      dex.alphabeticalOrder[#dex.alphabeticalOrder + 1] = row.id
    end
  end

  if mod and mod.log and n > 0 then
    mod.log:info("Gold Pokédex: filled %d missing entries (Gen3+)", n)
  end
  return n
end

return DexEntries
