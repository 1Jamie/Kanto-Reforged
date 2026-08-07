import os
import sys
import json
import argparse
import requests
import time
from PIL import Image

# This script lives in the mod folder.  The game loads assets via
# mods/<folder>/..., and the launcher installs zips to mods/<manifest.id>/,
# so the folder name must match the mod id (Kanto-Reforged).
MOD_ROOT = os.path.dirname(os.path.abspath(__file__))
MOD_ID = os.path.basename(MOD_ROOT)
ASSET_PREFIX = f"mods/{MOD_ID}"


def game_rel_mod_dir(outdir):
    """Game-relative mod path for spriteFront/spriteBack in pokemon_data.lua.

    Always mods/<folder-name>, never an absolute --outdir path.
    """
    name = os.path.basename(os.path.abspath(outdir).rstrip(r"\/"))
    return f"mods/{name}"


VANILLA_TYPES = {
    "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST",
    "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC_TYPE", "ICE", "DRAGON"
}

TYPE_MAP = {
    "PSYCHIC": "PSYCHIC_TYPE"
}

TYPE_CATEGORY = {
    "STEEL": "physical",
    "DARK": "special",
    "FAIRY": "special"
}

GROWTH_RATE_MAP = {
    "slow": "SLOW",
    "medium": "MEDIUM_FAST",
    "fast": "FAST",
    "medium-slow": "MEDIUM_SLOW",
    "erratic": "FAST",
    "fluctuating": "SLOW",
}

# Sun stone -> Moon stone, etc. mapping for Gen 1 compatibility
STONE_MAP = {
    "SUN_STONE": "MOON_STONE",
    "SHINY_STONE": "MOON_STONE",
    "DUSK_STONE": "MOON_STONE",
    "DAWN_STONE": "MOON_STONE",
}

# Trade held items mapped to stones for Gen 1 compatibility
TRADE_STONE_MAP = {
    "KINGS_ROCK": "MOON_STONE",
    "METAL_COAT": "MOON_STONE",
    "DRAGON_SCALE": "WATER_STONE",
    "DEEP_SEA_TOOTH": "WATER_STONE",
    "DEEP_SEA_SCALE": "MOON_STONE",
    "UP_GRADE": "MOON_STONE",
    "DUBIOUS_DISC": "MOON_STONE",
    "REAPER_CLOTH": "MOON_STONE",
    "PROTECTOR": "MOON_STONE",
    "ELECTIRIZER": "THUNDER_STONE",  # Gen 4 only; filtered when target is out of range
    "MAGMARIZER": "FIRE_STONE",      # Gen 4 only; filtered when target is out of range
    "PRISM_SCALE": "WATER_STONE"
}

# PokeAPI hyphenated names -> Gen 1 engine move ids (data/generated/moves.lua)
MOVE_REMAP = {
    "SOLAR_BEAM": "SOLARBEAM",
    "PSYCHIC": "PSYCHIC_M",
    "THUNDER_PUNCH": "THUNDERPUNCH",
    "SELF_DESTRUCT": "SELFDESTRUCT",
    "BUBBLE_BEAM": "BUBBLEBEAM",
    "POISON_POWDER": "POISONPOWDER",
    "THUNDER_SHOCK": "THUNDERSHOCK",
    "DOUBLE_SLAP": "DOUBLESLAP",
    "SONIC_BOOM": "SONICBOOM",
    "VICE_GRIP": "VICEGRIP",
    "HIGH_JUMP_KICK": "HI_JUMP_KICK",
    "SOFT_BOILED": "SOFTBOILED",
}

# Gen 1 item ids that exist in data/generated/items.lua (stones we map onto)
VANILLA_ITEMS = {
    "MOON_STONE", "WATER_STONE", "THUNDER_STONE", "FIRE_STONE", "LEAF_STONE",
}

# Version groups used when backporting Gen 2/3 learnset/TM additions onto
# Kanto species.  Later gens are excluded so Gen 1 mons do not pick up
# Gen 4+ level-up leftovers (Play Rough, etc.).
GEN1_VERSION_GROUPS = {"red-blue", "yellow"}
GEN2_3_VERSION_GROUPS = {
    "gold-silver", "crystal",
    "ruby-sapphire", "emerald", "firered-leafgreen",
    "colosseum", "xd",
}

# mods/Kanto-Reforged/berry_farm.lua plot art: pret/pokeemerald's berry tree
# object-event graphics (MIT-style decomp of Emerald's own GBA source tree,
# not a ROM rip) already ship a soil patch, a generic sprout, and a per-berry
# ripe-tree sheet, so the farm's plot art is fetched from there instead of
# checked into the repo.
POKEEMERALD_BERRY_TREE_BASE = (
    "https://raw.githubusercontent.com/pret/pokeemerald/master/"
    "graphics/object_events/pics/berry_trees/"
)
# Farmable berry id -> which pokeemerald berry-tree sheet stands in for it
# (plain BERRY reuses Oran's tree art; Chesto/Lum cover sleep + any-status).
BERRY_TREE_SHEET = {
    "BERRY": "oran",
    "CHERI_BERRY": "cheri",
    "CHESTO_BERRY": "chesto",
    "PECHA_BERRY": "pecha",
    "RAWST_BERRY": "rawst",
    "ASPEAR_BERRY": "aspear",
    "PERSIM_BERRY": "persim",
    "LUM_BERRY": "lum",
}
# Every sheet in that folder mattes its background to this exact RGB
# (confirmed across dirt_pile.png/sprout.png/the berry sheets) instead of
# real alpha, so it has to be keyed out by hand on the way to a mod asset.
BERRY_TREE_MATTE = (115, 197, 164)


def remap_move(move_id):
    return MOVE_REMAP.get(move_id, move_id)


# Engine id -> PokeAPI slug for moves we remapped away from hyphenated names
MOVE_API_SLUG = {v: k.lower().replace("_", "-") for k, v in MOVE_REMAP.items()}
# Prefer canonical PokeAPI names where the engine id differs
MOVE_API_SLUG.update({
    "PSYCHIC_M": "psychic",
    "HI_JUMP_KICK": "high-jump-kick",
    "SOLARBEAM": "solar-beam",
    "THUNDERPUNCH": "thunder-punch",
    "SELFDESTRUCT": "self-destruct",
    "BUBBLEBEAM": "bubble-beam",
    "POISONPOWDER": "poison-powder",
    "THUNDERSHOCK": "thunder-shock",
    "DOUBLESLAP": "double-slap",
    "SONICBOOM": "sonic-boom",
    "VICEGRIP": "vice-grip",
    "SOFTBOILED": "soft-boiled",
})


def move_api_slug(move_id):
    return MOVE_API_SLUG.get(move_id, move_id.lower().replace("_", "-"))


# Gen 1 engine stats (SpA/SpD collapse to SPECIAL)
STAT_MAP = {
    "attack": "attack",
    "defense": "defense",
    "special-attack": "special",
    "special-defense": "special",
    "speed": "speed",
    "accuracy": "accuracy",
    "evasion": "evasion",
}

