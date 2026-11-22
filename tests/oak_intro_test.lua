-- luajit mods/Kanto-Reforged/tests/oak_intro_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Host = require("mods.Kanto-Reforged.core.host")
local OakIntro = require("mods.Kanto-Reforged.world.oak_intro")

local function ball(index, player, rival, obj)
  return {
    { op = "lock" },
    { op = "faceplayer" },
    { op = "setvar", var = 16385, value = index, [2] = index },
    { op = "setvar", var = 16386, value = player, [2] = player },
    { op = "setvar", var = 16387, value = rival, [2] = rival },
    { op = "setvar", var = 16388, value = obj, [2] = obj },
  }
end

local function flat(entry)
  local parts = {}
  for _, row in ipairs(entry) do
    if type(row.s) == "string" then parts[#parts + 1] = row.s end
  end
  return table.concat(parts)
end

local qs = OakIntro.questions()
T.eq(#qs, 4, "four oak questions")
T.eq(qs[1].id, "random_starters", "starters first")
T.eq(qs[2].id, "full_mix", "spawn mix second")
T.eq(qs[3].id, "curated", "curated mix follows a yes on the mix")
T.eq(qs[4].id, "legends", "legendaries follow the mix too")
T.check(qs[3].when({}) ~= true, "curated waits until the mix is accepted")
T.check(qs[3].when({ full_mix = false }) ~= true, "no on the mix skips the curated question")
T.check(qs[3].when({ full_mix = true }) == true, "yes on the mix asks about a curated mix")
T.check(qs[4].when({ full_mix = false }) ~= true, "no on the mix skips legends")
T.check(qs[4].when({ full_mix = true }) == true, "yes on the mix asks about legends")

local seq = { 4, 4, 7, 1 }
local n = 0
local rolled = OakIntro.rollSlots(function()
  n = n + 1
  return seq[n] or 25
end, function(id) return id == 1 or id == 4 or id == 7 end)
T.eq(rolled[1], 4, "first distinct starter")
T.eq(rolled[2], 7, "duplicate roll is skipped")
T.eq(rolled[3], 1, "third starter")

local gapCalls = 0
local gapSeq = { 270, 252, 276, 411, 295, 1 }
local full = OakIntro.rollSlots(function()
  gapCalls = gapCalls + 1
  return gapSeq[gapCalls]
end)
T.eq(full[1], 411, "the old unown slots are rolled again")
T.eq(full[2], 295, "lotad's real species id is kept")
T.eq(full[3], 1, "the roll uses the full species list")

local slots = { 25, 52, 133 }
local scripts = {
  a = ball(0, 1, 4, 7),
  b = ball(1, 7, 1, 5),
  c = ball(2, 4, 7, 6),
  confirm = {
    { op = "loadword", value = "g3:bulba", [2] = "g3:bulba" },
    { op = "callstd", std = 5 },
  },
}
local text = {
  ["g3:bulba"] = {
    { t = "text", s = "I see! BULBASAUR is your choice." },
    { t = "eos" },
  },
}

T.check(OakIntro.patchLab(scripts, text, slots), "lab scripts take the rolled starters")
T.eq(scripts.a[4].value, 25, "left ball shows the first roll")
T.eq(scripts.a[4][2], 25, "setvar operand matches")
T.eq(scripts.a[5].value, 133, "rival of the left ball is the third roll")
T.eq(scripts.b[4].value, 52, "middle ball shows the second roll")
T.eq(scripts.b[5].value, 25, "rival of the middle ball is the first roll")
T.eq(scripts.c[4].value, 133, "right ball shows the third roll")
T.eq(scripts.c[5].value, 52, "rival of the right ball is the second roll")
T.eq(scripts.a[6].value, 7, "ball object id stays put")
T.eq(scripts.confirm[1].op, "bufferspeciesname", "oak names the rolled species")
T.eq(scripts.confirm[1][2], 16386, "the name comes from the ball's species var")
T.eq(text["g3:bulba"][2].t, "strvar", "choice line uses the buffered name")
T.check(OakIntro.patchLab(scripts, text, slots), "a second patch does not stack the buffer")
T.eq(scripts.confirm[1].op, "bufferspeciesname", "buffer stays a single row")
T.eq(scripts.confirm[2].op, "loadword", "the question still follows the name")

T.check(OakIntro.patchLab(scripts, text, nil), "turning the roll off restores the lab")
T.eq(scripts.a[4].value, 1, "left ball is Bulbasaur again")
T.eq(scripts.a[5].value, 4, "left rival is Charmander again")
T.eq(scripts.b[4].value, 7, "middle ball is Squirtle again")
T.eq(scripts.c[4].value, 4, "right ball is Charmander again")
T.eq(scripts.a[6].value, 7, "object id still untouched")
T.eq(scripts.confirm[1].op, "loadword", "species buffer is removed")
T.check(flat(text["g3:bulba"]):find("BULBASAUR", 1, true) ~= nil, "oak names Bulbasaur again")

local party = {
  { species = "CHARMANDER", speciesId = 4, level = 5 },
  { species = "PIDGEY", speciesId = 16, level = 5 },
  { species = "CHARMELEON", speciesId = 5, level = 16 },
}
local function nextOf(id)
  if id == 133 then return 134 end
  if id == 134 then return 135 end
  return nil
end
local rival = OakIntro.remapRivalParty(party, 328, slots, nextOf)
T.eq(rival[1].species, 133, "lab rival's starter is the rolled counter")
T.eq(rival[1].speciesId, 133, "species id follows the roll")
T.eq(rival[2].speciesId, 16, "the rest of the party stays")
T.eq(rival[3].species, 134, "later rival keeps the evolution stage")
T.eq(party[1].species, "CHARMANDER", "the vanilla party table is left alone")
local squirtleRival = OakIntro.remapRivalParty(
  { { species = "SQUIRTLE", speciesId = 7 } }, 326, slots, nextOf)
T.eq(squirtleRival[1].species, 52, "squirtle-line rival uses the middle roll")
local other = OakIntro.remapRivalParty(party, 12, slots, nextOf)
T.eq(other[1].species, "CHARMANDER", "other trainers are not remapped")

Host.force(3)
local bucket = {}
local saved = {}
local handlers = {}
local mod = {
  id = "Kanto-Reforged",
  _loader = { modOptions = {}, generation = 3 },
  options = { get = function(_, key) return bucket[key] end },
  save = {
    get = function(_, key, default)
      if saved[key] == nil then return default end
      return saved[key]
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  events = { on = function(_, name, fn) handlers[name] = fn end },
  hooks = { wrap = function() end },
}
mod._loader.modOptions[mod.id] = bucket

local mode, legends = OakIntro.commitSpawn(mod, true, false)
T.eq(mode, "full_random", "yes on the mix turns full spawn on")
T.eq(legends, false, "legends stay off until that question is yes")
T.eq(bucket["g3:full_spawn_random"], true, "full mix option is stored")
T.eq(bucket["g3:legends_in_mix"], false, "legends option is stored off")
mode, legends = OakIntro.commitSpawn(mod, true, true)
T.eq(legends, true, "yes on legends includes them")
T.eq(bucket["g3:legends_in_mix"], true, "legends option is stored on")
mode, legends = OakIntro.commitSpawn(mod, false, false)
T.eq(mode, "curated", "no on the mix leaves the vanilla tables")
T.eq(bucket["g3:full_spawn_random"], false, "full mix option is cleared")
T.eq(bucket["g3:legends_in_mix"], false, "declining the mix clears legends")

bucket["g3:pure_spawn_random"] = true
bucket["g3:legends_in_mix"] = true
mode, legends = OakIntro.commitSpawn(mod, false, false)
T.eq(mode, "pure_random", "pure random still overrides a declined full mix")
T.eq(legends, true, "declining full mix does not clear legends while pure is on")
T.eq(bucket["g3:legends_in_mix"], true, "pure legends option stays")
bucket["g3:pure_spawn_random"] = nil

OakIntro.install(mod)
local speech = {}
handlers["intro.oak_speech.started"]({ speech = speech })
T.eq(#speech.exitQuestions, 4, "oak speech receives the questions")
T.check(type(speech.exitIntro) == "string" and speech.exitIntro:find("few questions", 1, true) ~= nil,
  "oak speaks before the first question")
local heard = speech.exitConfirm({ random_starters = true, full_mix = true, curated = true, legends = true })
T.check(heard:find("surprise", 1, true) ~= nil, "the recap names randomized starters")
T.check(heard:find("curated mix", 1, true) ~= nil, "the recap names a curated mix")
T.check(heard:find("legendaries included", 1, true) ~= nil, "the recap names legendaries in the mix")
local pureHeard = speech.exitConfirm({ full_mix = true, curated = false, legends = false })
T.check(pureHeard:find("fully random", 1, true) ~= nil, "the recap names a fully random mix")
T.check(pureHeard:find("no legendaries", 1, true) ~= nil, "the recap names legendaries left out")
T.check(heard:find("adventure you want", 1, true) ~= nil, "oak asks them to confirm")
local plain = speech.exitConfirm({ random_starters = false, full_mix = false })
T.check(plain:find("usual three", 1, true) ~= nil, "the recap names the usual starters")
T.check(plain:find("stay as they are", 1, true) ~= nil, "the recap names ordinary spawns")
T.check(plain:find("legendaries", 1, true) == nil, "ordinary spawns skip the legendary line")
handlers["intro.oak_speech.answered"]({ label = "random_starters", value = true })
OakIntro.flushPending(mod)
T.eq(saved.g3_random_starters, true, "yes on starters is saved with the new game")
T.eq(#saved.g3_starter_slots, 3, "three species are saved")
handlers["intro.oak_speech.answered"]({ label = "random_starters", value = false })
OakIntro.flushPending(mod)
T.eq(saved.g3_random_starters, false, "no on starters clears the roll")

local EncountersGame3 = require("mods.Kanto-Reforged.world.encounters_game3")
local mixed = EncountersGame3.getTableForMap("3:19", "full_random", { legends = true })
local legendIds = {
  [144] = true, [145] = true, [146] = true, [150] = true, [151] = true,
  [243] = true, [244] = true, [245] = true, [249] = true, [250] = true, [251] = true,
  [402] = true, [403] = true, [404] = true, [405] = true, [406] = true,
  [407] = true, [408] = true, [409] = true, [410] = true, [411] = true,
}
T.check(legendIds[mixed.land.slots[4].species], "full mix with legends puts one in the table")
local plain = EncountersGame3.getTableForMap("3:19", "full_random", { legends = false })
T.check(not legendIds[plain.land.slots[4].species], "full mix without legends keeps that slot ordinary")

OakIntro.clearPreview()
OakIntro.onScriptCommand({
  runner = { store = { vars = { [16386] = 25 } }, ctx = {} },
}, "showmonpic", { 16386, 10, 3 })
T.eq(OakIntro.preview and OakIntro.preview.speciesId, 25, "lab picture records the offered species")
T.check(type(OakIntro.preview.name) == "string" and OakIntro.preview.name ~= "", "preview carries a name")
OakIntro.onScriptCommand(nil, "showmonpic", { 1, 10, 3 })
T.eq(OakIntro.preview.speciesId, 25, "other pictures leave the lab preview")
OakIntro.onScriptCommand(nil, "hidemonpic", {})
T.eq(OakIntro.preview, nil, "hiding the picture clears the preview")

Host.clearForce()
T.finish("oak_intro")
