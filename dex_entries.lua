-- Pokédex flavor text bridge for expansion species.
--
-- Vanilla stores dexEntry.text as a key into Data.text (e.g. "_BulbasaurDexEntry").
-- The generator embeds PokéAPI paragraphs inline, so DexEntryMenu's
-- `game.data.text[e.text]` lookup fails → "Data unknown."
--
-- At load we:
--   1. Prefer Gen 1–length customs from dex_text_overrides.lua
--   2. Soft-wrap to ~18 cols / 6 lines (Gen 1 dex box)
--   3. Register into Data.text and point dexEntry.text at the key

local DexEntries = {}

local COLS = 18
local MAX_LINES = 6

local Overrides = require("mods.expansion_pack.dex_text_overrides")

local function isTextKey(s)
  return type(s) == "string" and s:match("^_[%w_]+$") ~= nil
end

-- Soft-wrap like Gen 1 dex pages (~18 cols, \n between lines, \f every 3).
-- Hard-capped at MAX_LINES so nothing overflows DexEntryMenu (y 72..122).
function DexEntries.wrap(text, cols, maxLines)
  cols = cols or COLS
  maxLines = maxLines or MAX_LINES
  if type(text) ~= "string" or text == "" then return "" end

  local source = text
  if text:find("\n", 1, true) or text:find("\f", 1, true) then
    source = text:gsub("[\n\f\v]", " ")
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
  return nil
end

-- Rewrite one species record in place; register the body on mod.content.text.
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
  mod.content.text:register(key, body)
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

return DexEntries