# Named Gen 2/3 moves that need dedicated effects (or clear Gen1 analogues)
MOVE_EFFECT_OVERRIDES = {
    "SUNNY_DAY": "EXP_WEATHER_SUNNY",
    "RAIN_DANCE": "EXP_WEATHER_RAINY",
    "SANDSTORM": "EXP_WEATHER_SANDSTORM",
    "HAIL": "EXP_WEATHER_HAIL",
    "PROTECT": "EXP_PROTECT_EFFECT",
    "DETECT": "EXP_PROTECT_EFFECT",
    "BELLY_DRUM": "EXP_BELLY_DRUM_EFFECT",
    "OUTRAGE": "THRASH_PETAL_DANCE_EFFECT",
    "PETAL_DANCE": "THRASH_PETAL_DANCE_EFFECT",  # already Gen1, but safe
    "THRASH": "THRASH_PETAL_DANCE_EFFECT",
    "GIGA_DRAIN": "DRAIN_HP_EFFECT",
    "MEGA_DRAIN": "DRAIN_HP_EFFECT",
    "LEECH_LIFE": "DRAIN_HP_EFFECT",
    "DRAIN_PUNCH": "DRAIN_HP_EFFECT",
    "DRAINING_KISS": "DRAIN_HP_EFFECT",
    "SYNTHESIS": "HEAL_EFFECT",
    "MOONLIGHT": "HEAL_EFFECT",
    "MORNING_SUN": "HEAL_EFFECT",
    "SOFTBOILED": "HEAL_EFFECT",
    "MILK_DRINK": "HEAL_EFFECT",
    "RECOVER": "HEAL_EFFECT",
    "SLACK_OFF": "HEAL_EFFECT",
    "ROOST": "HEAL_EFFECT",
    "HEAL_ORDER": "HEAL_EFFECT",
    "SWORDS_DANCE": "ATTACK_UP2_EFFECT",
    "MEDITATE": "ATTACK_UP1_EFFECT",
    "SHARPEN": "ATTACK_UP1_EFFECT",
    "HOWL": "ATTACK_UP1_EFFECT",
    "DEFENSE_CURL": "DEFENSE_UP1_EFFECT",
    "HARDEN": "DEFENSE_UP1_EFFECT",
    "WITHDRAW": "DEFENSE_UP1_EFFECT",
    "IRON_DEFENSE": "DEFENSE_UP2_EFFECT",
    "ACID_ARMOR": "DEFENSE_UP2_EFFECT",
    "BARRIER": "DEFENSE_UP2_EFFECT",
    "AGILITY": "SPEED_UP2_EFFECT",
    "ROCK_POLISH": "SPEED_UP2_EFFECT",
    "AUTOTOMIZE": "SPEED_UP2_EFFECT",
    "AMNESIA": "SPECIAL_UP2_EFFECT",
    "GROWL": "ATTACK_DOWN1_EFFECT",
    "BABY_DOLL_EYES": "ATTACK_DOWN1_EFFECT",
    "TAIL_WHIP": "DEFENSE_DOWN1_EFFECT",
    "LEER": "DEFENSE_DOWN1_EFFECT",
    "SCREECH": "DEFENSE_DOWN2_EFFECT",
    "STRING_SHOT": "SPEED_DOWN1_EFFECT",
    "COTTON_SPORE": "SPEED_DOWN1_EFFECT",
    "SCARY_FACE": "SPEED_DOWN1_EFFECT",
    "FLASH": "ACCURACY_DOWN1_EFFECT",
    "SMOKESCREEN": "ACCURACY_DOWN1_EFFECT",
    "KINESIS": "ACCURACY_DOWN1_EFFECT",
    "SAND_ATTACK": "ACCURACY_DOWN1_EFFECT",
    "DOUBLE_TEAM": "EVASION_UP1_EFFECT",
    "MINIMIZE": "EVASION_UP1_EFFECT",
    "WILL_O_WISP": "EXP_BURN_EFFECT",
    "THUNDER_WAVE": "PARALYZE_EFFECT",
    "GLARE": "PARALYZE_EFFECT",
    "STUN_SPORE": "PARALYZE_EFFECT",
    "POISON_POWDER": "POISON_EFFECT",
    "POISON_GAS": "POISON_EFFECT",
    "TOXIC": "POISON_EFFECT",
    "SLEEP_POWDER": "SLEEP_EFFECT",
    "SPORE": "SLEEP_EFFECT",
    "HYPNOSIS": "SLEEP_EFFECT",
    "SING": "SLEEP_EFFECT",
    "GRASS_WHISTLE": "SLEEP_EFFECT",
    "LOVELY_KISS": "SLEEP_EFFECT",
    "CONFUSE_RAY": "CONFUSION_EFFECT",
    "SWEET_KISS": "CONFUSION_EFFECT",
    "SUPERSONIC": "CONFUSION_EFFECT",
    "SWAGGER": "EXP_SWAGGER_EFFECT",
    "HIDDEN_POWER": "NO_ADDITIONAL_EFFECT",  # type/power via battle.damage hook
    "WEATHER_BALL": "NO_ADDITIONAL_EFFECT",  # type/power via battle.damage hook
    "SPIKES": "EXP_SPIKES_EFFECT",
    "STEALTH_ROCK": "EXP_STEALTH_ROCK_EFFECT",
    "TOXIC_SPIKES": "EXP_TOXIC_SPIKES_EFFECT",
    "ENCORE": "EXP_ENCORE_EFFECT",
    "WISH": "EXP_WISH_EFFECT",
    "FAKE_OUT": "EXP_FAKE_OUT_EFFECT",
    "TAUNT": "EXP_TAUNT_EFFECT",
    "YAWN": "EXP_YAWN_EFFECT",
    "HEAL_BELL": "EXP_HEAL_BELL_EFFECT",
    "AROMATHERAPY": "EXP_HEAL_BELL_EFFECT",
    "SAFEGUARD": "EXP_SAFEGUARD_EFFECT",
    "REFRESH": "EXP_REFRESH_EFFECT",
    "CURSE": "EXP_CURSE_EFFECT",
    "MEAN_LOOK": "EXP_MEAN_LOOK_EFFECT",
    "BLOCK": "EXP_MEAN_LOOK_EFFECT",
    "SPIDER_WEB": "EXP_MEAN_LOOK_EFFECT",
    "PAIN_SPLIT": "EXP_PAIN_SPLIT_EFFECT",
    "ENDEAVOR": "EXP_ENDEAVOR_EFFECT",
    "RAPID_SPIN": "EXP_RAPID_SPIN_EFFECT",
    "PERISH_SONG": "EXP_PERISH_SONG_EFFECT",
    "DESTINY_BOND": "EXP_DESTINY_BOND_EFFECT",
    "ATTRACT": "EXP_ATTRACT_EFFECT",
    "INGRAIN": "EXP_INGRAIN_EFFECT",
    "AQUA_RING": "EXP_AQUA_RING_EFFECT",
    "STOCKPILE": "EXP_STOCKPILE_EFFECT",
    "SPIT_UP": "EXP_SPIT_UP_EFFECT",
    "SWALLOW": "EXP_SWALLOW_EFFECT",
    "MIRROR_COAT": "EXP_MIRROR_COAT_EFFECT",
    "FOCUS_PUNCH": "EXP_FOCUS_PUNCH_EFFECT",
    "U_TURN": "EXP_U_TURN_EFFECT",
    "VOLT_SWITCH": "EXP_U_TURN_EFFECT",
    "FLAIL": "EXP_VARIABLE_POWER_EFFECT",
    "REVERSAL": "EXP_VARIABLE_POWER_EFFECT",
    "RETURN": "EXP_VARIABLE_POWER_EFFECT",
    "FRUSTRATION": "EXP_VARIABLE_POWER_EFFECT",
    "FACADE": "NO_ADDITIONAL_EFFECT",  # power via battle.damage hook
    "ERUPTION": "NO_ADDITIONAL_EFFECT",  # power via battle.damage hook
    "WATER_SPOUT": "NO_ADDITIONAL_EFFECT",  # power via battle.damage hook
    "HEX": "NO_ADDITIONAL_EFFECT",
    "BRINE": "NO_ADDITIONAL_EFFECT",
    "VENOSHOCK": "NO_ADDITIONAL_EFFECT",
    "PAYBACK": "NO_ADDITIONAL_EFFECT",
    "PURSUIT": "NO_ADDITIONAL_EFFECT",
    "REVENGE": "NO_ADDITIONAL_EFFECT",
    "AVALANCHE": "NO_ADDITIONAL_EFFECT",
    "ENDURE": "EXP_ENDURE_EFFECT",
    "BRICK_BREAK": "EXP_BRICK_BREAK_EFFECT",
    "FALSE_SWIPE": "EXP_FALSE_SWIPE_EFFECT",
    "FURY_CUTTER": "EXP_FURY_CUTTER_EFFECT",
    "FUTURE_SIGHT": "EXP_FUTURE_SIGHT_EFFECT",
    "DOOM_DESIRE": "EXP_FUTURE_SIGHT_EFFECT",
    "PSYCH_UP": "EXP_PSYCH_UP_EFFECT",
    "LOCK_ON": "EXP_LOCK_ON_EFFECT",
    "MIND_READER": "EXP_LOCK_ON_EFFECT",
    "FORESIGHT": "EXP_FORESIGHT_EFFECT",
    "ODOR_SLEUTH": "EXP_FORESIGHT_EFFECT",
    "NIGHTMARE": "EXP_NIGHTMARE_EFFECT",
    "SPITE": "EXP_SPITE_EFFECT",
    "SMELLING_SALTS": "EXP_SMELLING_SALTS_EFFECT",
    "ROLLOUT": "EXP_ROLLOUT_EFFECT",
    "ICE_BALL": "EXP_ROLLOUT_EFFECT",
    "BATON_PASS": "EXP_BATON_PASS_EFFECT",
    "SLEEP_TALK": "EXP_SLEEP_TALK_EFFECT",
    "MAGIC_COAT": "EXP_MAGIC_COAT_EFFECT",
    "UPROAR": "EXP_UPROAR_EFFECT",
    "PRESENT": "EXP_PRESENT_EFFECT",
    "TORMENT": "EXP_TORMENT_EFFECT",
    "ROLE_PLAY": "EXP_ROLE_PLAY_EFFECT",
    "SKILL_SWAP": "EXP_SKILL_SWAP_EFFECT",
    "WORRY_SEED": "EXP_WORRY_SEED_EFFECT",
    "MUD_SPORT": "EXP_MUD_SPORT_EFFECT",
    "WATER_SPORT": "EXP_WATER_SPORT_EFFECT",
    "GRUDGE": "EXP_GRUDGE_EFFECT",
    "ACUPRESSURE": "EXP_ACUPRESSURE_EFFECT",
    "CAMOUFLAGE": "EXP_CAMOUFLAGE_EFFECT",
    "COPYCAT": "EXP_COPYCAT_EFFECT",
    "ASSIST": "EXP_ASSIST_EFFECT",
    "NATURE_POWER": "EXP_NATURE_POWER_EFFECT",
    "SKETCH": "EXP_SKETCH_EFFECT",
    "IMPRISON": "EXP_IMPRISON_EFFECT",
    "SNATCH": "EXP_SNATCH_EFFECT",
    "SECRET_POWER": "EXP_SECRET_POWER_EFFECT",
    "GASTRO_ACID": "EXP_GASTRO_ACID_EFFECT",
    "SIMPLE_BEAM": "EXP_SIMPLE_BEAM_EFFECT",
    "ENTRAINMENT": "EXP_ENTRAINMENT_EFFECT",
    "POWER_TRICK": "EXP_POWER_TRICK_EFFECT",
    "POWER_SWAP": "EXP_POWER_SWAP_EFFECT",
    "GUARD_SWAP": "EXP_GUARD_SWAP_EFFECT",
    "SPEED_SWAP": "EXP_SPEED_SWAP_EFFECT",
    "CLEAR_SMOG": "EXP_CLEAR_SMOG_EFFECT",
    "CHARGE": "EXP_CHARGE_EFFECT",
    "LUCKY_CHANT": "EXP_LUCKY_CHANT_EFFECT",
    "TAILWIND": "EXP_TAILWIND_EFFECT",
    "TRICK_ROOM": "EXP_TRICK_ROOM_EFFECT",
    "HEALING_WISH": "EXP_HEALING_WISH_EFFECT",
    "MEMENTO": "EXP_MEMENTO_EFFECT",
    "CONVERSION_2": "EXP_CONVERSION_2_EFFECT",
    "ME_FIRST": "EXP_ME_FIRST_EFFECT",
    "FOLLOW_ME": "EXP_FOLLOW_ME_EFFECT",
    "RAGE_POWDER": "EXP_FOLLOW_ME_EFFECT",
    "ALLY_SWITCH": "EXP_ALLY_SWITCH_EFFECT",
    "TRICK": "EXP_TRICK_EFFECT",
    "SWITCHEROO": "EXP_TRICK_EFFECT",
    "KNOCK_OFF": "EXP_KNOCK_OFF_EFFECT",
    "RECYCLE": "EXP_RECYCLE_EFFECT",
    "BESTOW": "EXP_BESTOW_EFFECT",


    "MAGNITUDE": "NO_ADDITIONAL_EFFECT",  # power via battle.damage hook
    "HYPER_BEAM": "HYPER_BEAM_EFFECT",
    "GIGA_IMPACT": "HYPER_BEAM_EFFECT",
    "FRENZY_PLANT": "HYPER_BEAM_EFFECT",
    "BLAST_BURN": "HYPER_BEAM_EFFECT",
    "HYDRO_CANNON": "HYPER_BEAM_EFFECT",
    "SOLAR_BEAM": "CHARGE_EFFECT",
    "SOLARBEAM": "CHARGE_EFFECT",
    "RAZOR_WIND": "CHARGE_EFFECT",
    "SKY_ATTACK": "CHARGE_EFFECT",
    "FLY": "FLY_EFFECT",
    "DIG": "FLY_EFFECT",
    "BOUNCE": "FLY_EFFECT",
    "DIVE": "FLY_EFFECT",
    "SHADOW_FORCE": "FLY_EFFECT",
    "EXPLOSION": "EXPLODE_EFFECT",
    "SELFDESTRUCT": "EXPLODE_EFFECT",
    "SELF_DESTRUCT": "EXPLODE_EFFECT",
    "GUILLOTINE": "OHKO_EFFECT",
    "FISSURE": "OHKO_EFFECT",
    "HORN_DRILL": "OHKO_EFFECT",
    "SHEER_COLD": "OHKO_EFFECT",
    "DOUBLE_KICK": "ATTACK_TWICE_EFFECT",
    "TWINEEDLE": "TWINEEDLE_EFFECT",
    "BONEMERANG": "ATTACK_TWICE_EFFECT",
    "DOUBLE_HIT": "ATTACK_TWICE_EFFECT",
    "DUAL_CHOP": "ATTACK_TWICE_EFFECT",
    "DOUBLE_SLAP": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "DOUBLESLAP": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "COMET_PUNCH": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "FURY_ATTACK": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "PIN_MISSILE": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "SPIKE_CANNON": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "BARRAGE": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "FURY_SWIPES": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "BONE_RUSH": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "ARM_THRUST": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "BULLET_SEED": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "ICICLE_SPEAR": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "ROCK_BLAST": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "TAIL_SLAP": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "WATER_SHURIKEN": "TWO_TO_FIVE_ATTACKS_EFFECT",
    "WRAP": "TRAPPING_EFFECT",
    "BIND": "TRAPPING_EFFECT",
    "FIRE_SPIN": "TRAPPING_EFFECT",
    "CLAMP": "TRAPPING_EFFECT",
    "WHIRLPOOL": "TRAPPING_EFFECT",
    "SAND_TOMB": "TRAPPING_EFFECT",
    "MAGMA_STORM": "TRAPPING_EFFECT",
    "INFESTATION": "TRAPPING_EFFECT",
    "TAKE_DOWN": "RECOIL_EFFECT",
    "DOUBLE_EDGE": "RECOIL_EFFECT",
    "SUBMISSION": "RECOIL_EFFECT",
    "STRUGGLE": "RECOIL_EFFECT",
    "VOLT_TACKLE": "RECOIL_EFFECT",
    "FLARE_BLITZ": "RECOIL_EFFECT",
    "BRAVE_BIRD": "RECOIL_EFFECT",
    "WOOD_HAMMER": "RECOIL_EFFECT",
    "WILD_CHARGE": "RECOIL_EFFECT",
    "HEAD_CHARGE": "RECOIL_EFFECT",
    "QUICK_ATTACK": "NO_ADDITIONAL_EFFECT",  # priority via field
    "EXTREME_SPEED": "NO_ADDITIONAL_EFFECT",
    "AQUA_JET": "NO_ADDITIONAL_EFFECT",
    "BULLET_PUNCH": "NO_ADDITIONAL_EFFECT",
    "ICE_SHARD": "NO_ADDITIONAL_EFFECT",
    "MACH_PUNCH": "NO_ADDITIONAL_EFFECT",
    "SHADOW_SNEAK": "NO_ADDITIONAL_EFFECT",
    "VACUUM_WAVE": "NO_ADDITIONAL_EFFECT",
    "SWIFT": "SWIFT_EFFECT",
    "AERIAL_ACE": "SWIFT_EFFECT",
    "MAGNET_BOMB": "SWIFT_EFFECT",
    "SHOCK_WAVE": "SWIFT_EFFECT",
    "MAGICAL_LEAF": "SWIFT_EFFECT",
    "SHADOW_PUNCH": "SWIFT_EFFECT",
    "FEINT_ATTACK": "SWIFT_EFFECT",
    "VITAL_THROW": "SWIFT_EFFECT",
}


def normalize_stat_changes(raw_changes):
    """Collapse PokeAPI stat_changes into Gen1 stage list."""
    out = []
    for entry in raw_changes or []:
        stat_name = (entry.get("stat") or {}).get("name")
        mapped = STAT_MAP.get(stat_name)
        change = entry.get("change") or 0
        if mapped and change:
            out.append({"stat": mapped, "change": change})
    # Merge duplicate SPECIAL ups/downs from spa+spd
    merged = {}
    order = []
    for sc in out:
        key = sc["stat"]
        if key not in merged:
            order.append(key)
            merged[key] = 0
        merged[key] += sc["change"]
    return [{"stat": k, "change": max(-6, min(6, merged[k]))} for k in order if merged[k]]


def primary_stat_effect(stat_changes, target_is_user):
    """Map a single-stat primary change onto a Gen1 effect id, if possible."""
    if len(stat_changes) != 1:
        return None
    sc = stat_changes[0]
    stat, change = sc["stat"], sc["change"]
    if target_is_user:
        table = {
            ("attack", 1): "ATTACK_UP1_EFFECT",
            ("attack", 2): "ATTACK_UP2_EFFECT",
            ("defense", 1): "DEFENSE_UP1_EFFECT",
            ("defense", 2): "DEFENSE_UP2_EFFECT",
            ("speed", 2): "SPEED_UP2_EFFECT",
            ("special", 1): "SPECIAL_UP1_EFFECT",
            ("special", 2): "SPECIAL_UP2_EFFECT",
            ("evasion", 1): "EVASION_UP1_EFFECT",
        }
    else:
        table = {
            ("attack", -1): "ATTACK_DOWN1_EFFECT",
            ("defense", -1): "DEFENSE_DOWN1_EFFECT",
            ("defense", -2): "DEFENSE_DOWN2_EFFECT",
            ("speed", -1): "SPEED_DOWN1_EFFECT",
            ("accuracy", -1): "ACCURACY_DOWN1_EFFECT",
        }
    return table.get((stat, change))


def side_stat_effect(stat_changes):
    """Map a single target-stat drop on contact onto Gen1 side effects."""
    if len(stat_changes) != 1:
        return None
    sc = stat_changes[0]
    if sc["change"] >= 0:
        return None
    return {
        "attack": "ATTACK_DOWN_SIDE_EFFECT",
        "defense": "DEFENSE_DOWN_SIDE_EFFECT",
        "speed": "SPEED_DOWN_SIDE_EFFECT",
        "special": "SPECIAL_DOWN_SIDE_EFFECT",
    }.get(sc["stat"])


def ailment_side_effect(ailment, chance):
    """Pick Gen1 secondary chance buckets from a percent chance."""
    chance = chance or 10
    if ailment == "burn":
        return "BURN_SIDE_EFFECT2" if chance >= 20 else "BURN_SIDE_EFFECT1"
    if ailment == "paralysis":
        return "PARALYZE_SIDE_EFFECT2" if chance >= 20 else "PARALYZE_SIDE_EFFECT1"
    if ailment == "freeze":
        return "FREEZE_SIDE_EFFECT1"
    if ailment == "poison":
        return "POISON_SIDE_EFFECT2" if chance >= 30 else "POISON_SIDE_EFFECT1"
    if ailment == "confusion":
        return "CONFUSION_SIDE_EFFECT"
    return None


def ailment_primary_effect(ailment):
    return {
        "sleep": "SLEEP_EFFECT",
        "poison": "POISON_EFFECT",
        "paralysis": "PARALYZE_EFFECT",
        "confusion": "CONFUSION_EFFECT",
        # Gen1 has no dedicated burn primary; Will-O-Wisp approximates via
        # a custom path later — for now leave unmapped here.
    }.get(ailment)


