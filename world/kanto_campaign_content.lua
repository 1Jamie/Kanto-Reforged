-- Hand-authored Gen2 Kanto Rocket campaign content overlays.
-- Applied at runtime onto restored *_KR layouts (never baked into generated data).

local Dialogue = require("mods.Kanto-Reforged.core.dialogue")

local Content = {}

-- High custom event ids (Save.EVENT_BYTES expanded to 4096 in restored_dungeons).
Content.FLAGS = {
  MT_MOON_ROCKETS_CLEARED = 3001,
  ROCK_TUNNEL_ROCKETS_CLEARED = 3002,
  SAFARI_UNLOCKED = 3003,
  SAFARI_ROCKETS_CLEARED = 3004,
  ROUTE22_BLUE_MET = 3005,
  BLUE_PHONE_MILESTONE = 3006, -- stores last announced kanto-badge tier (via events bit misuse avoided; use save key)
}

-- Gen2 overworld box: 18 cols, 2 lines, \f between pages (wait for A).
-- Extra lines without \f soft-wrap and auto-scroll with no button wait —
-- paragraph breaks (\n\n) become \f before wrap so the player pages through.
local function ow(text)
  if type(text) ~= "string" then return text end
  text = text
    :gsub("…", "...")
    :gsub("—", "--")
    :gsub("^%s+", "")
    :gsub("%s+$", "")
    :gsub("\n\n+", "\f")
  text = Dialogue.overworld(text)
  return (text:gsub("\f+$", ""))
end

Content.ow = ow

Content.TEXT = {
  -- Mt. Moon racket reframe (replaces Gen1 fossil-theft lines)
  TEXT_MTMOONB2F_SUPER_NERD = ow([[
TEAM ROCKET's using this cave as a toll booth!
They're shaking down trainers and grinding their POKéMON for something bigger!
]]),
  TEXT_MTMOONB2F_SUPER_NERD_WIN = ow("Maybe... I should take another route..."),
  TEXT_MTMOONB2F_ROCKET1 = ow([[
Toll's due, kid.
Nobody crosses MT. MOON without paying TEAM ROCKET!
]]),
  TEXT_MTMOONB2F_ROCKET1_WIN = ow("Urgh... the boss said train harder!"),
  TEXT_MTMOONB2F_ROCKET2 = ow([[
We're toughening up after JOHTO.
This cave's our gym -- and you're the sparring partner!
]]),
  TEXT_MTMOONB2F_ROCKET2_WIN = ow("I blew it... again!"),
  TEXT_MTMOONB2F_ROCKET3 = ow([[
Fuchsia's the real prize.
We're just warming up here!
]]),
  TEXT_MTMOONB2F_ROCKET3_WIN = ow("So you are good..."),
  TEXT_MTMOONB2F_ROCKET4 = ow([[
I'm running this checkpoint!
Once we're strong enough, the SAFARI ZONE is ours!
]]),
  TEXT_MTMOONB2F_ROCKET4_WIN = ow("No... the pipeline...!"),

  -- Rock Tunnel
  TEXT_ROCKTUNNEL_ROCKET1 = ow("Move along! We're shipping rare stock toward FUCHSIA!"),
  TEXT_ROCKTUNNEL_ROCKET1_WIN = ow("The line still runs..."),
  TEXT_ROCKTUNNEL_ROCKET2 = ow([[
ROCK TUNNEL's our supply corridor.
Don't get in the way!
]]),
  TEXT_ROCKTUNNEL_ROCKET2_WIN = ow("Grr...!"),
  TEXT_ROCKTUNNEL_ROCKET3 = ow([[
Caught anything good in the dark?
Hand it over!
]]),
  TEXT_ROCKTUNNEL_ROCKET3_WIN = ow("Worthless..."),
  TEXT_ROCKTUNNEL_ADMIN = ow([[
This tunnel feeds our SAFARI operation.
Beat me and the line goes cold!
]]),
  TEXT_ROCKTUNNEL_ADMIN_WIN = ow("The door... they'll open it anyway..."),

  -- Safari occupation
  TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1 = ow([[
Th-the WARDEN's gone... TEAM ROCKET seized the preserve!
They've turned it into a rare-POKéMON racket!
]]),
  TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER2 = ow([[
Grunts everywhere... the SECRET HOUSE is their HQ now.
Please -- clear them out!
]]),
  TEXT_SAFARIZONEWEST_FIND_WARDENS_TEETH_SIGN = ow([[
SAFARI NOTICE
WARDEN MISSING -- PRESERVE UNDER TEAM ROCKET CONTROL
Do not enter without a strong team!
]]),
  TEXT_SAFARIZONE_ROCKET1 = ow([[
This used to be a park.
Now it's TEAM ROCKET's ranch!
]]),
  TEXT_SAFARIZONE_ROCKET1_WIN = ow("Stock... escaping..."),
  TEXT_SAFARIZONE_ROCKET2 = ow([[
Rare POKéMON mean rare profit.
Scram!
]]),
  TEXT_SAFARIZONE_ROCKET2_WIN = ow("Boss won't like this..."),
  TEXT_SAFARIZONE_ROCKET3 = ow([[
We're building an industry here.
JOHTO was just a setback!
]]),
  TEXT_SAFARIZONE_ROCKET3_WIN = ow("No...!"),
  TEXT_SAFARIZONE_ROCKET4 = ow([[
East sector's locked down.
Authorized Rockets only!
]]),
  TEXT_SAFARIZONE_ROCKET4_WIN = ow("Breach..."),
  TEXT_SAFARIZONE_ROCKET5 = ow([[
North sector's locked down.
Authorized Rockets only!
]]),
  TEXT_SAFARIZONE_ROCKET5_WIN = ow("Breach..."),
  TEXT_SAFARIZONE_BOSS_SEEN = ow([[
So you're the JOHTO champ BLUE warned us about.

This preserve is ours -- rare stock, endless profit.
You want it back? Take it from me!
]]),
  TEXT_SAFARIZONE_BOSS_WIN = ow("The industry... collapses..."),
  TEXT_SAFARIZONE_BOSS_AFTER = ow([[
Fine! The preserve's yours!
TEAM ROCKET's pulling out of KANTO... for now.
]]),
}

