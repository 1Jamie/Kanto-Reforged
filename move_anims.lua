-- Map expansion (Gen 2+) moves onto Gen 1 battle-anim primitives.
-- Prefer custom seq compositions (subanims + SE_* + stock SFX ids) when a
-- whole-clip alias would collide with a sibling move; fall back to stock
-- Gen 1 clips otherwise. Sounds always reference Gen 1 move ids so the
-- MoveSoundTable lookup stays valid.

local MoveAnims = {}

-- Row helpers ---------------------------------------------------------------

local function se(effect, sound)
  local row = { effect = effect }
  if sound then row.sound = sound end
  return row
end

local function sub(subanim, tileset, delay, sound)
  local row = {
    subanim = subanim,
    tileset = tileset or 0,
    delay = delay or 4,
  }
  if sound then row.sound = sound end
  return row
end

local function custom(source, seq)
  return { source = source, seq = seq }
end

-- Custom compositions -------------------------------------------------------
-- Built only from stock subanims / SE_* / Gen 1 sound move ids.

local CUSTOM = {
  -- Ghost / Dark projectiles & auras
  SHADOW_BALL = custom("custom:shadow_ball", {
    se("SE_DARK_SCREEN_PALETTE", "CONFUSE_RAY"),
    sub(63, 1, 3, "SWIFT"),                 -- star/ball tiles
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DARK_PULSE = custom("custom:dark_pulse", {
    se("SE_DARK_SCREEN_PALETTE", "SUPERSONIC"),
    sub(49, 0, 4, "SUPERSONIC"),            -- ripple ring
    se("SE_WAVY_SCREEN", "CONFUSION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  HEX = custom("custom:hex", {
    se("SE_DARKEN_MON_PALETTE", "CONFUSE_RAY"),
    sub(62, 1, 6, "CONFUSE_RAY"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  OMINOUS_WIND = custom("custom:ominous_wind", {
    se("SE_DARKEN_MON_PALETTE"),
    sub(16, 1, 6, "GUST"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ASTONISH = custom("custom:astonish", {
    se("SE_DARK_SCREEN_FLASH", "LEER"),
    sub(2, 0, 6, "BITE"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  SHADOW_SNEAK = custom("custom:shadow_sneak", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(4, 1, 6),
    se("SE_SHOW_MON_PIC"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SHADOW_CLAW = custom("custom:shadow_claw", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(15, 0, 6, "SLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SHADOW_PUNCH = custom("custom:shadow_punch", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(2, 0, 4, "COMET_PUNCH"),
    sub(2, 0, 4, "COMET_PUNCH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  NIGHT_SLASH = custom("custom:night_slash", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  PHANTOM_FORCE = custom("custom:phantom_force", {
    se("SE_DARK_SCREEN_PALETTE", "TELEPORT"),
    se("SE_SQUISH_MON_PIC"),
    se("SE_SHOOT_BALLS_UPWARD"),
    se("SE_DELAY_ANIMATION_10"),
    se("SE_SHOW_MON_PIC"),
    sub(4, 1, 6, "MEGA_PUNCH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  POLTERGEIST = custom("custom:poltergeist", {
    se("SE_DARK_SCREEN_PALETTE", "CONFUSE_RAY"),
    sub(82, 0, 4, "PAY_DAY"),               -- flung debris / coins
    sub(48, 0, 4, "ROCK_THROW"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  WILL_O_WISP = custom("custom:will_o_wisp", {
    se("SE_DARKEN_MON_PALETTE"),
    sub(17, 1, 6, "EMBER"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  CURSE = custom("custom:curse", {
    se("SE_DARK_SCREEN_PALETTE", "DISABLE"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SPITE = custom("custom:spite", {
    se("SE_DARKEN_MON_PALETTE", "LEER"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DESTINY_BOND = custom("custom:destiny_bond", {
    se("SE_DARK_SCREEN_PALETTE", "CONFUSE_RAY"),
    sub(33, 0, 6),
    sub(34, 0, 6),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  GRUDGE = custom("custom:grudge", {
    se("SE_DARKEN_MON_PALETTE", "SMOG"),
    sub(25, 1, 6, "SMOG"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  NIGHTMARE = custom("custom:nightmare", {
    se("SE_FLASH_SCREEN_LONG", "HYPNOSIS"),
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_WAVY_SCREEN", "CONFUSION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Dark physical / status
  CRUNCH = custom("custom:crunch", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(2, 0, 8, "BITE"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SUCKER_PUNCH = custom("custom:sucker_punch", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(2, 0, 4, "COMET_PUNCH"),
    se("SE_SHOW_MON_PIC"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FOUL_PLAY = custom("custom:foul_play", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH", "TAKE_DOWN"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SNARL = custom("custom:snarl", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(21, 1, 6, "ROAR"),
    sub(21, 1, 6, "ROAR"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  THROAT_CHOP = custom("custom:throat_chop", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(3, 0, 8, "KARATE_CHOP"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  PAYBACK = custom("custom:payback", {
    se("SE_DARKEN_MON_PALETTE"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ASSURANCE = custom("custom:assurance", {
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
  }),
  NASTY_PLOT = custom("custom:nasty_plot", {
    se("SE_DARK_SCREEN_PALETTE", "AMNESIA"),
    sub(37, 0, 8, "AMNESIA"),
    sub(37, 0, 8, "AMNESIA"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  HONE_CLAWS = custom("custom:hone_claws", {
    se("SE_LIGHT_SCREEN_PALETTE", "SHARPEN"),
    sub(67, 0, 6),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  TAUNT = custom("custom:taunt", {
    se("SE_DARK_SCREEN_PALETTE", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH", "LEER"),
    se("SE_DARK_SCREEN_FLASH", "LEER"),
    se("SE_SHAKE_ENEMY_HUD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FAKE_TEARS = custom("custom:fake_tears", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    sub(18, 0, 6, "GROWL"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FLATTER = custom("custom:flatter", {
    se("SE_LIGHT_SCREEN_PALETTE", "LOVELY_KISS"),
    sub(18, 0, 6, "GROWL"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MEMENTO = custom("custom:memento", {
    se("SE_DARK_SCREEN_PALETTE", "SMOG"),
    se("SE_DARKEN_MON_PALETTE"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Psychic
  PSYSHOCK = custom("custom:psyshock", {
    se("SE_FLASH_SCREEN_LONG", "PSYBEAM"),
    sub(46, 0, 3, "PSYBEAM"),
    se("SE_DARK_SCREEN_FLASH"),
    sub(4, 1, 6, "MEGA_PUNCH"),
  }),
  PSYCHIC_FANGS = custom("custom:psychic_fangs", {
    se("SE_FLASH_SCREEN_LONG", "PSYCHIC_M"),
    sub(2, 0, 8, "BITE"),
    se("SE_WAVY_SCREEN"),
  }),
  ZEN_HEADBUTT = custom("custom:zen_headbutt", {
    se("SE_LIGHT_SCREEN_PALETTE", "MEDITATE"),
    sub(5, 1, 6, "HEADBUTT"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  EXTRASENSORY = custom("custom:extrasensory", {
    se("SE_FLASH_SCREEN_LONG", "CONFUSION"),
    sub(62, 1, 6, "CONFUSE_RAY"),
    se("SE_WAVY_SCREEN"),
  }),
  FUTURE_SIGHT = custom("custom:future_sight", {
    se("SE_LIGHT_SCREEN_PALETTE", "TELEPORT"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_FLASH_SCREEN_LONG", "PSYCHIC_M"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  PSYCHO_BOOST = custom("custom:psycho_boost", {
    se("SE_DARK_SCREEN_PALETTE", "PSYCHIC_M"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_FLASH_SCREEN_LONG"),
    se("SE_WAVY_SCREEN"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  LUSTER_PURGE = custom("custom:luster_purge", {
    se("SE_LIGHT_SCREEN_PALETTE", "FLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_FLASH_SCREEN_LONG", "PSYCHIC_M"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MIST_BALL = custom("custom:mist_ball", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  PSYCHO_CUT = custom("custom:psycho_cut", {
    se("SE_FLASH_SCREEN_LONG", "PSYBEAM"),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
  }),
  STORED_POWER = custom("custom:stored_power", {
    se("SE_LIGHT_SCREEN_PALETTE", "FOCUS_ENERGY"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  EXPANDING_FORCE = custom("custom:expanding_force", {
    se("SE_FLASH_SCREEN_LONG", "PSYCHIC_M"),
    se("SE_WAVY_SCREEN"),
    se("SE_SHAKE_SCREEN"),
  }),
  CALM_MIND = custom("custom:calm_mind", {
    se("SE_LIGHT_SCREEN_PALETTE", "MEDITATE"),
    sub(67, 0, 6),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  COSMIC_POWER = custom("custom:cosmic_power", {
    se("SE_LIGHT_SCREEN_PALETTE", "GROWTH"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  TRICK_ROOM = custom("custom:trick_room", {
    se("SE_DARK_SCREEN_PALETTE", "DISABLE"),
    se("SE_WAVY_SCREEN", "CONFUSION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MAGIC_ROOM = custom("custom:magic_room", {
    se("SE_LIGHT_SCREEN_PALETTE", "REFLECT"),
    se("SE_WAVY_SCREEN", "CONFUSION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  WONDER_ROOM = custom("custom:wonder_room", {
    se("SE_DARK_SCREEN_FLASH", "CONVERSION"),
    se("SE_WAVY_SCREEN", "CONFUSION"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  GRAVITY = custom("custom:gravity", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_SHAKE_SCREEN", "EARTHQUAKE"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  HEAL_PULSE = custom("custom:heal_pulse", {
    se("SE_LIGHT_SCREEN_PALETTE", "RECOVER"),
    sub(49, 0, 6, "SUPERSONIC"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Fairy
  MOONBLAST = custom("custom:moonblast", {
    se("SE_LIGHT_SCREEN_PALETTE", "LOVELY_KISS"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DAZZLING_GLEAM = custom("custom:dazzling_gleam", {
    se("SE_LIGHT_SCREEN_PALETTE", "FLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  PLAY_ROUGH = custom("custom:play_rough", {
    sub(1, 0, 6, "DOUBLESLAP"),
    sub(2, 0, 6, "BITE"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  DRAINING_KISS = custom("custom:draining_kiss", {
    se("SE_LIGHT_SCREEN_PALETTE", "LOVELY_KISS"),
    sub(18, 0, 6, "LOVELY_KISS"),
    sub(33, 0, 6),
    sub(34, 0, 6),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FAIRY_WIND = custom("custom:fairy_wind", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(16, 1, 6, "GUST"),
    se("SE_PETALS_FALLING"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DISARMING_VOICE = custom("custom:disarming_voice", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(18, 0, 6, "GROWL"),
    sub(21, 1, 6, "ROAR"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ALLURING_VOICE = custom("custom:alluring_voice", {
    se("SE_LIGHT_SCREEN_PALETTE", "SING"),
    sub(18, 0, 6, "SING"),
    sub(64, 0, 6),
    se("SE_WAVY_SCREEN"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MOONLIGHT = custom("custom:moonlight", {
    se("SE_LIGHT_SCREEN_PALETTE", "RECOVER"),
    se("SE_BLINK_MON"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  CHARM = custom("custom:charm", {
    se("SE_LIGHT_SCREEN_PALETTE", "LOVELY_KISS"),
    sub(18, 0, 6, "LOVELY_KISS"),
    se("SE_PETALS_FALLING"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  BABY_DOLL_EYES = custom("custom:baby_doll_eyes", {
    se("SE_LIGHT_SCREEN_PALETTE", "LEER"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MISTY_TERRAIN = custom("custom:misty_terrain", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    se("SE_PETALS_FALLING"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MISTY_EXPLOSION = custom("custom:misty_explosion", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    sub(52, 0, 4, "EXPLOSION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Dragon
  DRAGON_PULSE = custom("custom:dragon_pulse", {
    sub(31, 1, 4, "DRAGON_RAGE"),
    sub(46, 0, 3, "HYPER_BEAM"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  DRAGON_BREATH = custom("custom:dragon_breath", {
    sub(31, 1, 4, "DRAGON_RAGE"),
    sub(12, 1, 6),
    sub(25, 1, 6, "SMOG"),
  }),
  DRACO_METEOR = custom("custom:draco_meteor", {
    se("SE_DARK_SCREEN_PALETTE", "LEECH_SEED"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(48, 0, 4, "ROCK_THROW"),
    sub(48, 0, 4, "ROCK_THROW"),
    sub(46, 0, 2, "HYPER_BEAM"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DRAGON_DANCE = custom("custom:dragon_dance", {
    se("SE_LIGHT_SCREEN_PALETTE", "SWORDS_DANCE"),
    sub(24, 0, 6, "SWORDS_DANCE"),
    sub(24, 0, 6, "SWORDS_DANCE"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DRAGON_CLAW = custom("custom:dragon_claw", {
    sub(15, 0, 6, "SLASH"),
    sub(15, 0, 6, "SLASH"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  OUTRAGE = custom("custom:outrage", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(1, 0, 4, "THRASH"),
    sub(1, 0, 4, "THRASH"),
    sub(4, 1, 6, "THRASH"),
    se("SE_SHAKE_SCREEN"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  TWISTER = custom("custom:twister", {
    sub(16, 1, 6, "GUST"),
    sub(16, 1, 6, "WHIRLWIND"),
    se("SE_SHAKE_ENEMY_HUD"),
  }),
  DRAGON_RUSH = custom("custom:dragon_rush", {
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH", "TAKE_DOWN"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
  }),

  -- Steel
  FLASH_CANNON = custom("custom:flash_cannon", {
    se("SE_LIGHT_SCREEN_PALETTE", "SWIFT"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  IRON_HEAD = custom("custom:iron_head", {
    se("SE_LIGHT_SCREEN_PALETTE", "HARDEN"),
    sub(5, 1, 6, "HEADBUTT"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  IRON_TAIL = custom("custom:iron_tail", {
    se("SE_LIGHT_SCREEN_PALETTE", "HARDEN"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    sub(4, 1, 6, "FIRE_PUNCH"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  METAL_CLAW = custom("custom:metal_claw", {
    se("SE_LIGHT_SCREEN_PALETTE", "SHARPEN"),
    sub(15, 0, 6, "SLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  METEOR_MASH = custom("custom:meteor_mash", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(2, 0, 4, "COMET_PUNCH"),
    sub(2, 0, 4, "COMET_PUNCH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  BULLET_PUNCH = custom("custom:bullet_punch", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(2, 0, 3, "COMET_PUNCH"),
    se("SE_SHOW_MON_PIC"),
  }),
  GYRO_BALL = custom("custom:gyro_ball", {
    se("SE_LIGHT_SCREEN_PALETTE", "DEFENSE_CURL"),
    sub(67, 0, 4),
    sub(63, 1, 3, "SWIFT"),
    se("SE_MOVE_MON_HORIZONTALLY"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  STEEL_WING = custom("custom:steel_wing", {
    se("SE_LIGHT_SCREEN_PALETTE", "HARDEN"),
    sub(4, 1, 6, "WING_ATTACK"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DOOM_DESIRE = custom("custom:doom_desire", {
    se("SE_DARK_SCREEN_PALETTE", "LEECH_SEED"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_FLASH_SCREEN_LONG"),
    sub(46, 0, 2, "HYPER_BEAM"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  STEEL_BEAM = custom("custom:steel_beam", {
    se("SE_LIGHT_SCREEN_PALETTE", "HARDEN"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(46, 0, 2, "HYPER_BEAM"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  IRON_DEFENSE = custom("custom:iron_defense", {
    se("SE_LIGHT_SCREEN_PALETTE", "HARDEN"),
    sub(67, 0, 6),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  METAL_SOUND = custom("custom:metal_sound", {
    sub(21, 1, 6, "SCREECH"),
    sub(21, 1, 6, "SCREECH"),
    se("SE_SHAKE_ENEMY_HUD"),
  }),
  AUTOTOMIZE = custom("custom:autotomize", {
    se("SE_LIGHT_SCREEN_PALETTE", "AGILITY"),
    se("SE_SHOOT_MANY_BALLS_UPWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Fire
  FLARE_BLITZ = custom("custom:flare_blitz", {
    se("SE_LIGHT_SCREEN_PALETTE", "LEECH_SEED"),
    sub(17, 1, 4, "EMBER"),
    se("SE_MOVE_MON_HORIZONTALLY"),
    se("SE_DARK_SCREEN_FLASH", "DOUBLE_EDGE"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  BLAZE_KICK = custom("custom:blaze_kick", {
    sub(1, 0, 6, "DOUBLE_KICK"),
    sub(17, 1, 6, "FIRE_PUNCH"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  HEAT_WAVE = custom("custom:heat_wave", {
    sub(16, 1, 6, "GUST"),
    sub(12, 1, 6, "FLAMETHROWER"),
    sub(13, 1, 6),
  }),
  LAVA_PLUME = custom("custom:lava_plume", {
    sub(31, 1, 4, "FIRE_BLAST"),
    sub(32, 1, 4),
    se("SE_SHAKE_SCREEN"),
  }),
  OVERHEAT = custom("custom:overheat", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(31, 1, 4, "FLAMETHROWER"),
    sub(12, 1, 6),
    sub(13, 1, 6),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ERUPTION = custom("custom:eruption", {
    se("SE_SHAKE_SCREEN", "EARTHQUAKE"),
    sub(31, 1, 4, "FIRE_BLAST"),
    sub(32, 1, 4),
    sub(12, 1, 6),
  }),
  BLAST_BURN = custom("custom:blast_burn", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(31, 1, 4, "FIRE_BLAST"),
    sub(32, 1, 4),
    sub(32, 1, 4),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FLAME_WHEEL = custom("custom:flame_wheel", {
    sub(12, 1, 4, "FIRE_SPIN"),
    sub(13, 1, 4),
    se("SE_MOVE_MON_HORIZONTALLY"),
    se("SE_RESET_MON_POSITION"),
  }),
  FLAME_CHARGE = custom("custom:flame_charge", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(17, 1, 4, "EMBER"),
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(4, 1, 4),
    se("SE_SHOW_MON_PIC"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FIRE_FANG = custom("custom:fire_fang", {
    sub(2, 0, 6, "BITE"),
    sub(17, 1, 6, "EMBER"),
  }),
  MYSTICAL_FIRE = custom("custom:mystical_fire", {
    se("SE_LIGHT_SCREEN_PALETTE", "CONFUSE_RAY"),
    sub(17, 1, 6, "EMBER"),
    sub(62, 1, 6),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SACRED_FIRE = custom("custom:sacred_fire", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(31, 1, 4, "FIRE_BLAST"),
    sub(12, 1, 6),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Water
  WATER_PULSE = custom("custom:water_pulse", {
    sub(53, 0, 10, "BUBBLEBEAM"),
    se("SE_WAVY_SCREEN", "CONFUSION"),
  }),
  AQUA_JET = custom("custom:aqua_jet", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(44, 0, 4, "WATER_GUN"),
    sub(4, 1, 4),
    se("SE_SHOW_MON_PIC"),
  }),
  AQUA_TAIL = custom("custom:aqua_tail", {
    se("SE_SLIDE_MON_DOWN", "LEECH_SEED"),
    sub(26, 0, 4, "HYDRO_PUMP"),
    sub(2, 0, 4),
    se("SE_SLIDE_MON_UP"),
  }),
  SCALD = custom("custom:scald", {
    sub(26, 0, 6, "HYDRO_PUMP"),
    sub(17, 1, 6, "EMBER"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  MUDDY_WATER = custom("custom:muddy_water", {
    se("SE_DARKEN_MON_PALETTE"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    sub(26, 0, 6, "HYDRO_PUMP"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  WHIRLPOOL = custom("custom:whirlpool", {
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    sub(26, 0, 4, "HYDRO_PUMP"),
    sub(26, 0, 4),
  }),
  ORIGIN_PULSE = custom("custom:origin_pulse", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(26, 0, 4, "HYDRO_PUMP"),
    sub(46, 0, 2, "HYPER_BEAM"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  WATER_SPOUT = custom("custom:water_spout", {
    se("SE_SHOOT_MANY_BALLS_UPWARD", "HYDRO_PUMP"),
    sub(26, 0, 6, "HYDRO_PUMP"),
  }),
  AQUA_RING = custom("custom:aqua_ring", {
    se("SE_LIGHT_SCREEN_PALETTE", "RECOVER"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  RAIN_DANCE = custom("custom:rain_dance", {
    se("SE_DARKEN_MON_PALETTE"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  BRINE = custom("custom:brine", {
    sub(44, 0, 6, "WATER_GUN"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
  }),
  WAVE_CRASH = custom("custom:wave_crash", {
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH", "TAKE_DOWN"),
    se("SE_RESET_MON_POSITION"),
  }),

  -- Grass
  ENERGY_BALL = custom("custom:energy_ball", {
    se("SE_LIGHT_SCREEN_PALETTE", "MEGA_DRAIN"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  LEAF_BLADE = custom("custom:leaf_blade", {
    se("SE_LEAVES_FALLING", "RAZOR_LEAF"),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
  }),
  SEED_BOMB = custom("custom:seed_bomb", {
    sub(27, 0, 4, "LEECH_SEED"),
    sub(65, 0, 4, "EGG_BOMB"),
    sub(66, 0, 4, "EGG_BOMB"),
  }),
  BULLET_SEED = custom("custom:bullet_seed", {
    sub(27, 0, 3, "LEECH_SEED"),
    sub(28, 0, 3, "STUN_SPORE"),
    sub(0, 0, 3, "POISON_STING"),
  }),
  GIGA_DRAIN = custom("custom:giga_drain", {
    se("SE_LIGHT_SCREEN_PALETTE", "MEGA_DRAIN"),
    se("SE_DARK_SCREEN_FLASH"),
    sub(33, 0, 6),
    sub(34, 0, 6),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  WOOD_HAMMER = custom("custom:wood_hammer", {
    se("SE_LEAVES_FALLING"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH", "TAKE_DOWN"),
    se("SE_RESET_MON_POSITION"),
  }),
  POWER_WHIP = custom("custom:power_whip", {
    sub(22, 0, 4, "VINE_WHIP"),
    sub(1, 0, 4),
    sub(22, 0, 4, "VINE_WHIP"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  LEAF_STORM = custom("custom:leaf_storm", {
    se("SE_LEAVES_FALLING", "RAZOR_LEAF"),
    sub(68, 0, 4, "SWIFT"),
    sub(22, 0, 4, "RAZOR_WIND"),
    se("SE_SHAKE_SCREEN"),
  }),
  PETAL_BLIZZARD = custom("custom:petal_blizzard", {
    se("SE_LIGHT_SCREEN_PALETTE", "PETAL_DANCE"),
    se("SE_PETALS_FALLING"),
    se("SE_SHAKE_SCREEN"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FRENZY_PLANT = custom("custom:frenzy_plant", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(46, 0, 3, "SOLARBEAM"),
    se("SE_LEAVES_FALLING"),
    sub(1, 0, 4),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SOLAR_BLADE = custom("custom:solar_blade", {
    se("SE_LIGHT_SCREEN_PALETTE", "SOLARBEAM"),
    sub(46, 0, 3),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MAGICAL_LEAF = custom("custom:magical_leaf", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_LEAVES_FALLING", "RAZOR_LEAF"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  NEEDLE_ARM = custom("custom:needle_arm", {
    sub(0, 0, 4, "POISON_STING"),
    sub(3, 0, 6, "KARATE_CHOP"),
  }),
  SYNTHESIS = custom("custom:synthesis", {
    se("SE_LIGHT_SCREEN_PALETTE", "RECOVER"),
    se("SE_BLINK_MON"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  INGRAIN = custom("custom:ingrain", {
    sub(27, 0, 6, "LEECH_SEED"),
    sub(28, 0, 6, "STUN_SPORE"),
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  COTTON_GUARD = custom("custom:cotton_guard", {
    se("SE_LIGHT_SCREEN_PALETTE", "BARRIER"),
    sub(51, 0, 6, "BARRIER"),
    sub(54, 0, 6, "POISONPOWDER"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SPIKY_SHIELD = custom("custom:spiky_shield", {
    se("SE_LIGHT_SCREEN_PALETTE", "BARRIER"),
    sub(51, 0, 6, "BARRIER"),
    sub(0, 0, 4, "POISON_STING"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  AROMATHERAPY = custom("custom:aromatherapy", {
    se("SE_LIGHT_SCREEN_PALETTE", "PETAL_DANCE"),
    se("SE_PETALS_FALLING"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Electric
  VOLT_TACKLE = custom("custom:volt_tackle", {
    se("SE_DARK_SCREEN_PALETTE", "THUNDER"),
    sub(43, 1, 4, "THUNDER"),
    se("SE_MOVE_MON_HORIZONTALLY"),
    se("SE_DARK_SCREEN_FLASH", "TAKE_DOWN"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  WILD_CHARGE = custom("custom:wild_charge", {
    sub(41, 1, 2, "THUNDERBOLT"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
  }),
  DISCHARGE = custom("custom:discharge", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(41, 1, 2, "THUNDERBOLT"),
    sub(41, 1, 2, "THUNDERBOLT"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SHOCK_WAVE = custom("custom:shock_wave", {
    sub(41, 1, 2, "THUNDERSHOCK"),
    sub(49, 0, 4, "SUPERSONIC"),
  }),
  CHARGE_BEAM = custom("custom:charge_beam", {
    se("SE_LIGHT_SCREEN_PALETTE", "FOCUS_ENERGY"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(46, 0, 3, "THUNDERBOLT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  VOLT_SWITCH = custom("custom:volt_switch", {
    sub(41, 1, 2, "THUNDERSHOCK"),
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    se("SE_SHOW_MON_PIC"),
  }),
  ELECTRO_BALL = custom("custom:electro_ball", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(63, 1, 3, "SWIFT"),
    sub(41, 1, 2, "THUNDERBOLT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  THUNDER_FANG = custom("custom:thunder_fang", {
    sub(2, 0, 6, "BITE"),
    sub(43, 1, 4, "THUNDERPUNCH"),
  }),
  ZAP_CANNON = custom("custom:zap_cannon", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(41, 1, 2, "THUNDERBOLT"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  CHARGE = custom("custom:charge", {
    se("SE_LIGHT_SCREEN_PALETTE", "FOCUS_ENERGY"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(41, 1, 2, "THUNDER_WAVE"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ELECTRIC_TERRAIN = custom("custom:electric_terrain", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(41, 1, 2, "THUNDERSHOCK"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Ice
  ICE_SHARD = custom("custom:ice_shard", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(47, 0, 8, "ICE_BEAM"),
    se("SE_SHOW_MON_PIC"),
  }),
  ICE_FANG = custom("custom:ice_fang", {
    sub(2, 0, 6, "BITE"),
    sub(47, 0, 10, "ICE_PUNCH"),
  }),
  AVALANCHE = custom("custom:avalanche", {
    sub(29, 0, 4, "ROCK_SLIDE"),
    sub(30, 0, 4, "ROCK_SLIDE"),
    sub(56, 0, 4, "BLIZZARD"),
  }),
  SHEER_COLD = custom("custom:sheer_cold", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(56, 0, 4, "BLIZZARD"),
    se("SE_FLASH_SCREEN_LONG"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FREEZE_DRY = custom("custom:freeze_dry", {
    sub(46, 0, 3, "ICE_BEAM"),
    sub(47, 0, 10),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  ICY_WIND = custom("custom:icy_wind", {
    sub(16, 1, 6, "GUST"),
    sub(47, 0, 10, "ICE_BEAM"),
  }),
  ICICLE_SPEAR = custom("custom:icicle_spear", {
    sub(47, 0, 6, "ICE_BEAM"),
    sub(0, 0, 4, "POISON_STING"),
    sub(47, 0, 6),
  }),
  ICICLE_CRASH = custom("custom:icicle_crash", {
    sub(47, 0, 8, "ICE_BEAM"),
    sub(29, 0, 4, "ROCK_SLIDE"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  HAIL = custom("custom:hail", {
    sub(56, 0, 4, "BLIZZARD"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
  }),
  AURORA_VEIL = custom("custom:aurora_veil", {
    se("SE_LIGHT_SCREEN_PALETTE", "AURORA_BEAM"),
    sub(51, 0, 6, "LIGHT_SCREEN"),
    sub(46, 0, 3, "AURORA_BEAM"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Ground / Rock
  EARTH_POWER = custom("custom:earth_power", {
    se("SE_DARK_SCREEN_FLASH", "FISSURE"),
    se("SE_SHAKE_SCREEN", "EARTHQUAKE"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_SHAKE_SCREEN"),
  }),
  MUD_SHOT = custom("custom:mud_shot", {
    sub(40, 0, 4, "SAND_ATTACK"),
    sub(44, 0, 4, "WATER_GUN"),
  }),
  BULLDOZE = custom("custom:bulldoze", {
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_SHAKE_SCREEN", "EARTHQUAKE"),
    se("SE_RESET_MON_POSITION"),
  }),
  DRILL_RUN = custom("custom:drill_run", {
    sub(5, 1, 4, "HORN_DRILL"),
    sub(5, 1, 4, "HORN_DRILL"),
    se("SE_SHAKE_SCREEN"),
  }),
  PRECIPICE_BLADES = custom("custom:precipice_blades", {
    se("SE_DARK_SCREEN_FLASH", "FISSURE"),
    se("SE_SHAKE_SCREEN", "EARTHQUAKE"),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
  }),
  STONE_EDGE = custom("custom:stone_edge", {
    sub(29, 0, 4, "ROCK_SLIDE"),
    sub(30, 0, 4, "ROCK_SLIDE"),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
  }),
  ROCK_BLAST = custom("custom:rock_blast", {
    sub(48, 0, 3, "ROCK_THROW"),
    sub(48, 0, 3, "ROCK_THROW"),
    sub(48, 0, 3, "ROCK_THROW"),
  }),
  ROCK_TOMB = custom("custom:rock_tomb", {
    sub(48, 0, 4, "ROCK_THROW"),
    sub(29, 0, 4, "ROCK_SLIDE"),
    se("SE_SHAKE_ENEMY_HUD"),
  }),
  POWER_GEM = custom("custom:power_gem", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(63, 1, 3, "SWIFT"),
    sub(46, 0, 3, "AURORA_BEAM"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ANCIENT_POWER = custom("custom:ancient_power", {
    se("SE_LIGHT_SCREEN_PALETTE", "GROWTH"),
    sub(48, 0, 4, "ROCK_THROW"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  STEALTH_ROCK = custom("custom:stealth_rock", {
    sub(48, 0, 4, "ROCK_THROW"),
    sub(48, 0, 4, "ROCK_THROW"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  SANDSTORM = custom("custom:sandstorm", {
    sub(40, 0, 4, "SAND_ATTACK"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    se("SE_SHAKE_SCREEN"),
  }),
  ROCK_POLISH = custom("custom:rock_polish", {
    se("SE_LIGHT_SCREEN_PALETTE", "SHARPEN"),
    sub(67, 0, 6),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Flying
  AERIAL_ACE = custom("custom:aerial_ace", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(4, 1, 4, "WING_ATTACK"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_SHOW_MON_PIC"),
  }),
  AIR_SLASH = custom("custom:air_slash", {
    sub(16, 1, 4, "GUST"),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4, "RAZOR_WIND"),
  }),
  AIR_CUTTER = custom("custom:air_cutter", {
    sub(16, 1, 4, "GUST"),
    sub(22, 0, 4, "RAZOR_WIND"),
  }),
  BRAVE_BIRD = custom("custom:brave_bird", {
    se("SE_SQUISH_MON_PIC", "SKY_ATTACK"),
    se("SE_SHOOT_BALLS_UPWARD"),
    se("SE_SHOW_MON_PIC"),
    sub(4, 1, 4, "HI_JUMP_KICK"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  HURRICANE = custom("custom:hurricane", {
    sub(16, 1, 4, "GUST"),
    sub(16, 1, 4, "WHIRLWIND"),
    se("SE_WAVY_SCREEN", "CONFUSION"),
    se("SE_SHAKE_SCREEN"),
  }),
  AEROBLAST = custom("custom:aeroblast", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(16, 1, 4, "GUST"),
    sub(46, 0, 2, "HYPER_BEAM"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  BOUNCE = custom("custom:bounce", {
    se("SE_BOUNCE_UP_AND_DOWN", "SPLASH"),
    se("SE_SQUISH_MON_PIC"),
    se("SE_SHOOT_BALLS_UPWARD", "FLY"),
    se("SE_SHOW_MON_PIC"),
    sub(4, 1, 6),
  }),
  ACROBATICS = custom("custom:acrobatics", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(4, 1, 4, "WING_ATTACK"),
    sub(1, 0, 4, "DOUBLESLAP"),
    se("SE_SHOW_MON_PIC"),
  }),
  TAILWIND = custom("custom:tailwind", {
    se("SE_LIGHT_SCREEN_PALETTE", "AGILITY"),
    sub(16, 1, 6, "GUST"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ROOST = custom("custom:roost", {
    se("SE_LIGHT_SCREEN_PALETTE", "RECOVER"),
    se("SE_BLINK_MON"),
    sub(4, 1, 4, "WING_ATTACK"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DEFOG = custom("custom:defog", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(16, 1, 6, "WHIRLWIND"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FEATHER_DANCE = custom("custom:feather_dance", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_PETALS_FALLING", "PETAL_DANCE"),
    sub(4, 1, 4, "WING_ATTACK"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Bug
  X_SCISSOR = custom("custom:x_scissor", {
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
  }),
  SIGNAL_BEAM = custom("custom:signal_beam", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(46, 0, 3, "PSYBEAM"),
    se("SE_FLASH_SCREEN_LONG"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  U_TURN = custom("custom:u_turn", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(1, 0, 4, "TWINEEDLE"),
    se("SE_SHOW_MON_PIC"),
    se("SE_SLIDE_MON_OFF"),
    se("SE_SHOW_MON_PIC"),
  }),
  BUG_BUZZ = custom("custom:bug_buzz", {
    sub(21, 1, 4, "ROAR"),
    sub(49, 0, 4, "SUPERSONIC"),
    se("SE_WAVY_SCREEN"),
  }),
  SILVER_WIND = custom("custom:silver_wind", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    sub(16, 1, 6, "GUST"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MEGAHORN = custom("custom:megahorn", {
    sub(69, 0, 4, "HORN_ATTACK"),
    sub(5, 1, 4, "HORN_ATTACK"),
    sub(5, 1, 4, "HORN_DRILL"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  QUIVER_DANCE = custom("custom:quiver_dance", {
    se("SE_LIGHT_SCREEN_PALETTE", "PETAL_DANCE"),
    se("SE_PETALS_FALLING"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  TAIL_GLOW = custom("custom:tail_glow", {
    se("SE_LIGHT_SCREEN_PALETTE", "FLASH"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  STICKY_WEB = custom("custom:sticky_web", {
    sub(55, 0, 6, "STRING_SHOT"),
    sub(55, 0, 6, "STRING_SHOT"),
  }),

  -- Fighting
  CLOSE_COMBAT = custom("custom:close_combat", {
    se("SE_SLIDE_MON_OFF", "SUBMISSION"),
    sub(1, 0, 4),
    sub(3, 0, 4, "KARATE_CHOP"),
    sub(2, 0, 4, "COMET_PUNCH"),
    se("SE_SHOW_MON_PIC"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  FOCUS_BLAST = custom("custom:focus_blast", {
    se("SE_SPIRAL_BALLS_INWARD", "FOCUS_ENERGY"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_DARK_SCREEN_FLASH"),
    sub(4, 1, 6, "MEGA_PUNCH"),
  }),
  AURA_SPHERE = custom("custom:aura_sphere", {
    se("SE_LIGHT_SCREEN_PALETTE", "FOCUS_ENERGY"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  DRAIN_PUNCH = custom("custom:drain_punch", {
    se("SE_LIGHT_SCREEN_PALETTE", "MEGA_DRAIN"),
    sub(2, 0, 6, "MEGA_PUNCH"),
    sub(33, 0, 4),
    sub(34, 0, 4),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  BRICK_BREAK = custom("custom:brick_break", {
    sub(3, 0, 6, "KARATE_CHOP"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_SHAKE_ENEMY_HUD"),
  }),
  SUPERPOWER = custom("custom:superpower", {
    se("SE_LIGHT_SCREEN_PALETTE", "FOCUS_ENERGY"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_SLIDE_MON_OFF", "SUBMISSION"),
    sub(1, 0, 4),
    se("SE_SHOW_MON_PIC"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FOCUS_PUNCH = custom("custom:focus_punch", {
    se("SE_SPIRAL_BALLS_INWARD", "FOCUS_ENERGY"),
    se("SE_DELAY_ANIMATION_10"),
    sub(2, 0, 6, "MEGA_PUNCH"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  CROSS_CHOP = custom("custom:cross_chop", {
    sub(3, 0, 6, "KARATE_CHOP"),
    sub(3, 0, 6, "KARATE_CHOP"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  DYNAMIC_PUNCH = custom("custom:dynamic_punch", {
    sub(2, 0, 6, "MEGA_PUNCH"),
    se("SE_FLASH_SCREEN_LONG", "CONFUSION"),
    se("SE_SHAKE_SCREEN"),
  }),
  MACH_PUNCH = custom("custom:mach_punch", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(2, 0, 3, "COMET_PUNCH"),
    se("SE_SHOW_MON_PIC"),
  }),
  ARM_THRUST = custom("custom:arm_thrust", {
    sub(1, 0, 4, "DOUBLE_KICK"),
    sub(1, 0, 4, "DOUBLE_KICK"),
    sub(3, 0, 4, "KARATE_CHOP"),
  }),
  HAMMER_ARM = custom("custom:hammer_arm", {
    sub(2, 0, 6, "MEGA_PUNCH"),
    se("SE_SHAKE_SCREEN", "EARTHQUAKE"),
  }),
  BULK_UP = custom("custom:bulk_up", {
    se("SE_LIGHT_SCREEN_PALETTE", "MEDITATE"),
    sub(67, 0, 6),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Poison
  POISON_JAB = custom("custom:poison_jab", {
    sub(2, 0, 6, "COMET_PUNCH"),
    sub(19, 0, 4, "ACID"),
    sub(20, 0, 4, "SLUDGE"),
  }),
  SLUDGE_BOMB = custom("custom:sludge_bomb", {
    sub(19, 0, 4, "SLUDGE"),
    sub(20, 0, 4, "SLUDGE"),
    sub(65, 0, 4, "EGG_BOMB"),
  }),
  GUNK_SHOT = custom("custom:gunk_shot", {
    sub(19, 0, 4, "SLUDGE"),
    sub(65, 0, 4, "EGG_BOMB"),
    sub(66, 0, 4, "EGG_BOMB"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  ACID_SPRAY = custom("custom:acid_spray", {
    sub(19, 0, 4, "ACID"),
    se("SE_WATER_DROPLETS_EVERYWHERE", "SURF"),
  }),
  CROSS_POISON = custom("custom:cross_poison", {
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 4),
    sub(20, 0, 4, "POISON_STING"),
  }),
  POISON_FANG = custom("custom:poison_fang", {
    sub(2, 0, 6, "BITE"),
    sub(20, 0, 4, "POISON_STING"),
  }),
  TOXIC_SPIKES = custom("custom:toxic_spikes", {
    sub(0, 0, 4, "POISON_STING"),
    sub(0, 0, 4, "POISON_STING"),
    sub(20, 0, 4, "TOXIC"),
  }),
  VENOSHOCK = custom("custom:venoshock", {
    se("SE_DARKEN_MON_PALETTE"),
    sub(20, 0, 4, "TOXIC"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  COIL = custom("custom:coil", {
    sub(35, 0, 6, "BIND"),
    sub(35, 0, 6, "BIND"),
    se("SE_LIGHT_SCREEN_PALETTE", "GROWTH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),

  -- Normal / misc signature
  HYPER_VOICE = custom("custom:hyper_voice", {
    sub(21, 1, 4, "ROAR"),
    sub(21, 1, 4, "ROAR"),
    sub(18, 0, 4, "GROWL"),
    se("SE_SHAKE_ENEMY_HUD"),
  }),
  BOOMBURST = custom("custom:boomburst", {
    se("SE_DARK_SCREEN_PALETTE"),
    sub(21, 1, 4, "ROAR"),
    sub(21, 1, 4, "ROAR"),
    se("SE_SHAKE_SCREEN"),
    se("SE_WAVY_SCREEN"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  GIGA_IMPACT = custom("custom:giga_impact", {
    se("SE_LIGHT_SCREEN_PALETTE", "LEECH_SEED"),
    se("SE_MOVE_MON_HORIZONTALLY"),
    se("SE_DARK_SCREEN_FLASH", "DOUBLE_EDGE"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  EXTREME_SPEED = custom("custom:extreme_speed", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(4, 1, 3),
    se("SE_SHOW_MON_PIC"),
    se("SE_SLIDE_MON_OFF"),
    sub(4, 1, 3),
    se("SE_SHOW_MON_PIC"),
  }),
  WEATHER_BALL = custom("custom:weather_ball", {
    se("SE_SPIRAL_BALLS_INWARD", "SWIFT"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  HIDDEN_POWER = custom("custom:hidden_power", {
    se("SE_LIGHT_SCREEN_PALETTE", "FOCUS_ENERGY"),
    se("SE_SPIRAL_BALLS_INWARD"),
    sub(77, 1, 6, "TRI_ATTACK"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FACADE = custom("custom:facade", {
    se("SE_DARKEN_MON_PALETTE"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  RETURN = custom("custom:return", {
    se("SE_LIGHT_SCREEN_PALETTE"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FRUSTRATION = custom("custom:frustration", {
    se("SE_DARK_SCREEN_PALETTE"),
    se("SE_MOVE_MON_HORIZONTALLY", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH", "TAKE_DOWN"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  FURY_CUTTER = custom("custom:fury_cutter", {
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 3),
    se("SE_DARK_SCREEN_FLASH", "CUT"),
    sub(22, 0, 3),
  }),
  FALSE_SWIPE = custom("custom:false_swipe", {
    sub(22, 0, 4, "CUT"),
    se("SE_DELAY_ANIMATION_10"),
  }),
  PRESENT = custom("custom:present", {
    sub(65, 0, 4, "EGG_BOMB"),
    sub(82, 0, 4, "PAY_DAY"),
  }),
  FLING = custom("custom:fling", {
    sub(82, 0, 4, "PAY_DAY"),
    se("SE_DARK_SCREEN_FLASH"),
  }),
  THIEF = custom("custom:thief", {
    se("SE_SLIDE_MON_OFF", "QUICK_ATTACK"),
    sub(1, 0, 4, "POUND"),
    sub(82, 0, 4, "PAY_DAY"),
    se("SE_SHOW_MON_PIC"),
  }),
  ATTRACT = custom("custom:attract", {
    se("SE_LIGHT_SCREEN_PALETTE", "LOVELY_KISS"),
    sub(18, 0, 6, "LOVELY_KISS"),
    se("SE_PETALS_FALLING"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  HEAL_BELL = custom("custom:heal_bell", {
    se("SE_LIGHT_SCREEN_PALETTE", "SING"),
    sub(64, 0, 6, "SING"),
    sub(64, 0, 6),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  WISH = custom("custom:wish", {
    se("SE_LIGHT_SCREEN_PALETTE", "RECOVER"),
    sub(63, 1, 3, "SWIFT"),
    se("SE_SPIRAL_BALLS_INWARD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  YAWN = custom("custom:yawn", {
    sub(58, 0, 6, "REST"),
    sub(18, 0, 6, "SING"),
  }),
  ENCORE = custom("custom:encore", {
    se("SE_LIGHT_SCREEN_PALETTE", "DISABLE"),
    se("SE_DARK_SCREEN_FLASH", "LEER"),
    se("SE_SHAKE_ENEMY_HUD"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  TORMENT = custom("custom:torment", {
    se("SE_DARK_SCREEN_PALETTE", "DISABLE"),
    se("SE_DARK_SCREEN_FLASH", "LEER"),
    se("SE_DARK_SCREEN_FLASH"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  MEAN_LOOK = custom("custom:mean_look", {
    se("SE_DARK_SCREEN_PALETTE", "LEECH_SEED"),
    se("SE_DARK_SCREEN_FLASH", "GLARE"),
    se("SE_DARK_SCREEN_FLASH", "GLARE"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  BLOCK = custom("custom:block", {
    se("SE_LIGHT_SCREEN_PALETTE", "BARRIER"),
    sub(51, 0, 6, "BARRIER"),
    se("SE_DARK_SCREEN_FLASH", "GLARE"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  SPIKES = custom("custom:spikes", {
    sub(0, 0, 3, "POISON_STING"),
    sub(0, 0, 3, "POISON_STING"),
    sub(0, 0, 3, "PIN_MISSILE"),
  }),
  ROLLOUT = custom("custom:rollout", {
    se("SE_LIGHT_SCREEN_PALETTE", "DEFENSE_CURL"),
    sub(67, 0, 4),
    sub(48, 0, 4, "ROCK_THROW"),
    se("SE_MOVE_MON_HORIZONTALLY"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
  ICE_BALL = custom("custom:ice_ball", {
    se("SE_LIGHT_SCREEN_PALETTE", "DEFENSE_CURL"),
    sub(67, 0, 4),
    sub(47, 0, 8, "ICE_PUNCH"),
    se("SE_MOVE_MON_HORIZONTALLY"),
    se("SE_RESET_MON_POSITION"),
    se("SE_RESET_SCREEN_PALETTE"),
  }),
}

MoveAnims.CUSTOM = CUSTOM

-- Hand-picked whole-clip aliases where a stock Gen 1 clip is enough.
local EXPLICIT = {
  -- Multi-hit rocks already covered by CUSTOM for Rollout/Ice Ball/etc.
  HEAD_SMASH = "TAKE_DOWN",
  HEAT_CRASH = "TAKE_DOWN",
  HEAVY_SLAM = "TAKE_DOWN",
  -- Dark / Ghost leftovers
  PURSUIT = "QUICK_ATTACK",
  FAINT_ATTACK = "SWIFT",
  FEINT_ATTACK = "SWIFT",
  KNOCK_OFF = "STRENGTH",
  BEAT_UP = "FURY_ATTACK",
  PUNISHMENT = "BITE",
  DARKEST_LARIAT = "BODY_SLAM",
  BRUTAL_SWING = "STRENGTH",
  -- Dragon
  DRAGON_HAMMER = "STRENGTH",
  DRAGON_TAIL = "STRENGTH",
  DUAL_CHOP = "DOUBLE_KICK",
  BREAKING_SWIPE = "SLASH",
  SCALE_SHOT = "FURY_ATTACK",
  -- Steel
  MIRROR_SHOT = "SWIFT",
  SMART_STRIKE = "HORN_ATTACK",
  HARD_PRESS = "STRENGTH",
  METAL_BURST = "COUNTER",
  -- Fighting
  REVENGE = "COUNTER",
  REVERSAL = "LOW_KICK",
  LOW_SWEEP = "LOW_KICK",
  ROCK_SMASH = "KARATE_CHOP",
  POWER_UP_PUNCH = "COMET_PUNCH",
  FORCE_PALM = "MEGA_PUNCH",
  VITAL_THROW = "SEISMIC_TOSS",
  WAKE_UP_SLAP = "DOUBLESLAP",
  TRIPLE_KICK = "DOUBLE_KICK",
  SKY_UPPERCUT = "HI_JUMP_KICK",
  AXE_KICK = "HI_JUMP_KICK",
  BODY_PRESS = "BODY_SLAM",
  -- Fire / Water / Grass leftovers
  FIRE_PLEDGE = "FLAMETHROWER",
  WATER_PLEDGE = "SURF",
  GRASS_PLEDGE = "RAZOR_LEAF",
  HYDRO_CANNON = "HYDRO_PUMP",
  INCINERATE = "EMBER",
  FLAME_BURST = "EMBER",
  BURNING_JEALOUSY = "FLAMETHROWER",
  TEMPER_FLARE = "FIRE_PUNCH",
  BURN_UP = "FIRE_BLAST",
  INFERNO = "FIRE_BLAST",
  DIVE = "WATERFALL",
  LIQUIDATION = "WATERFALL",
  FLIP_TURN = "QUICK_ATTACK",
  RAZOR_SHELL = "CUT",
  OCTAZOOKA = "BUBBLEBEAM",
  CHILLING_WATER = "WATER_GUN",
  LEAFAGE = "RAZOR_LEAF",
  GRASSY_GLIDE = "VINE_WHIP",
  TRAILBLAZE = "VINE_WHIP",
  LEAF_TORNADO = "RAZOR_LEAF",
  -- Electric / Ice
  SPARK = "THUNDERSHOCK",
  NUZZLE = "THUNDERSHOCK",
  ELECTROWEB = "THUNDER_WAVE",
  SUPERCELL_SLAM = "THUNDER",
  POWDER_SNOW = "BLIZZARD",
  FROST_BREATH = "ICE_BEAM",
  ICE_SPINNER = "ICE_PUNCH",
  TRIPLE_AXEL = "DOUBLE_KICK",
  -- Flying / Bug / Ground
  DUAL_WINGBEAT = "WING_ATTACK",
  PLUCK = "PECK",
  SKY_DROP = "FLY",
  DRAGON_ASCENT = "SKY_ATTACK",
  BUG_BITE = "TWINEEDLE",
  FELL_STINGER = "POISON_STING",
  POUNCE = "QUICK_ATTACK",
  SKITTER_SMACK = "HEADBUTT",
  STRUGGLE_BUG = "STRING_SHOT",
  INFESTATION = "BIND",
  LUNGE = "TAKE_DOWN",
  POLLEN_PUFF = "STUN_SPORE",
  MUD_BOMB = "EGG_BOMB",
  MUD_SLAP = "SAND_ATTACK",
  SAND_TOMB = "DIG",
  SCORCHING_SANDS = "SAND_ATTACK",
  STOMPING_TANTRUM = "STOMP",
  HEADLONG_RUSH = "TAKE_DOWN",
  HIGH_HORSEPOWER = "STRENGTH",
  SMACK_DOWN = "ROCK_THROW",
  METEOR_BEAM = "HYPER_BEAM",
  -- Status / setup leftovers
  SPIDER_WEB = "STRING_SHOT",
  DETECT = "DOUBLE_TEAM",
  QUICK_GUARD = "DOUBLE_TEAM",
  WIDE_GUARD = "BARRIER",
  ENDURE = "BIDE",
  SNORE = "REST",
  SLEEP_TALK = "REST",
  STOCKPILE = "WITHDRAW",
  SPIT_UP = "HYPER_BEAM",
  SWALLOW = "RECOVER",
  -- Misc damage
  TRUMP_CARD = "SWIFT",
  NATURAL_GIFT = "EGG_BOMB",
  GRASS_KNOT = "VINE_WHIP",
  WRING_OUT = "CONSTRICT",
  ENDEAVOR = "SUPER_FANG",
  FLAIL = "TACKLE",
  MAGNITUDE = "EARTHQUAKE",
  UPROAR = "SCREECH",
  ECHOED_VOICE = "GROWL",
  ROUND = "GROWL",
  CHIP_AWAY = "TACKLE",
  COVET = "PAY_DAY",
  CRUSH_CLAW = "SLASH",
  DOUBLE_HIT = "DOUBLESLAP",
  FAKE_OUT = "POUND",
  FEINT = "QUICK_ATTACK",
  RETALIATE = "TAKE_DOWN",
  SECRET_POWER = "TACKLE",
  SMELLING_SALTS = "DOUBLESLAP",
  TAIL_SLAP = "DOUBLESLAP",
  HYPER_DRILL = "HORN_DRILL",
  LAST_RESORT = "BODY_SLAM",
  ROCK_CLIMB = "TAKE_DOWN",
  TERA_BLAST = "TRI_ATTACK",
  MIRROR_COAT = "COUNTER",
}

-- Type → Gen 1 stock clip (damaging). Status moves use STATUS_DEFAULT.
local TYPE_DEFAULT = {
  NORMAL = "TACKLE",
  FIRE = "EMBER",
  WATER = "WATER_GUN",
  GRASS = "VINE_WHIP",
  ELECTRIC = "THUNDERSHOCK",
  ICE = "ICE_BEAM",
  FIGHTING = "KARATE_CHOP",
  POISON = "POISON_STING",
  GROUND = "BONE_CLUB",
  FLYING = "WING_ATTACK",
  PSYCHIC_TYPE = "CONFUSION",
  BUG = "TWINEEDLE",
  ROCK = "ROCK_THROW",
  GHOST = "LICK",                 -- was Night Shade; keep Night Shade for the real move
  DRAGON = "DRAGON_RAGE",
  DARK = "BITE",
  STEEL = "HEADBUTT",
  FAIRY = "SWIFT",
}

-- Stronger clip when base power is high (Gen 1 “big version of the same idea”).
local TYPE_STRONG = {
  NORMAL = "BODY_SLAM",
  FIRE = "FLAMETHROWER",
  WATER = "HYDRO_PUMP",
  GRASS = "SOLARBEAM",
  ELECTRIC = "THUNDERBOLT",
  ICE = "BLIZZARD",
  FIGHTING = "SUBMISSION",
  POISON = "SLUDGE",
  GROUND = "EARTHQUAKE",
  FLYING = "SKY_ATTACK",
  PSYCHIC_TYPE = "PSYCHIC_M",
  BUG = "PIN_MISSILE",
  ROCK = "ROCK_SLIDE",
  GHOST = "NIGHT_SHADE",
  DRAGON = "HYPER_BEAM",
  DARK = "SUPER_FANG",            -- was Night Shade; distinct from Ghost strong
  STEEL = "STRENGTH",
  FAIRY = "LOVELY_KISS",
}

local STATUS_DEFAULT = {
  NORMAL = "GROWL",
  FIRE = "SMOKESCREEN",
  WATER = "WITHDRAW",
  GRASS = "GROWTH",
  ELECTRIC = "THUNDER_WAVE",
  ICE = "MIST",
  FIGHTING = "FOCUS_ENERGY",
  POISON = "POISONPOWDER",
  GROUND = "SAND_ATTACK",
  FLYING = "DOUBLE_TEAM",
  PSYCHIC_TYPE = "MEDITATE",
  BUG = "STRING_SHOT",
  ROCK = "HARDEN",
  GHOST = "CONFUSE_RAY",
  DRAGON = "LEER",
  DARK = "LEER",
  STEEL = "HARDEN",
  FAIRY = "LOVELY_KISS",
}

local STRONG_POWER = 80

-- moveId → Gen 1 anim id (filled during register; used by runtime fallback)
MoveAnims.ALIAS_BY_ID = {}

function MoveAnims.pickAlias(move)
  if not move or not move.id then return "TACKLE" end
  if CUSTOM[move.id] then
    return nil  -- custom composition; no whole-clip alias
  end
  local explicit = EXPLICIT[move.id]
  if explicit then return explicit end

  local typ = move.type or "NORMAL"
  local power = move.power or 0
  local cat = move.category
  -- Status only when classified as such. Variable-power damaging moves
  -- (Magnitude, Flail, …) ship with power 0/nil but category physical/special.
  local isStatus = (cat == "status")
    or (cat ~= "physical" and cat ~= "special" and power <= 0)
  if isStatus then
    return STATUS_DEFAULT[typ] or "GROWL"
  end
  if power >= STRONG_POWER then
    return TYPE_STRONG[typ] or TYPE_DEFAULT[typ] or "TACKLE"
  end
  return TYPE_DEFAULT[typ] or "TACKLE"
end

-- Returns registration payload: { seq, source } or nil if move unknown.
function MoveAnims.specFor(move)
  if not move or not move.id then
    return { seq = nil, source = "alias:TACKLE", alias = "TACKLE" }
  end
  local c = CUSTOM[move.id]
  if c then
    return { seq = c.seq, source = c.source, custom = true }
  end
  local alias = MoveAnims.pickAlias(move)
  return { alias = alias, source = "alias:" .. alias, custom = false }
end

function MoveAnims.register(mod, moves)
  local ok, base = pcall(require, "data.generated.battle_anims")
  if not ok or type(base) ~= "table" or not base.moveAnims then
    mod.log:warn("battle_anims missing; move anim aliases skipped")
    return 0
  end

  local stock = base.moveAnims
  local n, skipped, composed = 0, 0, 0
  for id, move in pairs(moves or {}) do
    -- Never clobber a real ROM anim if one ever shares an id.
    if stock[id] then
      skipped = skipped + 1
    else
      local c = CUSTOM[id]
      if c and c.seq then
        mod.content.battle_anims:register(id, {
          seq = c.seq,
          source = c.source or ("custom:" .. id),
        })
        MoveAnims.ALIAS_BY_ID[id] = c.source or ("custom:" .. id)
        composed = composed + 1
        n = n + 1
      else
        local alias = MoveAnims.pickAlias(move)
        local src = stock[alias]
        if not src then
          alias = "TACKLE"
          src = stock[alias]
        end
        if src and src.seq then
          mod.content.battle_anims:register(id, {
            seq = src.seq,
            source = "alias:" .. alias,
          })
          MoveAnims.ALIAS_BY_ID[id] = alias
          n = n + 1
        end
      end
    end
  end
  mod.log:info(
    "Registered %d move anims (%d composed, %d aliased; %d already present)",
    n, composed, n - composed, skipped)
  return n
end

-- Runtime safety net: if a move still has no clip (other mods, typos),
-- remap the start() id through our alias table / Tackle.
function MoveAnims.install(mod)
  local AnimPlayer = require("src.battle.AnimPlayer")
  if AnimPlayer._expansionAnimAlias then return end
  local original = AnimPlayer.start
  AnimPlayer.start = function(self, moveId, attackerIsPlayer, opts)
    local anims = self.data and self.data.moveAnims
    if anims and moveId and not anims[moveId] then
      local alias = MoveAnims.ALIAS_BY_ID[moveId]
      if type(alias) == "string" and anims[alias] then
        moveId = alias
      elseif anims.TACKLE then
        moveId = "TACKLE"
      end
    end
    return original(self, moveId, attackerIsPlayer, opts)
  end
  AnimPlayer._expansionAnimAlias = true
end

return MoveAnims