def map_move_effect(m_id, m_data):
    """
    Return (effect_id, extra_fields) for a PokeAPI move payload.
    extra_fields may include priority, highCrit, statChanges, statChance, statTarget.
    """
    extra = {}
    priority = m_data.get("priority") or 0
    if priority and priority != 0:
        extra["priority"] = priority

    if m_id in MOVE_EFFECT_OVERRIDES:
        return MOVE_EFFECT_OVERRIDES[m_id], extra

    meta = m_data.get("meta") or {}
    category = (meta.get("category") or {}).get("name") or ""
    ailment = (meta.get("ailment") or {}).get("name") or "none"
    ailment_chance = meta.get("ailment_chance") or 0
    flinch_chance = meta.get("flinch_chance") or 0
    drain = meta.get("drain") or 0
    healing = meta.get("healing") or 0
    crit_rate = meta.get("crit_rate") or 0
    min_hits = meta.get("min_hits")
    max_hits = meta.get("max_hits")
    power = m_data.get("power") or 0
    damage_class = (m_data.get("damage_class") or {}).get("name") or "status"

    if crit_rate and crit_rate > 0:
        extra["highCrit"] = True

    stat_changes = normalize_stat_changes(m_data.get("stat_changes"))
    stat_chance = meta.get("stat_chance") or 0

    # Multi-hit
    if min_hits and max_hits:
        if min_hits == 2 and max_hits == 2:
            return "ATTACK_TWICE_EFFECT", extra
        if max_hits >= 3:
            return "TWO_TO_FIVE_ATTACKS_EFFECT", extra

    # OHKO
    if category == "ohko":
        return "OHKO_EFFECT", extra

    # Drain / recoil (PokeAPI encodes recoil as negative drain)
    if drain and drain > 0 and power > 0:
        return "DRAIN_HP_EFFECT", extra
    if drain and drain < 0 and power > 0:
        return "RECOIL_EFFECT", extra

    # Healing status
    if healing and healing > 0 and power == 0:
        return "HEAL_EFFECT", extra

    # Pure status ailments
    if power == 0 and ailment != "none":
        primary = ailment_primary_effect(ailment)
        if primary:
            return primary, extra

    # Pure setup / debuff
    if power == 0 and stat_changes:
        target_is_user = all(sc["change"] > 0 for sc in stat_changes) or category == "net-good-stats"
        # Debuffs are usually all negative
        if all(sc["change"] < 0 for sc in stat_changes):
            target_is_user = False
        mapped = primary_stat_effect(stat_changes, target_is_user)
        if mapped:
            return mapped, extra
        extra["statChanges"] = stat_changes
        if target_is_user:
            extra["statTarget"] = "user"
            return "EXP_STAT_CHANGES_EFFECT", extra
        extra["statTarget"] = "target"
        return "EXP_STAT_DOWN_EFFECT", extra

    # Damaging + secondary ailment
    if power > 0 and ailment != "none" and ailment_chance > 0:
        side = ailment_side_effect(ailment, ailment_chance)
        if side:
            return side, extra

    # Damaging + flinch
    if power > 0 and flinch_chance > 0 and not stat_changes:
        if flinch_chance >= 100:
            return "EXP_FLINCH_SIDE_100", extra
        return "FLINCH_SIDE_EFFECT2" if flinch_chance >= 20 else "FLINCH_SIDE_EFFECT1", extra

    # Damaging + stat changes
    if power > 0 and stat_changes:
        # Self-stat drops after attacking (Overheat, Close Combat, Superpower)
        if all(sc["change"] < 0 for sc in stat_changes) and stat_chance >= 100:
            extra["statChanges"] = stat_changes
            extra["statTarget"] = "user"
            return "EXP_DAMAGE_USER_STAT_EFFECT", extra
        # Self-stat raises on hit (Metal Claw, Ancient Power multi)
        if all(sc["change"] > 0 for sc in stat_changes):
            extra["statChanges"] = stat_changes
            extra["statChance"] = stat_chance or 10
            extra["statTarget"] = "user"
            return "EXP_DAMAGE_STAT_SIDE_EFFECT", extra
        # Target stat drops (Shadow Ball, Crunch, Iron Tail)
        mapped = side_stat_effect(stat_changes)
        if mapped and len(stat_changes) == 1:
            return mapped, extra
        extra["statChanges"] = stat_changes
        extra["statChance"] = stat_chance or 10
        extra["statTarget"] = "target"
        return "EXP_DAMAGE_STAT_SIDE_EFFECT", extra

    # Field / unique / swagger leftovers stay cosmetic
    return "NO_ADDITIONAL_EFFECT", extra


def load_vanilla_species(repo_root="."):

    """Load Gen 1 species ids from the generated data file."""
    path = os.path.join(repo_root, "data", "generated", "pokemon.lua")
    if not os.path.exists(path):
        return set()
    ids = set()
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.endswith("= {") and line[0].isupper():
                ids.add(line.split("=")[0].strip())
    return ids


def load_vanilla_moves(repo_root="."):
    """Load Gen 1 move ids from data/generated/moves.lua."""
    path = os.path.join(repo_root, "data", "generated", "moves.lua")
    if not os.path.exists(path):
        return set()
    ids = set()
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.endswith("= {") and line[0].isupper():
                ids.add(line.split("=")[0].strip())
    return ids


def load_kanto_reforged_move_powers(outdir=None):
    """Parse power for each Kanto Reforged move from pokemon_data.lua (0 = status)."""
    path = os.path.join(outdir or MOD_ROOT, "pokemon_data.lua")
    powers = {}
    if not os.path.exists(path):
        return powers
    current = None
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if stripped.endswith("= {") and stripped[0].isupper():
                current = stripped.split("=")[0].strip()
            elif current and stripped.startswith("power ="):
                try:
                    powers[current] = int(stripped.split("=")[1].split(",")[0].strip())
                except ValueError:
                    powers[current] = 0
                current = None
            elif stripped.startswith("P.species"):
                break
    return powers


def collect_kanto_move_patches(registered_moves, start=1, end=151, outdir=None):
    """Diff Gen 2/3 learnsets/TMs against Gen 1 for Kanto species.

    Returns (learnset_patches, tmhm_patches) where each maps species id ->
    list of additions.  Learnset entries are {level, move}; tmhm is a list
    of move ids.  Only moves that already exist in Gen 1 or will be
    registered by Kanto Reforged are kept (so trainers/wild/gyms can
    legally roll them via Pokemon.movesAtLevel).

    Damaging Gen 2/3-only TM moves (e.g. Iron Tail on Pikachu) are also
    folded into the level-up learnset at level 30 so AI parties can use
    them — Crystal/Emerald only teach those via TM, but this engine has
    no Gen 2 TM items and builds wild/trainer moves from learnsets alone.
    """
    vanilla_moves = load_vanilla_moves()
    move_powers = load_kanto_reforged_move_powers(outdir)
    learnset_patches = {}
    tmhm_patches = {}
    TM_LEARN_LEVEL = 30

    for pid in range(start, end + 1):
        try:
            poke_data = fetch_json(
                f"https://pokeapi.co/api/v2/pokemon/{pid}/", "pokemon", pid
            )
        except Exception as e:
            print(f"Error fetching Kanto learnset for dex {pid}: {e}")
            continue

        species_id = poke_data["name"].upper().replace("-", "_")

        gen1_level = set()
        gen1_tm = set()
        gen23_level = {}  # move -> lowest level across Gen 2/3
        gen23_tm = set()

        for move_entry in poke_data["moves"]:
            m_name = remap_move(move_entry["move"]["name"].upper().replace("-", "_"))
            for detail in move_entry["version_group_details"]:
                vg = detail["version_group"]["name"]
                method = detail["move_learn_method"]["name"]
                level = detail["level_learned_at"]
                if vg in GEN1_VERSION_GROUPS:
                    if method == "level-up" and level > 0:
                        gen1_level.add(m_name)
                    elif method == "machine":
                        gen1_tm.add(m_name)
                elif vg in GEN2_3_VERSION_GROUPS:
                    if method == "level-up" and level > 0:
                        prev = gen23_level.get(m_name)
                        if prev is None or level < prev:
                            gen23_level[m_name] = level
                    elif method == "machine":
                        gen23_tm.add(m_name)

        learn_adds = []
        seen_learn = set()
        for move, level in sorted(gen23_level.items(), key=lambda kv: (kv[1], kv[0])):
            if move in gen1_level:
                continue
            if move not in vanilla_moves and move not in registered_moves:
                continue
            learn_adds.append({"level": level, "move": move})
            seen_learn.add(move)

        # Damaging Gen 2/3 TMs with no Gen 2/3 level-up slot → up to four
        # highest-power synthetic learnset entries (level 30), skipping the
        # generic tutor/TM spam so signature moves (Iron Tail, Zap Cannon)
        # survive Pokemon.movesAtLevel's last-4 window.
        GENERIC_TM = {
            "FACADE", "SECRET_POWER", "HIDDEN_POWER", "RETURN", "FRUSTRATION",
            "SNORE", "MUD_SLAP", "HEADBUTT", "ROCK_SMASH", "STRENGTH",
            "CUT", "FLASH", "WHIRLPOOL", "DIVE", "ROCK_CLIMB",
        }
        tm_candidates = []
        for m in gen23_tm:
            if m in seen_learn or m in gen1_level or m in gen23_level:
                continue
            if m not in registered_moves or m in GENERIC_TM:
                continue
            power = move_powers.get(m, 0)
            if power < 60:
                continue
            tm_candidates.append((power, m))
        tm_candidates.sort(key=lambda kv: (-kv[0], kv[1]))
        for _, m in tm_candidates[:4]:
            learn_adds.append({"level": TM_LEARN_LEVEL, "move": m})
            seen_learn.add(m)
        learn_adds.sort(key=lambda e: (e["level"], e["move"]))

        tm_adds = []
        for m in sorted(gen23_tm):
            if m in gen1_tm:
                continue
            if m not in vanilla_moves and m not in registered_moves:
                continue
            tm_adds.append(m)

        if learn_adds:
            learnset_patches[species_id] = learn_adds
        if tm_adds:
            tmhm_patches[species_id] = tm_adds

        if learn_adds or tm_adds:
            print(
                f"  {species_id}: +{len(learn_adds)} level-up, +{len(tm_adds)} TM/HM"
            )

    return learnset_patches, tmhm_patches


def write_learnset_patches_lua(path, learnset_patches, tmhm_patches):
    """Write mods/Kanto-Reforged/learnset_patches.lua."""
    print(f"Writing {path}...")
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Generated Gen 2/3 learnset/TM additions for Kanto species\n")
        f.write("-- Source: PokeAPI version groups gold-silver .. xd\n")
        f.write("local P = {}\n\n")
        f.write("P.learnset = {\n")
        for species_id in sorted(learnset_patches.keys()):
            f.write(f"  {species_id} = {{\n")
            for entry in learnset_patches[species_id]:
                f.write(
                    f"    {{ level = {entry['level']}, move = {json.dumps(entry['move'])} }},\n"
                )
            f.write("  },\n")
        f.write("}\n\n")
        f.write("P.tmhm = {\n")
        for species_id in sorted(tmhm_patches.keys()):
            f.write(f"  {species_id} = {{\n")
            for mv in tmhm_patches[species_id]:
                f.write(f"    {json.dumps(mv)},\n")
            f.write("  },\n")
        f.write("}\n\n")
        f.write("return P\n")


def ability_from_poke_data(poke_data):
    """First non-hidden ability id (Gen 3+ slot order), or NONE."""
    abilities = poke_data.get("abilities") or []
    non_hidden = [a for a in abilities if not a.get("is_hidden")]
    if non_hidden:
        non_hidden.sort(key=lambda x: x.get("slot", 0))
        return non_hidden[0]["ability"]["name"].upper().replace("-", "_")
    if abilities:
        return abilities[0]["ability"]["name"].upper().replace("-", "_")
    return "NONE"


def collect_kanto_ability_patches(start=1, end=151):
    """Fetch Gen 3-style abilities for Kanto species (PokeAPI pokemon endpoint).

    Returns species_id -> ability_id.  Vanilla Gen 1 data has no abilities;
    this is how Bulbasaur gets OVERGROW, etc.
    """
    patches = {}
    for pid in range(start, end + 1):
        try:
            poke_data = fetch_json(
                f"https://pokeapi.co/api/v2/pokemon/{pid}/", "pokemon", pid
            )
            species_id = poke_data["name"].upper().replace("-", "_")
            # Match engine ids (e.g. Nidoran forms)
            species_id = species_id.replace("NIDORAN_F", "NIDORAN_F").replace(
                "NIDORAN_M", "NIDORAN_M"
            )
            # PokeAPI uses nidoran-f / nidoran-m -> NIDORAN_F / NIDORAN_M
            ability = ability_from_poke_data(poke_data)
            if ability and ability != "NONE":
                patches[species_id] = ability
            print(f"  #{pid} {species_id} -> {ability}")
        except Exception as e:
            print(f"Error fetching ability for dex {pid}: {e}")
    return patches


def write_ability_patches_lua(path, ability_patches):
    """Write mods/Kanto-Reforged/ability_patches.lua."""
    print(f"Writing {path}...")
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Generated Gen 3 abilities for Kanto species (PokeAPI)\n")
        f.write("-- Applied onto vanilla Data.pokemon via pokemon:patch\n")
        f.write("local P = {}\n\n")
        f.write("P.abilities = {\n")
        for species_id in sorted(ability_patches.keys()):
            ability = ability_patches[species_id]
            f.write(f"  {species_id} = {json.dumps(ability)},\n")
        f.write("}\n\n")
        f.write("return P\n")


def species_id_from_pokeapi_name(name):
    """Map PokéAPI species name to engine id (nidoran-f -> NIDORAN_F)."""
    return name.upper().replace("-", "_")


def collect_gender_rate_patches(start=1, end=386):
    """Fetch PokéAPI gender_rate for species in [start, end].

    gender_rate is female eighths (0..8) or -1 for genderless.
    """
    patches = {}
    for pid in range(start, end + 1):
        try:
            spec_data = fetch_json(
                f"https://pokeapi.co/api/v2/pokemon-species/{pid}/",
                "species",
                pid,
            )
            species_id = species_id_from_pokeapi_name(spec_data["name"])
            rate = spec_data.get("gender_rate", -1)
            if rate is None:
                rate = -1
            patches[species_id] = int(rate)
            print(f"  #{pid} {species_id} gender_rate={rate}")
        except Exception as e:
            print(f"Error fetching gender_rate for dex {pid}: {e}")
    return patches


def write_gender_patches_lua(path, gender_patches):
    """Write mods/Kanto-Reforged/gender_patches.lua."""
    print(f"Writing {path}...")
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Generated genderRate (PokéAPI female eighths; -1 = genderless)\n")
        f.write("-- Applied onto Data.pokemon via pokemon:patch\n")
        f.write("local P = {}\n\n")
        f.write("P.rates = {\n")
        for species_id in sorted(gender_patches.keys()):
            rate = gender_patches[species_id]
            f.write(f"  {species_id} = {rate},\n")
        f.write("}\n\n")
        f.write("return P\n")


