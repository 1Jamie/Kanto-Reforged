-- Gen2 battle text: flat engine strings are word-wrapped to 18 columns but
-- printMessage only draws two rows.  Long lines (trainer run refusal, etc.) need
-- \v scroll markers and showPages/nextPage, matching Gen1's ContText behavior.

local Gen2Dialogue = {}

local TEXT_WIDTH = 18
local TEXT_ROWS = 2

local function wrapLines(text)
  local Chrome = require("src.ui.gen2.Chrome")
  return Chrome.wrap(text, TEXT_WIDTH)
end

function Gen2Dialogue.needsScroll(text)
  if type(text) ~= "string" or text == "" then return false end
  if text:find("\v", 1, true) or text:find("\f", 1, true) then return true end
  return #wrapLines(text) > TEXT_ROWS
end

function Gen2Dialogue.prepare(text)
  if type(text) ~= "string" then return text end
  if text:find("\v", 1, true) or text:find("\f", 1, true) then return text end
  if not Gen2Dialogue.needsScroll(text) then return text end
  local Dialogue = require("mods.Kanto-Reforged.core.dialogue")
  return Dialogue.format({
    maxCols = TEXT_WIDTH,
    maxLinesPerPage = TEXT_ROWS,
    line2Sep = "\n",
    overflowSep = "\v",
  }, text)
end

local function hasScrollMarkers(text)
  return type(text) == "string"
    and (text:find("\v", 1, true) or text:find("\f", 1, true))
end

function Gen2Dialogue.install(_mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen2() then return end

  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  Gen1Patch.apply(require("src.ui.gen2.BattleState"), function(BS)
    if BS._krGen2Dialogue then return end

    local origAdvanceQueue = BS.advanceQueue
    BS.advanceQueue = function(self)
      local event = self.queue[1]
      local kind = event and event.kind
      if event and type(event.text) == "string" then
        event.text = Gen2Dialogue.prepare(event.text)
      end
      origAdvanceQueue(self)
      if self.message and not self.messagePages and hasScrollMarkers(self.message) then
        local timer = self.messageTimer
        self:showPages(self.message)
        if kind == "move" or kind == "level" then
          self.messageTimer = timer
        end
      end
    end

    local origPrintMessage = BS.printMessage
    BS.printMessage = function(self)
      if self.message and not self.messagePages and hasScrollMarkers(self.message) then
        self:showPages(self.message)
      end
      return origPrintMessage(self)
    end

    BS._krGen2Dialogue = true
  end)
end

return Gen2Dialogue
