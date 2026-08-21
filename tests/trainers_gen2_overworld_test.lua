-- Gen2 overworld trainer parties (Gold class+member, not Gen1 OPP_*/parties).
-- luajit mods/Kanto-Reforged/tests/trainers_gen2_overworld_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Host = require("mods.Kanto-Reforged.core.host")
local GameVersion = require("src.core.GameVersion")
local ExpTrainers = require("mods.Kanto-Reforged.battle.trainers")

GameVersion.set("gold")
Host.force(2)

local home = os.getenv("HOME") or ""
local trainersPath = home .. "/.local/share/love/pokemon-love2d/gold/data/generated/trainers.lua"
local okTrainers, goldTrainers = pcall(dofile, trainersPath)
if not okTrainers or type(goldTrainers) ~= "table" then
  okTrainers, goldTrainers = pcall(dofile, "data/generated/trainers.lua")
end
T.check(okTrainers and type(goldTrainers) == "table", "Gold trainers.lua available")

local Data = {
  gen2Trainers = goldTrainers,
  trainers = goldTrainers,
}
local mod = {
  data = Data,
  content = {
    trainers = {
      patch = function() end,
      get = function() return nil end,
    },
  },
  log = { info = function() end, warn = function() end },
}

ExpTrainers.clearBaselines()
local n = ExpTrainers.apply(mod)
T.check(n >= 8, "Gen2 apply touches gym leader + gym trainer classes")
T.check(ExpTrainers.hasGen2Override("BROCK"), "override index has BROCK")
T.check(ExpTrainers.hasGen2Override("JANINE"), "override index has JANINE")
T.check(ExpTrainers.hasGen2Override("BLUE"), "override index has BLUE")
T.check(not ExpTrainers.hasGen2Override("FALKNER"), "Johto Falkner not overridden")

local classes = goldTrainers.classes or goldTrainers
local brock = classes.BROCK.trainers[1].party
T.eq(brock[1].species, "SUDOWOODO", "Brock party written to Gold trainers[].party")
T.eq(brock[#brock].item, "BERRY", "Brock ace uses Gen2 item field")
T.check(brock[#brock].heldItem == nil, "Brock ace has no Gen1 heldItem alias in Gold row")

local janine = classes.JANINE.trainers[1].party
T.eq(janine[1].species, "ARIADOS", "Janine (not Koga) gets Fuchsia gym team")

local blue = classes.BLUE.trainers[1].party
T.eq(blue[1].species, "PIDGEOT", "Blue gets Viridian gym team")
T.eq(#blue, 6, "Blue has six mons")

local jerry = classes.CAMPER.trainers[18].party
T.eq(jerry[1].species, "PHANPY", "Pewter gym Camper Jerry remixed")

local hope = classes.PICNICKER.trainers[6].party
T.eq(hope[1].species, ExpTrainers.GEN2_KANTO_ROUTE_PARTIES.PICNICKER[6][1].species,
  "Route 4 Picnicker Hope remixed in live data")
T.check(hope[1].level >= 50, "Hope levels use postgame Kanto curve")
T.check(ExpTrainers.hasGen2Override("PICNICKER"), "PICNICKER class has overrides")

-- Lookup overlay resolves string + numeric class the way gym scripts do.
ExpTrainers.installGen2(mod)
local G2Trainers = require("src.world.gen2.Trainers")
local rec = G2Trainers.lookup(goldTrainers, "BROCK", 1)
T.check(rec and rec.roster, "lookup returns Brock roster")
T.eq(rec.roster[1].species, "SUDOWOODO", "lookup roster lead")
T.eq(rec.roster[#rec.roster].item, "BERRY", "lookup roster ace item")

local byIndex = G2Trainers.classIndex(goldTrainers)
local brockIndex = classes.BROCK.index
T.check(type(brockIndex) == "number", "Brock has numeric class index")
local recNum = G2Trainers.lookup(goldTrainers, brockIndex, 1)
T.eq(recNum.roster[1].species, "SUDOWOODO", "numeric class lookup hits curated roster")

-- Johto rival parties must stay vanilla (Mt Moon rival is restored_dungeons).
local rival = classes.RIVAL2.trainers[1].party
T.eq(rival[1].species, "SNEASEL", "RIVAL2 member 1 left for stock/dungeons")
T.check(rival[1].level == 41 or rival[1].level == 58, "RIVAL2 not force-overwritten by Gen1 Mt Moon draft")

Host.clearForce()
GameVersion.set("red")
T.finish("trainers_gen2_overworld")