# PokéAPI egg-group slugs -> Gen 3 engine group ids
EGG_GROUP_MAP = {
    "monster": "MONSTER",
    "water1": "WATER_1",
    "bug": "BUG",
    "flying": "FLYING",
    "ground": "FIELD",
    "fairy": "FAIRY",
    "plant": "GRASS",
    "humanshape": "HUMAN_LIKE",
    "water3": "WATER_3",
    "mineral": "MINERAL",
    "indeterminate": "AMORPHOUS",
    "water2": "WATER_2",
    "ditto": "DITTO",
    "dragon": "DRAGON",
    "no-eggs": "UNDISCOVERED",
}


def egg_group_id(api_name):
    return EGG_GROUP_MAP.get(api_name, api_name.upper().replace("-", "_"))


def pokeapi_move_to_engine_id(api_name):
    """razor-wind -> RAZOR_WIND, then MOVE_REMAP."""
    raw = api_name.upper().replace("-", "_")
    return remap_move(raw)


def collect_breeding_patches(start=1, end=386):
    """eggGroups, hatchCounter, evolvesFrom, eggMoves for dex [start, end]."""
    patches = {}
    evolves_from = {}
    for pid in range(start, end + 1):
        try:
            spec_data = fetch_json(
                f"https://pokeapi.co/api/v2/pokemon-species/{pid}/",
                "species",
                pid,
            )
            species_id = species_id_from_pokeapi_name(spec_data["name"])
            groups = [
                egg_group_id(g["name"])
                for g in (spec_data.get("egg_groups") or [])
            ]
            hatch = int(spec_data.get("hatch_counter") or 20)
            parent = spec_data.get("evolves_from_species")
            if parent and parent.get("name"):
                evolves_from[species_id] = species_id_from_pokeapi_name(parent["name"])

            egg_moves = []
            seen = set()
            try:
                poke_data = fetch_json(
                    f"https://pokeapi.co/api/v2/pokemon/{pid}/",
                    "pokemon",
                    pid,
                )
                for entry in poke_data.get("moves") or []:
                    is_egg = False
                    for vg in entry.get("version_group_details") or []:
                        method = (vg.get("move_learn_method") or {}).get("name")
                        if method == "egg":
                            is_egg = True
                            break
                    if not is_egg:
                        continue
                    mid = pokeapi_move_to_engine_id(entry["move"]["name"])
                    if mid not in seen:
                        seen.add(mid)
                        egg_moves.append(mid)
            except Exception as e:
                print(f"  egg moves skip #{pid}: {e}")

            patches[species_id] = {
                "eggGroups": groups,
                "hatchCounter": hatch,
                "eggMoves": egg_moves,
            }
            print(
                f"  #{pid} {species_id} groups={groups} hatch={hatch} "
                f"eggs={len(egg_moves)}"
            )
        except Exception as e:
            print(f"Error fetching breeding data for dex {pid}: {e}")

    # Walk evolves_from to the root (baby / base form).
    def baby_of(sid):
        seen_chain = set()
        cur = sid
        while cur in evolves_from and cur not in seen_chain:
            seen_chain.add(cur)
            cur = evolves_from[cur]
        return cur

    for sid, row in patches.items():
        row["babySpecies"] = baby_of(sid)
        if sid in evolves_from:
            row["evolvesFrom"] = evolves_from[sid]
    return patches


def write_breeding_patches_lua(path, breeding_patches):
    """Write mods/Kanto-Reforged/breeding_patches.lua."""
    print(f"Writing {path}...")
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Generated breeding fields (PokéAPI egg groups / hatch / egg moves)\n")
        f.write("-- Applied onto Data.pokemon via pokemon:patch\n")
        f.write("local P = {}\n\n")
        f.write("P.species = {\n")
        for species_id in sorted(breeding_patches.keys()):
            row = breeding_patches[species_id]
            groups = ", ".join(json.dumps(g) for g in row["eggGroups"])
            moves = ", ".join(json.dumps(m) for m in row["eggMoves"])
            f.write(f"  {species_id} = {{\n")
            f.write(f"    eggGroups = {{ {groups} }},\n")
            f.write(f"    hatchCounter = {row['hatchCounter']},\n")
            f.write(f"    babySpecies = {json.dumps(row['babySpecies'])},\n")
            if row.get("evolvesFrom"):
                f.write(f"    evolvesFrom = {json.dumps(row['evolvesFrom'])},\n")
            f.write(f"    eggMoves = {{ {moves} }},\n")
            f.write("  },\n")
        f.write("}\n\n")
        f.write("return P\n")



def filter_evolutions(evos, allowed_species, allowed_items=VANILLA_ITEMS):
    """Drop evolutions targeting species/items outside Gen 1-3 content."""
    out = []
    for evo in evos:
        target = evo.get("species")
        if target not in allowed_species:
            sys.stderr.write(
                f"Skipping evolution to {target} (outside Gen 1-3 content)\n"
            )
            continue
        item = evo.get("item")
        if item and item not in allowed_items:
            sys.stderr.write(
                f"Skipping evolution to {target} via missing item {item}\n"
            )
            continue
        out.append(evo)
    return out

def sanitize_text(text):
    if not text:
        return ""
    text = text.replace("\xad", "").replace("\n", " ").replace("\f", " ")
    text = text.replace("“", '"').replace("”", '"').replace("’", "'").replace("‘", "'")
    text = text.encode("ascii", "ignore").decode("ascii")
    return " ".join(text.split())

def get_cache_path(category, filename):
    return os.path.join("tools", ".cache", "pokeapi", category, f"{filename}.json")

def fetch_json(url, cache_category, cache_name):
    cache_path = get_cache_path(cache_category, cache_name)
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    print(f"Fetching {url}...")
    time.sleep(0.1)
    os.makedirs(os.path.dirname(cache_path), exist_ok=True)
    res = requests.get(url)
    res.raise_for_status()
    data = res.json()
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    return data

def download_sprite_file(url, output_path):
    if os.path.exists(output_path):
        return True
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    print(f"Downloading sprite from {url}...")
    time.sleep(0.1)
    try:
        res = requests.get(url, stream=True)
        res.raise_for_status()
        with open(output_path, "wb") as f:
            for chunk in res.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
    except Exception as e:
        print(f"Failed to download sprite: {e}")
        return False

def key_out_flat_background(img):
    """Make the flat backdrop transparent on sprites that lack an alpha channel.

    PokéAPI's Gen 2 Crystal sheets are indexed PNGs with an opaque white
    (sometimes off-white) matte and no tRNS chunk.  Without this step,
    process_sprite treats every matte pixel as opaque white and the battle
    UI draws a white box behind the mon (Wobbuffet, Blissey, Unown, …).

    Strategy: if the image already has real transparency, leave it alone.
    Otherwise flood-fill from every border pixel that matches the dominant
    corner color, so sprite-touching-corner black pixels do not become the
    key color, and enclosed white highlights (eyes, shine) stay opaque.
    """
    from collections import Counter, deque

    img = img.convert("RGBA")
    w, h = img.size
    if w == 0 or h == 0:
        return img

    pixels = img.load()
    transparent = 0
    for y in range(h):
        for x in range(w):
            if pixels[x, y][3] < 128:
                transparent += 1
                if transparent > 0:
                    break
        if transparent > 0:
            break
    if transparent > 0:
        return img

    corners = [
        pixels[0, 0][:3],
        pixels[w - 1, 0][:3],
        pixels[0, h - 1][:3],
        pixels[w - 1, h - 1][:3],
    ]
    # Prefer white/near-white when present: Crystal mattes are white, and a
    # single corner covered by the silhouette should not win the vote.
    whiteish = [c for c in corners if c[0] >= 250 and c[1] >= 250 and c[2] >= 250]
    if whiteish:
        bg = Counter(whiteish).most_common(1)[0][0]
    else:
        bg = Counter(corners).most_common(1)[0][0]

    def matches(x, y):
        r, g, b, a = pixels[x, y]
        return a >= 128 and (r, g, b) == bg

    seen = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not seen[y][x] and matches(x, y):
                seen[y][x] = True
                q.append((x, y))
    for y in range(1, h - 1):
        for x in (0, w - 1):
            if not seen[y][x] and matches(x, y):
                seen[y][x] = True
                q.append((x, y))

    while q:
        x, y = q.popleft()
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and matches(nx, ny):
                seen[ny][nx] = True
                q.append((nx, ny))
    return img


def dilate_opaque(img, radius=1):
    """Expand opaque pixels into neighboring transparent cells.

    Gen 2/3 sheets ship 1px black outlines and pin-thin white waist stems.
    Fitting those into a Gen 1 32x32 back with NEAREST drops the stem rows
    and the battle pic looks like it lost its waist / edges.  A 1px dilate
    before the resize keeps silhouettes connected after scaling.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seeds = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 128:
                seeds.append((x, y, (r, g, b, a)))
    extras = {}
    for x, y, color in seeds:
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if dx == 0 and dy == 0:
                    continue
                if abs(dx) + abs(dy) > radius:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] < 128:
                    extras.setdefault((nx, ny), color)
    for (x, y), color in extras.items():
        px[x, y] = color
    return img


def drop_orphan_pixels(img, min_blob=4):
    """Clear tiny disconnected opaque blobs left by dilate + NEAREST scale.

    Keeps every component with >= min_blob pixels so a briefly-split waist
    is not erased, but 1-2px 'orphans' on the dress edge disappear.
    """
    from collections import deque

    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if seen[y][x] or px[x, y][3] < 128:
                continue
            q = deque([(x, y)])
            seen[y][x] = True
            cells = []
            while q:
                cx, cy = q.popleft()
                cells.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny][3] >= 128:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if len(cells) < min_blob:
                for ox, oy in cells:
                    r, g, b, _ = px[ox, oy]
                    px[ox, oy] = (r, g, b, 0)
    return img


def close_small_holes(img, max_gap=2):
    """Fill short transparent dents between opaque neighbors (waist / hem bites)."""
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()

    def pick_fill(colors):
        return max(colors, key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])

    for y in range(h):
        for x in range(w):
            if src[x, y][3] >= 128:
                continue
            neighbors = []
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] >= 128:
                    neighbors.append(src[nx, ny])
            left = x > 0 and src[x - 1, y][3] >= 128
            right = x + 1 < w and src[x + 1, y][3] >= 128
            if (left and right) or len(neighbors) >= 3:
                if left and right:
                    dst[x, y] = pick_fill([src[x - 1, y], src[x + 1, y]])
                elif neighbors:
                    dst[x, y] = pick_fill(neighbors)
        # Bridge short horizontal gaps (disconnected hem flares).
        x = 0
        while x < w:
            if src[x, y][3] >= 128:
                x += 1
                continue
            start = x
            while x < w and src[x, y][3] < 128:
                x += 1
            end = x
            gap = end - start
            if 1 <= gap <= max_gap and start > 0 and end < w:
                if src[start - 1, y][3] >= 128 and src[end, y][3] >= 128:
                    fill = pick_fill([src[start - 1, y], src[end, y]])
                    for fx in range(start, end):
                        dst[fx, y] = fill
    return out


def resize_pixel_art(img, new_w, new_h):
    """Downscale by majority-color blocks so thin outlines / folds survive.

    NEAREST keeps one lucky source pixel per cell and drops the rest — on
    96→32 backs that erases most internal detail.  Majority vote (with a
    boost for near-black) keeps Gen 1-readable structure.
    """
    from collections import Counter

    img = img.convert("RGBA")
    w, h = img.size
    if (w, h) == (new_w, new_h):
        return img
    if new_w >= w and new_h >= h:
        return img.resize((new_w, new_h), Image.NEAREST)

    px = img.load()
    out = Image.new("RGBA", (new_w, new_h), (0, 0, 0, 0))
    op = out.load()
    for y in range(new_h):
        y0 = int(y * h / new_h)
        y1 = max(y0 + 1, int((y + 1) * h / new_h))
        for x in range(new_w):
            x0 = int(x * w / new_w)
            x1 = max(x0 + 1, int((x + 1) * w / new_w))
            counts = Counter()
            for yy in range(y0, y1):
                for xx in range(x0, x1):
                    c = px[xx, yy]
                    if c[3] < 128:
                        continue
                    counts[c] += 1
                    if c[0] + c[1] + c[2] < 80:
                        counts[c] += 2
            if counts:
                op[x, y] = counts.most_common(1)[0][0]
    return out


def _pixel_luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def thicken_narrow_stems(img, min_width=7):
    """Widen thin mid-body rows without growing a 2px black outline blob.

    Copies the edge outline one pixel outward, then backfills the old edge
    with the inward body color when the edge was outline-dark.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    def row_span(y):
        xs = [x for x in range(w) if px[x, y][3] >= 128]
        if not xs:
            return None
        return min(xs), max(xs)

    spans = [row_span(y) for y in range(h)]
    out = img.copy()
    dst = out.load()
    for y in range(1, h - 1):
        cur = spans[y]
        if not cur:
            continue
        left, right = cur
        width = right - left + 1
        if width >= min_width:
            continue
        above = spans[y - 1]
        below = spans[y + 1]
        wider = []
        if above:
            wider.append(above[1] - above[0] + 1)
        if below:
            wider.append(below[1] - below[0] + 1)
        if not wider or max(wider) < width + 2:
            continue

        if left > 0 and dst[left, y][3] >= 128:
            edge = dst[left, y]
            inward = (
                dst[left + 1, y]
                if left + 1 <= right and dst[left + 1, y][3] >= 128
                else edge
            )
            dst[left - 1, y] = edge
            if _pixel_luma(edge) < 60 and _pixel_luma(inward) > _pixel_luma(edge) + 25:
                dst[left, y] = inward

        if right + 1 < w and dst[right, y][3] >= 128:
            edge = dst[right, y]
            inward = (
                dst[right - 1, y]
                if right - 1 >= left and dst[right - 1, y][3] >= 128
                else edge
            )
            dst[right + 1, y] = edge
            if _pixel_luma(edge) < 60 and _pixel_luma(inward) > _pixel_luma(edge) + 25:
                dst[right, y] = inward
    return out