local function standingMovementForRange(range, movement)
  if type(movement) == "number" then return movement end
  local byRange = {
    DOWN = 6,  -- SPRITEMOVEDATA_STANDING_DOWN
    UP = 7,
    LEFT = 8,
    RIGHT = 9,
  }
  return byRange[range or "DOWN"] or 6
end

local function trainerObj(opts)
  local classId = opts.trainerClass or "GRUNTM"
  local classNum = opts.classNum or 31
  -- HUD uses class display name ("ROCKET") + personal name ("GRUNT").
  -- Battle frontpic / palette key off classId ("GRUNTM" / "EXECUTIVEM" / …).
  local className = opts.className or "ROCKET"
  local name = opts.trainerName or "GRUNT"
  local range = opts.range or "DOWN"
  return {
    name = opts.name,
    sprite = opts.sprite or "SPRITE_ROCKET",
    x = opts.x,
    y = opts.y,
    range = range,
    movement = standingMovementForRange(range, opts.movement),
    sight = opts.sight or 3,
    event = opts.event,
    eventFlag = opts.event,
    level = opts.level or 55,
    trainerClass = classId,
    trainerParty = opts.member,
    text = opts.text,
    isCampaignOverlay = true,
    trainer = {
      class = classNum,
      classId = classId,
      className = className,
      name = name,
      event = opts.event,
      member = opts.member,
      party = opts.member,
      seenText = opts.text,
      winText = opts.text .. "_WIN",
      lossText = "Humph!",
    },
    afterScriptKey = opts.afterScriptKey,
  }
end

-- Objects upserted by name onto KR maps after layout normalize.
Content.OVERLAYS = {
  ROCK_TUNNEL_1F_KR = {
    trainerObj({
      name = "ROCKTUNNEL_ROCKET1",
      x = 12, y = 10,
      event = 3010,
      member = 220,
      text = "TEXT_ROCKTUNNEL_ROCKET1",
    }),
    trainerObj({
      name = "ROCKTUNNEL_ROCKET2",
      x = 28, y = 14,
      event = 3011,
      member = 221,
      text = "TEXT_ROCKTUNNEL_ROCKET2",
    }),
    {
      name = "ROCKTUNNEL_BLUE",
      sprite = "SPRITE_BLUE",
      x = 14, y = 31,
      range = "DOWN",
      movement = 6,
      sight = 0,
      event = 3015,
      eventFlag = 3015,
      isCampaignOverlay = true,
      text = "TEXT_ROCKTUNNEL_BLUE",
      -- scriptKey filled at apply time (flag-aware)
    },
  },
  ROCK_TUNNEL_B1F_KR = {
    trainerObj({
      name = "ROCKTUNNEL_ROCKET3",
      x = 16, y = 16,
      event = 3012,
      member = 222,
      text = "TEXT_ROCKTUNNEL_ROCKET3",
    }),
    trainerObj({
      name = "ROCKTUNNEL_ADMIN",
      x = 22, y = 20,
      event = 3013,
      member = 223,
      text = "TEXT_ROCKTUNNEL_ADMIN",
      trainerClass = "EXECUTIVEM",
      classNum = 51,
      className = "ROCKET",
      trainerName = "EXECUTIVE",
      sprite = "SPRITE_ROCKET",
      level = 62,
      -- clear flag wired in afterScript at apply
    }),
  },
  SAFARI_ZONE_CENTER_KR = {
    trainerObj({
      name = "SAFARIZONE_ROCKET1",
      x = 13, y = 23,
      range = "RIGHT",
      event = 3020,
      member = 230,
      text = "TEXT_SAFARIZONE_ROCKET1",
      level = 60,
    }),
    trainerObj({
      name = "SAFARIZONE_ROCKET2",
      x = 14, y = 1,
      range = "UP",
      event = 3021,
      member = 231,
      text = "TEXT_SAFARIZONE_ROCKET2",
      level = 61,
    }),
  },
  SAFARI_ZONE_EAST_KR = {
    trainerObj({
      name = "SAFARIZONE_ROCKET3",
      x = 3, y = 21,
      range = "LEFT",
      event = 3022,
      member = 232,
      text = "TEXT_SAFARIZONE_ROCKET3",
      level = 62,
    }),
  },
  SAFARI_ZONE_WEST_KR = {
    trainerObj({
      name = "SAFARIZONE_ROCKET4",
      x = 28, y = 22,
      range = "RIGHT",
      event = 3023,
      member = 233,
      text = "TEXT_SAFARIZONE_ROCKET4",
      level = 63,
    }),
  },
  SAFARI_ZONE_NORTH_KR = {
    trainerObj({
      name = "SAFARIZONE_ROCKET5",
      x = 18, y = 35,
      range = "RIGHT",
      event = 3024,
      member = 234,
      text = "TEXT_SAFARIZONE_ROCKET5",
      level = 63,
    }),
  },
}

