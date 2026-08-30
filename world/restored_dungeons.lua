-- restored_dungeons.lua
-- Runtime manager for Kanto-Reforged restored Gen 1 dungeons in Gen 2 mode.

local Host = require("mods.Kanto-Reforged.core.host")

local RestoredDungeons = {}

RestoredDungeons.APPLIED = false

local function kantoCampaign()
  local ok, C = pcall(require, "mods.Kanto-Reforged.world.kanto_campaign")
  if ok then return C end
  return nil
end

-- Item index mapping for Gold / Gen 2 item compatibility
local ITEM_INDEX_MAP = {
  MASTER_BALL = 1, ULTRA_BALL = 2, GREAT_BALL = 3, POKE_BALL = 4,
  TOWN_MAP = 5, BICYCLE = 6, SAFARI_BALL = 8, POKEDEX = 9,
  MOON_STONE = 10, ANTIDOTE = 11, BURN_HEAL = 12, ICE_HEAL = 13,
  AWAKENING = 14, PARLYZ_HEAL = 15, FULL_RESTORE = 16, MAX_POTION = 17,
  HYPER_POTION = 18, SUPER_POTION = 19, POTION = 20, ESCAPE_ROPE = 29,
  REPEL = 30, FIRE_STONE = 32, THUNDER_STONE = 33, WATER_STONE = 34,
  HP_UP = 35, PROTEIN = 36, IRON = 37, CARBOS = 38, CALCIUM = 39,
  RARE_CANDY = 40, DOME_FOSSIL = 41, HELIX_FOSSIL = 42, SECRET_KEY = 43,
  LEAF_STONE = 47, NUGGET = 49, FULL_HEAL = 52, REVIVE = 53,
  MAX_REVIVE = 54, SUPER_REPEL = 56, MAX_REPEL = 57, GOLD_TEETH = 64,
  PP_UP = 79, ETHER = 80, MAX_ETHER = 81, ELIXER = 82, MAX_ELIXER = 83,
  MAX_ELIXIR = 83,
  TM_DYNAMICPUNCH = 182, TM_MEGA_PUNCH = 182, TM01 = 182,
  TM_WATER_GUN = 193, TM_SWEET_SCENT = 193, TM12 = 193,
  TM_DOUBLE_TEAM = 213, TM32 = 213,
  TM_EGG_BOMB = 224, TM_DETECT = 224, TM43 = 224,
  TM_SKULL_BASH = 221, TM_DEFENSE_CURL = 221, TM40 = 221,
  HM01 = 244, HM_CUT = 244,
  HM02 = 245, HM_FLY = 245,
  HM03 = 246, HM_SURF = 246,
  HM04 = 247, HM_STRENGTH = 247,
  HM05 = 248, HM_FLASH = 248,
  HM06 = 249, HM_WHIRLPOOL = 249,
  HM07 = 250, HM_WATERFALL = 250,
}

-- Authentic NPC and Signpost dialogues for restored Kanto dungeons
local DUNGEON_TEXT = {
  -- Viridian Forest
  TEXT_VIRIDIANFOREST_YOUNGSTER1 = "I came here with some friends!\nThey're out for POKéMON fights!",
  TEXT_VIRIDIANFOREST_YOUNGSTER5 = "I ran out of POKé BALLs to catch\nPOKéMON with!\nYou should carry extras!",
  TEXT_VIRIDIANFOREST_YOUNGSTER2 = "Hey! You have POKéMON!\nCome on! Let's battle!",
  TEXT_VIRIDIANFOREST_YOUNGSTER2_WIN = "No!\nCATERPIE can't cut it!",
  TEXT_VIRIDIANFOREST_YOUNGSTER3 = "Yo! You can't jam out if you're\na POKéMON trainer!",
  TEXT_VIRIDIANFOREST_YOUNGSTER3_WIN = "Huh?\nI ran out of POKéMON!",
  TEXT_VIRIDIANFOREST_YOUNGSTER4 = "Hey, wait up!\nWhat's the hurry?",
  TEXT_VIRIDIANFOREST_YOUNGSTER4_WIN = "I give! You're good at this!",
  TEXT_VIRIDIANFOREST_TRAINER_TIPS1 = "TRAINER TIPS\nIf you want to avoid battles,\nstay away from grassy areas!",
  TEXT_VIRIDIANFOREST_TRAINER_TIPS2 = "TRAINER TIPS\nContact PROF.OAK via PC to get\nyour POKéDEX evaluated!",
  TEXT_VIRIDIANFOREST_TRAINER_TIPS3 = "TRAINER TIPS\nNo stealing POKéMON from other\ntrainers! Catch only wild ones!",
  TEXT_VIRIDIANFOREST_TRAINER_TIPS4 = "TRAINER TIPS\nWeaken POKéMON before catching!\nWhen healthy, they may escape!",
  TEXT_VIRIDIANFOREST_USE_ANTIDOTE_SIGN = "For poison, use ANTIDOTE!\nGet it at POKéMON MARTs!",
  TEXT_VIRIDIANFOREST_LEAVING_SIGN = "LEAVING VIRIDIAN FOREST\nPEWTER CITY AHEAD",

  -- Route 2 & Gatehouses
  TEXT_ROUTE2_SIGN = "ROUTE 2\nVIRIDIAN CITY - PEWTER CITY",
  TEXT_ROUTE2_DIGLETTS_CAVE_SIGN = "DIGLETT'S CAVE",
  TEXT_ROUTE2_MOON_STONE = "Found a MOON STONE!",
  TEXT_ROUTE2_HP_UP = "Found an HP UP!",
  TEXT_VIRIDIANFORESTNORTHGATE_SUPER_NERD = "Many POKéMON live only in\nforests and caves.\nYou need to look everywhere\nto get different kinds!",
  TEXT_VIRIDIANFORESTNORTHGATE_GRAMPS = "Have you noticed the bushes\non the roadside?\nThey can be cut down by\na special POKéMON move.",
  TEXT_VIRIDIANFORESTSOUTHGATE_GIRL = "Are you going to VIRIDIAN FOREST?\nBe careful, it's a natural maze!",
  TEXT_VIRIDIANFORESTSOUTHGATE_LITTLE_GIRL = "RATTATA may be small, but its\nbite is wicked! Did you get one?",
  TEXT_ROUTE2GATE_OAKS_AIDE = "Hi! Remember me? I'm PROF. OAK's\nAIDE!\nIf you caught 10 kinds of\nPOKéMON, I'm supposed to give\nyou HM05 FLASH!\nSo, how is your POKéDEX?",
  TEXT_ROUTE2GATE_YOUNGSTER = "Once a POKéMON learns FLASH,\nyou can get through dark caves.",
  TEXT_ROUTE2TRADEHOUSE_SCIENTIST = "A fainted POKéMON can't fight!\nBut it can still use moves like\nCUT out on the field!",
  TEXT_ROUTE2TRADEHOUSE_GAMEBOY_KID = "I'm looking for the POKéMON\nABRA! Wanna trade one for my\nMR. MIME?",

  -- Mt Moon 1F
  TEXT_MTMOON1F_HIKER = "WHOA! You shocked me!\nOh, you're just a kid!",
  TEXT_MTMOON1F_HIKER_WIN = "Wow!\nShocked again!",
  TEXT_MTMOON1F_YOUNGSTER1 = "Did you come to explore too?",
  TEXT_MTMOON1F_YOUNGSTER1_WIN = "Losing stinks!",
  TEXT_MTMOON1F_COOLTRAINER_F1 = "Wow! It's way bigger in here\nthan I thought!",
  TEXT_MTMOON1F_COOLTRAINER_F1_WIN = "Oh!\nI lost it!",
  TEXT_MTMOON1F_SUPER_NERD = "What!\nDon't sneak up on me!",
  TEXT_MTMOON1F_SUPER_NERD_WIN = "My POKéMON won't do!",
  TEXT_MTMOON1F_COOLTRAINER_F2 = "What? I'm waiting for my friends\nto find me here.",
  TEXT_MTMOON1F_COOLTRAINER_F2_WIN = "I lost?",
  TEXT_MTMOON1F_YOUNGSTER2 = "Suspicious men are in the cave.\nWhat about you?",
  TEXT_MTMOON1F_YOUNGSTER2_WIN = "You got me!",
  TEXT_MTMOON1F_YOUNGSTER3 = "Go through this cave to get to\nCERULEAN CITY!",
  TEXT_MTMOON1F_YOUNGSTER3_WIN = "I lost.",
  TEXT_MTMOON1F_BEWARE_ZUBAT_SIGN = "Beware!\nZUBAT is a blood sucker!",

  -- Mt Moon B2F
  TEXT_MTMOONB2F_SUPER_NERD = "Hiya! I found these fossils!\nThey're both mine!",
  TEXT_MTMOONB2F_SUPER_NERD_WIN = "All right!\nWe'll each take one!",
  TEXT_MTMOONB2F_ROCKET1 = "TEAM ROCKET will find fossils,\nrevive them and sell them!",
  TEXT_MTMOONB2F_ROCKET1_WIN = "Urgh!\nNow I'm mad!",
  TEXT_MTMOONB2F_ROCKET2 = "We, TEAM ROCKET, are POKéMON\ngangsters!",
  TEXT_MTMOONB2F_ROCKET2_WIN = "I blew it!",
  TEXT_MTMOONB2F_ROCKET3 = "We're pulling a big job here!\nGet lost, kid!",
  TEXT_MTMOONB2F_ROCKET3_WIN = "So, you are good...",
  TEXT_MTMOONB2F_ROCKET4 = "Little kids shouldn't be messing\naround with grown-ups!",
  TEXT_MTMOONB2F_ROCKET4_WIN = "I'm steamed!",
  TEXT_MTMOONB2F_DOME_FOSSIL = "You want the DOME FOSSIL?",
  TEXT_MTMOONB2F_HELIX_FOSSIL = "You want the HELIX FOSSIL?",

  -- Safari Zone (Gen 2 Kanto Canon)
  TEXT_SAFARIZONECENTER_REST_HOUSE_SIGN = "REST HOUSE\nTake a break from your safari!",
  TEXT_SAFARIZONECENTER_TRAINER_TIPS_SIGN = "TRAINER TIPS\nExplore each zone of the SAFARI PARK to encounter different wild POKéMON!",
  TEXT_SAFARIZONECENTERRESTHOUSE_GIRL = "SARA: Where did my boyfriend,\nERIK, go? We were supposed to\nexplore the park together!",
  TEXT_SAFARIZONECENTERRESTHOUSE_SCIENTIST = "I'm researching rare POKéMON\nspecies from JOHTO and HOENN\nthat thrive in this park!",

  -- Safari Zone Gate
  TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1 = "Welcome to the restored\nKANTO SAFARI PRESERVE!\nCatch all the wild POKéMON you\ncan find across all 4 zones!",
  TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER2 = "The SAFARI PRESERVE has 4\nzones in it.\nEach area is home to different\nrare POKéMON!\nExplore deep to find hidden items!",

  -- Safari Zone East & Rest House
  TEXT_SAFARIZONEEAST_REST_HOUSE_SIGN = "REST HOUSE",
  TEXT_SAFARIZONEEAST_SIGN = "AREA 1 (EAST)\nWEST: CENTER AREA\nNORTH: AREA 2",
  TEXT_SAFARIZONEEAST_TRAINER_TIPS = "TRAINER TIPS\nDifferent POKéMON appear depending\non the time of day! Check back at night!",
  TEXT_SAFARIZONEEASTRESTHOUSE_ROCKER = "I caught a rare CHANSEY here!\nThat makes this entire trip\nworthwhile!",
  TEXT_SAFARIZONEEASTRESTHOUSE_SCIENTIST = "How many POKéMON did you catch?\nI'm bushed from hiking across\nthe lakes!",
  TEXT_SAFARIZONEEASTRESTHOUSE_SILPHWORKERM = "Whew! I came from SILPH CO.\nin SAFFRON to take a vacation here!",

  -- Safari Zone North & Rest House
  TEXT_SAFARIZONENORTH_REST_HOUSE_SIGN = "REST HOUSE",
  TEXT_SAFARIZONENORTH_SIGN = "AREA 2 (NORTH)\nSOUTH: CENTER AREA\nWEST: AREA 3",
  TEXT_SAFARIZONENORTH_TRAINER_TIPS_1 = "TRAINER TIPS\nThe SECRET HOUSE is located\ndeep in AREA 3!",
  TEXT_SAFARIZONENORTH_TRAINER_TIPS_2 = "TRAINER TIPS\nWin a special prize for reaching\nthe SECRET HOUSE!",
  TEXT_SAFARIZONENORTH_TRAINER_TIPS_3 = "TRAINER TIPS\nZigzag through grassy areas\nto flush out rare POKéMON!",
  TEXT_SAFARIZONENORTHRESTHOUSE_GENTLEMAN = "My EEVEE evolved into ESPEON\nduring the day, and my friend's\nbecame UMBREON at night!\nIsn't friendship amazing?",
  TEXT_SAFARIZONENORTHRESTHOUSE_SAFARIWORKER = "Go to the deepest part of the\npark in AREA 3.\nThere is a SECRET HOUSE with\na grand prize!",
  TEXT_SAFARIZONENORTHRESTHOUSE_SCIENTIST = "You can keep any rare item you\nfind on the ground here!",

  -- Safari Zone West & Rest House
  TEXT_SAFARIZONEWEST_FIND_WARDENS_TEETH_SIGN = "SAFARI NOTICE\nThe WARDEN is abroad on vacation,\nbut the nature preserve is open!\nExplore deep to find rare items!",
  TEXT_SAFARIZONEWEST_REST_HOUSE_SIGN = "REST HOUSE",
  TEXT_SAFARIZONEWEST_SIGN = "AREA 3 (WEST)\nEAST: CENTER AREA\nNORTH: AREA 2",
  TEXT_SAFARIZONEWEST_TRAINER_TIPS = "TRAINER TIPS\nDeep in AREA 3 lies the\nSECRET HOUSE!",
  TEXT_SAFARIZONEWESTRESTHOUSE_COOLTRAINERM = "Some wild POKéMON here hold\nrare items when caught!",
  TEXT_SAFARIZONEWESTRESTHOUSE_SCIENTIST = "The natural ponds here are home\nto rare water-type POKéMON!",
  TEXT_SAFARIZONEWESTRESTHOUSE_SILPHWORKERF = "I hiked all the way out here\nto explore the scenic plateaus!",

  -- Safari Zone Secret House
  TEXT_SAFARIZONESECRETHOUSE_FISHING_GURU = "Ah! Finally!\nYou're the first person to reach\nthe SECRET HOUSE!\n\nAs a grand reward for navigating\nthe preserve, take this rare prize!",


  -- Seafoam / Cerulean Cave / Mt Moon Rival / Gyms
  TEXT_SEAFOAMISLANDSB4F_ARTICUNO = "Gyaoo!",
  TEXT_ARTICUNO_BATTLE = "Gyaoo!",
  TEXT_SEAFOAMISLANDSB4F_BOULDERS_SIGN = "Boulders might change the flow\nof water!",
  TEXT_SEAFOAMISLANDSB4F_DANGER_SIGN = "DANGER\nFast current!",
  TEXT_CERULEANCAVEB1F_MEWTWO = "Mew!",
  TEXT_MEWTWO_BATTLE = "Mew!",
  TEXT_CINNABARGYM_BLAINE = "Hah! I am BLAINE, the red-hot\nGym Leader of CINNABAR!",
  TEXT_CINNABAR_GYM_STATUE = "CINNABAR ISLAND POKéMON GYM\nLEADER: BLAINE\nWINNING TRAINERS:\n<RIVAL>",
  TEXT_MT_MOON_SILVER_RIVAL = "Hold it!\nYou thought you could sneak\nthrough MT. MOON?\n\nLet's see if you've gotten\nany stronger!",
  TEXT_MT_MOON_SILVER_RIVAL_WIN = "...I lost again?\nI came to KANTO to train,\nbut you're still ahead...\n\nDon't get cocky!\nI will become the greatest\ntrainer in the world!",
  TEXT_MT_MOON_SILVER_RIVAL_SEEN = "... ... ...\fIt's been a while,\n<PLAYER>.\f...Since I lost to\nyou, I thought\nabout what I was\nlacking with my\nPOKéMON...\fAnd we came up\nwith an answer.\f<PLAYER>, now we'll\nshow you!",
  TEXT_MT_MOON_SILVER_RIVAL_DEFEAT = "... ... ...\fI thought I raised\nmy POKéMON to be\nthe best they\ncould be...\f...But it still\nwasn't enough...",
  TEXT_MT_MOON_SILVER_RIVAL_AFTER = "... ... ...\f...You won, fair\nand square.\fI admit it. But\nthis isn't the\nend.\fI'm going to be\nthe greatest POKé-\nMON trainer ever.\fBecause these guys\nare behind me.\f...Listen, <PLAYER>.\fOne of these days\nI'm going to prove\nhow good I am by\nbeating you.",

  -- Rock Tunnel 1F, B1F, and PokeCenter
  TEXT_ROCKTUNNEL1F_HIKER1 = "This tunnel goes a long way, kid!",
  TEXT_ROCKTUNNEL1F_HIKER1_WIN = "Doh! You win!",
  TEXT_ROCKTUNNEL1F_HIKER2 = "Hmm. Maybe I'm lost in here...",
  TEXT_ROCKTUNNEL1F_HIKER2_WIN = "Ease up! What am I doing? Which way is out?",
  TEXT_ROCKTUNNEL1F_HIKER3 = "Outsiders like you need to show me some respect!",
  TEXT_ROCKTUNNEL1F_HIKER3_WIN = "I give!",
  TEXT_ROCKTUNNEL1F_SUPER_NERD = "POKéMON fight! Ready, go!",
  TEXT_ROCKTUNNEL1F_SUPER_NERD_WIN = "Game over!",
  TEXT_ROCKTUNNEL1F_COOLTRAINER_F1 = "Eek! Don't try anything funny in the dark!",
  TEXT_ROCKTUNNEL1F_COOLTRAINER_F1_WIN = "It was too dark!",
  TEXT_ROCKTUNNEL1F_COOLTRAINER_F2 = "I came this far for POKéMON!",
  TEXT_ROCKTUNNEL1F_COOLTRAINER_F2_WIN = "I'm out of POKéMON!",
  TEXT_ROCKTUNNEL1F_COOLTRAINER_F3 = "You have POKéMON! Let's start!",
  TEXT_ROCKTUNNEL1F_COOLTRAINER_F3_WIN = "You play hard!",
  TEXT_ROCKTUNNEL1F_SIGN = "ROCK TUNNEL\nCERULEAN CITY - LAVENDER TOWN",
  TEXT_ROCKTUNNELB1F_COOLTRAINER_F1 = "Hikers leave twigs as trail markers.",
  TEXT_ROCKTUNNELB1F_COOLTRAINER_F1_WIN = "Ohhh! I did my best!",
  TEXT_ROCKTUNNELB1F_HIKER1 = "Hahaha! Can you beat my power?",
  TEXT_ROCKTUNNELB1F_HIKER1_WIN = "Oops! Out-muscled!",
  TEXT_ROCKTUNNELB1F_SUPER_NERD1 = "You have a POKéDEX? I want one too!",
  TEXT_ROCKTUNNELB1F_SUPER_NERD1_WIN = "Shoot! I'm so jealous!",
  TEXT_ROCKTUNNELB1F_SUPER_NERD2 = "Do you know about costume players?",
  TEXT_ROCKTUNNELB1F_SUPER_NERD2_WIN = "Well, that's that.",
  TEXT_ROCKTUNNELB1F_HIKER2 = "My POKéMON techniques will leave you crying!",
  TEXT_ROCKTUNNELB1F_HIKER2_WIN = "I give! You're a better technician!",
  TEXT_ROCKTUNNELB1F_COOLTRAINER_F2 = "I don't often come here, but I will fight you!",
  TEXT_ROCKTUNNELB1F_COOLTRAINER_F2_WIN = "Oh! I lost!",
  TEXT_ROCKTUNNELB1F_HIKER3 = "Hit me with your best shot!",
  TEXT_ROCKTUNNELB1F_HIKER3_WIN = "Fired away!",
  TEXT_ROCKTUNNELB1F_SUPER_NERD3 = "I draw POKéMON when I'm home.",
  TEXT_ROCKTUNNELB1F_SUPER_NERD3_WIN = "Whew! I'm exhausted!",
  TEXT_ROCKTUNNELPOKECENTER_FISHER = "I sold a useless NUGGET for ¥5000!",
  TEXT_ROCKTUNNELPOKECENTER_GENTLEMAN = "The element types of POKéMON make them stronger or weaker!",
  TEXT_ROCKTUNNELPOKECENTER_GUY = "I heard that GHOSTs haunt LAVENDER TOWN!",
}