def despeckle_interior(img, passes=2):
    """Smooth noisy interior pixels left by NEAREST downscale (backs especially)."""
    img = img.convert("RGBA")
    for _ in range(passes):
        w, h = img.size
        src = img.load()
        out = img.copy()
        dst = out.load()
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                c = src[x, y]
                if c[3] < 128:
                    continue
                # Skip silhouette edge — outline pass owns those.
                if any(
                    src[x + dx, y + dy][3] < 128
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
                ):
                    continue
                neighbors = [
                    src[x + dx, y + dy]
                    for dy in (-1, 0, 1)
                    for dx in (-1, 0, 1)
                    if not (dx == 0 and dy == 0) and src[x + dx, y + dy][3] >= 128
                ]
                if len(neighbors) < 5:
                    continue
                # Bucket by coarse luma; replace outliers with the mode bucket's
                # median-ish member (first neighbor in that bucket).
                buckets = {}
                for n in neighbors:
                    key = int(_pixel_luma(n) // 64)
                    buckets.setdefault(key, []).append(n)
                mode_key = max(buckets.keys(), key=lambda k: len(buckets[k]))
                if len(buckets[mode_key]) < 4:
                    continue
                my_key = int(_pixel_luma(c) // 64)
                if my_key != mode_key:
                    dst[x, y] = buckets[mode_key][0]
        img = out
    return img


def clean_interior_ink(img):
    """Remove stray interior black blobs that are not real facial features.

    Isolated / nearly-isolated dark pixels inside the body read as mud on
    heavily downscaled backs.  Keeps dark runs with 2+ dark neighbors (eyes,
    mouth lines, folds).
    """
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            c = src[x, y]
            if c[3] < 128 or _pixel_luma(c) >= 50:
                continue
            if any(
                src[x + dx, y + dy][3] < 128
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
            ):
                continue  # silhouette ink
            dark_n = 0
            body = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    n = src[x + dx, y + dy]
                    if n[3] < 128:
                        continue
                    if _pixel_luma(n) < 50:
                        dark_n += 1
                    else:
                        body.append(n)
            if dark_n <= 1 and len(body) >= 4:
                dst[x, y] = max(body, key=_pixel_luma)
    return out


def ensure_selective_outline(img):
    """Readable Gen 1 rim: full silhouette ink, soft only on lit color tops.

    Raticate can drop outline on lit tan edges because tan still reads on a
    white battle BG.  Ralts' white gown cannot — those exterior whites vanish
    without ink.  Soften only the lit top of chromatic fills (green hair);
    every other exterior pixel gets a 1px black rim.
    """
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    black = (0, 0, 0, 255)

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    for y in range(h):
        for x in range(w):
            if src[x, y][3] < 128:
                continue
            open_l = not opaque(x - 1, y)
            open_r = not opaque(x + 1, y)
            open_u = not opaque(x, y - 1)
            open_d = not opaque(x, y + 1)
            if not (open_l or open_r or open_u or open_d):
                continue

            # Prefer a chromatic inward sample for lit-top softening.
            body = src[x, y]
            for nx, ny in (
                (x, y + 1), (x - 1, y), (x + 1, y), (x, y - 1),
                (x - 1, y + 1), (x + 1, y + 1),
            ):
                if opaque(nx, ny):
                    body = src[nx, ny]
                    break

            sat = max(body[0], body[1], body[2]) - min(body[0], body[1], body[2])
            lit_top = open_u and not open_d
            # Soft lit crown only for saturated mid colors (hair/leaves).
            if lit_top and sat >= 48 and 60 <= _pixel_luma(body) <= 190:
                dst[x, y] = body
            else:
                dst[x, y] = black
    return out


def gen1_depth_pass(img, strong=False):
    """Sparse interior ink + top highlights (Raticate-level, not ink flood)."""
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    luma = [[None] * w for _ in range(h)]
    satm = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a >= 128:
                luma[y][x] = _pixel_luma((r, g, b))
                satm[y][x] = max(r, g, b) - min(r, g, b)

    ys = [y for y in range(h) for x in range(w) if luma[y][x] is not None]
    if not ys:
        return img
    y_min, y_max = min(ys), max(ys)
    hi_band = y_min + max(2, int((y_max - y_min) * 0.35))
    step = 34 if strong else 42

    out = img.copy()
    dst = out.load()
    black = (0, 0, 0, 255)
    white = (255, 255, 255, 255)

    for y in range(h):
        for x in range(w):
            L = luma[y][x]
            if L is None:
                continue
            exterior = any(
                not (0 <= x + dx < w and 0 <= y + dy < h)
                or luma[y + dy][x + dx] is None
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
            )
            neighbors = []
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and luma[ny][nx] is not None:
                    neighbors.append(luma[ny][nx])
            if not neighbors:
                continue

            chroma = satm[y][x]
            if not exterior and any(L < n - step for n in neighbors):
                if L < (90 if chroma >= 40 else 110):
                    dst[x, y] = black
                    continue
            if (
                chroma < 40
                and y <= hi_band
                and L >= 175
                and L >= max(neighbors) - 2
                and not exterior
            ):
                dst[x, y] = white
    return out


def dither_indexed_flats(indexed_img):
    """Very sparse black grit in flat mid fills — Raticate fur, not hatch."""
    w, h = indexed_img.size
    px = indexed_img.load()
    marks = []
    for y in range(2, h - 2):
        for x in range(2, w - 2):
            if px[x, y] != 2:
                continue
            if any(
                px[x + dx, y + dy] != 2
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
            ):
                continue
            if any(
                px[x + dx, y + dy] == 0
                for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2))
            ):
                continue
            if (x * 5 + y * 11) % 8 == 0:
                marks.append((x, y))
    for x, y in marks:
        px[x, y] = 4
    return indexed_img


def seal_outline_breaks(img):
    """Fill 1px outline gaps on the silhouette (classic left-waist chew).

    If a transparent cell sits between two opaque cells on a row, and either
    neighbor is outline-dark, paint the gap black so white body cannot bleed
    into a white UI background.
    """
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    black = (0, 0, 0, 255)
    for y in range(h):
        for x in range(1, w - 1):
            if src[x, y][3] >= 128:
                continue
            left, right = src[x - 1, y], src[x + 1, y]
            if left[3] < 128 or right[3] < 128:
                continue
            if _pixel_luma(left) < 80 or _pixel_luma(right) < 80:
                dst[x, y] = black
        # Also seal vertical 1px bites on the left/right profile.
        for x in range(w):
            if src[x, y][3] >= 128:
                continue
            up = src[x, y - 1] if y > 0 else None
            down = src[x, y + 1] if y + 1 < h else None
            if not up or not down or up[3] < 128 or down[3] < 128:
                continue
            # Only when this column is on the exterior profile (side open).
            left_open = x == 0 or src[x - 1, y][3] < 128
            right_open = x + 1 >= w or src[x + 1, y][3] < 128
            if (left_open or right_open) and (
                _pixel_luma(up) < 80 or _pixel_luma(down) < 80
            ):
                dst[x, y] = black
    return out


