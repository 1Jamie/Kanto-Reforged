-- FRLG Oak intro questions, asked before the shrink into the bedroom.
-- 1. randomize the three lab starters
-- 2. randomize wild spawns
-- 3. only after a yes on 2: curated mix, or fully random
-- 4. only after a yes on 2: legendaries in that mix
local Host = require("mods.Kanto-Reforged.core.host")

local OakIntro = {}

local SAVE_ON = "g3_random_starters"
local SAVE_SLOTS = "g3_starter_slots"

-- VAR_TEMP_1 .. VAR_TEMP_4 in the lab ball scripts.
local VAR_INDEX = 16385
local VAR_PLAYER = 16386
local VAR_RIVAL = 16387
local VAR_BALL = 16388

local VANILLA_PLAYER = { [0] = 1, 7, 4 }
local VANILLA_RIVAL = { [0] = 4, 1, 7 }

-- Rival trainer ids are grouped Squirtle, Bulbasaur, Charmander.
-- That name is the rival's starter, not the player's.
local RIVAL_LINE = {}
local function markLine(ids, line)
  for i = 1, #ids do RIVAL_LINE[ids[i]] = line end
end
markLine({ 326, 329, 332, 426, 429, 432, 435 }, "squirtle")
markLine({ 327, 330, 333, 427, 430, 433, 436 }, "bulbasaur")
markLine({ 328, 331, 334, 428, 431, 434, 437 }, "charmander")

local LINE_INDEX = { charmander = 0, bulbasaur = 1, squirtle = 2 }
local FAMILY = {
  bulbasaur = { [1] = true, [2] = true, [3] = true,
    BULBASAUR = true, IVYSAUR = true, VENUSAUR = true },
  charmander = { [4] = true, [5] = true, [6] = true,
    CHARMANDER = true, CHARMELEON = true, CHARIZARD = true },
  squirtle = { [7] = true, [8] = true, [9] = true,
    SQUIRTLE = true, WARTORTLE = true, BLASTOISE = true },
}
local STAGE = {
  [1] = 0, [2] = 1, [3] = 2,
  [4] = 0, [5] = 1, [6] = 2,
  [7] = 0, [8] = 1, [9] = 2,
  BULBASAUR = 0, IVYSAUR = 1, VENUSAUR = 2,
  CHARMANDER = 0, CHARMELEON = 1, CHARIZARD = 2,
  SQUIRTLE = 0, WARTORTLE = 1, BLASTOISE = 2,
}

local pending = nil
local textOriginal = {}
local knownChoiceKeys = {}

local function copyRows(rows)
  local out = {}
  for i, row in ipairs(rows) do
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    out[i] = copy
  end
  return out
end

function OakIntro.introLine()
  return "Now then!\\l"
    .. "I have a few questions for you.\\p"
    .. "Your answers will shape\\l"
    .. "the adventure ahead.\\p"
end

function OakIntro.questions()
  return {
    {
      id = "random_starters",
      text = "Randomize your starters for\\la unique experience?",
    },
    {
      id = "full_mix",
      text = "Randomize the wild\\lPOKéMON you run into?",
    },
    {
      id = "curated",
      text = "Would you like a curated\\lrandomized mix?",
      when = function(answers)
        return answers.full_mix == true
      end,
    },
    {
      id = "legends",
      text = "Add legendaries to\\lthe spawn mix?",
      when = function(answers)
        return answers.full_mix == true
      end,
    },
  }
end

function OakIntro.confirmText(answers)
  answers = type(answers) == "table" and answers or {}
  local starters = answers.random_starters
    and "Your starters will be a surprise.\\p"
    or "Your starters stay the usual three.\\p"
  local wild
  if answers.full_mix then
    local kind = answers.curated == false and "fully random" or "a curated mix"
    wild = answers.legends
      and ("Wild POKéMON: %s,\\lwith legendaries included.\\p"):format(kind)
      or ("Wild POKéMON: %s,\\lwith no legendaries.\\p"):format(kind)
  else
    wild = "Wild POKéMON stay as they are\\lin each area.\\p"
  end
  return "Let me be sure I heard you.\\l" .. starters .. wild
    .. "Is this the adventure you want?"
end

-- FRLG internal ids run through Chimecho (411). 252-276 are the old
-- Unown-letter slots; those forms live on species 201 now, and the slots
-- themselves are a "?" with no real sprite.
local SPECIES_MAX = 411
local GAP_LO, GAP_HI = 252, 276