for _, v in pairs(DUNGEON_TEXT) do
  if type(v) == "string" then
    DUNGEON_TEXT[v] = v
  end
end

RestoredDungeons.DUNGEON_TEXT = DUNGEON_TEXT
RestoredDungeons.ITEM_INDEX_MAP = ITEM_INDEX_MAP

local RIVAL_MOVEMENTS = {
  MT_MOON_SILVER_APPROACH = { 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x47 },
  MT_MOON_SILVER_EXIT = { 0x0f, 0x0c, 0x0c, 0x0c, 0x47 },
  MT_MOON_SILVER_APPROACH_LEFT = { 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x47 },
  MT_MOON_SILVER_EXIT_LEFT = { 0x0f, 0x0c, 0x0c, 0x0c, 0x47 },
  MT_MOON_SILVER_APPROACH_RIGHT = { 0x0f, 0x0c, 0x0c, 0x0c, 0x0c, 0x0c, 0x47 },
  MT_MOON_SILVER_EXIT_RIGHT = { 0x0e, 0x0c, 0x0c, 0x0c, 0x47 },
}

local MT_MOON_RIVAL_LEFT_SCRIPT = {
  { op = "checkevent", event = 793 },
  { op = "iftrue", script = { { op = "end" } } },
  { op = "turnobject", object = 0, facing = 1 },
  { op = "showemote", emote = 0, object = 0, frames = 15 },
  { op = "pause", frames = 15 },
  { op = "setlasttalked", object = 15 },
  { op = "applymovement", object = 15, movement = "MT_MOON_SILVER_APPROACH_LEFT" },
  -- VM reads cmd.id (ROM extract form); 31=Music_LookRival, 32=Music_AfterTheRivalFight
  { op = "playmusic", id = 31 },
  { op = "opentext" },
  { op = "rawtext", text = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_SEEN },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "winlosstext", winText = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_DEFEAT, lossText = "Humph! As expected." },
  -- Gold RIVAL2 index 42; member 201+ avoids Indigo rematch slots 1–3.
  { op = "loadtrainer", class = 42, member = 201 },
  { op = "startbattle" },
  { op = "dontrestartmapmusic" },
  { op = "reloadmapafterbattle" },
  { op = "playmusic", id = 32 },
  { op = "opentext" },
  { op = "rawtext", text = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_AFTER },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "turnobject", object = 0, facing = 3 },
  { op = "applymovement", object = 15, movement = "MT_MOON_SILVER_EXIT_LEFT" },
  { op = "disappear", object = 15 },
  { op = "setscene", scene = 1 },
  { op = "setevent", event = 793 },
  { op = "setevent", event = 1914 },
  { op = "setevent", event = 2998 },
  { op = "setevent", event = 2999 },
  { op = "playmapmusic" },
  { op = "end" },
}

local MT_MOON_RIVAL_RIGHT_SCRIPT = {
  { op = "checkevent", event = 793 },
  { op = "iftrue", script = { { op = "end" } } },
  { op = "turnobject", object = 0, facing = 1 },
  { op = "showemote", emote = 0, object = 0, frames = 15 },
  { op = "pause", frames = 15 },
  { op = "setlasttalked", object = 15 },
  { op = "applymovement", object = 15, movement = "MT_MOON_SILVER_APPROACH_RIGHT" },
  { op = "playmusic", id = 31 },
  { op = "opentext" },
  { op = "rawtext", text = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_SEEN },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "winlosstext", winText = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_DEFEAT, lossText = "Humph! As expected." },
  { op = "loadtrainer", class = 42, member = 201 },
  { op = "startbattle" },
  { op = "dontrestartmapmusic" },
  { op = "reloadmapafterbattle" },
  { op = "playmusic", id = 32 },
  { op = "opentext" },
  { op = "rawtext", text = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_AFTER },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "turnobject", object = 0, facing = 2 },
  { op = "applymovement", object = 15, movement = "MT_MOON_SILVER_EXIT_RIGHT" },
  { op = "disappear", object = 15 },
  { op = "setscene", scene = 1 },
  { op = "setevent", event = 793 },
  { op = "setevent", event = 1914 },
  { op = "setevent", event = 2998 },
  { op = "setevent", event = 2999 },
  { op = "playmapmusic" },
  { op = "end" },
}

local MT_MOON_RIVAL_SCENE_SCRIPT = MT_MOON_RIVAL_LEFT_SCRIPT

-- Final Kanto rival lives on B2F (tucked away), not the 1F entrance ambush.
local KANTO_BADGE_FLAGS = {
  "ENGINE_BOULDERBADGE",
  "ENGINE_CASCADEBADGE",
  "ENGINE_THUNDERBADGE",
  "ENGINE_RAINBOWBADGE",
  "ENGINE_SOULBADGE",
  "ENGINE_MARSHBADGE",
  "ENGINE_VOLCANOBADGE",
  "ENGINE_EARTHBADGE",
}

local function isMtMoon1fMapId(mapId)
  return mapId == "MT_MOON_1F_KR"
    or mapId == "MT_MOON_1F"
    or mapId == "MOUNT_MOON"
    or mapId == "MOUNT_MOON_1F"
    or mapId == "MT_MOON"
end

local function isMtMoonB2fMapId(mapId)
  return mapId == "MT_MOON_B2F_KR"
    or mapId == "MT_MOON_B2F"
    or mapId == "MOUNT_MOON_B2F"
    or mapId == "MTMOON_B2F"
end

