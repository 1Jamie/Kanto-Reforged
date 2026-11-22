-- luajit mods/Kanto-Reforged/tests/old_man_tutorial_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local OldManTutorial = require("mods.Kanto-Reforged.world.old_man_tutorial")

local function tutorialScript()
  return {
    { op = "loadword", value = "g3:lecture" },
    { op = "callstd", std = 4 },
    { op = "closemessage" },
    { op = "special", id = 391 },
    { op = "compare_var_to_value", var = 32781, value = 2 },
    { op = "goto_if", cond = 1, target = "g3:quest_log_abort" },
    { op = "special", id = 392 },
    { op = "special", id = 157 },
    { op = "waitstate" },
    { op = "lock" },
    { op = "faceplayer" },
    { op = "loadword", value = "g3:educational" },
    { op = "callstd", std = 4 },
    { op = "setvar", var = 16465, value = 2 },
    { op = "callstd", std = 0 },
    { op = "return" },
  }
end

local scripts = { ["g3:tutorial"] = tutorialScript() }
T.check(OldManTutorial.patchScripts(scripts), "patches the tutorial script")
T.check(OldManTutorial.patchScripts(scripts), "second patch is a no-op success")

local list = scripts["g3:tutorial"]
local askAt
for i, row in ipairs(list) do
  if row.op == "loadword" and row.value == OldManTutorial.ASK_TEXT then
    askAt = i
  end
end
T.check(askAt ~= nil, "yes/no prompt is in the tutorial")
T.eq(list[askAt + 1].op, "callstd", "prompt uses the yes/no std")
T.eq(list[askAt + 1].std, 5, "std 5 is MSGBOX_YESNO")
T.eq(list[askAt + 3].op, "goto_if", "NO branches out")
T.eq(list[askAt + 3].target, OldManTutorial.AFTER_KEY, "NO goes to the gift")
T.eq(list[askAt - 1].op, "goto_if", "quest-log skip stays ahead of the question")
T.check(list[askAt + 4].op == "special" and list[askAt + 4].id == 392,
  "YES still cuts the quest log and starts the battle")

local tail = scripts[OldManTutorial.AFTER_KEY]
T.eq(tail[1].op, "lock", "skip tail still locks")
T.eq(tail[3].value, OldManTutorial.SKIP_TEXT, "skip line replaces the lesson recap")
local hasSetvar = false
for _, row in ipairs(tail) do
  if row.op == "setvar" and row.var == 16465 and row.value == 2 then
    hasSetvar = true
  end
end
T.check(hasSetvar, "skip still advances the old man's scene")
T.eq(tail[#tail].op, "return", "skip returns to the caller")

local recap
for i = askAt, #list do
  if list[i].op == "loadword" and list[i].value == "g3:educational" then
    recap = list[i]
  end
end
T.check(recap ~= nil, "YES path still recaps the lesson")

T.finish("old_man_tutorial")