Content.ROSTERS = {
  ROCKTUNNEL_ROCKET1 = {
    classId = "GRUNTM", classNum = 31, member = 220, event = 3010,
    className = "ROCKET", name = "GRUNT", baseMoney = 40,
    roster = {
      { species = "RATICATE", level = 52 },
      { species = "GOLBAT", level = 53 },
      { species = "HOUNDOUR", level = 54 },
    },
  },
  ROCKTUNNEL_ROCKET2 = {
    classId = "GRUNTM", classNum = 31, member = 221, event = 3011,
    className = "ROCKET", name = "GRUNT", baseMoney = 40,
    roster = {
      { species = "KOFFING", level = 53 },
      { species = "ARBOK", level = 54 },
      { species = "MUK", level = 55 },
    },
  },
  ROCKTUNNEL_ROCKET3 = {
    classId = "GRUNTM", classNum = 31, member = 222, event = 3012,
    className = "ROCKET", name = "GRUNT", baseMoney = 40,
    roster = {
      { species = "GOLBAT", level = 54 },
      { species = "WEEZING", level = 55 },
      { species = "HOUNDOOM", level = 56 },
    },
  },
  ROCKTUNNEL_ADMIN = {
    classId = "EXECUTIVEM", classNum = 51, member = 223, event = 3013,
    className = "ROCKET", name = "EXECUTIVE", baseMoney = 55,
    roster = {
      { species = "CROBAT", level = 58 },
      { species = "WEEZING", level = 59 },
      { species = "HOUNDOOM", level = 60 },
      { species = "GYARADOS", level = 61 },
      { species = "TYRANITAR", level = 62, item = "BLACKGLASSES" },
    },
  },
  SAFARIZONE_ROCKET1 = {
    classId = "GRUNTM", classNum = 31, member = 230, event = 3020,
    className = "ROCKET", name = "GRUNT", baseMoney = 45,
    roster = {
      { species = "RATICATE", level = 58 },
      { species = "VENOMOTH", level = 59 },
      { species = "GOLBAT", level = 60 },
    },
  },
  SAFARIZONE_ROCKET2 = {
    classId = "GRUNTM", classNum = 31, member = 231, event = 3021,
    className = "ROCKET", name = "GRUNT", baseMoney = 45,
    roster = {
      { species = "ARBOK", level = 59 },
      { species = "MUK", level = 60 },
      { species = "HYPNO", level = 61 },
    },
  },
  SAFARIZONE_ROCKET3 = {
    classId = "GRUNTM", classNum = 31, member = 232, event = 3022,
    className = "ROCKET", name = "GRUNT", baseMoney = 45,
    roster = {
      { species = "WEEZING", level = 60 },
      { species = "HOUNDOOM", level = 61 },
      { species = "CROBAT", level = 62 },
    },
  },
  SAFARIZONE_ROCKET4 = {
    classId = "GRUNTM", classNum = 31, member = 233, event = 3023,
    className = "ROCKET", name = "GRUNT", baseMoney = 45,
    roster = {
      { species = "SCYTHER", level = 61 },
      { species = "PINSIR", level = 62 },
      { species = "VILEPLUME", level = 63 },
    },
  },
  SAFARIZONE_ROCKET5 = {
    classId = "GRUNTM", classNum = 31, member = 234, event = 3024,
    className = "ROCKET", name = "GRUNT", baseMoney = 45,
    roster = {
      { species = "KANGASKHAN", level = 62 },
      { species = "TAUROS", level = 63 },
      { species = "SNORLAX", level = 64 },
    },
  },
  SAFARIZONE_BOSS = {
    classId = "EXECUTIVEF", classNum = 55, member = 235, event = 3025,
    className = "ROCKET", name = "ARIANA", baseMoney = 70,
    roster = {
      { species = "ARBOK", level = 64 },
      { species = "VILEPLUME", level = 65 },
      { species = "MURKROW", level = 65 },
      { species = "HOUNDOOM", level = 66 },
      { species = "CROBAT", level = 67 },
      { species = "TYRANITAR", level = 68, item = "LUM_BERRY" },
    },
  },
}

return Content