def extract_species_palette(img):
    """4 RGB triples (lightest first) from opaque pixels — Gen 1 SGB shape.

    Unknown Gen 2/3 species otherwise fall through to MEWMON (peach + purple),
    which is why Cyndaquil went blue and Ralts went muddled purple in Advanced
    color mode.  These colors are registered as the species' own palette and
    the grayscale pic is shaded by nearest-palette-color, not raw luminance.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    opaque = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 128:
                opaque.append((r, g, b))
    if not opaque:
        return [(255, 255, 255), (170, 170, 170), (85, 85, 85), (0, 0, 0)]

    # Boost saturated accent pixels (Ralts horns, Cyndaquil flames, …) so
    # MEDIANCUT does not fold them into a neighboring muddy mid-tone.
    weighted = []
    for r, g, b in opaque:
        weighted.append((r, g, b))
        sat = max(r, g, b) - min(r, g, b)
        if sat >= 48:
            weighted.extend([(r, g, b)] * 4)

    side = max(8, int(len(weighted) ** 0.5) + 1)
    canvas = Image.new("RGB", (side, side), (0, 0, 0))
    canvas.putdata(weighted + [(0, 0, 0)] * (side * side - len(weighted)))

    colors = []
    methods = [Image.Quantize.MAXCOVERAGE, Image.Quantize.MEDIANCUT]
    for method in methods:
        try:
            quantized = canvas.quantize(colors=4, method=method)
            raw = quantized.getpalette() or []
            colors = []
            has_real_black = any(max(p) < 24 for p in opaque)
            for i in range(0, min(12, len(raw)), 3):
                c = (raw[i], raw[i + 1], raw[i + 2])
                # Drop the padded black filler if it was not in the art.
                if c == (0, 0, 0) and not has_real_black:
                    continue
                if c not in colors:
                    colors.append(c)
            if len(colors) >= 3:
                break
        except Exception:
            continue

    if not colors:
        # Fallback: most common unique colors by luminance buckets.
        colors = [(255, 255, 255), (170, 170, 170), (85, 85, 85), (0, 0, 0)]

    while len(colors) < 4:
        # Split the largest luminance gap with a midpoint.
        ordered = sorted(
            colors,
            key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
        )
        best_i, best_gap = 0, -1
        for i in range(len(ordered) - 1):
            la = 0.299 * ordered[i][0] + 0.587 * ordered[i][1] + 0.114 * ordered[i][2]
            lb = 0.299 * ordered[i + 1][0] + 0.587 * ordered[i + 1][1] + 0.114 * ordered[i + 1][2]
            if lb - la > best_gap:
                best_gap, best_i = lb - la, i
        a, b = ordered[best_i], ordered[best_i + 1]
        colors.append(((a[0] + b[0]) // 2, (a[1] + b[1]) // 2, (a[2] + b[2]) // 2))
    colors = colors[:4]
    colors.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2], reverse=True)

    # Status-screen SGB zone behind the pic uses palette color 0 for the
    # white UI tiles in that rect.  Vanilla Advanced/GBC mon pals pin this
    # to pure white (255,255,255); the classic SGB off-white (255,239,255)
    # reads as a pink/lilac box around Gen 2/3 pics.  Match GBC.
    colors[0] = (255, 255, 255)
    # Gen 1 battle outlines read as true black (DMG shade 3 / SGB color 3).
    colors[3] = (0, 0, 0)
    return colors


def nearest_palette_index(r, g, b, colors):
    best_i, best_d = 0, None
    for i, (cr, cg, cb) in enumerate(colors):
        d = (r - cr) * (r - cr) + (g - cg) * (g - cg) + (b - cb) * (b - cb)
        if best_d is None or d < best_d:
            best_i, best_d = i, d
    return best_i


def shade_for_pixel(r, g, b, colors):
    """Map a source pixel to a 0..3 shade index.

    High-chroma accents (horns, flames) snap to the nearest palette color.
    Low-chroma structure uses a white / mid / black ramp (slots 0, 1, 3) so
    folds survive without painting dress shadows into the accent slot (2).
    """
    if r + g + b < 24:
        return 3
    sat = max(r, g, b) - min(r, g, b)
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    if sat >= 48:
        if luma < 75:
            return 3  # deep chroma folds → black ink
        return nearest_palette_index(r, g, b, colors)
    # Pale body (white / lavender) must stay on the white slot.
    if luma >= 175 or min(r, g, b) >= 170:
        return 0
    if luma >= 100:
        return 1
    return 3


# Backs are 32x32.  Shift feet DOWN by this many pixels so the bottom of the
# art is intentionally clipped (Gen 1 battle "cut by the FIGHT box" feel).
BACK_BOTTOM_CLIP = 5

# DMG shade indices written into the indexed PNG (1..4).  Runtime Advanced
# color remaps these via the species' 4-color SGB palette (light→dark).
DMG_SHADE_RGB = [
    (255, 255, 255),  # shade 0 / index 1
    (170, 170, 170),  # shade 1 / index 2
    (85, 85, 85),     # shade 2 / index 3
    (0, 0, 0),        # shade 3 / index 4
]


def process_sprite(input_path, output_path, target_size):
    """Build a Gen 1-style 4-shade sprite.

    Returns (ok, palette) where palette is 4 RGB triples lightest-first, or
    (False, None) on failure.  Callers register `palette` under the species
    id so Advanced color mode stops falling through to MEWMON.
    """
    try:
        img = key_out_flat_background(Image.open(input_path))

        # Crop transparency, but keep a 1px halo so tight silhouettes are
        # not shaved by getbbox before the dilate / resize.
        bbox = img.getbbox()
        if bbox:
            l, t, r, b = bbox
            l = max(0, l - 1)
            t = max(0, t - 1)
            r = min(img.size[0], r + 1)
            b = min(img.size[1], b + 1)
            img = img.crop((l, t, r, b))

        # Pull the species' 4 colors from the (still-hued) art BEFORE we
        # destroy chroma.  Same palette is what Advanced mode will reapply.
        species_colors = extract_species_palette(img)

        w, h = img.size
        is_back = target_size == (32, 32)
        # Backs may render taller than 32 then shift down so feet clip off.
        clip = BACK_BOTTOM_CLIP if is_back else 0
        fit_w = target_size[0]
        fit_h = target_size[1] + clip

        # Light pre-dilate on fronts only — backs lose detail if fattened
        # before a heavy 96→32 shrink.
        if (w > fit_w or h > fit_h) and not is_back:
            img = dilate_opaque(img)
            img = close_small_holes(img, max_gap=1)
            w, h = img.size

        ratio = min(fit_w / w, fit_h / h)
        new_w, new_h = max(1, int(round(w * ratio))), max(1, int(round(h * ratio)))
        new_w = min(new_w, fit_w)
        new_h = min(new_h, fit_h)
        # Majority-block shrink keeps folds; NEAREST alone drops them.
        img_resized = resize_pixel_art(img, new_w, new_h)
        img_resized = close_small_holes(img_resized, max_gap=2 if not is_back else 1)
        if not is_back:
            img_resized = thicken_narrow_stems(img_resized, min_width=7)
            img_resized = seal_outline_breaks(img_resized)

        # Backs: shift down so the bottom `clip` rows fall off the canvas.
        new_img = Image.new("RGBA", target_size, (255, 255, 255, 0))
        x = (target_size[0] - new_w) // 2
        if is_back:
            y = target_size[1] - new_h + clip
        else:
            y = (target_size[1] - new_h) // 2
        new_img.paste(img_resized, (x, y), img_resized)
        new_img = close_small_holes(new_img, max_gap=2 if not is_back else 1)
        if not is_back:
            new_img = seal_outline_breaks(new_img)
            new_img = thicken_narrow_stems(new_img, min_width=7)
        # Venusaur-style volume: interior black crevices + white top hits +
        # stipple.  Stronger on backs, which otherwise read as flat slabs.
        new_img = gen1_depth_pass(new_img, strong=is_back)
        new_img = drop_orphan_pixels(new_img)
        new_img = seal_outline_breaks(new_img)
        new_img = ensure_selective_outline(new_img)

        # Map pixels → DMG shades.  Accents keep hue; structure uses luma so
        # backs are not a flat green/white blob.
        px = new_img.load()
        indexed_img = Image.new("P", target_size, 0)
        for py in range(target_size[1]):
            for px_x in range(target_size[0]):
                r, g, b, a = px[px_x, py]
                if a < 128:
                    indexed_img.putpixel((px_x, py), 0)
                elif r + g + b < 24:
                    indexed_img.putpixel((px_x, py), 4)
                else:
                    shade = shade_for_pixel(r, g, b, species_colors)
                    indexed_img.putpixel((px_x, py), shade + 1)

        if is_back:
            indexed_img = dither_indexed_flats(indexed_img)

        palette = [
            255, 255, 255,  # 0: Transparent
            255, 255, 255,  # 1: White
            170, 170, 170,  # 2: Light Gray
            85, 85, 85,     # 3: Dark Gray
            0, 0, 0,        # 4: Black
        ]
        palette += [0] * (768 - len(palette))
        indexed_img.putpalette(palette)

        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        indexed_img.save(output_path, transparency=0)
        return True, species_colors
    except Exception as e:
        print(f"Failed processing sprite {input_path}: {e}")
        return False, None


# Gen 1 battle fronts are 40 / 48 / 56 px (frontSize 5 / 6 / 7 tiles).
# Kanto Reforged sprites used to be force-fitted to 56x56, so small mons like
# Aron drew as large as Onix. Map dex height onto those three buckets so
# proportions roughly match Gen 1 (Geodude-sized rocks stay small).
def front_size_for_height_dm(height_dm):
    inches = (height_dm or 0) * 3.937
    if inches <= 28:   # ≤ 2'4"  → 40px (Diglett / Geodude / Pikachu band)
        return 5
    if inches <= 47:   # ≤ 3'11" → 48px
        return 6
    return 7           # taller → 56px


def front_size_for_dex_entry(height_ft, height_in):
    inches = (height_ft or 0) * 12 + (height_in or 0)
    return front_size_for_height_dm(inches / 3.937)


def front_canvas_px(front_size):
    return front_size * 8


def sprite_cache_dir():
    """PokéAPI sprite cache: tools/.cache/sprites under the game repo.

    Prefer the repo that owns this mod (../.. from MOD_ROOT); fall back to
    cwd so `python3 generate_pokemon_mod.py --resprite` still works when
    run from the gen1recomp tree.
    """
    candidates = [
        os.path.join(os.path.dirname(os.path.dirname(MOD_ROOT)), "tools", ".cache", "sprites"),
        os.path.join("tools", ".cache", "sprites"),
    ]
    for path in candidates:
        if os.path.isdir(path):
            return path
    return candidates[0]


def write_species_palettes_lua(path, palettes_by_species):
    """Write mods/.../species_palettes.lua — id -> 4 RGB triples, lightest first."""
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Generated by generate_pokemon_mod.py. DO NOT EDIT.\n")
        f.write("-- Per-species SGB palettes extracted from source art so Advanced\n")
        f.write("-- color mode does not fall through to MEWMON (peach/purple).\n")
        f.write("return {\n")
        for species_id in sorted(palettes_by_species.keys()):
            colors = palettes_by_species[species_id]
            f.write(f"  {species_id} = {{\n")
            for r, g, b in colors:
                f.write(f"    {{ {int(r)}, {int(g)}, {int(b)} }},\n")
            f.write("  },\n")
        f.write("}\n")


def ensure_palette_field(body, species_id):
    """Insert or replace `palette = \"SPECIES\"` inside a pokemon_data species body."""
    import re
    if re.search(r'\bpalette\s*=', body):
        return re.sub(
            r'palette\s*=\s*"[^"]*"',
            f'palette = "{species_id}"',
            body,
            count=1,
        )
    # Place after frontSize when present, else after spriteBack.
    if re.search(r'frontSize\s*=\s*\d+', body):
        return re.sub(
            r'(frontSize\s*=\s*\d+,)',
            rf'\1\n    palette = "{species_id}",',
            body,
            count=1,
        )
    if re.search(r'spriteBack\s*=', body):
        return re.sub(
            r'(spriteBack\s*=\s*"[^"]*",)',
            rf'\1\n    palette = "{species_id}",',
            body,
            count=1,
        )
    return f'    palette = "{species_id}",\n' + body


def resprite_kanto_reforged(outdir):
    """Re-bake front sprites from the PokéAPI cache using height-based
    frontSize, and rewrite frontSize fields in pokemon_data.lua.
    Does not re-fetch species tables."""
    import re

    lua_path = os.path.join(outdir, "pokemon_data.lua")
    if not os.path.exists(lua_path):
        print(f"No pokemon_data.lua at {lua_path}")
        return

    with open(lua_path, "r", encoding="utf-8") as f:
        lua = f.read()

    counts = {5: 0, 6: 0, 7: 0}
    missing = []
    cache_dir = sprite_cache_dir()
    species_palettes = {}

    # Walk each P.species entry for id/dex/height.
    species_chunks = re.split(r'\n  ([A-Z0-9_]+) = \{', lua)
    # species_chunks[0] preamble; then name, body pairs
    out_parts = [species_chunks[0]]
    i = 1
    resprited = 0
    while i < len(species_chunks) - 1:
        name = species_chunks[i]
        body = species_chunks[i + 1]
        i += 2

        dex_m = re.search(r'dex = (\d+)', body)
        ft_m = re.search(r'heightFt = (\d+)', body)
        in_m = re.search(r'heightIn = (\d+)', body)
        if not (dex_m and ft_m and in_m):
            out_parts.append(f"\n  {name} = {{{body}")
            continue

        dex = int(dex_m.group(1))
        front_size = front_size_for_dex_entry(int(ft_m.group(1)), int(in_m.group(1)))
        counts[front_size] = counts.get(front_size, 0) + 1
        canvas = front_canvas_px(front_size)

        front_cache = os.path.join(cache_dir, f"{dex}_front.png")
        front_mod = os.path.join(outdir, "assets", f"{name.lower()}_front.png")
        back_cache = os.path.join(cache_dir, f"{dex}_back.png")
        back_mod = os.path.join(outdir, "assets", f"{name.lower()}_back.png")
        if os.path.exists(front_cache):
            ok, colors = process_sprite(front_cache, front_mod, (canvas, canvas))
            if ok:
                resprited += 1
                if colors:
                    species_palettes[name] = colors
            else:
                missing.append(name)
        else:
            missing.append(name)
        if os.path.exists(back_cache):
            ok_b, colors_b = process_sprite(back_cache, back_mod, (32, 32))
            # Prefer front-derived palette; fall back to back if front missing.
            if ok_b and colors_b and name not in species_palettes:
                species_palettes[name] = colors_b

        # Castform weather forms share Castform's height/canvas.
        if name == "CASTFORM":
            for form_suffix, form_id in [("sunny", 10013), ("rainy", 10014), ("snowy", 10015)]:
                f_cache = os.path.join(cache_dir, f"{form_id}_front.png")
                f_mod = os.path.join(outdir, "assets", f"castform_{form_suffix}_front.png")
                if os.path.exists(f_cache):
                    process_sprite(f_cache, f_mod, (canvas, canvas))
                b_cache = os.path.join(cache_dir, f"{form_id}_back.png")
                b_mod = os.path.join(outdir, "assets", f"castform_{form_suffix}_back.png")
                if os.path.exists(b_cache):
                    process_sprite(b_cache, b_mod, (32, 32))

        body = re.sub(
            r'frontSize = \d+',
            f'frontSize = {front_size}',
            body,
            count=1,
        )
        if name in species_palettes:
            body = ensure_palette_field(body, name)
        out_parts.append(f"\n  {name} = {{{body}")

    with open(lua_path, "w", encoding="utf-8") as f:
        f.write("".join(out_parts))

    if species_palettes:
        write_species_palettes_lua(
            os.path.join(outdir, "species_palettes.lua"),
            species_palettes,
        )
        print(f"Wrote {len(species_palettes)} species palettes")

    print(
        f"Resprited {resprited} fronts by dex height "
        f"(40px={counts.get(5,0)}, 48px={counts.get(6,0)}, 56px={counts.get(7,0)})"
    )
    if missing:
        print(f"  skipped {len(missing)} (no cache): {', '.join(missing[:8])}"
              f"{'...' if len(missing) > 8 else ''}")

def key_out_matte(img, matte=BERRY_TREE_MATTE):
    """RGBA copy of img with every exact-matte pixel made transparent."""
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if (r, g, b) == matte:
                pixels[x, y] = (r, g, b, 0)
    return img

def generate_berry_farm_assets(outdir):
    """Fetch mods/Kanto-Reforged/berry_farm.lua's plot art (soil patch,
    generic sprout, per-berry ripe tree) from pret/pokeemerald's decomp
    instead of shipping the sourced PNGs in version control.

    Growth-stage art (sprout, ripe tree) is composited onto the soil patch
    at generation time, baking soil into a single flattened frame per stage
    -- berry_farm.lua's one marker per plot just swaps which frame it shows,
    so there's never a second sprite fighting it for draw order."""
    assets_dir = os.path.join(outdir, "assets")
    os.makedirs(assets_dir, exist_ok=True)

    def fetch_sheet(name):
        cache_path = os.path.join("tools", ".cache", "berry_trees", f"{name}.png")
        if not os.path.exists(cache_path):
            if not download_sprite_file(POKEEMERALD_BERRY_TREE_BASE + f"{name}.png", cache_path):
                return None
        try:
            return Image.open(cache_path)
        except Exception as e:
            print(f"Failed to open berry tree sheet {name}: {e}")
            return None

    def on_soil(art, soil, art_y=0):
        """A fresh 16x16 canvas with soil underneath and art layered at art_y
        (negative = shifted up, so a plant's base sinks into the mound
        instead of sitting on the canvas floor below it)."""
        canvas = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        if soil:
            canvas.paste(soil, (0, 0), soil)
        if art:
            canvas.paste(art, (0, art_y), art)
        return canvas

    print("Generating berry farm plot art...")

    # Soil patch: shown bare on an empty plot, and baked under every
    # growth-stage frame below so the plot never reverts to plain grass.
    # dirt_pile.png's mound doesn't quite reach the bottom row as shipped
    # (~1px of clear space under it), so it's shifted down to sit flush
    # against the canvas floor -- otherwise a plant lined up against the
    # true floor reads as planted an inch below the visible dirt.
    soil_sheet = fetch_sheet("dirt_pile")
    soil = None
    if soil_sheet:
        raw = key_out_matte(soil_sheet)
        bbox = raw.getbbox()
        soil = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        soil.paste(raw, (0, 16 - bbox[3]) if bbox else (0, 0), raw)
        soil.save(os.path.join(assets_dir, "plot_soil.png"))

    # A plant's base needs to land inside the mound, not at the canvas
    # floor under it (the mound crowns a few pixels shy of the floor) --
    # shift every growth-stage frame up by this much once it's placed with
    # its own base at the floor (see PLANT_BASE_LIFT below each artwork's
    # native anchor).
    PLANT_BASE_LIFT = 3

    # Generic "still growing" sprout, shared by every berry (frame 0 of the
    # 2-frame idle-sway sheet) -- differentiating by species only happens
    # once the tree is ripe. It's drawn at a much bigger scale than the
    # ripe trees below (whose 16x32 sheet gets a uniform 0.5x), so it's
    # scaled down to match their visual weight instead of standing 16x16
    # next to art that reads as half that size.
    sprout_sheet = fetch_sheet("sprout")
    if sprout_sheet:
        sprout_raw = key_out_matte(sprout_sheet.crop((0, 0, 16, 16)))
        sw = sh = round(16 * 0.6)
        sprout_scaled = sprout_raw.resize((sw, sh), Image.NEAREST)
        sprout = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        sprout.paste(sprout_scaled, ((16 - sw) // 2, 16 - sh), sprout_scaled)
        on_soil(sprout, soil, -PLANT_BASE_LIFT).save(
            os.path.join(assets_dir, "plot_growing.png"))

    # Ripe tree, one frame per farmable berry: the sheet is 6 growth stages
    # across (mwidth 2 -> 16px) by one 16x32 (mheight 4) frame tall each, so
    # column 5 (the fullest, berry-laden stage) is a 16x32 slice with its
    # trunk's base -- the same "ground line" every stage in the sheet
    # shares -- at the very bottom row. A per-frame bbox trim would throw
    # that shared ground line away (and every berry's canopy sits at a
    # different height in the 32px slice, so trimming shifts each one by a
    # different amount), so instead the whole 16x32 slice is scaled down by
    # a fixed, uniform 0.5x and bottom-aligned -- keeping every berry's
    # trunk anchored to the same row before the shared PLANT_BASE_LIFT
    # tucks it into the mound.
    for berry_id, sheet_name in BERRY_TREE_SHEET.items():
        sheet = fetch_sheet(sheet_name)
        if not sheet:
            continue
        frame = key_out_matte(sheet.crop((5 * 16, 0, 6 * 16, 32)))
        scaled = frame.resize((8, 16), Image.NEAREST)
        art = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        art.paste(scaled, (4, 0), scaled)
        out_name = "plot_" + berry_id.replace("_BERRY", "").lower() + ".png"
        on_soil(art, soil, -PLANT_BASE_LIFT).save(os.path.join(assets_dir, out_name))

def parse_evolution_chain(chain_node, evolutions_map):
    current_species = chain_node["species"]["name"].upper().replace("-", "_")
    for next_node in chain_node.get("evolves_to", []):
        target_species = next_node["species"]["name"].upper().replace("-", "_")
        
        details = next_node.get("evolution_details", [{}])[0]
        trigger = details.get("trigger", {}).get("name", "level-up")
        
        method = "LEVEL"
        level = details.get("min_level")
        item = None
        
        if trigger == "use-item":
            method = "ITEM"
            item_raw = details.get("item", {}).get("name")
            if item_raw:
                item = item_raw.upper().replace("-", "_")
                item = STONE_MAP.get(item, item)
        elif trigger == "trade":
            held_item_data = details.get("held_item")
            if held_item_data:
                held_item = held_item_data.get("name", "").upper().replace("-", "_")
                mapped_stone = TRADE_STONE_MAP.get(held_item)
                if mapped_stone:
                    method = "ITEM"
                    item = mapped_stone
                else:
                    method = "TRADE"
            else:
                method = "TRADE"
        elif trigger == "level-up":
            if level is not None:
                method = "LEVEL"
            else:
                min_happiness = details.get("min_happiness")
                relative_physical_stats = details.get("relative_physical_stats")
                time_of_day = details.get("time_of_day")
                
                if current_species == "FEEBAS" and target_species == "MILOTIC":
                    method = "ITEM"
                    item = "WATER_STONE"
                elif min_happiness is not None:
                    if current_species == "EEVEE":
                        if time_of_day == "day":
                            method = "LEVEL"
                            level = 25
                        elif time_of_day == "night":
                            method = "ITEM"
                            item = "MOON_STONE"
                        else:
                            method = "LEVEL"
                            level = 25
                    else:
                        if current_species in ["PICHU", "CLEFFA", "IGGLYBUFF", "AZURILL", "BUDEW", "CHINGLING"]:
                            method = "LEVEL"
                            level = 15
                        elif current_species == "TOGEPI":
                            method = "LEVEL"
                            level = 20
                        elif current_species in ["GOLBAT", "CHANSEY"]:
                            method = "LEVEL"
                            level = 36
                        else:
                            method = "LEVEL"
                            level = 20
                elif relative_physical_stats is not None:
                    if relative_physical_stats == 1:
                        method = "TYROGUE_ATK"
                        level = 20
                    elif relative_physical_stats == -1:
                        method = "TYROGUE_DEF"
                        level = 20
                    else:
                        method = "TYROGUE_BAL"
                        level = 20
                elif current_species == "WURMPLE":
                    if target_species == "SILCOON":
                        method = "WURMPLE_A"
                        level = 7
                    else:
                        method = "WURMPLE_B"
                        level = 7
                else:
                    sys.stderr.write(f"Warning: unhandled level-up evolution for {current_species} to {target_species}, defaulting to level 20\n")
                    method = "LEVEL"
                    level = 20
        else:
            if target_species != "SHEDINJA":
                sys.stderr.write(f"Warning: unhandled trigger '{trigger}' for {current_species} to {target_species}, defaulting to level 20\n")
                method = "LEVEL"
                level = 20
            else:
                continue
            
        evo_entry = {
            "method": method,
            "species": target_species
        }
        if (method == "LEVEL" or method.startswith("TYROGUE_") or method.startswith("WURMPLE_")) and level:
            evo_entry["level"] = level
        elif method == "ITEM" and item:
            evo_entry["item"] = item
            
        if current_species not in evolutions_map:
            evolutions_map[current_species] = []
        evolutions_map[current_species].append(evo_entry)
        
        parse_evolution_chain(next_node, evolutions_map)

def main():
    parser = argparse.ArgumentParser(
        description="Generate Kanto-Reforged species data, sprites, and berry-farm art. "
        "Run from an extracted mod folder: python3 generate_pokemon_mod.py"
    )
    parser.add_argument("--start", type=int, default=152)
    parser.add_argument("--end", type=int, default=386)
    # Default to this script's directory so "unzip → run script → rezip" works
    # without knowing the repo layout.  Sprite paths written into
    # pokemon_data.lua still use mods/<folder>/ via game_rel_mod_dir().
    parser.add_argument("--outdir", type=str, default=MOD_ROOT)
    parser.add_argument(
        "--learnset-patches-only",
        action="store_true",
        help="Only regenerate Kanto Gen 2/3 learnset/TM patches (no species/sprites)",
    )
    parser.add_argument(
        "--ability-patches-only",
        action="store_true",
        help="Only regenerate Kanto Gen 3 ability patches (no species/sprites)",
    )
    parser.add_argument(
        "--gender-patches-only",
        action="store_true",
        help="Only regenerate genderRate patches for dex 1-386 (no species/sprites)",
    )
    parser.add_argument(
        "--breeding-patches-only",
        action="store_true",
        help="Only regenerate egg group / hatch / egg-move patches for dex 1-386",
    )
    parser.add_argument(
        "--berry-farm-only",
        action="store_true",
        help="Only fetch/build berry-farm plot art (soil, sprout, ripe trees)",
    )
    parser.add_argument(
        "--resprite",
        action="store_true",
        help="Re-bake battle fronts/backs from sprite cache using dex-height "
             "frontSize (40/48/56), back feet clipped 2px, outline dilate so "
             "thin waists/edges survive, and rewrite frontSize in pokemon_data.lua",
    )
    args = parser.parse_args()
    
    os.makedirs(args.outdir, exist_ok=True)

    if args.berry_farm_only:
        generate_berry_farm_assets(args.outdir)
        return

    if args.resprite:
        resprite_kanto_reforged(args.outdir)
        return

    if args.ability_patches_only:
        print("Collecting Gen 3 abilities for Kanto species...")
        ability_patches = collect_kanto_ability_patches()
        write_ability_patches_lua(
            os.path.join(args.outdir, "ability_patches.lua"),
            ability_patches,
        )
        print(f"Done: {len(ability_patches)} Kanto ability patches")
        return

    if args.gender_patches_only:
        print("Collecting genderRate patches for dex 1-386...")
        gender_patches = collect_gender_rate_patches(1, 386)
        write_gender_patches_lua(
            os.path.join(args.outdir, "gender_patches.lua"),
            gender_patches,
        )
        print(f"Done: {len(gender_patches)} genderRate patches")
        return

    if args.breeding_patches_only:
        print("Collecting breeding patches for dex 1-386...")
        breeding_patches = collect_breeding_patches(1, 386)
        write_breeding_patches_lua(
            os.path.join(args.outdir, "breeding_patches.lua"),
            breeding_patches,
        )
        print(f"Done: {len(breeding_patches)} breeding patches")
        return

    if args.learnset_patches_only:
        print("Collecting Gen 2/3 learnset/TM patches for Kanto species...")
        registered_moves = {}
        # Seed with moves already emitted by a prior full generation so we
        # do not drop patches that reference them.
        existing = os.path.join(args.outdir, "pokemon_data.lua")
        if os.path.exists(existing):
            with open(existing, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line.endswith("= {") and line[0].isupper() and "P.moves" not in line:
                        # crude: move keys sit under P.moves; species under P.species.
                        # Prefer scanning the moves block only.
                        pass
            # Parse move ids from P.moves = { ... }
            in_moves = False
            with open(existing, "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("P.moves"):
                        in_moves = True
                        continue
                    if in_moves and line.startswith("}"):
                        break
                    if in_moves:
                        stripped = line.strip()
                        if stripped.endswith("= {") and stripped[0].isupper():
                            registered_moves[stripped.split("=")[0].strip()] = True
        learnset_patches, tmhm_patches = collect_kanto_move_patches(
            registered_moves, outdir=args.outdir
        )
        write_learnset_patches_lua(
            os.path.join(args.outdir, "learnset_patches.lua"),
            learnset_patches,
            tmhm_patches,
        )
        print(
            f"Done: {len(learnset_patches)} species learnset patches, "
            f"{len(tmhm_patches)} species TM/HM patches "
            f"({len(registered_moves)} Kanto Reforged moves known)"
        )
        return

    generate_berry_farm_assets(args.outdir)

    pokemon_data_list = []
    registered_types = set()
    registered_moves = {}
    
    # 1. Fetch Pokémon data and details
    evolutions_map = {}
    processed_chains = set()
    for pid in range(args.start, args.end + 1):
        try:
            # Fetch Pokémon species to get growth rate, evolution chain, and dex entry
            spec_url = f"https://pokeapi.co/api/v2/pokemon-species/{pid}/"
            spec_data = fetch_json(spec_url, "species", pid)
            
            # Evolution chain parsing (cache-based)
            chain_url = spec_data["evolution_chain"]["url"]
            chain_id = chain_url.strip("/").split("/")[-1]
            if chain_id not in processed_chains:
                processed_chains.add(chain_id)
                chain_data = fetch_json(chain_url, "evolution", chain_id)
                parse_evolution_chain(chain_data["chain"], evolutions_map)
            
            # Fetch basic Pokémon data
            poke_url = f"https://pokeapi.co/api/v2/pokemon/{pid}/"
            poke_data = fetch_json(poke_url, "pokemon", pid)
            
            p_name = poke_data["name"].upper().replace("-", "_")
            p_types = [t["type"]["name"].upper() for t in poke_data["types"]]
            p_types = [TYPE_MAP.get(t, t) for t in p_types]
            
            for t in p_types:
                if t not in VANILLA_TYPES:
                    registered_types.add(t)
                    
            stats = poke_data["stats"]
            hp = stats[0]["base_stat"]
            attack = stats[1]["base_stat"]
            defense = stats[2]["base_stat"]
            sp_attack = stats[3]["base_stat"]
            sp_defense = stats[4]["base_stat"]
            speed = stats[5]["base_stat"]
            special = max(sp_attack, sp_defense)
            
            # Growth rate mapping
            gr_name = spec_data["growth_rate"]["name"]
            growth_rate = GROWTH_RATE_MAP.get(gr_name, "MEDIUM_FAST")
            
            # Sprite URLs: try Crystal/Emerald version first, fallback to default
            front_url = None
            back_url = None
            
            versions = poke_data.get("sprites", {}).get("versions", {})
            gen2 = versions.get("generation-ii", {}).get("crystal", {})
            gen3 = versions.get("generation-iii", {}).get("emerald", {})
            
            if pid <= 251:
                front_url = gen2.get("front_default") or poke_data["sprites"].get("front_default")
                back_url = gen2.get("back_default") or poke_data["sprites"].get("back_default")
            else:
                front_url = gen3.get("front_default") or poke_data["sprites"].get("front_default")
                back_url = gen3.get("back_default") or poke_data["sprites"].get("back_default")
                
            if not front_url:
                front_url = poke_data["sprites"].get("front_default")
            if not back_url:
                back_url = poke_data["sprites"].get("back_default")
                
            # Process sprites — canvas size follows Gen 1 frontSize buckets
            # derived from dex height (not always 56x56).
            front_size = front_size_for_height_dm(poke_data.get("height") or 0)
            front_px = front_canvas_px(front_size)

            front_cache_path = os.path.join("tools", ".cache", "sprites", f"{pid}_front.png")
            back_cache_path = os.path.join("tools", ".cache", "sprites", f"{pid}_back.png")
            
            front_mod_path = os.path.join(args.outdir, "assets", f"{p_name.lower()}_front.png")
            back_mod_path = os.path.join(args.outdir, "assets", f"{p_name.lower()}_back.png")

            species_palette = None
            if front_url and download_sprite_file(front_url, front_cache_path):
                ok, colors = process_sprite(front_cache_path, front_mod_path, (front_px, front_px))
                if ok and colors:
                    species_palette = colors
            if back_url and download_sprite_file(back_url, back_cache_path):
                ok_b, colors_b = process_sprite(back_cache_path, back_mod_path, (32, 32))
                if ok_b and colors_b and not species_palette:
                    species_palette = colors_b
                
            # Castform weather forms sprite downloading
            if p_name == "CASTFORM":
                for form_suffix, form_id in [("sunny", 10013), ("rainy", 10014), ("snowy", 10015)]:
                    form_url = f"https://pokeapi.co/api/v2/pokemon/{form_id}/"
                    form_data = fetch_json(form_url, "pokemon", form_id)
                    form_front = None
                    form_back = None
                    versions = form_data.get("sprites", {}).get("versions", {})
                    gen3 = versions.get("generation-iii", {}).get("emerald", {})
                    if gen3:
                        form_front = gen3.get("front_default")
                        form_back = gen3.get("back_default")
                    if not form_front:
                        form_front = form_data["sprites"].get("front_default")
                    if not form_back:
                        form_back = form_data["sprites"].get("back_default")
                        
                    f_front_cache = os.path.join("tools", ".cache", "sprites", f"{form_id}_front.png")
                    f_back_cache = os.path.join("tools", ".cache", "sprites", f"{form_id}_back.png")
                    
                    f_front_mod = os.path.join(args.outdir, "assets", f"castform_{form_suffix}_front.png")
                    f_back_mod = os.path.join(args.outdir, "assets", f"castform_{form_suffix}_back.png")
                    
                    if form_front and download_sprite_file(form_front, f_front_cache):
                        process_sprite(f_front_cache, f_front_mod, (front_px, front_px))
                    if form_back and download_sprite_file(form_back, f_back_cache):
                        process_sprite(f_back_cache, f_back_mod, (32, 32))
                        
            # Moves and level-up learnset (remap Gen 1 ids to engine names)
            learnset_list = []
            tmhm_set = set()
            for move_entry in poke_data["moves"]:
                m_name = remap_move(move_entry["move"]["name"].upper().replace("-", "_"))
                for detail in move_entry["version_group_details"]:
                    method = detail["move_learn_method"]["name"]
                    if method == "level-up":
                        learnset_list.append({
                            "level": detail["level_learned_at"],
                            "move": m_name
                        })
                    elif method == "machine":
                        tmhm_set.add(m_name)
                        
            tmhm_list = sorted(list(tmhm_set))
                        
            lowest_lvl_moves = {}
            evolution_moves_set = set()
            for entry in learnset_list:
                mv = entry["move"]
                lvl = entry["level"]
                if lvl == 0:
                    evolution_moves_set.add(mv)
                else:
                    if mv not in lowest_lvl_moves or lvl < lowest_lvl_moves[mv]:
                        lowest_lvl_moves[mv] = lvl
            learnset = [{"level": lvl, "move": mv} for mv, lvl in lowest_lvl_moves.items()]
            learnset.sort(key=lambda x: x["level"])
            
            evolution_moves = sorted(list(evolution_moves_set))
            
            level1_moves = [entry["move"] for entry in learnset if entry["level"] == 1]
            if not level1_moves:
                level1_moves = ["TACKLE"]
                
            for mv in lowest_lvl_moves.keys():
                registered_moves[mv] = True
            for mv in evolution_moves:
                registered_moves[mv] = True
            for mv in tmhm_list:
                registered_moves[mv] = True
                
            dex_text = "A newly discovered species."
            for entry in spec_data.get("flavor_text_entries", []):
                if entry["language"]["name"] == "en":
                    dex_text = sanitize_text(entry["flavor_text"])
                    break
                    
            kind = "UNKNOWN"
            for entry in spec_data.get("genera", []):
                if entry["language"]["name"] == "en":
                    kind = sanitize_text(entry["genus"]).upper().replace(" POKÉMON", "")
                    break
                    
            ability = ability_from_poke_data(poke_data)
            
            # Determine habitat with legendary/mythical rare override
            is_legendary = spec_data.get("is_legendary", False) or spec_data.get("is_mythical", False)
            habitat_data = spec_data.get("habitat")
            habitat_name = habitat_data["name"] if habitat_data else None
            if is_legendary:
                habitat = "rare"
            elif not habitat_name:
                habitat = "grassland"
            else:
                habitat = habitat_name
                
            mon_record = {
                "id": p_name,
                "name": p_name.replace("_", " "),
                "dex": pid,
                "types": p_types,
                "baseStats": {
                    "hp": hp, "attack": attack, "defense": defense, "speed": speed, "special": special
                },
                "sp_attack": sp_attack,
                "sp_defense": sp_defense,
                "ability": ability,
                "genderRate": spec_data.get("gender_rate", -1)
                    if spec_data.get("gender_rate") is not None else -1,
                "habitat": habitat,
                "catchRate": spec_data["capture_rate"],
                "baseExp": min(255, poke_data["base_experience"] or 64),
                "growthRate": growth_rate,
                "level1Moves": level1_moves,
                "learnset": learnset,
                "evolutionMoves": evolution_moves,
                "tmhm": tmhm_list,
                "dexEntry": {
                    "kind": kind,
                    "heightFt": int(poke_data["height"] * 0.328084),
                    "heightIn": int((poke_data["height"] * 0.328084 % 1) * 12),
                    "weight": float(poke_data["weight"] / 10.0),
                    "text": dex_text
                },
                "frontSize": front_size,
                "palette": species_palette,
            }
            pokemon_data_list.append(mon_record)
        except Exception as e:
            print(f"Error fetching data for Pokedex ID {pid}: {e}")
            
    # Allowed targets: Gen 1 species + everything generated in this run
    vanilla_species = load_vanilla_species()
    generated_ids = {m["id"] for m in pokemon_data_list}
    allowed_species = vanilla_species | generated_ids

    for m in pokemon_data_list:
        evos = filter_evolutions(evolutions_map.get(m["id"], []), allowed_species)
        m["evolutions"] = evos
        evolutions_map[m["id"]] = evos

    # Vanilla species patches: only Gen 2/3 targets (avoid duplicating Gen 1 evos)
    for species_id, evos in list(evolutions_map.items()):
        if species_id in generated_ids:
            continue
        filtered = [
            e for e in filter_evolutions(evos, allowed_species)
            if e["species"] in generated_ids
        ]
        if filtered:
            evolutions_map[species_id] = filtered
        else:
            evolutions_map.pop(species_id, None)

    # 2. Fetch custom types and generate matchups
    all_types = list(VANILLA_TYPES) + list(registered_types)
    custom_types_details = {}
    matchups_list = []
    
    for ct in registered_types:
        category = TYPE_CATEGORY.get(ct, "special")
        custom_types_details[ct] = {
            "name": ct,
            "category": category
        }
        
        type_url = f"https://pokeapi.co/api/v2/type/{ct.lower()}/"
        try:
            type_data = fetch_json(type_url, "type", ct.lower())
            relations = type_data["damage_relations"]
            
            ct_matchups = {t: 10 for t in all_types}
            
            double_to = [t["name"].upper().replace("-", "_") for t in relations["double_damage_to"]]
            half_to = [t["name"].upper().replace("-", "_") for t in relations["half_damage_to"]]
            no_to = [t["name"].upper().replace("-", "_") for t in relations["no_damage_to"]]
            
            double_to = [TYPE_MAP.get(t, t) for t in double_to]
            half_to = [TYPE_MAP.get(t, t) for t in half_to]
            no_to = [TYPE_MAP.get(t, t) for t in no_to]
            
            for t in double_to:
                if t in ct_matchups: ct_matchups[t] = 20
            for t in half_to:
                if t in ct_matchups: ct_matchups[t] = 5
            for t in no_to:
                if t in ct_matchups: ct_matchups[t] = 0
                
            for target, mult in ct_matchups.items():
                matchups_list.append({
                    "attacker": ct,
                    "defender": target,
                    "multiplier": mult
                })
        except Exception as e:
            print(f"Error resolving type data for {ct}: {e}")
            for target in all_types:
                matchups_list.append({
                    "attacker": ct,
                    "defender": target,
                    "multiplier": 10
                })
                
    for t in VANILLA_TYPES:
        t_url = f"https://pokeapi.co/api/v2/type/{t.lower().replace('_type', '')}/"
        try:
            t_data = fetch_json(t_url, "type", t.lower())
            relations = t_data["damage_relations"]
            
            double_to = [x["name"].upper().replace("-", "_") for x in relations["double_damage_to"]]
            half_to = [x["name"].upper().replace("-", "_") for x in relations["half_damage_to"]]
            no_to = [x["name"].upper().replace("-", "_") for x in relations["no_damage_to"]]
            
            double_to = [TYPE_MAP.get(x, x) for x in double_to]
            half_to = [TYPE_MAP.get(x, x) for x in half_to]
            no_to = [TYPE_MAP.get(x, x) for x in no_to]
            
            for ct in registered_types:
                mult = 10
                if ct in double_to:
                    mult = 20
                elif ct in half_to:
                    mult = 5
                elif ct in no_to:
                    mult = 0
                matchups_list.append({
                    "attacker": t,
                    "defender": ct,
                    "multiplier": mult
                })
        except Exception as e:
            print(f"Error resolving damage relations from {t} to custom types: {e}")
            for ct in registered_types:
                matchups_list.append({
                    "attacker": t,
                    "defender": ct,
                    "multiplier": 10
                })
                
    # 3. Fetch custom moves details
    custom_moves_list = []
    effect_counts = {}
    for m_id in sorted(registered_moves.keys()):
        m_lower = move_api_slug(m_id)
        try:
            m_url = f"https://pokeapi.co/api/v2/move/{m_lower}/"
            m_data = fetch_json(m_url, "move", m_id.lower())
            
            if m_data["id"] <= 165:
                continue
                
            m_type = m_data["type"]["name"].upper()
            m_type = TYPE_MAP.get(m_type, m_type)
            m_class = m_data.get("damage_class", {}).get("name", "physical")
            effect_id, extra = map_move_effect(m_id, m_data)
            effect_counts[effect_id] = effect_counts.get(effect_id, 0) + 1
            
            move_record = {
                "id": m_id,
                "name": m_data["name"].upper().replace("-", " "),
                "type": m_type,
                "power": m_data["power"] or 0,
                "accuracy": m_data["accuracy"] or 100,
                "pp": m_data["pp"] or 35,
                "category": m_class,
                "effect": effect_id,
            }
            for key, value in extra.items():
                move_record[key] = value
            custom_moves_list.append(move_record)
        except Exception as e:
            print(f"Error resolving move data for {m_id}: {e}")

    print("Move effect distribution:")
    for effect_id, count in sorted(effect_counts.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"  {effect_id}: {count}")
            
    # 4. Generate Lua files
    types_lua_path = os.path.join(args.outdir, "types_data.lua")
    print(f"Writing {types_lua_path}...")
    with open(types_lua_path, "w", encoding="utf-8") as f:
        f.write("-- Generated custom types and matchups data\n")
        f.write("local T = {}\n\n")
        f.write("T.types = {\n")
        for ct, details in sorted(custom_types_details.items()):
            f.write(f"  {ct} = {{ name = {json.dumps(details['name'])}, category = {json.dumps(details['category'])} }},\n")
        f.write("}\n\n")
        f.write("T.matchups = {\n")
        for row in matchups_list:
            f.write(f"  {{ attacker = {json.dumps(row['attacker'])}, defender = {json.dumps(row['defender'])}, multiplier = {row['multiplier']} }},\n")
        f.write("}\n\n")
        f.write("return T\n")
        
    pokemon_lua_path = os.path.join(args.outdir, "pokemon_data.lua")
    print(f"Writing {pokemon_lua_path}...")
    with open(pokemon_lua_path, "w", encoding="utf-8") as f:
        f.write("-- Generated Pokémon species and custom moves data\n")
        f.write("local P = {}\n\n")
        
        f.write("P.moves = {\n")
        for mv in custom_moves_list:
            f.write(f"  {mv['id']} = {{\n")
            f.write(f"    id = {json.dumps(mv['id'])}, name = {json.dumps(mv['name'])}, type = {json.dumps(mv['type'])},\n")
            f.write(f"    power = {mv['power']}, accuracy = {mv['accuracy']}, pp = {mv['pp']},\n")
            f.write(f"    category = {json.dumps(mv['category'])}, effect = {json.dumps(mv['effect'])}")
            if mv.get("priority"):
                f.write(f",\n    priority = {int(mv['priority'])}")
            if mv.get("highCrit"):
                f.write(",\n    highCrit = true")
            if mv.get("statChance"):
                f.write(f",\n    statChance = {int(mv['statChance'])}")
            if mv.get("statTarget"):
                f.write(f",\n    statTarget = {json.dumps(mv['statTarget'])}")
            if mv.get("statChanges"):
                f.write(",\n    statChanges = {\n")
                for sc in mv["statChanges"]:
                    f.write(f"      {{ stat = {json.dumps(sc['stat'])}, change = {int(sc['change'])} }},\n")
                f.write("    }")
            f.write("\n  },\n")
        f.write("}\n\n")
        
        f.write("P.species = {\n")
        for mon in pokemon_data_list:
            f.write(f"  {mon['id']} = {{\n")
            f.write(f"    id = {json.dumps(mon['id'])}, name = {json.dumps(mon['name'])}, dex = {mon['dex']},\n")
            f.write(f"    types = {{\n")
            for t in mon["types"]:
                f.write(f"      {json.dumps(t)},\n")
            f.write("    },\n")
            f.write("    baseStats = {\n")
            f.write(f"      hp = {mon['baseStats']['hp']}, attack = {mon['baseStats']['attack']},\n")
            f.write(f"      defense = {mon['baseStats']['defense']}, speed = {mon['baseStats']['speed']},\n")
            f.write(f"      special = {mon['baseStats']['special']}\n")
            f.write("    },\n")
            f.write(f"    sp_attack = {mon['sp_attack']},\n")
            f.write(f"    sp_defense = {mon['sp_defense']},\n")
            f.write(f"    ability = {json.dumps(mon['ability'])},\n")
            f.write(f"    genderRate = {mon.get('genderRate', -1)},\n")
            f.write(f"    habitat = {json.dumps(mon['habitat'])},\n")
            f.write(f"    catchRate = {mon['catchRate']}, baseExp = {mon['baseExp']},\n")
            f.write(f"    growthRate = {json.dumps(mon['growthRate'])},\n")
            f.write("    level1Moves = {\n")
            for mv in mon["level1Moves"]:
                f.write(f"      {json.dumps(mv)},\n")
            f.write("    },\n")
            f.write("    learnset = {\n")
            for entry in mon["learnset"]:
                f.write(f"      {{ level = {entry['level']}, move = {json.dumps(entry['move'])} }},\n")
            f.write("    },\n")
            f.write("    evolutionMoves = {\n")
            for mv in mon["evolutionMoves"]:
                f.write(f"      {json.dumps(mv)},\n")
            f.write("    },\n")
            f.write("    tmhm = {\n")
            for mv in mon["tmhm"]:
                f.write(f"      {json.dumps(mv)},\n")
            f.write("    },\n")
            f.write("    evolutions = {\n")
            for evo in mon["evolutions"]:
                f.write("      { ")
                f.write(f"method = {json.dumps(evo['method'])}, species = {json.dumps(evo['species'])}")
                if "level" in evo:
                    f.write(f", level = {evo['level']}")
                if "item" in evo:
                    f.write(f", item = {json.dumps(evo['item'])}")
                f.write(" },\n")
            f.write("    },\n")
            rel_dir = game_rel_mod_dir(args.outdir)
            f.write(f"    spriteFront = \"{rel_dir}/assets/{mon['id'].lower()}_front.png\",\n")
            f.write(f"    spriteBack = \"{rel_dir}/assets/{mon['id'].lower()}_back.png\",\n")
            f.write(f"    frontSize = {mon.get('frontSize') or 5},\n")
            if mon.get("palette"):
                f.write(f"    palette = \"{mon['id']}\",\n")
            f.write("    dexEntry = {\n")
            f.write(f"      kind = {json.dumps(mon['dexEntry']['kind'])},\n")
            f.write(f"      heightFt = {mon['dexEntry']['heightFt']},\n")
            f.write(f"      heightIn = {mon['dexEntry']['heightIn']},\n")
            f.write(f"      weight = {mon['dexEntry']['weight']},\n")
            # Inline prose for now; mods/Kanto-Reforged/dex_entries.lua
            # registers it into Data.text at load (vanilla uses _NameDexEntry keys).
            f.write(f"      text = {json.dumps(mon['dexEntry']['text'])}\n")
            f.write("    }\n")
            f.write("  },\n")
        f.write("}\n\n")
        
        f.write("P.evolutions = {\n")
        for species_id, evos in sorted(evolutions_map.items()):
            # Only vanilla (non-generated) species need patches; their
            # evolutions were already filtered to Gen 2/3 targets above.
            if species_id not in generated_ids and evos:
                f.write(f"  {species_id} = {{\n")
                for evo in evos:
                    f.write("    { ")
                    f.write(f"method = {json.dumps(evo['method'])}, species = {json.dumps(evo['species'])}")
                    if "level" in evo:
                        f.write(f", level = {evo['level']}")
                    if "item" in evo:
                        f.write(f", item = {json.dumps(evo['item'])}")
                    f.write(" },\n")
                f.write("  },\n")
        f.write("}\n\n")
        
        f.write("return P\n")

    # Per-species SGB palettes (Advanced color mode); without these every
    # Gen 2/3 mon falls through to MEWMON (peach/purple).
    pals = {
        mon["id"]: mon["palette"]
        for mon in pokemon_data_list
        if mon.get("palette")
    }
    if pals:
        write_species_palettes_lua(
            os.path.join(args.outdir, "species_palettes.lua"),
            pals,
        )
        print(f"Wrote {len(pals)} species palettes")

    # Gen 2/3 learnset/TM additions for vanilla Kanto species (trainers/wild/gyms
    # build moves from Pokemon.movesAtLevel, so these patches are how Gen 1 mons
    # actually receive Metal Claw / Smokescreen / etc.)
    print("Collecting Gen 2/3 learnset/TM patches for Kanto species...")
    learnset_patches, tmhm_patches = collect_kanto_move_patches(
        registered_moves, outdir=args.outdir
    )
    write_learnset_patches_lua(
        os.path.join(args.outdir, "learnset_patches.lua"),
        learnset_patches,
        tmhm_patches,
    )

    print("Collecting Gen 3 abilities for Kanto species...")
    ability_patches = collect_kanto_ability_patches()
    write_ability_patches_lua(
        os.path.join(args.outdir, "ability_patches.lua"),
        ability_patches,
    )

    print("Collecting genderRate patches for dex 1-386...")
    gender_patches = collect_gender_rate_patches(1, 386)
    write_gender_patches_lua(
        os.path.join(args.outdir, "gender_patches.lua"),
        gender_patches,
    )

    print("Collecting breeding patches for dex 1-386...")
    breeding_patches = collect_breeding_patches(1, 386)
    write_breeding_patches_lua(
        os.path.join(args.outdir, "breeding_patches.lua"),
        breeding_patches,
    )
        
    print("Done generating Pokémon mod files!")

if __name__ == "__main__":
    main()
