-- Unified cross-generational dialogue and text layout engine for Kanto-Reforged.
-- Handles generational column budgets, multi-byte UTF-8 glyph counting (♂, ♀, é),
-- word wrapping, and authentic Game Boy control codes (\n for line 2, \v for scroll, \f for page break).

local Dialogue = {}

-- Visual glyph width counter (UTF-8 multi-byte sequence aware).
-- Single-tile Game Boy glyphs (♂ \u2642, ♀ \u2640, é \u00E9, etc.) must count as 1 character width.
function Dialogue.glyphLen(str)
  if type(str) ~= "string" then return 0 end
  local len = 0
  local i = 1
  local n = #str
  while i <= n do
    local b = str:byte(i)
    if b < 0x80 then
      len = len + 1
      i = i + 1
    elseif b >= 0xC0 and b <= 0xDF then
      len = len + 1
      i = i + 2
    elseif b >= 0xE0 and b <= 0xEF then
      len = len + 1
      i = i + 3
    elseif b >= 0xF0 and b <= 0xF7 then
      len = len + 1
      i = i + 4
    else
      len = len + 1
      i = i + 1
    end
  end
  return len
end

Dialogue.PRESETS = {
  -- Battle text box: 17 columns (column 18 reserved for prompt arrow ▼ on line 2),
  -- 2 lines per page. Line 2 uses \n, lines 3+ use \v (vertical scroll).
  battle = {
    maxCols = 17,
    maxLinesPerPage = 2,
    line2Sep = "\n",
    overflowSep = "\v",
  },
  -- Overworld message window: 18 columns, 2 visible lines per page, \f on page break.
  overworld = {
    maxCols = 18,
    maxLinesPerPage = 2,
    line2Sep = "\n",
    overflowSep = "\f",
  },
  -- Summary / Ability description pages: 18 columns, static \n breaks.
  summary = {
    maxCols = 18,
    maxLinesPerPage = 4,
    line2Sep = "\n",
    overflowSep = "\n",
  },
  -- Signposts / Trainer intros: 18 columns.
  signpost = {
    maxCols = 18,
    maxLinesPerPage = 2,
    line2Sep = "\n",
    overflowSep = "\f",
  },
  -- Pokédex entry pages: 18 columns, 3 lines per page, \f on page break.
  dex = {
    maxCols = 18,
    maxLinesPerPage = 3,
    line2Sep = "\n",
    overflowSep = "\f",
  },
}

-- Format dialogue according to the target surface preset.
function Dialogue.format(preset, template, ...)
  if type(template) ~= "string" then return tostring(template or "") end

  local cfg = Dialogue.PRESETS[preset] or Dialogue.PRESETS.battle
  if type(preset) == "table" then cfg = preset end

  local maxCols = cfg.maxCols or 17
  local maxLinesPerPage = cfg.maxLinesPerPage or 2
  local line2Sep = cfg.line2Sep or "\n"
  local overflowSep = cfg.overflowSep or "\v"

  -- Safely interpolate arguments if provided
  local text = template
  if select("#", ...) > 0 then
    local ok, formatted = pcall(string.format, template, ...)
    if ok and formatted then
      text = formatted
    end
  end

  -- Normalize escape sequences
  local s = text:gsub("\\f", "\f"):gsub("\\n", "\n"):gsub("\\v", "\v")

  -- Split into pages by \f
  local rawPages = {}
  local last = 1
  for p, e in s:gmatch("()\f()") do
    table.insert(rawPages, s:sub(last, p - 1))
    last = e
  end
  table.insert(rawPages, s:sub(last))

  local formattedPages = {}
  for _, rawPage in ipairs(rawPages) do
    -- Split page by explicit line breaks (\n or \v)
    local rawLines = {}
    local lineLast = 1
    for p, e in rawPage:gmatch("()[\n\v]()") do
      table.insert(rawLines, rawPage:sub(lineLast, p - 1))
      lineLast = e
    end
    table.insert(rawLines, rawPage:sub(lineLast))

    -- Word-wrap lines exceeding maxCols using glyphLen
    local wrappedLines = {}
    for _, rawLine in ipairs(rawLines) do
      if Dialogue.glyphLen(rawLine) <= maxCols then
        table.insert(wrappedLines, rawLine)
      else
        local curLine = ""
        for w in rawLine:gmatch("%S+") do
          if curLine == "" then
            curLine = w
          elseif Dialogue.glyphLen(curLine) + 1 + Dialogue.glyphLen(w) <= maxCols then
            curLine = curLine .. " " .. w
          else
            table.insert(wrappedLines, curLine)
            curLine = w
          end
        end
        if curLine ~= "" then
          table.insert(wrappedLines, curLine)
        end
      end
    end

    -- Assemble lines using appropriate delimiters
    local pageOut = ""
    if overflowSep == "\f" then
      local subPages = {}
      local curSubPage = {}
      for _, l in ipairs(wrappedLines) do
        table.insert(curSubPage, l)
        if #curSubPage >= maxLinesPerPage then
          table.insert(subPages, table.concat(curSubPage, line2Sep))
          curSubPage = {}
        end
      end
      if #curSubPage > 0 then
        table.insert(subPages, table.concat(curSubPage, line2Sep))
      end
      pageOut = table.concat(subPages, "\f")
    else
      for lineIdx, l in ipairs(wrappedLines) do
        if lineIdx == 1 then
          pageOut = l
        elseif lineIdx <= maxLinesPerPage then
          pageOut = pageOut .. line2Sep .. l
        else
          pageOut = pageOut .. overflowSep .. l
        end
      end
    end
    table.insert(formattedPages, pageOut)
  end

  return table.concat(formattedPages, "\f")
end

-- Shorthand for battle messages
function Dialogue.battle(template, ...)
  return Dialogue.format("battle", template, ...)
end

-- Shorthand for overworld dialogues
function Dialogue.overworld(template, ...)
  return Dialogue.format("overworld", template, ...)
end

-- Shorthand for summary descriptions
function Dialogue.summary(template, ...)
  return Dialogue.format("summary", template, ...)
end

-- Shorthand for Pokédex descriptions (Gen 1 formatted string with \n and \f)
function Dialogue.dex(template, ...)
  return Dialogue.format("dex", template, ...)
end

-- Pokédex helper returning a list of pages, where each page is an array of lines
function Dialogue.dexPages(text, cols)
  local formatted = Dialogue.format({
    maxCols = cols or 18,
    maxLinesPerPage = 3,
    line2Sep = "\n",
    overflowSep = "\f",
  }, text)

  local pages = {}
  for p in (formatted .. "\f"):gmatch("([^\f]+)") do
    local lines = {}
    for l in (p .. "\n"):gmatch("([^\n]+)") do
      table.insert(lines, l)
    end
    if #lines > 0 then
      table.insert(pages, lines)
    end
  end
  return pages
end

-- Pokédex helper for Gen 2 returning a list of page strings joined by <NEXT>
function Dialogue.dexGen2(text, cols)
  local pages = Dialogue.dexPages(text, cols)
  local gen2Pages = {}
  for _, pageLines in ipairs(pages) do
    table.insert(gen2Pages, table.concat(pageLines, "<NEXT>"))
  end
  return gen2Pages
end

return Dialogue
