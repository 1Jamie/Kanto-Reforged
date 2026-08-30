-- Kanto Indigo rematch dialogue (post-Johto Champion). Johto-first E4 keeps stock
-- gen2Text from the ROM extract; rematch swaps pointer keys at read time.

local E4Dialogue = {}

local ExpTrainers = require("mods.Kanto-Reforged.battle.trainers")
local Dialogue = require("mods.Kanto-Reforged.core.dialogue")

-- ROM text.lua keys (see tools/rom_manifest_gold.json / data/generated/text.lua).
local KEYS = {
  WILL = { intro = "5a:4ddd", win = "5a:4ed8", after = "5a:4ef0" },
  KOGA = { intro = "5a:503f", win = "5a:5155", after = "5a:5176" },
  BRUNO = { intro = "5a:52aa", win = "5a:53cf", after = "5a:53e8" },
  KAREN = { intro = "5a:54d3", win = "5a:55a4", after = "5a:55d5" },
  CHAMPION = { intro = "5a:5816", win = "5a:5953", after = "5a:59e1" },
}

local function ow(text)
  return Dialogue.overworld(text)
end

local REMATCH = {
  [KEYS.WILL.intro] = ow([[
So you cleared JOHTO's LEAGUE, {PLAYER}.
Impressive -- but this is KANTO's ELITE FOUR.
We've held this post long before your region had one.
I am WILL. My psychic POKéMON are tuned for veterans, not first-timers.
Show me you belong here!
]]),
  [KEYS.WILL.win] = ow("I… I can't… believe it…\nNot at this level…"),
  [KEYS.WILL.after] = ow([[
KANTO's standard is\nsteep, isn't it?
Keep climbing -- the\nrest won't go easy.
]]),

  [KEYS.KOGA.intro] = ow([[
Fwahahahaha!
Champion of JOHTO, are you?
I am KOGA of KANTO's ELITE FOUR -- a ninja who has guarded this hall for decades.
Your JOHTO tricks won't confound a shadow that old.
Prepare yourself!
]]),
  [KEYS.KOGA.win] = ow("Ah!\nYou have proven\nyour worth!"),
  [KEYS.KOGA.after] = ow([[
I gave you everything\na Kanto ninja knows.
Go on -- Bruno awaits.
]]),

  [KEYS.BRUNO.intro] = ow([[
I am BRUNO of KANTO's ELITE FOUR.
You earned JOHTO's title -- respect.
We trained on this side of the land decades before your journey began.
My fighting POKéMON push harder than anything in JOHTO.
Let's see your spirit!
]]),
  [KEYS.BRUNO.win] = ow("Why? How could we\nlose?"),
  [KEYS.BRUNO.after] = ow([[
Having lost, I have\nno right to say much…
Go face your next\nchallenge!
]]),

  -- Karen map slot → Lance (teams + intro pic patched in battle/trainers.lua).
  [KEYS.KAREN.intro] = ow([[
LANCE: Back again, {PLAYER}?
JOHTO made you CHAMPION -- good.
KANTO's ELITE FOUR stood long before JOHTO rebuilt its LEAGUE. We never left.
My dragons answer only to trainers who've proven they can handle this caliber.
Battle!
]]),
  [KEYS.KAREN.win] = ow("Well, aren't you\ngood. I like that\nin a trainer."),
  [KEYS.KAREN.after] = ow([[
Strong POKéMON.
Weak POKéMON.
That is only the selfish perception of people.
Truly skilled trainers should try winning with their favorites.
]]),

  -- Champion slot → Blue.
  [KEYS.CHAMPION.intro] = ow([[
BLUE: So JOHTO calls you CHAMPION now, {PLAYER}.
KANTO's LEAGUE is older than both of us. I held this room once myself.
If you want KANTO's respect too, you'll beat me at full strength -- no excuses!
]]),
  [KEYS.CHAMPION.win] = ow([[
…It's over.
But it's an odd feeling.
I'm not angry that I lost. In fact, I feel happy.
Happy that I witnessed the rise of a great new CHAMPION!
]]),
  [KEYS.CHAMPION.after] = ow([[
…Whew.
You have become truly powerful, {PLAYER}.
Your POKéMON have responded to your strong and upstanding nature.
]]),
}

E4Dialogue.KEYS = KEYS
E4Dialogue.REMATCH = REMATCH

local function liveSave()
  local ok, Host = pcall(require, "mods.Kanto-Reforged.core.host")
  if ok and Host and Host.liveGame then
    local game = Host.liveGame()
    if game and game.save then return game.save end
  end
  local game = _G.game
  return game and game.save
end

function E4Dialogue.resolve(textKey, textTable, save)
  if not textKey or type(textTable) ~= "table" then return nil end
  save = save or liveSave()
  if ExpTrainers.isGen2E4Rematch(save) and REMATCH[textKey] then
    return REMATCH[textKey]
  end
  return textTable[textKey]
end

function E4Dialogue.install(mod)
  local Host = require("mods.Kanto-Reforged.core.host")
  if not Host.isGen2() then return end

  local Gen1Patch = require("mods.Kanto-Reforged.core.gen1_patch")
  Gen1Patch.apply(require("src.script.gen2.Vm"), function(Vm)
    if Vm._krE4Dialogue then return end
    local origShowText = Vm.showText
    function Vm:showText(textKey)
      local save = liveSave()
      if ExpTrainers.isGen2E4Rematch(save) and REMATCH[textKey] then
        local stock = self.text[textKey]
        self.text[textKey] = REMATCH[textKey]
        origShowText(self, textKey)
        self.text[textKey] = stock
        return
      end
      origShowText(self, textKey)
    end
    Vm._krE4Dialogue = true
  end)

  local okWorld, World = pcall(require, "src.world.gen2.World")
  if okWorld and World and World.trainerWinLossText and not World._krE4WinLossPatched then
    World._krE4WinLossPatched = true
    local origWinLoss = World.trainerWinLossText
    function World:trainerWinLossText()
      local vm = self.vm
      if not vm then return nil, nil end
      local obj = vm.trainerObject or {}
      local text = self.text or {}
      local winKey, lossKey
      if vm.winLossArmed then
        winKey, lossKey = vm.winTextOverride, vm.lossTextOverride
      else
        winKey, lossKey = obj.winText, obj.lossText
      end
      local save = self.game and self.game.save or liveSave()
      local winText = E4Dialogue.resolve(winKey, text, save)
      local lossText = lossKey and text[lossKey] or nil
      return winText, lossText
    end
  end

  if mod and mod.log then
    mod.log:info("Gen2 Kanto E4 rematch dialogue installed")
  end
end

return E4Dialogue
