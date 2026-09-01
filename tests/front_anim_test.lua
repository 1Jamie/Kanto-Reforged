-- GS front idle anim index + edition fallback policy.
-- luajit mods/Kanto-Reforged/tests/front_anim_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local Host = require("mods.Kanto-Reforged.core.host")
local FrontAnim = require("mods.Kanto-Reforged.battle.front_anim")

local mod = { id = "Kanto-Reforged", path = "mods/Kanto-Reforged" }
FrontAnim._mod = mod

local idx = require("mods.Kanto-Reforged.pokemon.gs_anim_index")
T.check(idx.ARBOK ~= nil, "gs_anim_index has ARBOK")
T.eq(idx.ARBOK.frameCount, 6, "ARBOK frame count")

T.eq(
  FrontAnim.stripLayout({ frontW = 40, frontH = 40, frameCount = 4 }, 160, 40),
  "horizontal",
  "wide strip is horizontal"
)
T.eq(
  FrontAnim.stripLayout({ frontW = 40, frontH = 40, frameCount = 4 }, 40, 160),
  "vertical",
  "tall strip is vertical"
)
local ox, oy = FrontAnim.frameOffset(
  { frontW = 40, frontH = 40, frameCount = 4, layout = "vertical" }, 3, 40, 160)
T.eq(ox, 0, "vertical frame x")
T.eq(oy, 80, "vertical frame y (frame 3)")

T.check(
  FrontAnim.prefersKrAnim("ARBOK", nil, nil, mod),
  "ARBOK prefers KR strip when gs front exists"
)
T.check(not FrontAnim.prefersKrAnim("ZZZZZ", nil, nil, mod),
  "unknown species does not prefer KR")

GameVersion.set("gold")
Host.clearForce()
Host.force(2)
T.check(not Host.isCrystal(), "gold is not crystal")
T.check(
  not FrontAnim.allowCrystalNative("CHIKORITA", nil, nil, mod),
  "Gold never uses Crystal MonAnim fallback"
)

GameVersion.set("crystal")
Host.clearForce()
Host.force(2)
T.check(Host.isCrystal(), "crystal edition")
T.check(
  not FrontAnim.allowCrystalNative("ARBOK", nil, nil, mod),
  "Crystal uses KR strips for gs ARBOK"
)
T.check(
  FrontAnim.allowCrystalNative("PIDGEY", nil, nil, mod),
  "Crystal may use native MonAnim for ROM species without gs strip"
)

local meta = {
  frameCount = 2,
  durations = { 1, 1 },
  loop = true,
}
local st = { frame = 1, timer = 0 }
local changed = 0
for _ = 1, 7 do
  if FrontAnim.stepState(st, meta) then changed = changed + 1 end
end
T.check(changed >= 1, "stepState advances at least one frame in 7 ticks")

-- Two full passes (frames 1→2 twice), then hold frame 1.
FrontAnim.resetState(st)
local steps = 0
while not st.done and steps < 200 do
  FrontAnim.stepState(st, meta)
  steps = steps + 1
end
T.check(st.done, "battle anim stops after BATTLE_CYCLES")
T.eq(st.frame, 1, "rests on static frame 1")
T.eq(st.cycles, FrontAnim.BATTLE_CYCLES, "completed two strip cycles")

T.eq(
  FrontAnim.animSpeciesId("CASTFORM", nil, { _krCastformForm = "rainy" }),
  "CASTFORM_RAINY",
  "Forecast suffix maps to anim id"
)

local enemy = { isPlayer = false, species = "ARBOK" }
local battle = { introSlide = 10, enemy = enemy }
T.check(
  FrontAnim.presentationHoldsEnemyGen1(battle, enemy),
  "Gen1 holds during intro slide"
)
battle.introSlide = 0
battle.growIn = { battler = enemy, frame = 3 }
T.check(
  FrontAnim.presentationHoldsEnemyGen1(battle, enemy),
  "Gen1 holds during grow-in"
)
battle.growIn = nil
T.check(
  not FrontAnim.presentationHoldsEnemyGen1(battle, enemy),
  "Gen1 plays after grow-in lands"
)

local AnimView = require("src.ui.gen2.BattleAnimView")
local view = {
  slideFrame = 0,
  showEnemyTrainer = false,
  picHidden = { enemy = false },
  battle = { enemy = { species = "ARBOK" } },
}
local mon = view.battle.enemy
T.check(
  FrontAnim.presentationHoldsEnemyGen2(view, mon),
  "Gen2 holds during intro slide"
)
view.slideFrame = AnimView.SLIDE_FRAMES
T.check(
  not FrontAnim.presentationHoldsEnemyGen2(view, mon),
  "Gen2 plays after intro slide"
)

-- Test Gen2 BattleState installation and stepFrontAnim without boolean indexing error
local BS = require("src.ui.gen2.BattleState")
BS._krFrontAnimInstalled = nil
Host.clearForce()
GameVersion.set("red")
FrontAnim.install({ id = "Kanto-Reforged", path = "mods/Kanto-Reforged",
  _loader = { generation = 2 } })
T.check(BS._krFrontAnimInstalled, "Gen2 BattleState installs via loader.generation=2")

local mockBS = setmetatable({
  slideFrame = AnimView.SLIDE_FRAMES,
  showEnemyTrainer = false,
  picHidden = { enemy = false },
  battle = { enemy = { species = "ARBOK" } },
  picCache = {},
}, { __index = BS })

mockBS:startFrontAnim(mockBS.battle.enemy)
local okStep, errStep = pcall(function()
  for _ = 1, 30 do
    mockBS:stepFrontAnim()
  end
end)
T.check(okStep, "mockBS:stepFrontAnim runs cleanly without indexing error: " .. tostring(errStep))
local stMon = mockBS._krFrontAnimMonState and mockBS._krFrontAnimMonState[mockBS.battle.enemy]
T.check(stMon ~= nil, "Gen2 mon state initialized on instance")
T.check(type(stMon.frame) == "number", "Gen2 mon state has numeric frame")

local frame0 = stMon.frame
for _ = 1, 10 do mockBS:stepFrontAnim() end
T.check(
  mockBS._krFrontAnimMonState[mockBS.battle.enemy].frame ~= frame0,
  "Gen2 stepFrontAnim advances strip state"
)
local sheet, quad = mockBS:frontAnimFrame(mockBS.battle.enemy)
T.check(sheet ~= nil and quad ~= nil, "Gen2 frontAnimFrame returns KR strip quad")

Host.clearForce()
T.finish("front_anim")