local function isUnownGap(id)
  return id >= GAP_LO and id <= GAP_HI
end

function OakIntro.rollSlots(rng, valid)
  -- math.random starts from a fixed seed, so a fresh game always drew the
  -- same three species. love.math is seeded from the system.
  rng = rng or function(a, b)
    if love and love.math and love.math.random then
      return love.math.random(a, b)
    end
    return math.random(a, b)
  end
  valid = valid or function(id) return id >= 1 and id <= SPECIES_MAX end
  local picked = {}
  local slots = {}
  local guard = 0
  while #slots < 3 and guard < 2000 do
    guard = guard + 1
    local id = tonumber(rng(1, SPECIES_MAX))
    if id and not isUnownGap(id) and not picked[id] and valid(id) then
      picked[id] = true
      slots[#slots + 1] = id
    end
  end
  return slots
end

function OakIntro.playerSpecies(slots, index)
  return slots and slots[index + 1]
end

function OakIntro.rivalSpecies(slots, index)
  if not slots then return nil end
  return slots[((index + 2) % 3) + 1]
end

function OakIntro.atStage(base, stage, nextOf)
  local cur = tonumber(base)
  if not cur then return base end
  stage = tonumber(stage) or 0
  nextOf = nextOf or OakIntro.nextEvo
  for _ = 1, stage do
    local nxt = tonumber(nextOf(cur))
    if not nxt or nxt < 1 or nxt == cur then break end
    cur = nxt
  end
  return cur
end

function OakIntro.nextEvo(species)
  local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
  if not ok or not Pokemon or type(Pokemon.evolutions) ~= "function" then return nil end
  local okRows, rows = pcall(Pokemon.evolutions, species)
  if not okRows or type(rows) ~= "table" then return nil end
  local row = rows[1]
  if type(row) ~= "table" then return nil end
  return tonumber(row.target or row[3])
end

local function speciesKey(species)
  if type(species) == "string" then return species:upper() end
  return species
end

local function familyOf(species)
  local key = speciesKey(species)
  for line, set in pairs(FAMILY) do
    if set[key] then return line end
  end
  return nil
end

function OakIntro.remapRivalParty(party, trainerId, slots, nextOf)
  if type(party) ~= "table" or type(slots) ~= "table" or #slots < 3 then return party end
  local line = RIVAL_LINE[tonumber(trainerId)]
  local index = line and LINE_INDEX[line]
  if index == nil then return party end
  local base = OakIntro.rivalSpecies(slots, index)
  if not base then return party end
  local out = {}
  for i, mon in ipairs(party) do
    local row = {}
    if type(mon) == "table" then
      for k, v in pairs(mon) do row[k] = v end
      local sp = mon.speciesId or mon.species
      if familyOf(sp) == line then
        local stage = STAGE[speciesKey(sp)] or 0
        local nid = OakIntro.atStage(base, stage, nextOf)
        if tonumber(nid) then
          row.species = tonumber(nid)
          row.speciesId = tonumber(nid)
        end
      end
    else
      row = mon
    end
    out[i] = row
  end
  return out
end

local function isBallScript(list)
  if type(list) ~= "table" then return false end
  if list._krBallIndex ~= nil then return true end
  local a, b, c, d = list[3], list[4], list[5], list[6]
  if not (list[1] and list[1].op == "lock" and list[2] and list[2].op == "faceplayer") then
    return false
  end
  if not (a and a.op == "setvar" and a.var == VAR_INDEX) then return false end
  if not (b and b.op == "setvar" and b.var == VAR_PLAYER) then return false end
  if not (c and c.op == "setvar" and c.var == VAR_RIVAL) then return false end
  if not (d and d.op == "setvar" and d.var == VAR_BALL) then return false end
  local index = tonumber(a.value)
  if index ~= 0 and index ~= 1 and index ~= 2 then return false end
  local player = tonumber(b.value)
  local rival = tonumber(c.value)
  if player ~= 1 and player ~= 4 and player ~= 7 then return false end
  if rival ~= 1 and rival ~= 4 and rival ~= 7 then return false end
  return true
end

local function setvarValue(row, value)
  row.value = value
  row[2] = value
end

local function textFlat(entry)
  if type(entry) ~= "table" then return "" end
  local parts = {}
  for _, row in ipairs(entry) do
    if type(row) == "table" and type(row.s) == "string" then
      parts[#parts + 1] = row.s
    end
  end
  return table.concat(parts)
end

local function choiceKeys(text)
  local keys = {}
  if type(text) ~= "table" then return keys end
  for key, entry in pairs(text) do
    local flat = textFlat(entry)
    if flat:find("is your choice", 1, true)
        and (flat:find("BULBASAUR", 1, true)
          or flat:find("CHARMANDER", 1, true)
          or flat:find("SQUIRTLE", 1, true)) then
      keys[key] = true
      knownChoiceKeys[key] = true
      if not textOriginal[key] then
        textOriginal[key] = copyRows(entry)
      end
    end
  end
  for key in pairs(knownChoiceKeys) do keys[key] = true end
  return keys
end

local function genericChoice()
  return {
    { t = "text", s = "Ah! " },
    { t = "strvar", n = 1 },
    { t = "text", s = " is your choice." },
    { t = "nl" },
    { t = "text", s = "You should raise it patiently." },
    { t = "para" },
    { t = "text", s = "So, " },
    { t = "player" },
    { t = "text", s = ", you want to go with" },
    { t = "nl" },
    { t = "text", s = "this POKéMON?" },
    { t = "eos" },
    _krStarterGeneric = true,
  }
end

local function bufferRow()
  return {
    op = "bufferspeciesname",
    [1] = 0,
    [2] = VAR_PLAYER,
    _krStarterBuffer = true,
  }
end

function OakIntro.patchLab(scripts, text, slots)
  if type(scripts) ~= "table" then return false end
  local on = type(slots) == "table" and #slots >= 3
  local keys = choiceKeys(text)
  local patched = false

  for _, list in pairs(scripts) do
    if isBallScript(list) then
      local index = list._krBallIndex
      if index == nil then index = tonumber(list[3].value) end
      list._krBallIndex = index
      local player = on and OakIntro.playerSpecies(slots, index) or VANILLA_PLAYER[index]
      local rival = on and OakIntro.rivalSpecies(slots, index) or VANILLA_RIVAL[index]
      if player and rival then
        setvarValue(list[4], player)
        setvarValue(list[5], rival)
        patched = true
      end
    end
  end

  if type(text) == "table" then
    for key in pairs(keys) do
      if on then
        text[key] = genericChoice()
      elseif textOriginal[key] then
        text[key] = copyRows(textOriginal[key])
      end
      patched = true
    end
  end

  for _, list in pairs(scripts) do
    if type(list) == "table" then
      if not on then
        local i = 1
        while i <= #list do
          if list[i]._krStarterBuffer then
            table.remove(list, i)
          else
            i = i + 1
          end
        end
      else
        local insertAt = {}
        for i, row in ipairs(list) do
          if row.op == "loadword" and keys[row.value or row[2]] then
            local prev = list[i - 1]
            if not (prev and prev._krStarterBuffer) then
              insertAt[#insertAt + 1] = i
            end
          end
        end
        for n = #insertAt, 1, -1 do
          table.insert(list, insertAt[n], bufferRow())
          patched = true
        end
      end
    end
  end
  return patched
end

local function readSlots(mod)
  if pending and pending.on and type(pending.slots) == "table" then
    return pending.slots
  end
  if not (mod and mod.save and mod.save.get) then return nil end
  if mod.save:get(SAVE_ON, false) ~= true then return nil end
  local slots = mod.save:get(SAVE_SLOTS, nil)
  if type(slots) == "table" and #slots >= 3 then return slots end
  return nil
end

local function eachScriptBundle(mod)
  local bundles = {}
  local Space = package.loaded["src.core.game3.scripting.space"]
  local bundle = Space and Space.bundle
  if bundle and bundle.scripts then
    bundles[#bundles + 1] = bundle
  end
  local game = Host.liveGame(mod)
  local data = game and game.data
  if data and data.gen3Scripts and (not bundle or data.gen3Scripts ~= bundle.scripts) then
    bundles[#bundles + 1] = {
      scripts = data.gen3Scripts,
      text = data.gen3Text,
    }
  end
  return bundles
end

function OakIntro.sync(mod)
  local slots = readSlots(mod)
  for _, bundle in ipairs(eachScriptBundle(mod)) do
    OakIntro.patchLab(bundle.scripts, bundle.text, slots)
  end
end

local function nameOk(id)
  if type(id) ~= "number" or id < 1 or id > SPECIES_MAX or isUnownGap(id) then return false end
  local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
  if not ok or not Pokemon or type(Pokemon.keyName) ~= "function" or not Pokemon._names then
    return true
  end
  local okName, name = pcall(Pokemon.keyName, id)
  return okName and type(name) == "string" and name ~= ""
end

function OakIntro.setRandomStarters(mod, yes)
  if yes then
    local slots = OakIntro.rollSlots(nil, nameOk)
    if #slots < 3 then return end
    pending = { on = true, slots = slots }
  else
    pending = { on = false }
  end
  -- The bedroom warp creates the save after these questions. Hold the roll
  -- until save.created so it lands on the new playthrough.
  OakIntro.sync(mod)
end

function OakIntro.flushPending(mod)
  if not pending or not (mod and mod.save and mod.save.set) then return end
  mod.save:set(SAVE_ON, pending.on and true or false)
  mod.save:set(SAVE_SLOTS, pending.on and pending.slots or nil)
  pending = nil
  OakIntro.sync(mod)
end

function OakIntro.commitSpawn(mod, fullMix, legends, pureChoice)
  local HostLocal = Host
  local function write(logical, value)
    local key = HostLocal.optionKey(logical)
    local loader = HostLocal.modLoader(mod)
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id][key] = value and true or false
    end
    return key
  end
  if pureChoice == true then
    write("full_spawn_random", false)
    write("pure_spawn_random", true)
  elseif pureChoice == false then
    write("full_spawn_random", fullMix)
    write("pure_spawn_random", false)
  else
    write("full_spawn_random", fullMix)
  end
  local pure = mod.options and mod.options:get(HostLocal.optionKey("pure_spawn_random"))
  if fullMix or not pure then
    write("legends_in_mix", fullMix and legends)
  end
  local mode = "curated"
  if pure then
    mode = "pure_random"
  elseif fullMix then
    mode = "full_random"
  end
  local legendsOn = false
  if mode == "full_random" or mode == "pure_random" then
    legendsOn = (fullMix and legends) and true or false
    if not fullMix and pure then
      legendsOn = mod.options:get(HostLocal.optionKey("legends_in_mix")) and true or false
    end
  end
  return mode, legendsOn
end

function OakIntro.applySpawn(mod, fullMix, legends, curated)
  local pureChoice = nil
  if fullMix and curated ~= nil then
    pureChoice = curated == false
  end
  local mode, legendsOn = OakIntro.commitSpawn(mod, fullMix, legends, pureChoice)
  Host.persistModOptions(mod)
  local opts = { legends = legendsOn, legendsInMix = legendsOn }
  if mode == "pure_random" and pureChoice == true then
    local entropy = os.time()
    if love and love.math and love.math.random then
      entropy = entropy + love.math.random(1, 999999)
    end
    opts.seed = entropy
    if mod.save and mod.save.set then mod.save:set("g3_pure_seed", entropy) end
  end
  local EncountersGame3 = require("mods.Kanto-Reforged.world.encounters_game3")
  EncountersGame3.apply(mod, mode, opts)
  return mode, legendsOn
end

OakIntro.preview = nil

local function speciesLabel(id)
  local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
  if not ok or not Pokemon or type(Pokemon.name) ~= "function" then return "POKéMON" end
  local okName, name = pcall(Pokemon.name, id)
  if okName and type(name) == "string" and name ~= "" then return name end
  return "POKéMON"
end

function OakIntro.setPreview(speciesId)
  speciesId = tonumber(speciesId)
  if not speciesId or speciesId < 1 then
    OakIntro.preview = nil
    return nil
  end
  OakIntro.preview = { speciesId = speciesId, name = speciesLabel(speciesId) }
  return OakIntro.preview
end

function OakIntro.clearPreview()
  OakIntro.preview = nil
end

-- Lab balls show the offered species with showmonpic of VAR_TEMP_2 (16386).
-- The native picture window is not relied on. This record is what both
-- previews draw: Omni when that mod is loaded, and the fallback below when
-- it is not.
function OakIntro.onScriptCommand(ctx, op, row)
  if op == "hidemonpic" then
    OakIntro.clearPreview()
    return
  end
  if op ~= "showmonpic" or not row then return end
  local src = tonumber(row[1] or row.species)
  if src ~= VAR_PLAYER then return end
  local vm = ctx and ctx.runner
  local Flags = require("src.core.game3.scripting.flags")
  local id = Flags.getVar(vm and vm.store, vm and vm.ctx, VAR_PLAYER)
  OakIntro.setPreview(id)
end

local function drawFallback(viewport)
  local preview = OakIntro.preview
  if not preview or not (love and love.graphics) then return end
  viewport = viewport or {}
  local gw = viewport.gameWidth or 240
  local gh = viewport.gameHeight or 160
  local gx = viewport.gameX or 0
  local gy = viewport.gameY or 0
  local cardW = math.min(150, gw * 0.5)
  local cardH = math.min(132, gh * 0.62)
  local x = gx + (gw - cardW) / 2
  local y = gy + (gh - cardH) / 2
  love.graphics.setColor(0.06, 0.07, 0.1, 0.92)
  love.graphics.rectangle("fill", x, y, cardW, cardH, 8, 8)
  love.graphics.setColor(0.85, 0.78, 0.45, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, cardW, cardH, 8, 8)
  local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
  local entry
  if ok and Pokemon and Pokemon.frontPic then
    local okPic, pic = pcall(Pokemon.frontPic, preview.speciesId, nil, false)
    if okPic and type(pic) == "table" then entry = pic end
  end
  if entry and entry.image then
    local iw = entry.w or 64
    local ih = entry.h or 64
    local box = math.min(cardW, cardH) - 36
    local scale = math.min(box / iw, box / ih)
    local dw, dh = iw * scale, ih * scale
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(entry.image, x + (cardW - dw) / 2, y + 8, 0, scale, scale)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(tostring(preview.name or "POKéMON"), x + 6, y + cardH - 22, cardW - 12, "center")
end

local function slotsFromSave(mod)
  if not (mod and mod.save and mod.save.get) then return nil end
  if mod.save:get(SAVE_ON, false) ~= true then return nil end
  local slots = mod.save:get(SAVE_SLOTS, nil)
  if type(slots) == "table" and #slots >= 3 then return slots end
  return nil
end

local speechAttached = false

function OakIntro.attachSpeech()
  if speechAttached then return end
  local ok, Scene = pcall(require, "src.ui.game3.new_game_scene")
  if not (ok and Scene and Scene.Task_OakSpeech_LetsGo) then return end
  speechAttached = true
  local FrlgFont = require("src.ui.game3.frlg_font")
  local RomText = require("src.core.game3.rom_text")
  local newPrinter
  local i = 1
  while debug and debug.getupvalue do
    local name, val = debug.getupvalue(Scene.oakPrint, i)
    if not name then break end
    if name == "newPrinter" and type(val) == "function" then newPrinter = val break end
    i = i + 1
  end

  function Scene:sayRaw(text, speed)
    text = tostring(text or ""):gsub("\\p", "\f"):gsub("\\l", "\n")
    self.win.dialog = true
    if not newPrinter then return end
    self.printer = newPrinter(text, speed == nil and self.textSpeed or speed, true)
  end

  local vanillaLetsGo = Scene.Task_OakSpeech_LetsGo

  local function nextExitQuestion(questions, answers, index)
    index = index or 1
    while index <= #questions do
      local q = questions[index]
      local show = type(q) == "table" and type(q.text) == "string" and q.text ~= ""
      if show and type(q.when) == "function" then
        local okWhen, res = pcall(q.when, answers)
        show = okWhen and res and true or false
      end
      if show then return index, q end
      index = index + 1
    end
    return nil
  end

  function Scene.Task_OakSpeech_ExitIntro(self, t)
    if self:printerActive() and not t.data.exitIntroShown then return end
    if not t.data.exitIntroShown then
      t.data.exitIntroShown = true
      self:sayRaw(self.exitIntro)
      return
    end
    if self:printerActive() then return end
    self:clearDialog()
    t.func = Scene.Task_OakSpeech_ExitQuestion
  end

  function Scene.Task_OakSpeech_ExitQuestion(self, t)
    local qs = self.exitQuestions or {}
    t.data.exitAnswers = t.data.exitAnswers or {}
    local index, q = nextExitQuestion(qs, t.data.exitAnswers, t.data.exitIndex or 1)
    if not index then
      if type(self.exitConfirm) == "function" and not t.data.exitConfirmed then
        t.func = Scene.Task_OakSpeech_ExitConfirm
        return
      end
      t.data.exitDone = true
      t.func = Scene.Task_OakSpeech_LetsGo
      return
    end
    t.data.exitIndex = index
    t.data.exitQuestion = q
    self:sayRaw(q.text)
    t.func = Scene.Task_OakSpeech_ExitQuestionMenu
  end

  function Scene.Task_OakSpeech_ExitQuestionMenu(self, t)
    if self:printerActive() then return end
    local raw = RomText.plain("gText_YesNo") or "YES\nNO"
    local yes, no = raw:match("^(.-)\n(.*)$")
    self.win.menu = {
      kind = "yesno", left = 2, top = 2, width = 6, height = 4,
      items = { { yes or "YES", 8, 2 }, { no or "NO", 8, 2 + FrlgFont.LINE_PITCH } },
      cursorX = 0, cursorY = 2, pitch = 16, cursor = 0,
    }
    t.func = Scene.Task_OakSpeech_ExitQuestionInput
  end

  function Scene.Task_OakSpeech_ExitConfirm(self, t)
    local okText, text = pcall(self.exitConfirm, t.data.exitAnswers or {})
    if not okText or type(text) ~= "string" or text == "" then
      text = "Is this the adventure you want?"
    end
    t.data.exitQuestion = { id = "confirm", confirm = true }
    self:sayRaw(text)
    t.func = Scene.Task_OakSpeech_ExitQuestionMenu
  end

  function Scene.Task_OakSpeech_ExitQuestionInput(self, t)
    local r = self:menuInput(false)
    if r ~= 0 and r ~= 1 then return end
    self.win.menu = nil
    local q = t.data.exitQuestion or {}
    local yes = r == 0
    self:clearDialog()
    if q.confirm then
      if yes then
        t.data.exitConfirmed = true
        t.data.exitDone = true
        t.func = Scene.Task_OakSpeech_LetsGo
      else
        t.data.exitAnswers = {}
        t.data.exitIndex = 1
        t.data.exitQuestion = nil
        t.func = Scene.Task_OakSpeech_ExitQuestion
      end
      return
    end
    local id = q.id or t.data.exitIndex
    t.data.exitAnswers[id] = yes
    self:_answered(id, yes)
    t.data.exitIndex = (t.data.exitIndex or 1) + 1
    t.func = Scene.Task_OakSpeech_ExitQuestion
  end

  function Scene.Task_OakSpeech_LetsGo(self, t)
    if t.data.picFadeState == 0 then return end
    local qs = self.exitQuestions
    if not t.data.exitDone and type(qs) == "table" and #qs > 0 then
      t.data.exitIndex = 1
      if type(self.exitIntro) == "string" and self.exitIntro ~= "" then
        t.func = Scene.Task_OakSpeech_ExitIntro
      else
        t.func = Scene.Task_OakSpeech_ExitQuestion
      end
      return
    end
    return vanillaLetsGo(self, t)
  end
end

function OakIntro.install(mod)
  if not Host.isGen3From(mod) and not Host.isGen3() then return end
  OakIntro.attachSpeech(mod)
  if mod.events and mod.events.on then
    mod.events:on("intro.oak_speech.started", function(ev)
      local speech = ev and ev.speech
      if type(speech) == "table" then
        speech.exitIntro = OakIntro.introLine()
        speech.exitQuestions = OakIntro.questions()
        speech.exitConfirm = OakIntro.confirmText
      end
    end)
    local spawnChoice = { curated = true }
    mod.events:on("intro.oak_speech.answered", function(ev)
      if not ev then return end
      if ev.label == "random_starters" then
        OakIntro.setRandomStarters(mod, ev.value == true)
      elseif ev.label == "full_mix" then
        spawnChoice.curated = true
        if ev.value ~= true then
          OakIntro.applySpawn(mod, false, false)
        end
      elseif ev.label == "curated" then
        spawnChoice.curated = ev.value == true
      elseif ev.label == "legends" then
        OakIntro.applySpawn(mod, true, ev.value == true, spawnChoice.curated)
      end
    end)
    mod.events:on("save.created", function()
      OakIntro.flushPending(mod)
    end)
    mod.events:on("save.loaded", function()
      pending = nil
      OakIntro.sync(mod)
    end)
    mod.events:on("game.ready", function()
      OakIntro.sync(mod)
    end)
  end
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("script.command", function(next, ctx, op, row)
      OakIntro.onScriptCommand(ctx, op, row)
      return next(ctx, op, row)
    end)
    mod.hooks:wrap("render.hud", function(next, game, viewport)
      if next then next(game, viewport) end
      local omni = mod.find and mod.find("omni_ui")
      if omni then return end
      drawFallback(viewport)
    end)
    mod.hooks:wrap("trainer.party", function(next, _class, trainerId, party)
      local out = next(_class, trainerId, party)
      local slots = slotsFromSave(mod) or (pending and pending.on and pending.slots)
      if not slots then return out end
      return OakIntro.remapRivalParty(out, trainerId, slots)
    end, 1000)
  end
  OakIntro.sync(mod)
end

return OakIntro
