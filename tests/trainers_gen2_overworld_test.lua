-- Gen2 overworld trainer parties (Gold class+member, not Gen1 OPP_*/parties).
-- luajit mods/Kanto-Reforged/tests/trainers_gen2_overworld_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Host = require("mods.Kanto-Reforged.core.host")
local GameVersion = require("src.core.GameVersion")
local ExpTrainers = require("mods.Kanto-Reforged.battle.trainers")

GameVersion.set("gold")
Host.force(2)

local CachePaths = require("mods.Kanto-Reforged.core.cache_paths")
local goldTrainers = CachePaths.loadGenerated("trainers.lua", "gold")
local okTrainers = type(goldTrainers) == "table"
T.check(okTrainers, "Gen2 trainers.lua available")

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

-- Routes 26/27 are Johto league approach — must stay vanilla, not postgame curve.
local route = ExpTrainers.GEN2_KANTO_ROUTE_PARTIES
T.check(route.COOLTRAINERF[8] == nil, "Joyce (Route 26) not in Kanto curve table")
T.check(route.COOLTRAINERF[9] == nil, "Beth (Route 26) not in Kanto curve table")
T.check(route.COOLTRAINERM == nil or route.COOLTRAINERM[9] == nil, "Jake (Route 26) not in Kanto curve table")
T.check(route.BIRD_KEEPER[14] == nil, "Jose (Route 27) not in Kanto curve table")
T.check(route.FISHER[21] == nil, "Scott (Route 26) not in Kanto curve table")
T.check(route.PSYCHIC_T[9] == nil and route.PSYCHIC_T[10] == nil,
  "Richard/Gilbert (Route 26/27) not in Kanto curve table")
local joyce = classes.COOLTRAINERF.trainers[8]
T.check(joyce and joyce.party and joyce.party[1].level < 45,
  "Joyce stays near vanilla league-approach levels")
T.check(joyce.party[1].species ~= "MILOTIC", "Joyce not force-remixed to Milotic")

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
T.check((recNum.baseMoney or 0) > 0, "lookup overlay keeps class baseMoney")

local World = require("src.world.gen2.World")
local world = setmetatable({
  game = { data = Data, save = { player = { money = 0, name = "TEST" } } },
}, { __index = World })
local partyRec = world:trainerParty(brockIndex, 1)
T.check(partyRec and partyRec.baseMoney and partyRec.baseMoney > 0,
  "trainerParty path pays Kanto gym leaders (loadtrainer/startbattle)")

-- Johto rival parties must stay vanilla Indigo stock (Mt Moon Silver is member 201+).
local rival = classes.RIVAL2.trainers[1].party
T.eq(rival[1].species, "SNEASEL", "RIVAL2 member 1 left for stock Indigo")
T.eq(rival[1].level, 41, "RIVAL2 member 1 stays stock Lv41, not Mt Moon 58")
T.check(classes.RIVAL2.trainers[201] == nil or classes.RIVAL2.trainers[201].name == "SILVER",
  "Mt Moon Silver uses high member slot when installed")

Host.clearForce()
GameVersion.set("red")

-- E4 rematch: post-Champion only; Johto-first league stays vanilla stock.
_G.game = {
  data = Data,
  save = { flags = { EVENT_BEAT_CHAMPION_LANCE = true }, player = { money = 0, name = "TEST" } },
}
local brunoRematch = G2Trainers.lookup(goldTrainers, "BRUNO", 1)
T.eq(brunoRematch.roster[1].species, "STEELIX", "E4 rematch Bruno opens on Steelix")
T.eq(brunoRematch.roster[1].level, 80, "E4 rematch Bruno postgame level")
T.eq(brunoRematch.roster[#brunoRematch.roster].item, "CHESTO_BERRY", "E4 rematch Bruno ace berry")

local karenRematch = G2Trainers.lookup(goldTrainers, "KAREN", 1)
T.eq(karenRematch.name, "LANCE", "Karen slot shows Lance on rematch")
T.eq(karenRematch.roster[#karenRematch.roster].species, "DRAGONITE", "Karen slot runs Lance dragon ace")

local champRematch = G2Trainers.lookup(goldTrainers, "CHAMPION", 1)
T.eq(champRematch.name, "BLUE", "Champion slot is Blue on rematch")
T.eq(champRematch.roster[#champRematch.roster].species, "ARCANINE", "Champion Blue ace Arcanine")

local willFirst = classes.WILL.trainers[1].party
T.eq(willFirst[1].level, 40, "Johto-first Will stays vanilla in trainer table")
_G.game.save.flags.EVENT_BEAT_CHAMPION_LANCE = nil
local willNoRematch = G2Trainers.lookup(goldTrainers, classes.WILL.index, 1)
T.eq(willNoRematch.roster[1].level, 40, "Without champion flag Will lookup stays stock")

T.finish("trainers_gen2_overworld")
