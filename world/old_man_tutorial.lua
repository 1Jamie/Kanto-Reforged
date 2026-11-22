-- FRLG Viridian old man catch lesson.
-- Vanilla always starts the Weedle battle after the coffee speech.
-- Ask first. No skips the battle and still gives the Teachy TV so the
-- scene var advances and he stops blocking the road.
local Host = require("mods.Kanto-Reforged.core.host")

local OldManTutorial = {}

OldManTutorial.ASK_TEXT = "kr:old_man_catch_ask"
OldManTutorial.SKIP_TEXT = "kr:old_man_catch_skip"
OldManTutorial.AFTER_KEY = "kr:old_man_catch_after"
-- VAR_RESULT. yesnobox writes 1 for YES and 0 for NO.
local VAR_RESULT = 32781
local TUTORIAL_SPECIAL = 157
local QUEST_LOG_CUT = 392

local function specialId(row)
  return row and row.op == "special" and (row.id or row[1]) or nil
end

local function findTutorial(scripts)
  for key, list in pairs(scripts) do
    if type(list) == "table" and key ~= OldManTutorial.AFTER_KEY then
      for _, row in ipairs(list) do
        if specialId(row) == TUTORIAL_SPECIAL then
          return key, list
        end
      end
    end
  end
  return nil
end

local function askRows()
  return {
    {
      op = "loadword", dest = 0,
      value = OldManTutorial.ASK_TEXT,
      [1] = 0, [2] = OldManTutorial.ASK_TEXT,
    },
    { op = "callstd", std = 5, [1] = 5 },
    {
      op = "compare_var_to_value",
      var = VAR_RESULT, value = 0,
      [1] = VAR_RESULT, [2] = 0,
    },
    {
      op = "goto_if", cond = 1,
      target = OldManTutorial.AFTER_KEY,
      [1] = 1, [2] = OldManTutorial.AFTER_KEY,
    },
  }
end

--- Splice the yes/no into the live FRLG script table. Idempotent.
-- Returns true when the tutorial script now asks.
function OldManTutorial.patchScripts(scripts)
  if type(scripts) ~= "table" then return false end
  if scripts[OldManTutorial.AFTER_KEY] then return true end
  local _, list = findTutorial(scripts)
  if not list or list._krOldManSkip then return false end

  local battleAt
  for i, row in ipairs(list) do
    if specialId(row) == TUTORIAL_SPECIAL then
      battleAt = i
      break
    end
  end
  if not battleAt then return false end

  local tailAt
  for i = battleAt + 1, #list do
    if list[i].op == "lock" then
      tailAt = i
      break
    end
  end
  if not tailAt then return false end

  -- Tail is the post-battle gift. On No, swap the "that was educational"
  -- line for the skip line and keep the item, the scene var, and the return.
  local tail = {}
  for i = tailAt, #list do
    local row = list[i]
    if row.op == "loadword" and not tail._krSwappedLine then
      row = {
        op = "loadword", dest = row.dest or 0,
        value = OldManTutorial.SKIP_TEXT,
        [1] = 0, [2] = OldManTutorial.SKIP_TEXT,
      }
      tail._krSwappedLine = true
    end
    tail[#tail + 1] = row
  end
  tail._krSwappedLine = nil
  scripts[OldManTutorial.AFTER_KEY] = tail

  local insertAt = battleAt
  if specialId(list[battleAt - 1]) == QUEST_LOG_CUT then
    insertAt = battleAt - 1
  end
  local ask = askRows()
  for n = #ask, 1, -1 do
    table.insert(list, insertAt, ask[n])
  end
  list._krOldManSkip = true
  return true
end

function OldManTutorial.install(mod)
  if not Host.isGen3From(mod) and not Host.isGen3() then return end
  mod.content.text:register(OldManTutorial.ASK_TEXT,
    "Would you like me to show you\nhow to catch a POKéMON?")
  mod.content.text:register(OldManTutorial.SKIP_TEXT,
    "That's all right.\nTake this, then.")

  local function patch()
    local Space = package.loaded["src.core.game3.scripting.space"]
    local bundle = Space and Space.bundle
    if bundle and bundle.scripts then
      OldManTutorial.patchScripts(bundle.scripts)
    end
    local game = Host.liveGame(mod)
    local scripts = game and game.data and game.data.gen3Scripts
    if scripts and scripts ~= (bundle and bundle.scripts) then
      OldManTutorial.patchScripts(scripts)
    end
  end

  patch()
  if mod.events and mod.events.on then
    mod.events:on("game.ready", patch)
  end
end

return OldManTutorial