-- Strip legacy 1F coord-event ambush (wrong level, sets cap flag too early).
local function stripMtMoon1fSilverAmbush(mdef)
  if not mdef then return end
  local kept = {}
  for _, obj in ipairs(mdef.objects or {}) do
    if obj.name ~= "MT_MOON_1F_SILVER_RIVAL" and not obj.isRivalEvent then
      kept[#kept + 1] = obj
    end
  end
  mdef.objects = kept
  mdef.coordEvents = {}
end

local function buildKantoBadgeGateScript(rejectText, bodyScript)
  local script = {}
  for _, flag in ipairs(KANTO_BADGE_FLAGS) do
    script[#script + 1] = { op = "checkflag", flag = flag }
    script[#script + 1] = {
      op = "iffalse",
      script = {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "rawtext", text = rejectText },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      },
    }
  end
  for _, cmd in ipairs(bodyScript) do
    script[#script + 1] = cmd
  end
  return script
end

local MT_MOON_B2F_SILVER_BATTLE_SCRIPT = {
  { op = "faceplayer" },
  { op = "opentext" },
  { op = "rawtext", text = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_SEEN },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "winlosstext", winText = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_DEFEAT, lossText = "Humph! As expected." },
  { op = "loadtrainer", class = 42, member = 210 },
  { op = "startbattle" },
  { op = "dontrestartmapmusic" },
  { op = "reloadmapafterbattle" },
  { op = "playmusic", id = 32 },
  { op = "opentext" },
  { op = "rawtext", text = DUNGEON_TEXT.TEXT_MT_MOON_SILVER_RIVAL_AFTER },
  { op = "waitbutton" },
  { op = "closetext" },
  { op = "setevent", event = 793 },
  { op = "setevent", event = 1914 },
  { op = "setevent", event = 2998 },
  { op = "playmapmusic" },
  { op = "end" },
}

local MT_MOON_B2F_SILVER_SCRIPT = buildKantoBadgeGateScript(
  "…You again?\n\nI've been training in the depths of MT. MOON.\nBut you're not ready yet.\n\nBeat all eight KANTO GYM LEADERS first!",
  MT_MOON_B2F_SILVER_BATTLE_SCRIPT
)

table.insert(MT_MOON_B2F_SILVER_SCRIPT, 1, {
  op = "iftrue",
  script = {
    { op = "faceplayer" },
    { op = "opentext" },
    { op = "rawtext", text = "…Don't get in my way.\nI'm still training to surpass RED." },
    { op = "waitbutton" },
    { op = "closetext" },
    { op = "end" },
  },
})
table.insert(MT_MOON_B2F_SILVER_SCRIPT, 1, { op = "checkevent", event = 793 })

local function ensureMtMoonB2fSilverRival(mdef)
  if not mdef then return end
  mdef.objects = mdef.objects or {}

  local rival = nil
  for _, obj in ipairs(mdef.objects) do
    if obj.name == "MTMOONB2F_SILVER_RIVAL"
        or obj.name == "MT_MOON_B2F_SILVER_RIVAL"
        or obj.isRivalEvent then
      rival = obj
      break
    end
  end

  if not rival then
    rival = {
      index = 10,
      name = "MTMOONB2F_SILVER_RIVAL",
      sprite = "SPRITE_RIVAL",
      x = 3,
      y = 2,
      range = "DOWN",
      movement = 6,
      sight = 0,
      event = 2998,
      eventFlag = 2998,
      isRivalEvent = true,
      level = 78,
      trainerClass = "RIVAL2",
      trainerParty = 210,
      text = "TEXT_MT_MOON_SILVER_RIVAL_SEEN",
    }
    mdef.objects[#mdef.objects + 1] = rival
  end

  rival.name = "MTMOONB2F_SILVER_RIVAL"
  rival.x = 3
  rival.y = 2
  rival.sight = 0
  rival.range = "DOWN"
  rival.movement = 6
  rival.sprite = "SPRITE_RIVAL"
  rival.event = 2998
  rival.eventFlag = 2998
  rival.isRivalEvent = true
  rival.level = 78
  rival.trainerClass = "RIVAL2"
  rival.trainerParty = 210
  rival.scriptKey = MT_MOON_B2F_SILVER_SCRIPT
  rival.trainer = nil
end

-- Curated Gen 2 / Gen 3 post-game rosters (Lv 46–50) for restored Kanto dungeons
local DUNGEON_ROSTERS = {
  -- MT MOON 1F
  MTMOON1F_HIKER = {
    classId = "OPP_HIKER",
    classNum = 9,
    member = 1,
    event = 2101,
    className = "HIKER",
    name = "MARCOS",
    baseMoney = 32,
    roster = {
      { species = "GRAVELER", level = 47 },
      { species = "LAIRON", level = 47 },
      { species = "GOLEM", level = 48 },
    }
  },
  MTMOON1F_YOUNGSTER1 = {
    classId = "OPP_YOUNGSTER",
    classNum = 1,
    member = 1,
    event = 2102,
    className = "YOUNGSTER",
    name = "JOSH",
    baseMoney = 16,
    roster = {
      { species = "RATICATE", level = 46 },
      { species = "LINOONE", level = 47 },
      { species = "SWELLOW", level = 47 },
    }
  },
  MTMOON1F_COOLTRAINER_F1 = {
    classId = "OPP_COOLTRAINER_F",
    classNum = 32,
    member = 1,
    event = 2103,
    className = "COOLTRAINER",
    name = "MIRIAM",
    baseMoney = 35,
    roster = {
      { species = "CLEFABLE", level = 48 },
      { species = "WIGGLYTUFF", level = 48 },
      { species = "GARDEVOIR", level = 49 },
    }
  },
  MTMOON1F_SUPER_NERD = {
    classId = "OPP_SUPER_NERD",
    classNum = 8,
    member = 1,
    event = 2104,
    className = "SUPER NERD",
    name = "JOVAN",
    baseMoney = 25,
    roster = {
      { species = "MAGNETON", level = 47 },
      { species = "MUK", level = 47 },
      { species = "METANG", level = 48 },
    }
  },
  MTMOON1F_COOLTRAINER_F2 = {
    classId = "OPP_COOLTRAINER_F",
    classNum = 32,
    member = 2,
    event = 2105,
    className = "COOLTRAINER",
    name = "IRIS",
    baseMoney = 35,
    roster = {
      { species = "BELLOSSOM", level = 48 },
      { species = "VILEPLUME", level = 48 },
      { species = "ROSELIA", level = 49 },
    }
  },
  MTMOON1F_YOUNGSTER2 = {
    classId = "OPP_YOUNGSTER",
    classNum = 1,
    member = 2,
    event = 2106,
    className = "YOUNGSTER",
    name = "WARREN",
    baseMoney = 16,
    roster = {
      { species = "SANDSLASH", level = 47 },
      { species = "MANECTRIC", level = 47 },
      { species = "MIGHTYENA", level = 48 },
    }
  },
  MTMOON1F_BUG_CATCHER = {
    classId = "OPP_BUG_CATCHER",
    classNum = 2,
    member = 1,
    event = 2107,
    className = "BUG CATCHER",
    name = "KENT",
    baseMoney = 12,
    roster = {
      { species = "SCIZOR", level = 48 },
      { species = "PINSIR", level = 48 },
      { species = "HERACROSS", level = 49 },
    }
  },

  -- MT MOON B2F
  MTMOONB2F_SUPER_NERD = {
    classId = "OPP_SUPER_NERD",
    classNum = 8,
    member = 2,
    event = 2201,
    className = "SUPER NERD",
    name = "MIGUEL",
    baseMoney = 24,
    roster = {
      { species = "MUK", level = 49 },
      { species = "WEEZING", level = 49 },
      { species = "PORYGON2", level = 50 },
    }
  },
  MTMOONB2F_ROCKET1 = {
    classId = "OPP_ROCKET",
    classNum = 30,
    member = 1,
    event = 2202,
    -- Gen2 HUD is class display + trainer name → "ROCKET GRUNT".
    className = "ROCKET",
    name = "GRUNT",
    baseMoney = 40,
    roster = {
      { species = "GOLBAT", level = 48 },
      { species = "RATICATE", level = 48 },
      { species = "MIGHTYENA", level = 48 },
    }
  },
  MTMOONB2F_ROCKET2 = {
    classId = "OPP_ROCKET",
    classNum = 30,
    member = 2,
    event = 2203,
    -- Gen2 HUD is class display + trainer name → "ROCKET GRUNT".
    className = "ROCKET",
    name = "GRUNT",
    baseMoney = 40,
    roster = {
      { species = "HOUNDOOM", level = 49 },
      { species = "ARBOK", level = 49 },
      { species = "SABLEYE", level = 49 },
    }
  },
  MTMOONB2F_ROCKET3 = {
    classId = "OPP_ROCKET",
    classNum = 30,
    member = 3,
    event = 2204,
    -- Gen2 HUD is class display + trainer name → "ROCKET GRUNT".
    className = "ROCKET",
    name = "GRUNT",
    baseMoney = 40,
    roster = {
      { species = "WEEZING", level = 49 },
      { species = "HYPNO", level = 49 },
      { species = "CACTURNE", level = 49 },
    }
  },
  MTMOONB2F_ROCKET4 = {
    classId = "OPP_ROCKET",
    classNum = 30,
    member = 4,
    event = 2205,
    -- Gen2 HUD is class display + trainer name → "ROCKET GRUNT".
    className = "ROCKET",
    name = "GRUNT",
    baseMoney = 40,
    roster = {
      { species = "MACHAMP", level = 50 },
      { species = "TYRANITAR", level = 50 },
      { species = "SHIFTRY", level = 50 },
    }
  },

  -- VIRIDIAN FOREST
  VIRIDIANFOREST_YOUNGSTER1 = {
    classId = "OPP_BUG_CATCHER",
    classNum = 2,
    member = 1,
    event = 2052,
    className = "BUG CATCHER",
    name = "DOUG",
    baseMoney = 16,
    roster = {
      { species = "SCIZOR", level = 48 },
      { species = "PINSIR", level = 48 },
      { species = "HERACROSS", level = 49 },
    }
  },
  VIRIDIANFOREST_YOUNGSTER3 = {
    classId = "OPP_BUG_CATCHER",
    classNum = 2,
    member = 2,
    event = 2053,
    className = "BUG CATCHER",
    name = "SAMMY",
    baseMoney = 16,
    roster = {
      { species = "YANMA", level = 48 },
      { species = "FORRETRESS", level = 48 },
      { species = "DUSTOX", level = 49 },
    }
  },
  VIRIDIANFOREST_YOUNGSTER4 = {
    classId = "OPP_BUG_CATCHER",
    classNum = 2,
    member = 3,
    event = 2054,
    className = "BUG CATCHER",
    name = "CHARLIE",
    baseMoney = 16,
    roster = {
      { species = "SHUCKLE", level = 48 },
      { species = "PARASECT", level = 48 },
      { species = "VOLBEAT", level = 49 },
    }
  },
  VIRIDIANFOREST_YOUNGSTER2 = {
    classId = "OPP_BUG_CATCHER",
    classNum = 2,
    member = 4,
    event = 2055,
    className = "BUG CATCHER",
    name = "DOUG",
    baseMoney = 16,
    roster = {
      { species = "SCIZOR", level = 48 },
      { species = "PINSIR", level = 48 },
      { species = "HERACROSS", level = 49 },
    }
  },

  -- SPECIAL ENCOUNTERS
  MT_MOON_1F_SILVER_RIVAL = {
    classId = "OPP_RIVAL2",
    classNum = 42,
    member = 1,
    event = 793,
    className = "RIVAL",
    name = "SILVER",
    baseMoney = 65,
    roster = {
      { species = "SNEASEL", level = 58, item = "FOCUS_BAND" },
      { species = "MAGNETON", level = 59, item = "MAGNET" },
      { species = "GENGAR", level = 59, item = "SPELL_TAG" },
      { species = "ALAKAZAM", level = 60, item = "TWISTEDSPOON" },
      { species = "CROBAT", level = 60, item = "SHARP_BEAK" },
      { species = "MEGANIUM", level = 62, item = "MIRACLE_SEED" },
    }
  },
  MT_MOON_1F_SILVER_RIVAL_2 = {
    classId = "OPP_RIVAL2",
    classNum = 42,
    member = 2,
    event = 793,
    className = "RIVAL",
    name = "SILVER",
    baseMoney = 65,
    roster = {
      { species = "SNEASEL", level = 58, item = "FOCUS_BAND" },
      { species = "MAGNETON", level = 59, item = "MAGNET" },
      { species = "GENGAR", level = 59, item = "SPELL_TAG" },
      { species = "ALAKAZAM", level = 60, item = "TWISTEDSPOON" },
      { species = "CROBAT", level = 60, item = "SHARP_BEAK" },
      { species = "TYPHLOSION", level = 62, item = "CHARCOAL" },
    }
  },
  MT_MOON_1F_SILVER_RIVAL_3 = {
    classId = "OPP_RIVAL2",
    classNum = 42,
    member = 3,
    event = 793,
    className = "RIVAL",
    name = "SILVER",
    baseMoney = 65,
    roster = {
      { species = "SNEASEL", level = 58, item = "FOCUS_BAND" },
      { species = "MAGNETON", level = 59, item = "MAGNET" },
      { species = "GENGAR", level = 59, item = "SPELL_TAG" },
      { species = "ALAKAZAM", level = 60, item = "TWISTEDSPOON" },
      { species = "CROBAT", level = 60, item = "SHARP_BEAK" },
      { species = "FERALIGATR", level = 62, item = "MYSTIC_WATER" },
    }
  },
  MTMOONB2F_SILVER_RIVAL = {
    classId = "OPP_RIVAL2",
    classNum = 42,
    member = 10,
    event = 2998,
    className = "RIVAL",
    name = "SILVER",
    baseMoney = 65,
    roster = {
      { species = "SNEASEL", level = 75, item = "FOCUS_BAND" },
      { species = "MAGNETON", level = 76, item = "MAGNET" },
      { species = "GENGAR", level = 76, item = "SPELL_TAG" },
      { species = "ALAKAZAM", level = 77, item = "TWISTEDSPOON" },
      { species = "CROBAT", level = 77, item = "SHARP_BEAK" },
      { species = "TYRANITAR", level = 78, item = "LUM_BERRY" },
    }
  },
  MTMOONB2F_SILVER_RIVAL_2 = {
    classId = "OPP_RIVAL2",
    classNum = 42,
    member = 11,
    event = 2998,
    className = "RIVAL",
    name = "SILVER",
    baseMoney = 65,
    roster = {
      { species = "SNEASEL", level = 75, item = "FOCUS_BAND" },
      { species = "MAGNETON", level = 76, item = "MAGNET" },
      { species = "GENGAR", level = 76, item = "SPELL_TAG" },
      { species = "ALAKAZAM", level = 77, item = "TWISTEDSPOON" },
      { species = "CROBAT", level = 77, item = "SHARP_BEAK" },
      { species = "TYPHLOSION", level = 78, item = "LUM_BERRY" },
    }
  },
  MTMOONB2F_SILVER_RIVAL_3 = {
    classId = "OPP_RIVAL2",
    classNum = 42,
    member = 12,
    event = 2998,
    className = "RIVAL",
    name = "SILVER",
    baseMoney = 65,
    roster = {
      { species = "SNEASEL", level = 75, item = "FOCUS_BAND" },
      { species = "MAGNETON", level = 76, item = "MAGNET" },
      { species = "GENGAR", level = 76, item = "SPELL_TAG" },
      { species = "ALAKAZAM", level = 77, item = "TWISTEDSPOON" },
      { species = "CROBAT", level = 77, item = "SHARP_BEAK" },
      { species = "FERALIGATR", level = 78, item = "LUM_BERRY" },
    }
  },
  SEAFOAM_GYM_BLAINE = {
    classId = "OPP_BLAINE",
    classNum = 39,
    member = 1,
    event = 2401,
    className = "LEADER",
    name = "BLAINE",
    baseMoney = 70,
    roster = {
      { species = "MAGCARGO", level = 68, item = "CHARCOAL" },
      { species = "RAPIDASH", level = 68, item = "CHARCOAL" },
      { species = "MAGMAR", level = 69, item = "CHARCOAL" },
      { species = "NINETALES", level = 69, item = "CHARCOAL" },
      { species = "FLAREON", level = 70, item = "CHARCOAL" },
      { species = "HOUNDOOM", level = 70, item = "CHARCOAL" },
    }
  },

  -- Rock Tunnel 1F
  ROCKTUNNEL1F_HIKER1 = {
    classId = "OPP_HIKER",
    classNum = 9,
    member = 12,
    event = 2301,
    className = "HIKER",
    name = "LENNY",
    baseMoney = 32,
    roster = {
      { species = "GEODUDE", level = 48 },
      { species = "GRAVELER", level = 49 },
      { species = "GOLEM", level = 50 },
    }
  },
  ROCKTUNNEL1F_HIKER2 = {
    classId = "OPP_HIKER",
    classNum = 9,
    member = 13,
    event = 2302,
    className = "HIKER",
    name = "OLIVER",
    baseMoney = 32,
    roster = {
      { species = "MACHOP", level = 48 },
      { species = "ONIX", level = 49 },
      { species = "STEELIX", level = 51 },
    }
  },
  ROCKTUNNEL1F_HIKER3 = {
    classId = "OPP_HIKER",
    classNum = 9,
    member = 14,
    event = 2303,
    className = "HIKER",
    name = "LUCAS",
    baseMoney = 32,
    roster = {
      { species = "GRAVELER", level = 49 },
      { species = "MACHOKE", level = 50 },
    }
  },
  ROCKTUNNEL1F_SUPER_NERD = {
    classId = "OPP_POKEMANIAC",
    classNum = 7,
    member = 7,
    event = 2304,
    className = "POKEMANIAC",
    name = "ASHTON",
    baseMoney = 40,
    roster = {
      { species = "SLOWPOKE", level = 48 },
      { species = "SLOWBRO", level = 50 },
      { species = "LICKITUNG", level = 50 },
    }
  },
  ROCKTUNNEL1F_COOLTRAINER_F1 = {
    classId = "OPP_PICNICKER",
    classNum = 6,
    member = 17,
    event = 2305,
    className = "PICNICKER",
    name = "SOFIA",
    baseMoney = 20,
    roster = {
      { species = "BELLSPROUT", level = 48 },
      { species = "WEEPINBELL", level = 49 },
      { species = "VICTREEBEL", level = 51 },
    }
  },
  ROCKTUNNEL1F_COOLTRAINER_F2 = {
    classId = "OPP_PICNICKER",
    classNum = 6,
    member = 18,
    event = 2306,
    className = "PICNICKER",
    name = "MARTHA",
    baseMoney = 20,
    roster = {
      { species = "MEOWTH", level = 48 },
      { species = "PERSIAN", level = 50 },
      { species = "CLEFABLE", level = 50 },
    }
  },
  ROCKTUNNEL1F_COOLTRAINER_F3 = {
    classId = "OPP_PICNICKER",
    classNum = 6,
    member = 19,
    event = 2307,
    className = "PICNICKER",
    name = "TINA",
    baseMoney = 20,
    roster = {
      { species = "PIKACHU", level = 49 },
      { species = "RAICHU", level = 51 },
      { species = "WIGGLYTUFF", level = 50 },
    }
  },

  -- Rock Tunnel B1F
  ROCKTUNNELB1F_COOLTRAINER_F1 = {
    classId = "OPP_PICNICKER",
    classNum = 6,
    member = 9,
    event = 2308,
    className = "PICNICKER",
    name = "ALICE",
    baseMoney = 20,
    roster = {
      { species = "ODDISH", level = 49 },
      { species = "GLOOM", level = 50 },
      { species = "BELLOSSOM", level = 52 },
    }
  },
  ROCKTUNNELB1F_HIKER1 = {
    classId = "OPP_HIKER",
    classNum = 9,
    member = 9,
    event = 2309,
    className = "HIKER",
    name = "ALLEN",
    baseMoney = 32,
    roster = {
      { species = "GEODUDE", level = 49 },
      { species = "GRAVELER", level = 51 },
      { species = "RHYHORN", level = 52 },
    }
  },
  ROCKTUNNELB1F_SUPER_NERD1 = {
    classId = "OPP_POKEMANIAC",
    classNum = 7,
    member = 3,
    event = 2310,
    className = "POKEMANIAC",
    name = "ERIC",
    baseMoney = 40,
    roster = {
      { species = "CUBONE", level = 49 },
      { species = "MAROWAK", level = 51 },
      { species = "KANGASKHAN", level = 52 },
    }
  },
  ROCKTUNNELB1F_SUPER_NERD2 = {
    classId = "OPP_POKEMANIAC",
    classNum = 7,
    member = 4,
    event = 2311,
    className = "POKEMANIAC",
    name = "AVERY",
    baseMoney = 40,
    roster = {
      { species = "CHARMANDER", level = 49 },
      { species = "CHARMELEON", level = 51 },
      { species = "MAGMAR", level = 52 },
    }
  },
  ROCKTUNNELB1F_HIKER2 = {
    classId = "OPP_HIKER",
    classNum = 9,
    member = 10,
    event = 2312,
    className = "HIKER",
    name = "ERIC",
    baseMoney = 32,
    roster = {
      { species = "MACHOP", level = 49 },
      { species = "MACHOKE", level = 51 },
      { species = "MACHAMP", level = 53 },
    }
  },
  ROCKTUNNELB1F_COOLTRAINER_F2 = {
    classId = "OPP_PICNICKER",
    classNum = 6,
    member = 10,
    event = 2313,
    className = "PICNICKER",
    name = "DANA",
    baseMoney = 20,
    roster = {
      { species = "BUTTERFREE", level = 51 },
      { species = "BEEDRILL", level = 52 },
      { species = "BEAUTIFLY", level = 52 },
    }
  },
  ROCKTUNNELB1F_HIKER3 = {
    classId = "OPP_HIKER",
    classNum = 9,
    member = 11,
    event = 2314,
    className = "HIKER",
    name = "COOPER",
    baseMoney = 32,
    roster = {
      { species = "GRAVELER", level = 51 },
      { species = "LAIRON", level = 52 },
      { species = "GOLEM", level = 53 },
    }
  },
  ROCKTUNNELB1F_SUPER_NERD3 = {
    classId = "OPP_POKEMANIAC",
    classNum = 7,
    member = 5,
    event = 2315,
    className = "POKEMANIAC",
    name = "WINSTON",
    baseMoney = 40,
    roster = {
      { species = "ELECTABUZZ", level = 52 },
      { species = "MAGNETON", level = 52 },
      { species = "PORYGON2", level = 53 },
    }
  },
}

-- Remap Gen1 OPP_* / classNum identities onto Gold class strings + high
-- members (200+). Defeated state is stored on record.event (numeric event
-- flags), not class_member, so remapping members does not require save
-- migration. Stock Johto uses members 1–~100; high indexes isolate KR.
local GEN1_TO_GOLD = {
  OPP_YOUNGSTER = { id = "YOUNGSTER", index = 22 },
  OPP_BUG_CATCHER = { id = "BUG_CATCHER", index = 36 },
  OPP_PICNICKER = { id = "PICNICKER", index = 53 },
  OPP_POKEMANIAC = { id = "POKEMANIAC", index = 30 },
  OPP_SUPER_NERD = { id = "SUPER_NERD", index = 41 },
  OPP_HIKER = { id = "HIKER", index = 44 },
  OPP_ROCKET = { id = "GRUNTM", index = 31 },
  OPP_COOLTRAINER_F = { id = "COOLTRAINERF", index = 28 },
  OPP_BLAINE = { id = "BLAINE", index = 46 },
  OPP_RIVAL2 = { id = "RIVAL2", index = 42 },
}

local GOLD_MEMBERS = {
  MTMOON1F_HIKER = 201,
  MTMOON1F_YOUNGSTER1 = 201,
  MTMOON1F_COOLTRAINER_F1 = 201,
  MTMOON1F_SUPER_NERD = 201,
  MTMOON1F_COOLTRAINER_F2 = 202,
  MTMOON1F_YOUNGSTER2 = 202,
  MTMOON1F_BUG_CATCHER = 201,
  MTMOONB2F_SUPER_NERD = 202,
  MTMOONB2F_ROCKET1 = 201,
  MTMOONB2F_ROCKET2 = 202,
  MTMOONB2F_ROCKET3 = 203,
  MTMOONB2F_ROCKET4 = 204,
  VIRIDIANFOREST_YOUNGSTER1 = 202,
  VIRIDIANFOREST_YOUNGSTER3 = 203,
  VIRIDIANFOREST_YOUNGSTER4 = 204,
  VIRIDIANFOREST_YOUNGSTER2 = 205,
  MT_MOON_1F_SILVER_RIVAL = 201,
  MT_MOON_1F_SILVER_RIVAL_2 = 202,
  MT_MOON_1F_SILVER_RIVAL_3 = 203,
  MTMOONB2F_SILVER_RIVAL = 210,
  MTMOONB2F_SILVER_RIVAL_2 = 211,
  MTMOONB2F_SILVER_RIVAL_3 = 212,
  SEAFOAM_GYM_BLAINE = 201,
  ROCKTUNNEL1F_HIKER1 = 202,
  ROCKTUNNEL1F_HIKER2 = 203,
  ROCKTUNNEL1F_HIKER3 = 204,
  ROCKTUNNEL1F_SUPER_NERD = 201,
  ROCKTUNNEL1F_COOLTRAINER_F1 = 201,
  ROCKTUNNEL1F_COOLTRAINER_F2 = 202,
  ROCKTUNNEL1F_COOLTRAINER_F3 = 203,
  ROCKTUNNELB1F_COOLTRAINER_F1 = 204,
  ROCKTUNNELB1F_HIKER1 = 205,
  ROCKTUNNELB1F_SUPER_NERD1 = 202,
  ROCKTUNNELB1F_SUPER_NERD2 = 203,
  ROCKTUNNELB1F_HIKER2 = 206,
  ROCKTUNNELB1F_COOLTRAINER_F2 = 205,
  ROCKTUNNELB1F_HIKER3 = 207,
  ROCKTUNNELB1F_SUPER_NERD3 = 204,
}

for rosterKey, entry in pairs(DUNGEON_ROSTERS) do
  local gold = GEN1_TO_GOLD[entry.classId]
  if gold then
    entry.gen1ClassId = entry.classId
    entry.gen1ClassNum = entry.classNum
    entry.classId = gold.id
    entry.classNum = gold.index
    entry.goldClass = gold.id
    entry.goldIndex = gold.index
  end
  local mid = GOLD_MEMBERS[rosterKey]
  if mid then
    entry.member = mid
  end
end

-- Fast lookup: object name, Gold class string/index + high member, unique events.
-- Never register Gen1 classNums — those collide with Gold RIVAL1/Falkner/etc.
local DUNGEON_BY_KEY = {}
local eventOwners = {}
for k, entry in pairs(DUNGEON_ROSTERS) do
  DUNGEON_BY_KEY[k] = entry
  local goldId = entry.goldClass or entry.classId
  local goldIdx = entry.goldIndex or entry.classNum
  if goldId and entry.member then
    DUNGEON_BY_KEY[string.format("%s_%s", tostring(goldId), tostring(entry.member))] = entry
  end
  if goldIdx and entry.member then
    DUNGEON_BY_KEY[string.format("%s_%s", tostring(goldIdx), tostring(entry.member))] = entry
  end
  if entry.event then
    local ev = tostring(entry.event)
    if not eventOwners[ev] then
      eventOwners[ev] = k
      DUNGEON_BY_KEY[ev] = entry
    end
    -- Shared events (e.g. Silver starter variants on 793) stay name/member keyed.
  end
end

-- Digletts/Safari pattern: rewrite overworld entrance destMaps to restored *_KR
-- maps in place (never replace the whole warps table), then rebuild _warpAt.
local function aliasRestoredMoonMaps(maps, Data)
  if not (maps and Data and Data.maps) then return end
  local m1 = Data.maps.MT_MOON_1F_KR or Data.maps.MT_MOON_1F
  local mb1 = Data.maps.MT_MOON_B1F_KR or Data.maps.MT_MOON_B1F
  local mb2 = Data.maps.MT_MOON_B2F_KR or Data.maps.MT_MOON_B2F
  if m1 then
    maps.MOUNT_MOON = m1
    maps.MT_MOON = m1
    maps.MOUNT_MOON_1F = m1
    maps.MT_MOON_1F = m1
  end
  if mb1 then
    maps.MOUNT_MOON_B1F = mb1
    maps.MT_MOON_B1F = mb1
  end
  if mb2 then
    maps.MOUNT_MOON_B2F = mb2
    maps.MT_MOON_B2F = mb2
  end
end

local function redirectMtMoonEntranceWarp(w, fromMapId)
  if not w or type(w.destMap) ~= "string" then return end
  local d = w.destMap
  if d == "MT_MOON_POKECENTER" or d == "MT_MOON_POKECENTER_KR" then
    return
  end
  if d == "MT_MOON_B1F" or d == "MOUNT_MOON_B1F" or d == "MT_MOON_B1F_KR" then
    w.destMap = "MT_MOON_B1F_KR"
    if not w.destWarp or w.destWarp < 1 then w.destWarp = 8 end
    return
  end
  if d == "MT_MOON_1F" or d == "MOUNT_MOON" or d == "MT_MOON"
      or d == "MOUNT_MOON_1F" or d == "MT_MOON_1F_KR" then
    if fromMapId == "ROUTE_4" then
      -- Route 4 cave mouths land on the Gen 1 B1F exit pad (warp 8).
      w.destMap = "MT_MOON_B1F_KR"
      w.destWarp = 8
    else
      w.destMap = "MT_MOON_1F_KR"
      if not w.destWarp or w.destWarp < 1 then w.destWarp = 1 end
    end
  end
end

local function patchMtMoonEntranceWarps(warps, fromMapId)
  if type(warps) ~= "table" then return end
  for _, w in ipairs(warps) do
    redirectMtMoonEntranceWarp(w, fromMapId)
  end
end

local function rebuildWarpAt(map)
  if not map or type(map.warps) ~= "table" then return end
  map._warpAt = {}
  for idx, w in ipairs(map.warps) do
    if w and w.x and w.y then
      map._warpAt[w.y * 1024 + w.x] = { index = idx, def = w }
    end
  end
end

-- Gen1 tileset sheets ship under overrides/tilesets/kr_*.png so Gold mobile
-- (versioned gold/assets/generated only) can bake MT_MOON_*_KR without a Red
-- import, and so we never shadow Gold's gate/house/pokecenter/forest sheets.
local function bindGen1TilesetOverrideImages(Data)
  if not (Data and Data.tilesets) then return end
  for tsId, tsDef in pairs(Data.tilesets) do
    if type(tsDef) == "table" and type(tsDef.image) == "string"
        and not tostring(tsId):match("^TILESET_") then
      local base = tsDef.image:match("tilesets/([^/]+)$")
      if base and not base:match("^kr_") then
        tsDef.image = "assets/generated/tilesets/kr_" .. base
      end
    end
  end
end

RestoredDungeons.bindGen1TilesetOverrideImages = bindGen1TilesetOverrideImages

local function normalizeDungeonData(Data)
  if not Data or not Data.maps then return end
  -- Do not short-circuit with a normalized guard: the eventFlag sync below
  -- must run on every apply() so it catches already-cached module data.

  local Campaign = kantoCampaign()
  if Campaign and Campaign.mergeTexts then
    Campaign.mergeTexts(DUNGEON_TEXT)
  end

  bindGen1TilesetOverrideImages(Data)

  if Data.maps.SEAFOAM_GYM then
    local gym = Data.maps.SEAFOAM_GYM
    gym.height = 8
    gym.heightCells = 16
    if gym.blocks and #gym.blocks >= 48 then
      gym.blocks[45] = 5
      gym.blocks[46] = 5
    end
  end

  local SPRITE_MAP = {
    SPRITE_BLAINE = "SPRITE_GRAMPS",
    SPRITE_POKEMON = "SPRITE_MONSTER",
    SPRITE_SILVER = "SPRITE_RIVAL",
  }

  -- 3. Rewrite all objects, signs, and bgEvents to native rawtext scripts
  for mapId, mdef in pairs(Data.maps) do
    if isMtMoon1fMapId(mapId) then
      stripMtMoon1fSilverAmbush(mdef)
    end
    if isMtMoonB2fMapId(mapId) then
      ensureMtMoonB2fSilverRival(mdef)
    end

    if mdef.objects then
      for objIdx, obj in ipairs(mdef.objects) do
        if obj.sprite and SPRITE_MAP[obj.sprite] then
          obj.sprite = SPRITE_MAP[obj.sprite]
        end
        local customDef = DUNGEON_ROSTERS[obj.name] or DUNGEON_BY_KEY[obj.name]
        if not customDef and obj.trainerClass and obj.trainerParty then
          customDef = DUNGEON_BY_KEY[string.format("%s_%s", tostring(obj.trainerClass), tostring(obj.trainerParty))]
        end
        local isBoulder = (obj.sprite and obj.sprite:find("BOULDER")) or (obj.name and obj.name:find("BOULDER"))
        local textKey = obj.text or string.format("TEXT_%s_%d", mapId, objIdx)
        local authenticText = DUNGEON_TEXT[textKey] or obj.text or "Hello!"

        if obj.itemball then
          local rawItem = obj.itemball.item or obj.item or "POKE_BALL"
          local num = ITEM_INDEX_MAP[rawItem] or (tonumber(rawItem))
          obj.itemball.item = num or rawItem
          obj.itemball.itemId = tostring(rawItem)
          obj.itemball.quantity = obj.itemball.quantity or 1
        end

        if obj.name == "MTMOONB2F_SILVER_RIVAL" or obj.name == "MT_MOON_B2F_SILVER_RIVAL" or obj.isRivalEvent then
          ensureMtMoonB2fSilverRival(mdef)
        elseif not obj.trainer and not obj.itemball and not isBoulder then
          if obj.name == "CERULEANCAVEB1F_MEWTWO" or obj.name == "CERULEAN_CAVE_MEWTWO" then
            obj.scriptKey = {
              { op = "faceplayer" },
              { op = "opentext" },
              { op = "rawtext", text = "Mew!" },
              { op = "cry", mon = 150 },
              { op = "closetext" },
              { op = "loadwildmon", species = 150, level = 70 },
              { op = "startbattle" },
              { op = "disappear", object = 254 },
              { op = "reloadmapafterbattle" },
              { op = "end" },
            }
          elseif obj.name == "SEAFOAMISLANDSB4F_ARTICUNO" or obj.name == "SEAFOAM_ARTICUNO" then
            obj.scriptKey = {
              { op = "faceplayer" },
              { op = "opentext" },
              { op = "rawtext", text = "Gyaoo!" },
              { op = "cry", mon = 144 },
              { op = "closetext" },
              { op = "loadwildmon", species = 144, level = 50 },
              { op = "startbattle" },
              { op = "disappear", object = 254 },
              { op = "reloadmapafterbattle" },
              { op = "end" },
            }
          elseif obj.name == "MTMOONB2F_DOME_FOSSIL" then
            obj.scriptKey = {
              { op = "opentext" },
              { op = "rawtext", text = "You want the DOME FOSSIL?" },
              { op = "verbosegiveitem", item = 41 },
              { op = "disappear", object = 254 },
              { op = "waitbutton" },
              { op = "closetext" },
              { op = "end" },
            }
          elseif obj.name == "MTMOONB2F_HELIX_FOSSIL" then
            obj.scriptKey = {
              { op = "opentext" },
              { op = "rawtext", text = "You want the HELIX FOSSIL?" },
              { op = "verbosegiveitem", item = 42 },
              { op = "disappear", object = 254 },
              { op = "waitbutton" },
              { op = "closetext" },
              { op = "end" },
            }
          elseif obj.name == "SAFARIZONESECRETHOUSE_FISHING_GURU" then
            -- Campaign overlay replaces this with the Rocket industry boss.
            -- Keep a non-HM fallback if campaign failed to load.
            obj.scriptKey = {
              { op = "faceplayer" },
              { op = "opentext" },
              { op = "rawtext", text = authenticText },
              { op = "waitbutton" },
              { op = "closetext" },
              { op = "end" },
            }
          else
            obj.scriptKey = {
              { op = "faceplayer" },
              { op = "opentext" },
              { op = "rawtext", text = authenticText },
              { op = "waitbutton" },
              { op = "closetext" },
              { op = "end" },
            }
          end
        end

        if obj.trainer and not obj.isRivalEvent then
          local tr = obj.trainer
          if customDef then
            -- Embed roster on the object so battles work even if global
            -- class/member lookup misses; class/member are Gold-scoped (200+).
            tr.roster = customDef.roster
            tr.party = customDef.roster
            tr.trainerName = customDef.name
            tr.name = customDef.name
            -- className = HUD display ("ROCKET"); classId = art/palette key ("GRUNTM").
            tr.className = customDef.className
            tr.classId = customDef.goldClass or customDef.classId
            tr.class = customDef.goldIndex or customDef.classNum or tr.class
            tr.member = customDef.member or tr.member
            tr.baseMoney = customDef.baseMoney
            tr.event = customDef.event or tr.event
            obj.trainerClass = customDef.goldClass or customDef.classId or obj.trainerClass
            obj.trainerParty = customDef.member or obj.trainerParty
          end
          if obj.eventFlag and not tr.event then
            tr.event = obj.eventFlag
          end
          local authSeen = DUNGEON_TEXT[tr.seenText] or DUNGEON_TEXT[textKey] or tr.seenText or "Let's battle!"
          local authWin = DUNGEON_TEXT[tr.winText] or DUNGEON_TEXT[textKey .. "_WIN"] or tr.winText or "You beat me!"
          tr.seenText = authSeen
          tr.winText = authWin
          tr.scriptKey = obj.afterScriptKey or tr.scriptKey or {
            { op = "opentext" },
            { op = "rawtext", text = authWin },
            { op = "waitbutton" },
            { op = "closetext" },
            { op = "end" },
          }
        end
      end
    end

    if isMtMoonB2fMapId(mapId) then
      ensureMtMoonB2fSilverRival(mdef)
    end

    for _, sign in ipairs(mdef.signs or {}) do
      local authText = DUNGEON_TEXT[sign.text] or sign.text or ""
      sign.scriptKey = {
        { op = "opentext" },
        { op = "rawtext", text = authText },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      }
    end

    for _, bg in ipairs(mdef.bgEvents or {}) do
      local authText = DUNGEON_TEXT[bg.text] or bg.text or ""
      bg.scriptKey = {
        { op = "opentext" },
        { op = "rawtext", text = authText },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      }
    end
  end
end

function RestoredDungeons.apply(mod)
  if not Host.isGen2() then
    return false
  end

  local okData, Data = pcall(require, "mods.Kanto-Reforged.world.restored_dungeons_data")
  if not okData or not Data or not Data.maps then
    if mod and mod.log then
      mod.log:error("Failed to load restored_dungeons_data")
    end
    return false
  end

  -- Normalize data tables unconditionally
  normalizeDungeonData(Data)

  do
    local Campaign = kantoCampaign()
    local save = (mod and mod.game and mod.game.save)
      or (_G.game and _G.game.save)
    if Campaign and Campaign.applyToData then
      Campaign.applyToData(Data, DUNGEON_TEXT, DUNGEON_ROSTERS, DUNGEON_BY_KEY, save)
    end
  end

  local game = _G.game or (mod and mod.game)
  local data = (mod and mod.data)
    or (mod and mod.content and mod.content.maps)
    or (game and game.data)
    or (type(mod) == "table" and (mod.ROUTE_3 or mod.MOUNT_MOON or mod.MT_MOON_1F) and mod)

  -- Monkey-patch Events to handle both numeric indices and string event flags gracefully
  local okEv, Events = pcall(require, "src.world.gen2.Events")
  if okEv and Events and not Events._krPatched then
    Events._krPatched = true
    local origGet = Events.get
    function Events:get(id)
      local num = tonumber(id)
      if num then return origGet(self, num) end
      if type(id) == "string" then
        return self.stringFlags and self.stringFlags[id] or false
      end
      return origGet(self, id)
    end
    local origSet = Events.set
    function Events:set(id, value)
      local num = tonumber(id)
      if num then return origSet(self, num, value) end
      if type(id) == "string" then
        self.stringFlags = self.stringFlags or {}
        self.stringFlags[id] = value and true or false
        return
      end
      return origSet(self, id, value)
    end
  end

  -- Monkey-patch Trainers.lookup and Trainers.party so trainer lookups dynamically resolve
  local okTrainers, Trainers = pcall(require, "src.world.gen2.Trainers")
  if okTrainers and Trainers and not Trainers._krPatched then
    Trainers._krPatched = true
    local origLookup = Trainers.lookup
    function Trainers.lookup(trainerData, class, member)
      member = tonumber(member) or 1
      local customKey = string.format("%s_%s", tostring(class), tostring(member))
      local customDef = DUNGEON_BY_KEY[customKey]
      if customDef then
        return {
          class = class,
          classId = customDef.goldClass or customDef.classId or tostring(class),
          className = customDef.className or tostring(class),
          member = member,
          id = customDef.name .. "_" .. tostring(member),
          name = customDef.name,
          trainerType = "TRAINERTYPE_NORMAL",
          roster = customDef.roster or {},
          attributes = {},
          items = {},
          baseMoney = customDef.baseMoney or 30,
        }
      end

      if trainerData then
        local cache = rawget(trainerData, "_byIndex")
        if not cache then
          cache = {}
          local classes = trainerData.classes or trainerData
          for id, cl in pairs(classes) do
            if type(cl) == "table" then
              -- Only index real class tables (have .trainers/.index), never
              -- flat dungeon leftover tables keyed by bare numbers.
              if cl.index and (cl.trainers or cl.parties) then
                cache[cl.index] = cl
              end
              cl.id = cl.id or id
              if type(id) == "string" then
                cache[id] = cl
              end
            end
          end
          rawset(trainerData, "_byIndex", cache)
        end
        local entry = cache[class] or (trainerData.classes and trainerData.classes[class]) or trainerData[class]
        if type(entry) == "table" and (entry.parties or entry.trainers) then
          local parties = entry.parties or entry.trainers
          local row = parties[member]
          if row then
            local roster = (type(row) == "table" and row.party) and row.party or row
            return {
              class = class,
              classId = entry.id,
              className = entry.name,
              member = member,
              id = (type(row) == "table" and row.id) or (entry.id and (entry.id .. "_" .. member)) or tostring(member),
              name = (type(row) == "table" and row.name) or entry.name or tostring(class),
              trainerType = type(row) == "table" and row.trainerType or nil,
              roster = roster or {},
              attributes = entry.attributes,
              items = (function()
                local out = {}
                for _, id in ipairs(entry.items or {}) do out[#out + 1] = id end
                return out
              end)(),
              baseMoney = entry.baseMoney,
            }
          end
        end
      end
      return origLookup(trainerData, class, member)
    end

    local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
    if okMon and Mon then
      local origParty = Trainers.party
      function Trainers.party(trainerData, class, member)
        local record = Trainers.lookup(trainerData, class, member)
        if not record or not record.roster then
          return origParty(trainerData, class, member)
        end
        local party = {}
        local tData = trainerData or (data and data.pokemon and data) or (game and game.data)
        for _, row in ipairs(record.roster) do
          local moves = {}
          if row.moves then
            for _, moveId in ipairs(row.moves) do
              local mDef = tData and tData.moves and tData.moves[moveId]
              moves[#moves + 1] = { id = moveId, pp = mDef and mDef.pp or 20,
                maxPp = mDef and mDef.pp or 20 }
            end
          end
          local species = row.species
          if type(species) == "number" and tData and tData.pokemon then
            for id, def in pairs(tData.pokemon) do
              if type(def) == "table" and def.index == species then
                species = id
                break
              end
            end
          end
          local mon = Mon.new(tData, species, row.level, {
            moves = moves,
            item = row.item,
            dvs = { attack = 9, defense = 8, speed = 8, special = 8 },
          })
          if mon then party[#party + 1] = mon end
        end
        return party
      end
    end
  end

  -- Synchronize data tables into coreData, game.data, mod.data, and mod.content
  local targets = {}
  local okCore, coreData = pcall(require, "src.core.Data")
  if okCore and coreData then table.insert(targets, coreData) end
  if game and game.data and game.data ~= coreData then table.insert(targets, game.data) end
  if mod and mod.data and mod.data ~= coreData and mod.data ~= (game and game.data) then table.insert(targets, mod.data) end
  if _G.Data and _G.Data ~= coreData then table.insert(targets, _G.Data) end

  for _, d in ipairs(targets) do
    d.gen2Tilesets = d.gen2Tilesets or {}
    d.gen2Palettes = d.gen2Palettes or {}
    d.gen2Palettes.bg = d.gen2Palettes.bg or {}
    d.gen2Palettes.environments = d.gen2Palettes.environments or {}

    if Data.tilesets then
      for tsId, tsDef in pairs(Data.tilesets) do
        d.gen2Tilesets[tsId] = tsDef
        if d.tilesets then d.tilesets[tsId] = tsDef end

        if tsDef.palettes then
          local slots = {}
          local dark_slots = {}
          for slotIdx, palColors in ipairs(tsDef.palettes) do
            local palKey = tsId .. "_" .. tostring(slotIdx)
            d.gen2Palettes.bg[palKey] = palColors
            table.insert(slots, palKey)

            local darkKey = tsId .. "_DARK_" .. tostring(slotIdx)
            if slotIdx == 5 then -- PAL_BG_YELLOW cave entrance blinking slot
              d.gen2Palettes.bg[darkKey] = {
                { 247, 247, 90 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }
              }
            else
              d.gen2Palettes.bg[darkKey] = {
                { 8, 8, 16 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }
              }
            end
            table.insert(dark_slots, darkKey)
          end
          d.gen2Palettes.environments[tsId] = {
            MORN = slots,
            DAY  = slots,
            NITE = slots,
            DARK = dark_slots,
          }
        end
      end
    end

    d.gen2Trainers = d.gen2Trainers or {}
    local gt = d.gen2Trainers
    if gt.classes == nil then rawset(gt, "classes", gt) end

    -- Install dungeon parties into real Gold class tables at high members only.
    -- Never write Gen1 numeric indexes or orphan OPP_* keys — those stomped
    -- RIVAL1/Falkner/etc. Defeated flags remain on record.event, not class_member.
    local function installDungeonMember(trainerRoot, entry)
      if not trainerRoot then return end
      local classes = trainerRoot.classes or trainerRoot
      local classId = entry.goldClass or entry.classId
      if not classId or not entry.member or not entry.roster then return end
      local cls = classes[classId]
      if type(cls) ~= "table" then return end
      cls.trainers = cls.trainers or {}
      cls.trainers[entry.member] = {
        id = string.format("%s_%s", entry.name or classId, tostring(entry.member)),
        index = entry.member,
        name = entry.name,
        party = entry.roster,
        trainerType = "TRAINERTYPE_NORMAL",
      }
    end

    for _, entry in pairs(DUNGEON_ROSTERS) do
      installDungeonMember(d.gen2Trainers, entry)
      installDungeonMember(d.trainers, entry)
    end

    d.gen2Maps = d.gen2Maps or {}
    for mapId, mdef in pairs(Data.maps) do
      d.gen2Maps[mapId] = mdef
      if d.maps then d.maps[mapId] = mdef end
    end

    if Data.gen2Encounters then
      d.gen2Encounters = d.gen2Encounters or {}
      for kind, maps in pairs(Data.gen2Encounters) do
        d.gen2Encounters[kind] = d.gen2Encounters[kind] or {}
        for mapId, tbl in pairs(maps) do
          d.gen2Encounters[kind][mapId] = tbl
          d.gen2Encounters[kind]["KR_" .. mapId] = tbl
        end
      end
    end

    if Data.encounters then
      d.encounters = d.encounters or {}
      for mapId, enc in pairs(Data.encounters) do
        d.encounters[mapId] = enc
        d.encounters["KR_" .. mapId] = enc
      end
    end

    d.gen2Text = d.gen2Text or {}
    for k, v in pairs(DUNGEON_TEXT) do d.gen2Text[k] = v end
    if d.text then
      for k, v in pairs(DUNGEON_TEXT) do d.text[k] = v end
    end

    if d.sprites and not d.sprites.SPRITE_RIVAL then
      d.sprites.SPRITE_RIVAL = d.sprites.SPRITE_BLUE
    end
    if d.sprites and not d.sprites.SPRITE_SILVER then
      d.sprites.SPRITE_SILVER = d.sprites.SPRITE_RIVAL or d.sprites.SPRITE_BLUE
    end
    if d.sprites then
      if not d.sprites.SPRITE_LASS then d.sprites.SPRITE_LASS = d.sprites.SPRITE_GIRL or d.sprites.SPRITE_BEAUTY end
      if not d.sprites.SPRITE_TWIN then d.sprites.SPRITE_TWIN = d.sprites.SPRITE_GIRL or d.sprites.SPRITE_LITTLE_GIRL end
      if not d.sprites.SPRITE_BUG_CATCHER then d.sprites.SPRITE_BUG_CATCHER = d.sprites.SPRITE_YOUNGSTER end
      if not d.sprites.SPRITE_GAMEBOY_KID then d.sprites.SPRITE_GAMEBOY_KID = d.sprites.SPRITE_YOUNGSTER end
    end
    if d.gen2Sprites and not d.gen2Sprites.SPRITE_SILVER then
      d.gen2Sprites.SPRITE_SILVER = d.gen2Sprites.SPRITE_RIVAL
    end
    if d.gen2Sprites then
      if not d.gen2Sprites.SPRITE_GIRL then d.gen2Sprites.SPRITE_GIRL = d.gen2Sprites.SPRITE_LASS end
      if not d.gen2Sprites.SPRITE_LITTLE_GIRL then d.gen2Sprites.SPRITE_LITTLE_GIRL = d.gen2Sprites.SPRITE_TWIN end
    end
  end

  -- Also register with mod.content if available
  if mod and mod.content then
    if mod.content.maps and Data.maps then
      for mapId, mdef in pairs(Data.maps) do
        pcall(function() mod.content.maps:register(mapId, mdef) end)
      end
    end
    if mod.content.tilesets and Data.tilesets then
      for tsId, tsDef in pairs(Data.tilesets) do
        pcall(function() mod.content.tilesets:register(tsId, tsDef) end)
      end
    end
    if mod.content.encounters and Data.gen2Encounters then
      for kind, maps in pairs(Data.gen2Encounters) do
        pcall(function() mod.content.encounters:patch(kind, maps) end)
      end
    end
  end

  -- Monkey-patch World item lookup, load, and setMap
  local okWorld, World = pcall(require, "src.world.gen2.World")
  if okWorld and World and not World._krRestoredHooked then
    World._krRestoredHooked = true

    local origGetItemName = World.getItemName
    function World:getItemName(itemIndex)
      local items = self.game and self.game.data and self.game.data.items
      if items then
        if type(itemIndex) == "string" then
          local def = items[itemIndex] or (ITEM_INDEX_MAP[itemIndex] and items[ITEM_INDEX_MAP[itemIndex]])
          if def and def.name then return def.name end
          for id, d in pairs(items) do
            if type(d) == "table" and (id == itemIndex or d.id == itemIndex) then
              return d.name or id
            end
          end
        elseif type(itemIndex) == "number" then
          local direct = items[itemIndex]
          if direct and direct.name then return direct.name end
          for id, def in pairs(items) do
            if type(def) == "table" and def.index == itemIndex then
              return def.name or id
            end
          end
        end
      end
        if type(itemIndex) == "string" and ITEM_INDEX_MAP[itemIndex] then
          local num = ITEM_INDEX_MAP[itemIndex]
          if items then
            local direct = items[num]
            if direct and direct.name then return direct.name end
            for id, def in pairs(items) do
              if type(def) == "table" and def.index == num then
                return def.name or id
              end
            end
          end
        end
        if origGetItemName then return origGetItemName(self, itemIndex) end
        return tostring(itemIndex):gsub("^ITEM", ""):gsub("_", " ")
      end

    local origTrainerParty = World.trainerParty
    function World:trainerParty(class, member)
      member = tonumber(member) or member or 1
      -- Mt. Moon B2F Silver: member 210 is the Chikorita line slot; remap by rival starter.
      if (class == 42 or class == "RIVAL2") and member == 210 then
        local rs = tonumber(self.save and self.save.rivalStarter) or 1
        if rs >= 1 and rs <= 3 then
          member = 209 + rs
        end
      end
      -- Prefer embedded roster on the engaged trainer object (normalize stamps it).
      local engaged = self.vm and self.vm.trainerObject
      if engaged and type(engaged.roster) == "table" and #engaged.roster > 0 then
        local engClass = engaged.class
        local engMember = engaged.member
        if (engClass == nil or engClass == class) and (engMember == nil or engMember == member) then
          local roster = {}
          for si, slot in ipairs(engaged.roster) do
            roster[si] = {
              species = slot.species,
              level = slot.level,
              item = slot.item or slot.heldItem,
              heldItem = slot.item or slot.heldItem,
            }
          end
          local custom = DUNGEON_BY_KEY[string.format("%s_%s", tostring(class), tostring(member))]
            or DUNGEON_BY_KEY[string.format("%s_%s", tostring(engaged.classId or ""), tostring(member))]
          return {
            class = class,
            classId = engaged.classId or (type(class) == "string" and class) or tostring(class),
            className = engaged.className or "TRAINER",
            name = engaged.name or engaged.trainerName or "TRAINER",
            member = member,
            roster = roster,
            trainerType = "TRAINERTYPE_NORMAL",
            -- Prize.reward(nil) → $0; must carry TRNATTR_BASE_REWARD.
            baseMoney = engaged.baseMoney
              or (custom and custom.baseMoney)
              or 30,
            attributes = engaged.attributes or {},
            items = engaged.items or {},
          }
        end
      end
      -- Exact Gold class_member keys only (high members 200+). No blanket
      -- RIVAL2 redirect — that hijacked Indigo rematches.
      local custom = DUNGEON_BY_KEY[string.format("%s_%s", tostring(class), tostring(member))]
      if custom and custom.roster then
        local roster = {}
        for si, slot in ipairs(custom.roster) do
          roster[si] = {
            species = slot.species,
            level = slot.level,
            item = slot.item or slot.heldItem,
            heldItem = slot.item or slot.heldItem,
          }
        end
        return {
          class = class,
          classId = custom.goldClass or custom.classId or (type(class) == "string" and class) or "RIVAL2",
          className = custom.className or "TRAINER",
          name = custom.name or "TRAINER",
          member = member,
          roster = roster,
          trainerType = "TRAINERTYPE_NORMAL",
          baseMoney = custom.baseMoney or 30,
          attributes = {},
          items = {},
        }
      end
      if origTrainerParty then
        return origTrainerParty(self, class, member)
      end
      return nil
    end

    local origSetMap = World.setMap
    if origSetMap then
      function World:setMap(mapId, cx, cy, facing, opts)
        package.loaded["mods.Kanto-Reforged.world.restored_dungeons_data"] = nil
        local okFresh, freshData = pcall(require, "mods.Kanto-Reforged.world.restored_dungeons_data")
        if okFresh and freshData then
          Data = freshData
          normalizeDungeonData(Data)
        end
        if Data and Data.tilesets then
          for tsId, tsDef in pairs(Data.tilesets) do
            if self.tilesets then self.tilesets[tsId] = tsDef end
            if self.data and self.data.gen2Tilesets then self.data.gen2Tilesets[tsId] = tsDef end
          end
        end
        if self.maps and Data and Data.maps then
          for mid, mdef in pairs(Data.maps) do
            self.maps[mid] = mdef
          end
          aliasRestoredMoonMaps(self.maps, Data)
          self.maps.SEAFOAM_ISLANDS = Data.maps["SEAFOAM_ISLANDS_1F_KR"] or Data.maps["SEAFOAM_ISLANDS_1F"]
          self.maps.CERULEAN_CAVE = Data.maps["CERULEAN_CAVE_1F_KR"] or Data.maps["CERULEAN_CAVE_1F"]
          self.maps.SAFARI_ZONE = Data.maps["SAFARI_ZONE_GATE_KR"] or Data.maps["SAFARI_ZONE_GATE"]
          self.maps.SAFARI_ZONE_GATE = Data.maps["SAFARI_ZONE_GATE_KR"] or Data.maps["SAFARI_ZONE_GATE"]
          local data = self.data or (self.game and self.game.data)
          local mapsContainer = (data and (data.gen2Maps or (data.maps and data.maps.ROUTE_3 and data.maps) or data)) or self.maps
          if mapsContainer then
            if mapsContainer.ROUTE_3 then self.maps.ROUTE_3 = mapsContainer.ROUTE_3 end
            if mapsContainer.ROUTE_4 then self.maps.ROUTE_4 = mapsContainer.ROUTE_4 end
            if mapsContainer.CERULEAN_CITY then self.maps.CERULEAN_CITY = mapsContainer.CERULEAN_CITY end
            if mapsContainer.ROUTE_20 then self.maps.ROUTE_20 = mapsContainer.ROUTE_20 end
            if mapsContainer.FUCHSIA_CITY then self.maps.FUCHSIA_CITY = mapsContainer.FUCHSIA_CITY end
          end
          do
            local Camp = kantoCampaign()
            local save = self.save or (self.game and self.game.save)
            if Camp and Camp.applyToData and Data then
              Camp.applyToData(Data, DUNGEON_TEXT, DUNGEON_ROSTERS, DUNGEON_BY_KEY, save)
            end
            if Camp and Camp.syncFuchsiaSafariDoor and self.maps.FUCHSIA_CITY then
              Camp.syncFuchsiaSafariDoor(self.maps.FUCHSIA_CITY, save)
            end
          end
        end
        if self.sprites then
          if not self.sprites.SPRITE_RIVAL and self.sprites.SPRITE_BLUE then
            self.sprites.SPRITE_RIVAL = self.sprites.SPRITE_BLUE
          end
          if not self.sprites.SPRITE_SILVER and self.sprites.SPRITE_RIVAL then
            self.sprites.SPRITE_SILVER = self.sprites.SPRITE_RIVAL
          end
          if not self.sprites.SPRITE_LASS then self.sprites.SPRITE_LASS = self.sprites.SPRITE_GIRL or self.sprites.SPRITE_BEAUTY end
          if not self.sprites.SPRITE_TWIN then self.sprites.SPRITE_TWIN = self.sprites.SPRITE_GIRL or self.sprites.SPRITE_LITTLE_GIRL end
          if not self.sprites.SPRITE_BUG_CATCHER then self.sprites.SPRITE_BUG_CATCHER = self.sprites.SPRITE_YOUNGSTER end
          if not self.sprites.SPRITE_GAMEBOY_KID then self.sprites.SPRITE_GAMEBOY_KID = self.sprites.SPRITE_YOUNGSTER end
        end
        if self.scripts then
          self.scripts.movements = self.scripts.movements or {}
          for k, v in pairs(RIVAL_MOVEMENTS) do self.scripts.movements[k] = v end
        end
        if self.vm then
          self.vm.movements = self.vm.movements or {}
          for k, v in pairs(RIVAL_MOVEMENTS) do self.vm.movements[k] = v end
        end
        -- Keep Silver coordEvents on the shared KR table (aliases point here).
        -- Do not clear sceneScripts here — that used to wipe the KR map after rename.
        if self.maps then
          local moon1f = self.maps.MT_MOON_1F_KR or self.maps.MT_MOON_1F or self.maps.MOUNT_MOON
          if moon1f then stripMtMoon1fSilverAmbush(moon1f) end
          local moonB2f = self.maps.MT_MOON_B2F_KR or self.maps.MT_MOON_B2F or self.maps.MOUNT_MOON_B2F
          if moonB2f then ensureMtMoonB2fSilverRival(moonB2f) end
        end
        if mapId == "FUCHSIA_CITY" and self.dropMapImages then
          self:dropMapImages("FUCHSIA_CITY")
        end
        local res = origSetMap(self, mapId, cx, cy, facing, opts)
        if self.map and mapId == "FUCHSIA_CITY" then
          local Camp = kantoCampaign()
          local save = self.save or (self.game and self.game.save)
          if Camp and Camp.syncFuchsiaSafariDoor then
            Camp.syncFuchsiaSafariDoor(self.map, save)
          end
          rebuildWarpAt(self.map)
        end

        if self.map and mapId == "VERMILION_CITY" then
          self.map.warps = self.map.warps or {}
          for _, w in ipairs(self.map.warps) do
            if w.destMap == "DIGLETTS_CAVE" or (w.x == 34 and w.y == 7) then
              w.destMap = "DIGLETTS_CAVE_ROUTE_11_KR"
              w.destWarp = 1
            end
          end
          rebuildWarpAt(self.map)
        end

        if self.map and (mapId == "ROUTE_2" or mapId == "ROUTE_2_KR") then
          self.map.warps = self.map.warps or {}
          for _, w in ipairs(self.map.warps) do
            if w.destMap == "DIGLETTS_CAVE" then
              w.destMap = "DIGLETTS_CAVE_ROUTE_2_KR"
              w.destWarp = 1
            end
          end
          rebuildWarpAt(self.map)
        end

        -- Same Digletts/Safari live-patch pattern for Mt Moon overworld mouths.
        if self.map and mapId == "ROUTE_4" then
          self.map.warps = self.map.warps or {}
          patchMtMoonEntranceWarps(self.map.warps, "ROUTE_4")
          rebuildWarpAt(self.map)
        end
        if self.map and mapId == "ROUTE_3" then
          self.map.warps = self.map.warps or {}
          if #self.map.warps < 1 then
            table.insert(self.map.warps, { x = 52, y = 1, destMap = "MT_MOON_1F_KR", destWarp = 1 })
            table.insert(self.map.warps, { x = 53, y = 1, destMap = "MT_MOON_1F_KR", destWarp = 2 })
          else
            patchMtMoonEntranceWarps(self.map.warps, "ROUTE_3")
          end
          rebuildWarpAt(self.map)
        end

        if self.map and Data and Data.maps and Data.maps[mapId] then
          local mdef = Data.maps[mapId]
          local tsDef = Data.tilesets and Data.tilesets[mdef.tileset]
          if tsDef and tsDef.collision then
            self.map.collision = tsDef.collision
          end
        end
        return res
      end
    end


    local Map = package.loaded["src.world.gen2.Map"] or (pcall(require, "src.world.gen2.Map") and package.loaded["src.world.gen2.Map"])
    if Map and Map.new then
      local origMapNew = Map.new
      function Map.new(def, tileset)
        if def and def.connections then
          for _, conn in pairs(def.connections) do
            if type(conn) == "table" then
              if conn.map and not conn.mapId then conn.mapId = conn.map end
              if conn.mapId and not conn.map then conn.map = conn.mapId end
            end
          end
        end
        local m = origMapNew(def, tileset)
        if m and m.connections then
          for _, conn in pairs(m.connections) do
            if type(conn) == "table" then
              if conn.map and not conn.mapId then conn.mapId = conn.map end
              if conn.mapId and not conn.map then conn.map = conn.mapId end
            end
          end
        end
        return m
      end
    end

    local origTakeWarp = World.takeWarp
    if origTakeWarp then
      function World:takeWarp(warpDef)
        if self.maps and Data and Data.maps then
          for mid, mdef in pairs(Data.maps) do
            self.maps[mid] = mdef
          end
          aliasRestoredMoonMaps(self.maps, Data)
          self.maps.SEAFOAM_ISLANDS = Data.maps["SEAFOAM_ISLANDS_1F_KR"] or Data.maps["SEAFOAM_ISLANDS_1F"]
          self.maps.CERULEAN_CAVE = Data.maps["CERULEAN_CAVE_1F_KR"] or Data.maps["CERULEAN_CAVE_1F"]
          self.maps.SAFARI_ZONE = Data.maps["SAFARI_ZONE_GATE_KR"] or Data.maps["SAFARI_ZONE_GATE"]
          self.maps.SAFARI_ZONE_GATE = Data.maps["SAFARI_ZONE_GATE_KR"] or Data.maps["SAFARI_ZONE_GATE"]
          if self.maps.ROUTE_4 and self.maps.ROUTE_4.warps then
            patchMtMoonEntranceWarps(self.maps.ROUTE_4.warps, "ROUTE_4")
          end
          if self.maps.ROUTE_3 and self.maps.ROUTE_3.warps then
            patchMtMoonEntranceWarps(self.maps.ROUTE_3.warps, "ROUTE_3")
          end
          if self.maps.FUCHSIA_CITY then
            local Camp = kantoCampaign()
            local save = self.save or (self.game and self.game.save)
            if Camp and Camp.syncFuchsiaSafariDoor then
              Camp.syncFuchsiaSafariDoor(self.maps.FUCHSIA_CITY, save)
            end
          end

          if self.maps.VERMILION_CITY and self.maps.VERMILION_CITY.warps then
            for _, w in ipairs(self.maps.VERMILION_CITY.warps) do
              if w.destMap == "DIGLETTS_CAVE" or (w.x == 34 and w.y == 7) then
                w.destMap = "DIGLETTS_CAVE_ROUTE_11_KR"
                w.destWarp = 1
              end
            end
          end

          if self.maps.ROUTE_2 and self.maps.ROUTE_2.warps then
            for _, w in ipairs(self.maps.ROUTE_2.warps) do
              if w.destMap == "DIGLETTS_CAVE" then
                w.destMap = "DIGLETTS_CAVE_ROUTE_2_KR"
                w.destWarp = 1
              end
            end
          end
        end

        -- Direct warpDef intercept if destMap is DIGLETTS_CAVE
        if warpDef and warpDef.destMap == "DIGLETTS_CAVE" then
          local curId = self.map and self.map.id
          if curId == "VERMILION_CITY" then
            warpDef = { x = warpDef.x, y = warpDef.y, destMap = "DIGLETTS_CAVE_ROUTE_11_KR", destWarp = 1 }
          elseif curId == "ROUTE_2" or curId == "ROUTE_2_KR" then
            warpDef = { x = warpDef.x, y = warpDef.y, destMap = "DIGLETTS_CAVE_ROUTE_2_KR", destWarp = 1 }
          end
        end

        -- Same Digletts-style intercept for Mt Moon vanilla / Gen2 names
        if warpDef and type(warpDef.destMap) == "string" then
          local curId = self.map and self.map.id
          local d = warpDef.destMap
          if d == "MT_MOON_B1F" or d == "MOUNT_MOON_B1F" then
            warpDef = { x = warpDef.x, y = warpDef.y, destMap = "MT_MOON_B1F_KR", destWarp = warpDef.destWarp or 8 }
          elseif d == "MT_MOON_1F" or d == "MOUNT_MOON" or d == "MT_MOON" or d == "MOUNT_MOON_1F" then
            if curId == "ROUTE_4" then
              warpDef = { x = warpDef.x, y = warpDef.y, destMap = "MT_MOON_B1F_KR", destWarp = 8 }
            else
              warpDef = { x = warpDef.x, y = warpDef.y, destMap = "MT_MOON_1F_KR", destWarp = warpDef.destWarp or 1 }
            end
          end
        end


        -- Handle edge landing adjustments between Safari Zone areas
        if warpDef and warpDef.destMap and warpDef.destMap:find("SAFARI_ZONE") then
          local destMapId, destWarpNumber = self:resolveWarp(warpDef)
          local dest = self.maps and self.maps[destMapId]
          local destWarp = dest and dest.warps and dest.warps[destWarpNumber]
          if destWarp then
            local targetFacing = "down"
            local tx, ty = destWarp.x, destWarp.y
            local wCells = (dest.width or 15) * 2
            local hCells = (dest.height or 13) * 2
            if tx <= 0 then
              tx = 1; targetFacing = "right"
            elseif tx >= wCells - 1 then
              tx = wCells - 2; targetFacing = "left"
            elseif ty <= 0 then
              ty = 1; targetFacing = "down"
            elseif ty >= hCells - 1 then
              ty = hCells - 2; targetFacing = "up"
            end
            return self:runMapSetup(MAPSETUP and MAPSETUP.DOOR or 1, function()
              local ok = self:setMap(destMapId, tx, ty, targetFacing)
              if ok and self.spawnFacing then self:spawnFacing() end
              return ok
            end)
          end
        end

        return origTakeWarp(self, warpDef)
      end
    end

    -- Hook checkWarpOnArrive to trigger area warps on walkable ground in restored Gen 1 / Safari maps
    local origCheckWarpOnArrive = World.checkWarpOnArrive
    if origCheckWarpOnArrive then
      function World:checkWarpOnArrive()
        local p = self.player
        if p and self.map and self.map.id and (self.map.id:find("_KR") or self.map.id:find("SAFARI_ZONE")) then
          local entry = self.map:warpAt(p.cellX, p.cellY)
          if entry and entry.def then
            if not (self.warpsSuppressed and self:warpsSuppressed()) then
              return self:takeWarp(entry.def) and true or false
            end
          end
        end
        return origCheckWarpOnArrive(self)
      end
    end

    -- Hook checkCarpetWhileStanding to trigger edge warps when pressing into the map boundary
    local origCheckCarpet = World.checkCarpetWhileStanding
    if origCheckCarpet then
      function World:checkCarpetWhileStanding()
        local p = self.player
        if p and not p.moving and self.heldDir and self.map and self.map.id and (self.map.id:find("_KR") or self.map.id:find("SAFARI_ZONE")) then
          local entry = self.map:warpAt(p.cellX, p.cellY)
          if entry and entry.def then
            local wCells = (self.map.width or 15) * 2
            local hCells = (self.map.height or 13) * 2
            local isEdge = (p.cellX <= 1 and self.heldDir == "left") or
                           (p.cellX >= wCells - 2 and self.heldDir == "right") or
                           (p.cellY <= 1 and self.heldDir == "up") or
                           (p.cellY >= hCells - 2 and self.heldDir == "down")
            if isEdge or not (self.warpsSuppressed and self:warpsSuppressed()) then
              return self:takeWarp(entry.def) and true or false
            end
          end
        end
        return origCheckCarpet(self)
      end
    end

    -- Hook tryConnection to take edge warps when walking into the boundary of a restored Gen 1 map
    local origTryConnection = World.tryConnection
    if origTryConnection then
      function World:tryConnection(dir)
        local p = self.player
        if p and self.map and self.map.id and (self.map.id:find("_KR") or self.map.id:find("SAFARI_ZONE")) then
          local entry = self.map:warpAt(p.cellX, p.cellY)
          if not entry then
            local dx = (dir == "left" and -1 or dir == "right" and 1 or 0)
            local dy = (dir == "up" and -1 or dir == "down" and 1 or 0)
            entry = self.map:warpAt(p.cellX + dx, p.cellY + dy)
          end
          if entry and entry.def then
            return self:takeWarp(entry.def) and true or false
          end
        end
        return origTryConnection(self, dir)
      end
    end


    -- Expand Save.EVENT_BYTES so high event flag IDs (>= 2048) for restored dungeons and added trainers are preserved in save files
    local okSave, Save = pcall(require, "src.core.gen2.Save")
    if okSave and Save then
      Save.EVENT_BYTES = math.max(Save.EVENT_BYTES or 256, 4096)
    end



    -- Monkey-patch Permissions.doorForcedDirection so interior warp panels (0x7c) never force downward movement
    local okPerm, Permissions = pcall(require, "src.world.gen2.Permissions")
    if okPerm and Permissions and not Permissions._krDoorForcedPatched then
      Permissions._krDoorForcedPatched = true
      local origDoorForced = Permissions.doorForcedDirection
      function Permissions.doorForcedDirection(coll)
        if coll == 0x7c then return nil end
        return origDoorForced(coll)
      end
    end

    -- Monkey-patch BattleState.trainerArt and Palettes.trainerColors so enemy trainer frontpic always resolves
    local okBS, BattleState = pcall(require, "src.ui.gen2.BattleState")
    if okBS and BattleState and not BattleState._krTrainerArtPatched then
      BattleState._krTrainerArtPatched = true
      local origTrainerArt = BattleState.trainerArt
      function BattleState.trainerArt(data, classId)
        if not classId then return nil, false end
        local path, tc = origTrainerArt(data, classId)
        if path then return path, tc end

        local strId = tostring(classId)
        local gt = data and (data.gen2Trainers or data.trainers)
        if gt then
          local classes = gt.classes or gt
          if classes[strId] and type(classes[strId]) == "table" and classes[strId].pic then
            return classes[strId].pic, (classes[strId].trueColor and true or false)
          end
          local oppKey = strId:find("^OPP_") and strId or ("OPP_" .. strId)
          if classes[oppKey] and type(classes[oppKey]) == "table" and classes[oppKey].pic then
            return classes[oppKey].pic, (classes[oppKey].trueColor and true or false)
          end
          if type(classId) == "number" then
            local classDef = (gt._byIndex and gt._byIndex[classId]) or gt[classId]
            if classDef and type(classDef) == "table" then
              if classDef.pic then
                return classDef.pic, (classDef.trueColor and true or false)
              end
              -- Class tables often have no .pic; resolve via menu_gfx trainerPics[id].
              local hud = data and data.gen2MenuGfx and data.gen2MenuGfx.battleHud
              local pics = hud and hud.trainerPics
              if pics and classDef.id and pics[classDef.id] then
                return pics[classDef.id], false
              end
            end
          end
          local normTarget = strId:gsub("^OPP_", ""):gsub("_", ""):gsub("%.", ""):lower()
          for k, classDef in pairs(classes) do
            if type(classDef) == "table" and classDef.pic then
              local normK = tostring(k):gsub("^OPP_", ""):gsub("_", ""):gsub("%.", ""):lower()
              if normK == normTarget then
                return classDef.pic, (classDef.trueColor and true or false)
              end
            end
          end
        end

        local hud = data and data.gen2MenuGfx and data.gen2MenuGfx.battleHud
        local trainerPics = hud and hud.trainerPics
        if trainerPics then
          if trainerPics[strId] then return trainerPics[strId], false end
          local normTarget = strId:gsub("^OPP_", ""):gsub("_", ""):gsub("%.", ""):lower()
          for k, picPath in pairs(trainerPics) do
            local normK = tostring(k):gsub("^OPP_", ""):gsub("_", ""):gsub("%.", ""):lower()
            if normK == normTarget then
              return picPath, false
            end
          end
        end

        return nil, false
      end
    end

    local okPal, Palettes = pcall(require, "src.world.gen2.Palettes")
    if okPal and Palettes and not Palettes._krTrainerPalPatched then
      Palettes._krTrainerPalPatched = true
      local origTrainerColors = Palettes.trainerColors
      function Palettes.trainerColors(data, className)
        if className then
          local strId = tostring(className)
          local trainers = data and data.trainers
          if trainers then
            if trainers[strId] then
              local pair = trainers[strId]
              if pair and pair[1] and pair[2] then
                return {
                  { 255, 255, 255 },
                  { pair[1][1], pair[1][2], pair[1][3] },
                  { pair[2][1], pair[2][2], pair[2][3] },
                  { 0, 0, 0 },
                }
              end
            end
            local normTarget = strId:gsub("^OPP_", ""):gsub("_", ""):gsub("%.", ""):lower()
            for k, pair in pairs(trainers) do
              local normK = tostring(k):gsub("^OPP_", ""):gsub("_", ""):gsub("%.", ""):lower()
              if normK == normTarget and type(pair) == "table" and pair[1] and pair[2] then
                return {
                  { 255, 255, 255 },
                  { pair[1][1], pair[1][2], pair[1][3] },
                  { pair[2][1], pair[2][2], pair[2][3] },
                  { 0, 0, 0 },
                }
              end
            end
          end
        end
        return origTrainerColors(data, className)
      end
    end

    -- Monkey-patch Vm:showText and Vm.new so any dungeon text key or plain text is never displayed as "..."
    local okVm, Vm = pcall(require, "src.script.gen2.Vm")
    if okVm and Vm and not Vm._krPatched then
      Vm._krPatched = true
      local origVmNew = Vm.new
      function Vm.new(scripts, text, events, hooks)
        if text then
          for k, v in pairs(DUNGEON_TEXT) do text[k] = v end
        end
        return origVmNew(scripts, text, events, hooks)
      end

      local origShowText = Vm.showText
      function Vm:showText(textKey)
        local body = textKey and (
          (self.text and self.text[textKey])
          or DUNGEON_TEXT[textKey]
          or (type(textKey) == "string" and not textKey:find("^TEXT_") and textKey)
        )
        if textKey then self.lastTextKey = textKey end
        if not body or body == "" or body == "..." then
          body = DUNGEON_TEXT[textKey] or (type(textKey) == "string" and not textKey:find("^TEXT_") and textKey) or "..."
        end
        if self.stringBuffer and self.stringBuffer ~= "" then
          body = body:gsub("{STRBUF}", self.stringBuffer)
        end
        if self.showTextFn then
          coroutine.yield({ kind = "text", text = body, stay = self:textStays() })
        end
      end
    end

    -- Gold class indexes only (Gen1 OPP_* nums collided with Johto leaders).
    local ClassIndexMap = {}
    for gen1, gold in pairs(GEN1_TO_GOLD) do
      ClassIndexMap[gen1] = gold.index
      ClassIndexMap[gold.id] = gold.index
    end

    local targetMaps = (data and (data.gen2Maps or data.maps or data)) or {}
    local mapIdx = 0
    for mapId, mdef in pairs(targetMaps) do
      mapIdx = mapIdx + 1
      if type(mdef) == "table" and mdef.objects then
        for objIdx, obj in ipairs(mdef.objects) do
          if type(obj) == "table" and obj.trainerClass and not obj.trainer then
            local customDef = DUNGEON_ROSTERS[obj.name]
            local classId = (customDef and (customDef.goldClass or customDef.classId)) or obj.trainerClass
            local classNum = (customDef and (customDef.goldIndex or customDef.classNum))
              or ClassIndexMap[classId] or classId
            local member = (customDef and customDef.member) or obj.trainerParty or 1
            local sight = obj.sight or 3
            local eventNum = (customDef and customDef.event) or obj.event or (3000 + mapIdx * 50 + objIdx)
            local textKey = obj.text or string.format("TEXT_%s_%d", mapId, objIdx)
            local winKey = textKey .. "_WIN"

            obj.trainerClass = classId
            obj.trainerParty = member
            obj.trainer = {
              class = classNum,
              classId = classId,
              className = (customDef and customDef.className) or classId,
              member = member,
              party = (customDef and customDef.roster) or member,
              roster = customDef and customDef.roster or nil,
              name = customDef and customDef.name or nil,
              event = eventNum,
              sight = sight,
              seenText = textKey,
              winText = winKey,
              lossText = "Better luck next time!",
              text = { textKey, winKey, "Better luck next time!" },
              scriptKey = obj.afterScriptKey or obj.scriptKey or {
                { op = "opentext" },
                { op = "writetext", text = winKey },
                { op = "waitbutton" },
                { op = "closetext" },
              }
            }

            if data.gen2Text then
              local authSeen = DUNGEON_TEXT[textKey]
              if authSeen then
                data.gen2Text[textKey] = authSeen
              else
                local niceName = (customDef and customDef.name) or (obj.name or classId):gsub("^.*_", "")
                local textVal = string.format("I'm a %s!\nLet's battle!", niceName)
                data.gen2Text[textKey] = data.gen2Text[textKey] or textVal
                data.gen2Text[textVal] = data.gen2Text[textVal] or textVal
              end
              local authWin = DUNGEON_TEXT[winKey]
              if authWin then
                data.gen2Text[winKey] = authWin
              else
                data.gen2Text[winKey] = data.gen2Text[winKey] or "You beat me!"
              end
            end
          end
        end
      end
    end

    local mapsContainer = (data and (
      (data.gen2Maps and data.gen2Maps.ROUTE_3 and data.gen2Maps)
      or (data.maps and data.maps.ROUTE_3 and data.maps)
      or data
    )) or {}

    -- Ensure overworld ROUTE_3 map has restored dungeon entrance warps
    if mapsContainer.ROUTE_3 then
      mapsContainer.ROUTE_3.warps = mapsContainer.ROUTE_3.warps or {}
      if #mapsContainer.ROUTE_3.warps < 1 then
        mapsContainer.ROUTE_3.warps = {
          { x = 52, y = 1, destMap = "MT_MOON_1F_KR", destWarp = 1 },
          { x = 53, y = 1, destMap = "MT_MOON_1F_KR", destWarp = 2 },
        }
      else
        patchMtMoonEntranceWarps(mapsContainer.ROUTE_3.warps, "ROUTE_3")
      end
    end

    -- Digletts/Safari pattern: mutate Route 4 cave mouths in place to *_KR
    -- (do not replace the whole warps table — that drops live _warpAt links).
    if mapsContainer.ROUTE_4 and mapsContainer.ROUTE_4.warps then
      patchMtMoonEntranceWarps(mapsContainer.ROUTE_4.warps, "ROUTE_4")
    end

    if data then
      if type(data.gen2Maps) == "table" then
        data.gen2Maps.ROUTE_3 = mapsContainer.ROUTE_3
        data.gen2Maps.ROUTE_4 = mapsContainer.ROUTE_4
      end
      if type(data.maps) == "table" then
        data.maps.ROUTE_3 = mapsContainer.ROUTE_3
        data.maps.ROUTE_4 = mapsContainer.ROUTE_4
      end
      if type(data) == "table" then
        data.ROUTE_3 = mapsContainer.ROUTE_3
        data.ROUTE_4 = mapsContainer.ROUTE_4
      end
    end

    -- Overworld entrance redirects for Kanto dungeons
    if mapsContainer.ROUTE_3 and mapsContainer.ROUTE_3.warps then
      patchMtMoonEntranceWarps(mapsContainer.ROUTE_3.warps, "ROUTE_3")
    end

    if mapsContainer.ROUTE_4 and mapsContainer.ROUTE_4.warps then
      patchMtMoonEntranceWarps(mapsContainer.ROUTE_4.warps, "ROUTE_4")
    end

    if mapsContainer.CERULEAN_CITY and mapsContainer.CERULEAN_CITY.warps then
      for _, w in ipairs(mapsContainer.CERULEAN_CITY.warps) do
        if w.destMap == "CERULEAN_CAVE" or w.destMap == "CERULEAN_CAVE_1F" then
          w.destMap = "CERULEAN_CAVE_1F"
          w.destWarp = 1
        end
      end
    end

    if mapsContainer.ROUTE_20 and mapsContainer.ROUTE_20.warps then
      for idx, w in ipairs(mapsContainer.ROUTE_20.warps) do
        if w.destMap == "SEAFOAM" or w.destMap == "SEAFOAM_ISLANDS" or w.destMap == "SEAFOAM_ISLANDS_1F" then
          w.destMap = "SEAFOAM_ISLANDS_1F"
          w.destWarp = (idx == 1) and 1 or 3
        end
      end
    end

    if mapsContainer.VERMILION_CITY and mapsContainer.VERMILION_CITY.warps then
      for _, w in ipairs(mapsContainer.VERMILION_CITY.warps) do
        if w.destMap == "DIGLETTS_CAVE" or w.destMap == "DIGLETTS_CAVE_ROUTE_11" or (w.x == 34 and w.y == 7) then
          w.destMap = "DIGLETTS_CAVE_ROUTE_11_KR"
          w.destWarp = 1
        end
      end
    end

    if mapsContainer.ROUTE_2 and mapsContainer.ROUTE_2.warps then
      for _, w in ipairs(mapsContainer.ROUTE_2.warps) do
        if w.destMap == "DIGLETTS_CAVE" or w.destMap == "DIGLETTS_CAVE_ROUTE_2" then
          w.destMap = "DIGLETTS_CAVE_ROUTE_2_KR"
          w.destWarp = 1
        end
      end
    end


    local allContainers = { mapsContainer, coreData and coreData.maps, coreData and coreData.gen2Maps, data and data.maps, data and data.gen2Maps, game and game.data and game.data.maps, game and game.data and game.data.gen2Maps, game and game.world and game.world.maps }
    for _, cont in ipairs(allContainers) do
      if type(cont) == "table" then
        if cont.VERMILION_CITY and cont.VERMILION_CITY.warps then
          for _, w in ipairs(cont.VERMILION_CITY.warps) do
            if w.destMap == "DIGLETTS_CAVE" or (w.x == 34 and w.y == 7) then
              w.destMap = "DIGLETTS_CAVE_ROUTE_11_KR"
              w.destWarp = 1
            end
          end
        end
        if cont.ROUTE_2 and cont.ROUTE_2.warps then
          for _, w in ipairs(cont.ROUTE_2.warps) do
            if w.destMap == "DIGLETTS_CAVE" then
              w.destMap = "DIGLETTS_CAVE_ROUTE_2_KR"
              w.destWarp = 1
            end
          end
        end
        if cont.FUCHSIA_CITY then
          local Camp = kantoCampaign()
          local save = (_G.game and _G.game.save) or (mod and mod.game and mod.game.save)
          if Camp and Camp.syncFuchsiaSafariDoor then
            Camp.syncFuchsiaSafariDoor(cont.FUCHSIA_CITY, save)
          end
        end
      end
    end


    -- Update OVERWORLD / KANTO tileset with custom blocks 129-151
    local customBlocksList = {
      [129] = { tiles = {64, 65, 82, 82, 80, 81, 82, 82, 64, 65, 82, 82, 80, 81, 82, 82}, collision = {0x07, 0x18, 0x07, 0x18} },
      [130] = { tiles = {82, 82, 64, 65, 82, 82, 80, 81, 82, 82, 64, 65, 82, 82, 80, 81}, collision = {0x18, 0x07, 0x18, 0x07} },
      [131] = { tiles = {64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81, 35, 35}, collision = {0x07, 0x00, 0x07, 0x00} },
      [132] = { tiles = {35, 35, 64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81}, collision = {0x00, 0x07, 0x00, 0x07} },
      [133] = { tiles = {64, 65, 64, 65, 80, 81, 80, 81, 35, 35, 35, 35, 35, 35, 35, 35}, collision = {0x07, 0x07, 0x00, 0x00} },
      [134] = { tiles = {35, 35, 35, 35, 35, 35, 35, 35, 64, 65, 64, 65, 80, 81, 80, 81}, collision = {0x00, 0x00, 0x07, 0x07} },
      [135] = { tiles = {35, 35, 35, 35, 57, 35, 35, 35, 42, 43, 42, 43, 58, 59, 58, 59}, collision = {0x00, 0x00, 0xA0, 0xA0} },
      [136] = { tiles = {35, 35, 35, 35, 57, 35, 35, 35, 44, 44, 44, 44, 44, 44, 44, 44}, collision = {0x00, 0x00, 0x70, 0x70} },
      [137] = { tiles = {44, 44, 44, 44, 44, 44, 44, 44, 35, 35, 35, 35, 57, 35, 35, 35}, collision = {0x78, 0x78, 0x00, 0x00} },
      [138] = { tiles = {50, 75, 75, 50, 75, 75, 75, 75, 11, 12, 10, 10, 27, 28, 26, 26}, collision = {0x07, 0x07, 0x71, 0x71} },
      [58]  = { tiles = {50, 75, 75, 50, 75, 75, 75, 75, 11, 12, 10, 10, 27, 28, 26, 26}, collision = {0x07, 0x07, 0x71, 0x71} },
      [131] = { tiles = {64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81, 35, 35}, collision = {0x07, 0x00, 0x07, 0x00} },
      [132] = { tiles = {35, 35, 64, 65, 35, 35, 80, 81, 35, 35, 64, 65, 35, 35, 80, 81}, collision = {0x00, 0x07, 0x00, 0x07} },
      [133] = { tiles = {64, 65, 64, 65, 80, 81, 80, 81, 35, 35, 35, 35, 35, 35, 35, 35}, collision = {0x07, 0x07, 0x00, 0x00} },
      [134] = { tiles = {35, 35, 35, 35, 35, 35, 35, 35, 64, 65, 64, 65, 80, 81, 80, 81}, collision = {0x00, 0x00, 0x07, 0x07} },
      [142] = { tiles = {51, 51, 51, 51, 51, 20, 20, 20, 51, 20, 20, 20, 51, 20, 20, 20}, collision = {0x07, 0x07, 0x07, 0x29} },
      [143] = { tiles = {51, 51, 51, 51, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20}, collision = {0x07, 0x07, 0x29, 0x29} },
      [144] = { tiles = {51, 51, 51, 51, 20, 20, 20, 84, 20, 20, 20, 84, 20, 20, 20, 84}, collision = {0x07, 0x07, 0x29, 0x07} },
      [145] = { tiles = {51, 20, 20, 20, 51, 20, 20, 20, 51, 20, 20, 20, 51, 20, 20, 20}, collision = {0x07, 0x29, 0x07, 0x29} },
      [146] = { tiles = {20, 20, 20, 84, 20, 20, 20, 84, 20, 20, 20, 84, 20, 20, 20, 84}, collision = {0x29, 0x07, 0x29, 0x07} },
      [150] = { tiles = {20, 20, 20, 20, 20, 20, 51, 35, 20, 20, 51, 35, 20, 20, 51, 35}, collision = {0x29, 0x29, 0x07, 0x00} },
      [151] = { tiles = {20, 20, 20, 20, 35, 84, 20, 20, 35, 84, 20, 20, 35, 84, 20, 20}, collision = {0x29, 0x29, 0x00, 0x07} },
      [152] = { tiles = {20, 20, 51, 35, 20, 20, 51, 35, 20, 20, 20, 20, 20, 20, 20, 20}, collision = {0x07, 0x00, 0x29, 0x29} },
      [153] = { tiles = {35, 84, 20, 20, 35, 84, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20}, collision = {0x00, 0x07, 0x29, 0x29} },
      [158] = { tiles = {17, 17, 17, 17, 17, 17, 17, 17, 77, 78, 77, 78, 83, 84, 83, 84}, collision = {0x00, 0x00, 0x00, 0x00} },
      [159] = { tiles = {77, 78, 77, 78, 83, 84, 83, 84, 17, 17, 17, 17, 17, 17, 17, 17}, collision = {0x00, 0x00, 0x00, 0x00} },
      -- Gen1 FOREST wooden sign (forest_wooden_sign.png → tiles 96–99)
      [160] = { tiles = {96, 97, 35, 35, 98, 99, 35, 35, 35, 35, 35, 35, 35, 35, 35, 35}, collision = {0x82, 0x00, 0x00, 0x00} },
    }

    for _, tsKey in ipairs({"OVERWORLD", "TILESET_KANTO", "KANTO"}) do
      local ts = (Data.tilesets and Data.tilesets[tsKey]) or (data and data.gen2Tilesets and data.gen2Tilesets[tsKey]) or (data and data.tilesets and data.tilesets[tsKey])
      if ts then
        ts.blocks = ts.blocks or {}
        ts.collision = ts.collision or {}
        for bId, bDef in pairs(customBlocksList) do
          ts.blocks[bId + 1] = bDef.tiles
          ts.collision[bId + 1] = bDef.collision
        end
        if ts.tilePalettes then
          ts.tilePalettes[78] = 1 -- Tile 77 (left stair step)
          ts.tilePalettes[79] = 1 -- Tile 78 (right stair step)
          ts.tilePalettes[84] = 1 -- Tile 83 (ladder rungs)
          -- Outdoor sign tiles 96–99 (extra row on kanto.png override)
          while #ts.tilePalettes < 100 do
            table.insert(ts.tilePalettes, 1)
          end
          ts.tilePalettes[97] = 1
          ts.tilePalettes[98] = 1
          ts.tilePalettes[99] = 1
          ts.tilePalettes[100] = 1
        end
        -- overrides/tileset_quads/forest_wooden_sign.png → composed kanto.png (128×56)
        ts.imageHeight = 56
      end
    end

    -- Force atlas re-resolve so kr_* override sheets win after registration.
    if Assets and Assets.flush then
      pcall(Assets.flush)
    end
    if game and game.world then
      if game.world.mapImages then game.world.mapImages = {} end
      if game.world.atlasCache then game.world.atlasCache = {} end
      if game.world.tilesets and Data.tilesets then
        for tsId, tsDef in pairs(Data.tilesets) do
          game.world.tilesets[tsId] = tsDef
        end
      end
    end


    -- Map aliases so any warp or save state using legacy or Gen2 names maps to restored maps
    aliasRestoredMoonMaps(mapsContainer, Data)

    mapsContainer.SEAFOAM_ISLANDS = Data.maps["SEAFOAM_ISLANDS_1F_KR"] or Data.maps["SEAFOAM_ISLANDS_1F"]
    mapsContainer.CERULEAN_CAVE = Data.maps["CERULEAN_CAVE_1F_KR"] or Data.maps["CERULEAN_CAVE_1F"]
    mapsContainer.SAFARI_ZONE = Data.maps["SAFARI_ZONE_GATE_KR"] or Data.maps["SAFARI_ZONE_GATE"]
    mapsContainer.SAFARI_ZONE_GATE = Data.maps["SAFARI_ZONE_GATE_KR"] or Data.maps["SAFARI_ZONE_GATE"]
    mapsContainer.SAFARI_ZONE_CENTER = Data.maps["SAFARI_ZONE_CENTER_KR"] or Data.maps["SAFARI_ZONE_CENTER"]
    mapsContainer.SAFARI_ZONE_EAST = Data.maps["SAFARI_ZONE_EAST_KR"] or Data.maps["SAFARI_ZONE_EAST"]
    mapsContainer.SAFARI_ZONE_NORTH = Data.maps["SAFARI_ZONE_NORTH_KR"] or Data.maps["SAFARI_ZONE_NORTH"]
    mapsContainer.SAFARI_ZONE_WEST = Data.maps["SAFARI_ZONE_WEST_KR"] or Data.maps["SAFARI_ZONE_WEST"]
    mapsContainer.SAFARI_ZONE_CENTER_REST_HOUSE = Data.maps["SAFARI_ZONE_CENTER_REST_HOUSE_KR"] or Data.maps["SAFARI_ZONE_CENTER_REST_HOUSE"]
    mapsContainer.SAFARI_ZONE_EAST_REST_HOUSE = Data.maps["SAFARI_ZONE_EAST_REST_HOUSE_KR"] or Data.maps["SAFARI_ZONE_EAST_REST_HOUSE"]
    mapsContainer.SAFARI_ZONE_NORTH_REST_HOUSE = Data.maps["SAFARI_ZONE_NORTH_REST_HOUSE_KR"] or Data.maps["SAFARI_ZONE_NORTH_REST_HOUSE"]
    mapsContainer.SAFARI_ZONE_WEST_REST_HOUSE = Data.maps["SAFARI_ZONE_WEST_REST_HOUSE_KR"] or Data.maps["SAFARI_ZONE_WEST_REST_HOUSE"]
    mapsContainer.SAFARI_ZONE_SECRET_HOUSE = Data.maps["SAFARI_ZONE_SECRET_HOUSE_KR"] or Data.maps["SAFARI_ZONE_SECRET_HOUSE"]

    mapsContainer.ROCK_TUNNEL = Data.maps["ROCK_TUNNEL_1F_KR"] or Data.maps["ROCK_TUNNEL_1F"]
    mapsContainer.ROCK_TUNNEL_1F = Data.maps["ROCK_TUNNEL_1F_KR"] or Data.maps["ROCK_TUNNEL_1F"]
    mapsContainer.ROCK_TUNNEL_B1F = Data.maps["ROCK_TUNNEL_B1F_KR"] or Data.maps["ROCK_TUNNEL_B1F"]
    mapsContainer.ROCK_TUNNEL_POKECENTER = Data.maps["ROCK_TUNNEL_POKECENTER_KR"] or Data.maps["ROCK_TUNNEL_POKECENTER"]

    if mapsContainer.ROUTE_10 and mapsContainer.ROUTE_10.warps then
      for _, w in ipairs(mapsContainer.ROUTE_10.warps) do
        if w.destMap == "ROCK_TUNNEL" or w.destMap == "ROCK_TUNNEL_1F" then
          w.destMap = "ROCK_TUNNEL_1F"
        end
      end
    end

    -- Normalize connections on all maps to ensure mapId is populated for Gen 2 seamless transitions
    local allContainers = { mapsContainer, Data.maps, data and data.maps, data and data.gen2Maps, game and game.world and game.world.maps }
    for _, cont in ipairs(allContainers) do
      if type(cont) == "table" then
        for mapId, mdef in pairs(cont) do
          if type(mdef) == "table" and type(mdef.connections) == "table" then
            for dir, conn in pairs(mdef.connections) do
              if type(conn) == "table" then
                if conn.map and not conn.mapId then conn.mapId = conn.map end
                if conn.mapId and not conn.map then conn.map = conn.mapId end
              end
            end
          end
        end
        if cont.ROUTE_4 and cont.ROUTE_4.warps then
          patchMtMoonEntranceWarps(cont.ROUTE_4.warps, "ROUTE_4")
        end
        if cont.ROUTE_3 and cont.ROUTE_3.warps then
          patchMtMoonEntranceWarps(cont.ROUTE_3.warps, "ROUTE_3")
        end
        aliasRestoredMoonMaps(cont, Data)
      end
    end

  -- 3. Direct patch into live game.world maps if overworld is active
  if game and game.world then
    if game.world.tilesets and Data.tilesets then
      for tsId, tsDef in pairs(Data.tilesets) do
        game.world.tilesets[tsId] = tsDef
      end
    end
    if game.world.maps then
      if mapsContainer.ROUTE_3 then game.world.maps.ROUTE_3 = mapsContainer.ROUTE_3 end
      if mapsContainer.ROUTE_4 then game.world.maps.ROUTE_4 = mapsContainer.ROUTE_4 end
      for mapId, mdef in pairs(Data.maps) do
        game.world.maps[mapId] = mdef
      end
      aliasRestoredMoonMaps(game.world.maps, Data)
    end
  end

  -- 4. Dynamic warp.destination hook registration
  if mod and mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("warp.destination", function(next_, mapId, x, y, ctx)
      -- Already on restored KR maps: keep resolveWarp's landing coords (ladders etc).
      if mapId == "MT_MOON_1F_KR" or mapId == "MT_MOON_B1F_KR" or mapId == "MT_MOON_B2F_KR" then
        return next_(mapId, x, y, ctx)
      end
      if mapId == "MOUNT_MOON" or mapId == "MT_MOON" or mapId == "MT_MOON_1F"
          or mapId == "MT_MOON_B1F" or mapId == "MOUNT_MOON_B1F" then
        local w = ctx and ctx.warp
        -- Route 3 -> MT_MOON_1F_KR exit carpets (14, 35 / 15, 35)
        if w and (w.destMap == "MT_MOON_1F" or w.destMap == "MT_MOON_1F_KR" or (w.x and w.x >= 50)) then
          if w.x and w.x >= 53 then
            return "MT_MOON_1F_KR", 15, 35
          else
            return "MT_MOON_1F_KR", 14, 35
          end
        end
        -- Route 4 / legacy B1F names -> restored exit pad (warp 8 at 27, 3)
        return "MT_MOON_B1F_KR", 27, 3
      elseif mapId == "ROUTE_3" then
        local w = ctx and ctx.warp
        if w and (w.x and w.x >= 15) then
          return "ROUTE_3", 53, 2
        else
          return "ROUTE_3", 52, 2
        end
      elseif mapId == "ROUTE_4" then
        -- Stand just south of the Route 4 cave mouth that links to B1F.
        local w = ctx and ctx.warp
        if w and w.x and w.x >= 20 then
          return "ROUTE_4", 24, 6
        elseif w and w.x and w.x >= 15 then
          return "ROUTE_4", 18, 6
        end
        return "ROUTE_4", 24, 6
      elseif mapId == "CERULEAN_CAVE" then
        return "CERULEAN_CAVE_1F", 24, 16
      elseif mapId == "SEAFOAM" or mapId == "SEAFOAM_ISLANDS" then
        local w = ctx and ctx.warp
        if w and (w.destWarp == 3 or w.destWarp == 4 or (w.x and w.x >= 40)) then
          return "SEAFOAM_ISLANDS_1F", 26, 3
        else
          return "SEAFOAM_ISLANDS_1F", 4, 3
        end
      elseif mapId == "SAFARI" or mapId == "SAFARI_ZONE" then
        return "SAFARI_ZONE_GATE", 3, 4
      end
      return next_(mapId, x, y, ctx)
    end)
  end

  -- Register maps and tilesets cleanly with mod.content registry
  if mod and mod.content then
    if mod.content.tilesets and Data.tilesets then
      for tsId, tsDef in pairs(Data.tilesets) do
        pcall(function() mod.content.tilesets:register(tsId, tsDef) end)
      end
    end
    if mod.content.maps then
      for mapId, mdef in pairs(Data.maps) do
        pcall(function() mod.content.maps:register(mapId, mdef) end)
      end
      if mapsContainer.ROUTE_3 then pcall(function() mod.content.maps:patch("ROUTE_3", { warps = mapsContainer.ROUTE_3.warps }) end) end
      if mapsContainer.ROUTE_4 then pcall(function() mod.content.maps:patch("ROUTE_4", { warps = mapsContainer.ROUTE_4.warps }) end) end
      if mapsContainer.CERULEAN_CITY then pcall(function() mod.content.maps:patch("CERULEAN_CITY", { warps = mapsContainer.CERULEAN_CITY.warps }) end) end
      if mapsContainer.ROUTE_20 then pcall(function() mod.content.maps:patch("ROUTE_20", { warps = mapsContainer.ROUTE_20.warps }) end) end
      if mapsContainer.FUCHSIA_CITY then pcall(function() mod.content.maps:patch("FUCHSIA_CITY", { blocks = mapsContainer.FUCHSIA_CITY.blocks, warps = mapsContainer.FUCHSIA_CITY.warps }) end) end
    end
  end

  local mapCount = 0
  for _ in pairs(Data.maps) do mapCount = mapCount + 1 end


  local world = (_G.game and _G.game.world) or (mod and mod.game and mod.game.world)
  if world then
    world.scripts = world.scripts or {}
    world.scripts.movements = world.scripts.movements or {}
    for k, v in pairs(RIVAL_MOVEMENTS) do world.scripts.movements[k] = v end
    if world.vm then
      world.vm.movements = world.vm.movements or {}
      for k, v in pairs(RIVAL_MOVEMENTS) do world.vm.movements[k] = v end
    end
  end

  if mod and mod.events and mod.events.on then
    mod.events:on("world.stepped", function(payload)
      local game = _G.game or (mod and mod.game) or (Runtime and Runtime.game)
      local w = game and game.world
      if w and w.scripts then
        w.scripts.movements = w.scripts.movements or {}
        for k, v in pairs(RIVAL_MOVEMENTS) do w.scripts.movements[k] = w.scripts.movements[k] or v end
        if w.vm and w.vm.movements then
          for k, v in pairs(RIVAL_MOVEMENTS) do w.vm.movements[k] = w.vm.movements[k] or v end
        end
      end
    end)
  end

  RestoredDungeons.APPLIED = true
  if mod and mod.log then
    mod.log:info("Restored Gen 1 Kanto dungeons applied to Gen 2 mode (%d maps)", mapCount)
  end
  return true
end
end

function RestoredDungeons.applySeafoamBoulderPatch(mapId, boulderDropped)
  if not Host.isGen2() or not boulderDropped then return end
  local okData, Data = pcall(require, "mods.Kanto-Reforged.world.restored_dungeons_data")
  if not okData or not Data or not Data.seafoamBoulderPatches then return end

  local patches = Data.seafoamBoulderPatches[mapId]
  if not patches then return end

  local map = (_G.game and _G.game.world and _G.game.world.maps and _G.game.world.maps[mapId])
  if map and map.collision then
    if map.tileset and map.collision == map.tileset.collision then
      local copy = {}
      for k, v in pairs(map.collision) do copy[k] = v end
      map.collision = copy
    end
    for _, patch in ipairs(patches) do
      local blockIdx = patch.y * map.width + patch.x + 1
      if map.blocks and map.blocks[blockIdx] then
        local blockId = map.blocks[blockIdx]
        map.collision[blockId + 1] = patch.targetQuad
      end
    end
  end
end

return RestoredDungeons
