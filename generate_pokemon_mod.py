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
    # PokéAPI meta.category:
    #   damage-raise  → changes the user's stats (Overheat, Close Combat,
    #                   Metal Claw, Flame Charge, …)
    #   damage-lower  → lowers the target's stats (Rock Tomb, Snarl, …)
    # Do NOT key off "100% + all-negative" alone: foe drops like Rock Tomb
    # are also 100% and were wrongly tagged as self-drops.
    if power > 0 and stat_changes:
        self_stat = category == "damage-raise"
        # Self-stat drops after attacking (Overheat, Close Combat, Superpower)
        if self_stat and all(sc["change"] < 0 for sc in stat_changes):
            extra["statChanges"] = stat_changes
            extra["statTarget"] = "user"
            return "EXP_DAMAGE_USER_STAT_EFFECT", extra
        # Self-stat raises on hit (Metal Claw, Ancient Power multi)
        if all(sc["change"] > 0 for sc in stat_changes):
            extra["statChanges"] = stat_changes
            extra["statChance"] = stat_chance or 10
            extra["statTarget"] = "user"
            return "EXP_DAMAGE_STAT_SIDE_EFFECT", extra
        # Target stat drops (Rock Tomb, Snarl, Shadow Ball, Crunch, …)
        mapped = side_stat_effect(stat_changes)
        if mapped and len(stat_changes) == 1 and (stat_chance or 0) < 100:
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


def collect_special_stat_patches(start=1, end=151):
    """Fetch PokeAPI SpA/SpD for Kanto species (pokemon endpoint stats[3]/[4]).

    Vanilla Gen 1 only has baseStats.special; these fields power the optional
    SP.ATK / SP.DEF toggle without changing the Gen 1 special base.
    """
    patches = {}
    for pid in range(start, end + 1):
        try:
            poke_data = fetch_json(
                f"https://pokeapi.co/api/v2/pokemon/{pid}/", "pokemon", pid
            )
            species_id = species_id_from_pokeapi_name(poke_data["name"])
            stats = poke_data["stats"]
            sp_attack = int(stats[3]["base_stat"])
            sp_defense = int(stats[4]["base_stat"])
            patches[species_id] = {
                "sp_attack": sp_attack,
                "sp_defense": sp_defense,
            }
            print(f"  #{pid} {species_id} -> SpA {sp_attack} SpD {sp_defense}")
        except Exception as e:
            print(f"Error fetching special stats for dex {pid}: {e}")
    return patches


def write_special_stat_patches_lua(path, patches):
    """Write mods/Kanto-Reforged/special_stat_patches.lua."""
    print(f"Writing {path}...")
    with open(path, "w", encoding="utf-8") as f:
        f.write("-- Generated SpA/SpD for Kanto species (PokeAPI)\n")
        f.write("-- Applied onto vanilla Data.pokemon via pokemon:patch\n")
        f.write("-- Leaves baseStats.special alone for Gen 1 mechanics.\n")
        f.write("local P = {}\n\n")
        f.write("P.stats = {\n")
        for species_id in sorted(patches.keys()):
            row = patches[species_id]
            f.write(
                f"  {species_id} = {{ sp_attack = {row['sp_attack']}, "
                f"sp_defense = {row['sp_defense']} }},\n"
            )
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

def pokeapi_cache_dir():
    """PokéAPI JSON cache: tools/.cache/pokeapi under the game repo (not the mod)."""
    candidates = [
        os.path.join(os.path.dirname(os.path.dirname(MOD_ROOT)), "tools", ".cache", "pokeapi"),
        os.path.join("tools", ".cache", "pokeapi"),
    ]
    for path in candidates:
        parent = os.path.dirname(path)
        if os.path.isdir(parent) or os.path.isdir(path):
            return path
    return candidates[0]


def get_cache_path(category, filename):
    return os.path.join(pokeapi_cache_dir(), category, f"{filename}.json")

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

    White-bodied mons (Forretress) leak: the shell is the same white as the
    matte and touches the border, so a plain flood eats the body.  When that
    happens, fall back to dilating non-matte ink/color into a silhouette mask
    and only key white *outside* that mask.
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

    bg_n = 0
    content_n = 0
    for y in range(h):
        for x in range(w):
            if pixels[x, y][:3] == bg:
                bg_n += 1
            else:
                content_n += 1

    def matches(x, y, pix):
        r, g, b, a = pix[x, y]
        return a >= 128 and (r, g, b) == bg

    def flood_key(src_img):
        out = src_img.copy()
        pix = out.load()
        seen = [[False] * w for _ in range(h)]
        q = deque()
        for x in range(w):
            for y in (0, h - 1):
                if not seen[y][x] and matches(x, y, pix):
                    seen[y][x] = True
                    q.append((x, y))
        for y in range(1, h - 1):
            for x in (0, w - 1):
                if not seen[y][x] and matches(x, y, pix):
                    seen[y][x] = True
                    q.append((x, y))
        while q:
            x, y = q.popleft()
            r, g, b, _ = pix[x, y]
            pix[x, y] = (r, g, b, 0)
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and matches(nx, ny, pix):
                    seen[ny][nx] = True
                    q.append((nx, ny))
        return out

    def content_mask_key(src_img, dilate_n=6):
        """Keep matte-colored body pixels that sit inside dilated non-matte ink."""
        out = src_img.copy()
        pix = out.load()
        mask = [[False] * w for _ in range(h)]
        for y in range(h):
            for x in range(w):
                if pix[x, y][:3] != bg:
                    mask[y][x] = True
        for _ in range(dilate_n):
            nxt = [row[:] for row in mask]
            for y in range(h):
                for x in range(w):
                    if not mask[y][x]:
                        continue
                    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                        if 0 <= nx < w and 0 <= ny < h:
                            nxt[ny][nx] = True
            mask = nxt
        for y in range(h):
            for x in range(w):
                if pix[x, y][:3] == bg and not mask[y][x]:
                    pix[x, y] = (bg[0], bg[1], bg[2], 0)
        return out

    flooded = flood_key(img)
    fp = flooded.load()
    white_left = 0
    opaque_left = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = fp[x, y]
            if a < 128:
                continue
            opaque_left += 1
            if (r, g, b) == bg:
                white_left += 1

    # Flood ate a white shell that was contiguous with the matte (Forretress).
    bg_is_white = bg[0] >= 250 and bg[1] >= 250 and bg[2] >= 250
    if (
        bg_is_white
        and bg_n > content_n
        and white_left < max(24, int(bg_n * 0.08))
        and opaque_left < max(80, int(content_n * 1.25))
    ):
        return content_mask_key(img)

    # Copy flood result onto the working image.
    for y in range(h):
        for x in range(w):
            pixels[x, y] = fp[x, y]
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


def extract_gap_mask(img):
    """Binary mask of load-bearing negative space (bays + enclosed holes).

    Used by the plated style: OR-pool through shrink, then force transparent
    so limb/body gaps cannot be majority-filled with body midtone.
    """
    from collections import deque

    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    mask = Image.new("1", (w, h), 0)
    mp = mask.load()

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y][3] >= 128

    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= 128:
                continue
            if (opaque(x - 1, y) and opaque(x + 1, y)) or (
                opaque(x, y - 1) and opaque(x, y + 1)
            ):
                mp[x, y] = 1

    exterior = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if px[x, y][3] < 128:
                exterior[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if px[x, y][3] < 128 and not exterior[y][x]:
                exterior[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (
                0 <= nx < w
                and 0 <= ny < h
                and not exterior[ny][nx]
                and px[nx, ny][3] < 128
            ):
                exterior[ny][nx] = True
                q.append((nx, ny))
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 128 and not exterior[y][x]:
                mp[x, y] = 1
    return mask


def carve_gap_mask(img, gap_mask):
    """Force gap-mask pixels to transparent on an RGBA image."""
    img = img.convert("RGBA")
    gap_mask = gap_mask.convert("1")
    if gap_mask.size != img.size:
        return img
    out = img.copy()
    px = out.load()
    gp = gap_mask.load()
    w, h = img.size
    clear = (0, 0, 0, 0)
    for y in range(h):
        for x in range(w):
            if gp[x, y]:
                px[x, y] = clear
    return out


def carve_interior_seams_to_gaps(img, ink_mask):
    """Turn fully-interior body↔body ink into transparent cutouts.

    Prefer open_limb_gaps_along_ink for plated art — blind carving swiss-cheeses
    plate lines.  Kept for small final-size cleanup of gap-adjacent seams.
    """
    img = img.convert("RGBA")
    ink_mask = ink_mask.convert("1")
    if ink_mask.size != img.size:
        return img
    w, h = img.size
    src = img.load()
    mp = ink_mask.load()
    out = img.copy()
    dst = out.load()
    clear = (0, 0, 0, 0)

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    def is_body(x, y):
        if not opaque(x, y):
            return False
        r, g, b, _ = src[x, y]
        return r + g + b >= 40

    for y in range(h):
        for x in range(w):
            if not mp[x, y]:
                continue
            if not opaque(x, y):
                continue
            horiz = is_body(x - 1, y) and is_body(x + 1, y)
            vert = is_body(x, y - 1) and is_body(x, y + 1)
            if not (horiz or vert):
                continue
            # Only carve when the seam is fully enclosed (not silhouette rim).
            if opaque(x - 1, y) and opaque(x + 1, y) and opaque(x, y - 1) and opaque(
                x, y + 1
            ):
                dst[x, y] = clear
    return out


def open_limb_gaps_along_ink(img, ink_mask, gap_mask=None, max_steps=24):
    """Open limb/body cutouts by growing exterior bays along separating ink.

    Emerald Metagross (and similar plated mons) draw leg joins as 1px black
    seams on a continuous opaque silhouette — not as real transparent armpits.
    After 4-shade collapse those seams freckle and midtone fills the join.
    Growing from silhouette bays along body↔body ink turns the join into a
    real gap the shrink OR-pool can preserve, without carving every plate line.
    """
    from collections import deque

    img = img.convert("RGBA")
    ink_mask = ink_mask.convert("1")
    w, h = img.size
    if gap_mask is None:
        gap_mask = extract_gap_mask(img)
    else:
        gap_mask = gap_mask.convert("1").copy()
    if ink_mask.size != (w, h) or gap_mask.size != (w, h):
        return img, gap_mask, ink_mask

    out = img.copy()
    src = out.load()
    working_ink = ink_mask.copy()
    wip = working_ink.load()
    gp = gap_mask.load()
    clear = (0, 0, 0, 0)

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    def body_on_axis(x, y, dx, dy, max_skip=2):
        """Find non-ink body within max_skip, skipping ink in between."""
        for i in range(1, max_skip + 1):
            nx, ny = x + dx * i, y + dy * i
            if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] < 128:
                return False
            r, g, b, _ = src[nx, ny]
            if r + g + b >= 40:
                return True
        return False

    def separates_body(x, y):
        return (
            body_on_axis(x, y, -1, 0) and body_on_axis(x, y, 1, 0)
        ) or (body_on_axis(x, y, 0, -1) and body_on_axis(x, y, 0, 1))

    def carve_at(x, y):
        src[x, y] = clear
        wip[x, y] = 0
        gp[x, y] = 1

    q = deque()
    # Seed A: existing bay / hole gap pixels.
    for y in range(h):
        for x in range(w):
            if src[x, y][3] >= 128:
                continue
            pinched = (opaque(x - 1, y) and opaque(x + 1, y)) or (
                opaque(x, y - 1) and opaque(x, y + 1)
            )
            if gp[x, y] or pinched:
                gp[x, y] = 1
                q.append((x, y, 0))

    # Seed B: rim ink that already separates body and touches empty —
    # the mouth of an armpit before any transparent bay exists.
    for y in range(h):
        for x in range(w):
            if not wip[x, y] or not opaque(x, y):
                continue
            if not separates_body(x, y):
                continue
            touches_empty = False
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] < 128:
                    touches_empty = True
                    break
            if touches_empty:
                carve_at(x, y)
                q.append((x, y, 0))

    while q:
        x, y, steps = q.popleft()
        if steps >= max_steps:
            continue
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if not (0 <= nx < w and 0 <= ny < h) or gp[nx, ny]:
                continue
            if not wip[nx, ny] or not opaque(nx, ny):
                continue
            if not separates_body(nx, ny):
                continue
            carve_at(nx, ny)
            q.append((nx, ny, steps + 1))

    return out, gap_mask, working_ink


def open_ink_between_body_parts(img, ink_mask, gap_mask=None, min_part=28):
    """Carve ink that separates two large body components into real gaps.

    Metagross legs share one opaque silhouette with the torso — joins are
    black seams, not exterior bays.  Treating ink as cuts and finding which
    ink pixels border two different large body CCs opens those joins without
    swiss-cheesing plate lines that stay inside one component.
    """
    from collections import deque

    img = img.convert("RGBA")
    ink_mask = ink_mask.convert("1")
    w, h = img.size
    if gap_mask is None:
        gap_mask = Image.new("1", (w, h), 0)
    else:
        gap_mask = gap_mask.convert("1").copy()
    if ink_mask.size != (w, h) or gap_mask.size != (w, h):
        return img, gap_mask, ink_mask

    src_img = img
    src = src_img.load()
    wip_ink = ink_mask.copy()
    wip = wip_ink.load()
    gp = gap_mask.load()

    # Body = opaque non-ink.  Label connected components.
    label = [[-1] * w for _ in range(h)]
    sizes = {}
    next_id = 0
    for y in range(h):
        for x in range(w):
            if label[y][x] != -1:
                continue
            if src[x, y][3] < 128 or wip[x, y]:
                continue
            r, g, b, _ = src[x, y]
            if r + g + b < 40:
                continue
            q = deque([(x, y)])
            label[y][x] = next_id
            n = 0
            while q:
                cx, cy = q.popleft()
                n += 1
                for nx, ny in (
                    (cx - 1, cy),
                    (cx + 1, cy),
                    (cx, cy - 1),
                    (cx, cy + 1),
                ):
                    if not (0 <= nx < w and 0 <= ny < h) or label[ny][nx] != -1:
                        continue
                    if src[nx, ny][3] < 128 or wip[nx, ny]:
                        continue
                    nr, ng, nb, _ = src[nx, ny]
                    if nr + ng + nb < 40:
                        continue
                    label[ny][nx] = next_id
                    q.append((nx, ny))
            sizes[next_id] = n
            next_id += 1

    large = {i for i, n in sizes.items() if n >= min_part}
    if len(large) < 2:
        return img, gap_mask, ink_mask

    out = img.copy()
    dst = out.load()
    clear = (0, 0, 0, 0)
    for y in range(h):
        for x in range(w):
            if not wip[x, y] or src[x, y][3] < 128:
                continue
            neigh = set()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                lid = label[ny][nx]
                if lid in large:
                    neigh.add(lid)
            if len(neigh) >= 2:
                dst[x, y] = clear
                wip[x, y] = 0
                gp[x, y] = 1
    return out, gap_mask, wip_ink


def widen_gaps_into_separating_ink(img, ink_mask, gap_mask, passes=2):
    """Widen limb cutouts by carving adjacent body↔body ink (not silhouette rim).

    1px corridors vanish under majority shrink and read as freckles; a 2px
    channel survives.  Never carve rim ink that merely touches exterior empty
    without separating body — that eats claw/arm tips.
    """
    img = img.convert("RGBA")
    ink_mask = ink_mask.convert("1")
    gap_mask = gap_mask.convert("1").copy()
    if ink_mask.size != img.size or gap_mask.size != img.size:
        return img, gap_mask, ink_mask
    w, h = img.size
    out = img.copy()
    src = out.load()
    working_ink = ink_mask.copy()
    wip = working_ink.load()
    gp = gap_mask.load()
    clear = (0, 0, 0, 0)

    def body_on_axis(x, y, dx, dy, max_skip=2):
        for i in range(1, max_skip + 1):
            nx, ny = x + dx * i, y + dy * i
            if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] < 128:
                return False
            r, g, b, _ = src[nx, ny]
            if r + g + b >= 40:
                return True
        return False

    def separates_body(x, y):
        return (
            body_on_axis(x, y, -1, 0) and body_on_axis(x, y, 1, 0)
        ) or (body_on_axis(x, y, 0, -1) and body_on_axis(x, y, 0, 1))

    for _ in range(max(1, passes)):
        add = []
        for y in range(h):
            for x in range(w):
                if not gp[x, y]:
                    continue
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    if gp[nx, ny] or not wip[nx, ny] or src[nx, ny][3] < 128:
                        continue
                    if separates_body(nx, ny):
                        add.append((nx, ny))
        for x, y in add:
            src[x, y] = clear
            wip[x, y] = 0
            gp[x, y] = 1
    return out, gap_mask, working_ink


def ink_gap_rims(img, gap_mask, ink_mask=None):
    """Paint black on opaque pixels that touch a gap so cutouts read as seams."""
    img = img.convert("RGBA")
    gap_mask = gap_mask.convert("1")
    if gap_mask.size != img.size:
        return img, ink_mask
    w, h = img.size
    out = img.copy()
    src = out.load()
    gp = gap_mask.load()
    if ink_mask is None:
        new_ink = Image.new("1", (w, h), 0)
    else:
        new_ink = ink_mask.convert("1").copy()
    nmp = new_ink.load()
    black = (0, 0, 0, 255)
    for y in range(h):
        for x in range(w):
            if src[x, y][3] < 128 or gp[x, y]:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and gp[nx, ny]:
                    src[x, y] = black
                    nmp[x, y] = 1
                    break
    return out, new_ink


def deepen_pinched_gaps(img, gap_mask, passes=1):
    """Widen O–gap–O pinches by carving one body pixel into each wall.

    Natural Emerald armpits are often 1px; after 64→56 majority they fill.
    Deepening only pinched corridors (not exterior silhouette) keeps claws
    intact while making limb cutouts actually readable.
    """
    img = img.convert("RGBA")
    gap_mask = gap_mask.convert("1").copy()
    if gap_mask.size != img.size:
        return img, gap_mask
    w, h = img.size
    out = img.copy()
    src = out.load()
    gp = gap_mask.load()
    clear = (0, 0, 0, 0)

    def is_body(x, y):
        if not (0 <= x < w and 0 <= y < h) or src[x, y][3] < 128:
            return False
        r, g, b, _ = src[x, y]
        return r + g + b >= 40

    for _ in range(max(1, passes)):
        add = []
        for y in range(h):
            for x in range(w):
                if not gp[x, y] or src[x, y][3] >= 128:
                    continue
                if is_body(x - 1, y) and is_body(x + 1, y):
                    add.append((x - 1, y))
                    add.append((x + 1, y))
                if is_body(x, y - 1) and is_body(x, y + 1):
                    add.append((x, y - 1))
                    add.append((x, y + 1))
        for x, y in add:
            if src[x, y][3] < 128:
                continue
            src[x, y] = clear
            gp[x, y] = 1
    return out, gap_mask


def reinforce_interior_ink(img, ink_mask):
    """Thicken interior ink one pixel so limb seams survive majority shrink."""
    img = img.convert("RGBA")
    ink_mask = ink_mask.convert("1")
    if ink_mask.size != img.size:
        return img, ink_mask
    w, h = img.size
    src = img.load()
    mp = ink_mask.load()
    out = img.copy()
    dst = out.load()
    new_mask = ink_mask.copy()
    nmp = new_mask.load()
    black = (0, 0, 0, 255)

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    def is_body(x, y):
        if not opaque(x, y):
            return False
        r, g, b, _ = src[x, y]
        return r + g + b >= 40

    grow = []
    for y in range(h):
        for x in range(w):
            if not mp[x, y]:
                continue
            if not (
                opaque(x - 1, y)
                and opaque(x + 1, y)
                and opaque(x, y - 1)
                and opaque(x, y + 1)
            ):
                continue
            if is_body(x - 1, y) and is_body(x + 1, y):
                for nx in (x - 1, x + 1):
                    if is_body(nx, y) and not mp[nx, y]:
                        grow.append((nx, y))
            if is_body(x, y - 1) and is_body(x, y + 1):
                for ny in (y - 1, y + 1):
                    if is_body(x, ny) and not mp[x, ny]:
                        grow.append((x, ny))
    for x, y in grow:
        dst[x, y] = black
        nmp[x, y] = 1
    return out, new_mask


def extract_ink_mask(img, luma_max=48, soft_luma_max=70, contrast_delta=22):
    """Binary mask of the artist's real dark outline / seam pixels.

    Taken from full-resolution source *before* majority-vote shrink, which
    otherwise outvotes 1px lines between same-colored limbs.

    Near-black pixels (luma <= luma_max) always count.  Darker-than-body
    stroke pixels (up to soft_luma_max) also count when they sit against a
    distinctly lighter opaque neighbor or the silhouette edge — this catches
    Metagross's dark-blue plate seams and Treecko's olive limb joins that
    are line art, not flat black ink.

    Returns a '1' mode image matching img's size.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    luma = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 128:
                luma[y][x] = _pixel_luma((r, g, b))

    mask = Image.new("1", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            L = luma[y][x]
            if L is None:
                continue
            if L <= luma_max:
                mp[x, y] = 1
                continue
            if L > soft_luma_max:
                continue
            # Stroke against lighter body, or silhouette dark edge.
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or luma[ny][nx] is None:
                    mp[x, y] = 1
                    break
                if luma[ny][nx] >= L + contrast_delta:
                    mp[x, y] = 1
                    break
    return mask


def filter_ink_mask(mask, min_blob=3):
    """Drop tiny ink islands (AA freckles / stray dither), keep real seams.

    Connected components smaller than min_blob are cleared.  One tunable
    threshold — not a per-species override.
    """
    from collections import deque

    mask = mask.convert("1")
    w, h = mask.size
    mp = mask.load()
    seen = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if seen[y][x] or not mp[x, y]:
                continue
            q = deque([(x, y)])
            seen[y][x] = True
            cells = []
            while q:
                cx, cy = q.popleft()
                cells.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if (
                        0 <= nx < w
                        and 0 <= ny < h
                        and not seen[ny][nx]
                        and mp[nx, ny]
                    ):
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if len(cells) < min_blob:
                for ox, oy in cells:
                    mp[ox, oy] = 0
    return mask


def resize_ink_mask_or(mask, new_w, new_h):
    """Downscale an ink mask with OR / max-pool logic.

    If *any* source pixel in a block was ink, the output pixel is ink.
    Opposite bias from majority-vote color shrink — correct for 1px line art.
    """
    mask = mask.convert("1")
    w, h = mask.size
    if (w, h) == (new_w, new_h):
        return mask
    if new_w >= w and new_h >= h:
        return mask.resize((new_w, new_h), Image.NEAREST)

    mp = mask.load()
    out = Image.new("1", (new_w, new_h), 0)
    op = out.load()
    for y in range(new_h):
        y0 = int(y * h / new_h)
        y1 = max(y0 + 1, int((y + 1) * h / new_h))
        for x in range(new_w):
            x0 = int(x * w / new_w)
            x1 = max(x0 + 1, int((x + 1) * w / new_w))
            ink = False
            for yy in range(y0, y1):
                for xx in range(x0, x1):
                    if mp[xx, yy]:
                        ink = True
                        break
                if ink:
                    break
            if ink:
                op[x, y] = 1
    return out


def composite_ink_mask(img, mask, only_opaque=True):
    """Force mask pixels to pure black on the shaded RGBA image.

    only_opaque: do not paint ink into intentional transparent gaps (armpits,
    leg holes) — only re-ink seams that sit on the silhouette.
    """
    img = img.convert("RGBA")
    mask = mask.convert("1")
    if mask.size != img.size:
        raise ValueError(
            f"ink mask size {mask.size} != image size {img.size}"
        )
    w, h = img.size
    out = img.copy()
    px = out.load()
    mp = mask.load()
    black = (0, 0, 0, 255)
    for y in range(h):
        for x in range(w):
            if not mp[x, y]:
                continue
            if only_opaque and px[x, y][3] < 128:
                continue
            px[x, y] = black
    return out


def _union_quantized_black_into_ink(mask, quantized, colors):
    """OR palette-black pixels into an existing ink mask (same size)."""
    mask = mask.convert("1")
    quantized = quantized.convert("RGBA")
    if mask.size != quantized.size:
        return mask
    ink = tuple(colors[3][:3]) if colors and len(colors) > 3 else (0, 0, 0)
    w, h = mask.size
    out = mask.copy()
    mp = out.load()
    qp = quantized.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = qp[x, y]
            if a >= 128 and (r, g, b) == ink:
                mp[x, y] = 1
    return out


def force_indexed_ink(indexed_img, mask, ink_index=4):
    """Force OR-pooled ink onto the indexed PNG (shade slot 3 / index 4)."""
    mask = mask.convert("1")
    if mask.size != indexed_img.size:
        return indexed_img
    w, h = indexed_img.size
    out = indexed_img.copy()
    px = out.load()
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            if mp[x, y] and px[x, y] != 0:
                px[x, y] = ink_index
    return out


def build_face_priority_mask(img):
    """Upper-bbox face band + near-white eye clusters for majority boost.

    Gen 1 readability lives in the face.  Mark the top ~40% of the opaque
    silhouette and any bright sclera-like pixels in the top half so shrink
    prefers eyes/forehead over torso mass.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    ys = [y for y in range(h) for x in range(w) if px[x, y][3] >= 128]
    if not ys:
        return Image.new("1", (w, h), 0)
    y_min, y_max = min(ys), max(ys)
    face_cut = y_min + max(1, int((y_max - y_min + 1) * 0.42))
    mid_y = y_min + max(1, int((y_max - y_min + 1) * 0.55))
    mask = Image.new("1", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            if y <= face_cut:
                mp[x, y] = 1
            elif y <= mid_y and min(r, g, b) >= 220:
                mp[x, y] = 1
    return mask


def indexed_readability_metrics(indexed_img):
    """Cheap Gen 1 readability proxies after Stage 6."""
    from collections import deque

    w, h = indexed_img.size
    px = indexed_img.load()
    opaque = 0
    white = light = mid = ink = 0
    upper_white = False
    upper_cut = max(1, h // 3)
    for y in range(h):
        for x in range(w):
            v = px[x, y]
            if v == 0:
                continue
            opaque += 1
            if v == 1:
                white += 1
                if y < upper_cut:
                    upper_white = True
            elif v == 2:
                light += 1
            elif v == 3:
                mid += 1
            elif v == 4:
                ink += 1
    if opaque == 0:
        return {
            "components": 0,
            "perim_area": 0.0,
            "has_upper_white": False,
            "mid_frac": 1.0,
            "light_frac": 0.0,
            "ink_frac": 0.0,
            "opaque": 0,
        }

    # Connected opaque components.
    seen = [[False] * w for _ in range(h)]
    comps = 0
    for y in range(h):
        for x in range(w):
            if seen[y][x] or px[x, y] == 0:
                continue
            comps += 1
            q = deque([(x, y)])
            seen[y][x] = True
            while q:
                cx, cy = q.popleft()
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if (
                        0 <= nx < w
                        and 0 <= ny < h
                        and not seen[ny][nx]
                        and px[nx, ny] != 0
                    ):
                        seen[ny][nx] = True
                        q.append((nx, ny))

    # Silhouette perimeter (opaque next to empty / edge).
    perim = 0
    for y in range(h):
        for x in range(w):
            if px[x, y] == 0:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny] == 0:
                    perim += 1
                    break
    return {
        "components": comps,
        "perim_area": perim / float(opaque),
        "has_upper_white": upper_white,
        "mid_frac": mid / float(opaque),
        "light_frac": light / float(opaque),
        "ink_frac": ink / float(opaque),
        "opaque": opaque,
    }


def indexed_readability_score(metrics):
    """Higher is more Gen 1-readable.  Used to pick primary vs soft fallback."""
    if not metrics or metrics.get("opaque", 0) < 8:
        return -99
    score = 0
    comps = metrics["components"]
    if comps == 1:
        score += 4
    elif comps == 2:
        score += 1
    else:
        score -= 3
    if metrics["has_upper_white"]:
        score += 4
    else:
        score -= 1  # many steel/rock mons lack bright sclera; soft penalty
    # Flat mid mass + black rim = form is gone.
    body_flat = metrics["light_frac"] + metrics["mid_frac"]
    if body_flat >= 0.82 and metrics["mid_frac"] >= 0.55:
        score -= 3
    elif metrics["mid_frac"] <= 0.08 and metrics["light_frac"] >= 0.7:
        score -= 1  # almost no dark mid structure
    pa = metrics["perim_area"]
    if pa > 0.55:
        score -= 2  # noisy / freckled silhouette
    elif pa < 0.10:
        score -= 1  # over-blobbed
    else:
        score += 1
    if 0.08 <= metrics["ink_frac"] <= 0.45:
        score += 1
    elif metrics["ink_frac"] > 0.55:
        score -= 2  # ink soup
    return score


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


def resize_pixel_art(
    img,
    new_w,
    new_h,
    preserve_features=False,
    boost_rgbs=None,
    boost_mask=None,
    preserve_gaps=False,
    gap_mask=None,
    boost_weight=8,
):
    """Downscale by majority-color blocks so thin outlines / folds survive.

    NEAREST keeps one lucky source pixel per cell and drops the rest — on
    96→32 backs that erases most internal detail.  Majority vote (with a
    boost for near-black) keeps Gen 1-readable structure.

    preserve_features: extra boost for pure white / pure black so 1–2px
    eyes (white sclera + black pupil) survive the shrink.  Use after
    quantize-to-palette so those slots are exact.  Also prefers keeping
    transparent when a block is mostly empty — Metagross armpit / leg
    gaps must not majority-fill into solid slabs.

    boost_rgbs: optional extra RGB triples (e.g. accent gem) that get a
    heavy vote weight so 1–2px chroma marks survive 64→48 majority blocks.

    boost_mask: optional '1' mask (same size as img).  Opaque pixels under
    the mask get an extra majority vote — used for the face/eye band.

    preserve_gaps: stricter empty preference for plated/multi-limb art —
    keep a cell transparent whenever empty ties or beats opaque count.

    gap_mask: optional '1' mask; any block that overlaps it stays empty so
    carved limb cutouts cannot majority-fill.
    """
    from collections import Counter

    img = img.convert("RGBA")
    w, h = img.size
    if (w, h) == (new_w, new_h):
        return img
    if new_w >= w and new_h >= h:
        return img.resize((new_w, new_h), Image.NEAREST)

    boost = set()
    if boost_rgbs:
        for c in boost_rgbs:
            boost.add(tuple(c[:3]))

    bm = None
    if boost_mask is not None:
        boost_mask = boost_mask.convert("1")
        if boost_mask.size == (w, h):
            bm = boost_mask.load()

    gm = None
    if gap_mask is not None:
        gap_mask = gap_mask.convert("1")
        if gap_mask.size == (w, h):
            gm = gap_mask.load()

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
            empty = 0
            cells = 0
            gap_hit = False
            for yy in range(y0, y1):
                for xx in range(x0, x1):
                    cells += 1
                    if gm is not None and gm[xx, yy]:
                        gap_hit = True
                    c = px[xx, yy]
                    if c[3] < 128:
                        empty += 1
                        continue
                    counts[c] += 1
                    rgb_sum = c[0] + c[1] + c[2]
                    # Extra weight for ink / near-black so 1px jaw and limb
                    # creases survive majority vote against surrounding body.
                    if rgb_sum < 80:
                        counts[c] += 6 if preserve_features else 2
                    elif preserve_features and c[0] >= 250 and c[1] >= 250 and c[2] >= 250:
                        counts[c] += 4  # eyes beat body in face band
                    elif preserve_features and (c[0], c[1], c[2]) in boost:
                        counts[c] += int(boost_weight)
                    if bm is not None and bm[xx, yy]:
                        counts[c] += 5
            if gap_hit and preserve_gaps:
                # Only force empty when the block is actually gap-dominated —
                # a 1px bay clipping a majority-body cell must not punch a hole.
                gap_n = 0
                for yy in range(y0, y1):
                    for xx in range(x0, x1):
                        if gm[xx, yy]:
                            gap_n += 1
                if gap_n * 2 >= cells:
                    continue
            opaque_n = cells - empty
            if preserve_gaps and empty >= opaque_n and not (
                counts and min(c[0] + c[1] + c[2] for c in counts) < 40
            ):
                # Plated limb gaps: empty wins ties — don't majority-fill.
                continue
            if preserve_features and cells and empty * 2 >= cells and not (
                counts and min(c[0] + c[1] + c[2] for c in counts) < 80
            ):
                # Majority-empty block → keep the gap (unless it held ink).
                continue
            if counts:
                op[x, y] = counts.most_common(1)[0][0]
    return out


def quantize_rgba_to_palette(img, colors):
    """Snap every opaque pixel to the species' 4 SGB colors at full res.

    Doing this BEFORE downscale (not after) is what keeps tiny features like
    Treecko's eye — majority-block shrink then votes among already-clean
    slots instead of blending yellow into green mush.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 96:
                continue
            idx = nearest_palette_index(r, g, b, colors, hue_aware=True)
            cr, cg, cb = colors[idx]
            op[x, y] = (cr, cg, cb, 255)
    return out


def clean_quantized_freckles(img, colors, min_accent=14):
    """Remove AA rim noise that snapped to the accent slot.

    Emerald anti-aliased edges produce 1–3px freckles of belly-red / flame
    orange around the silhouette.  Large accent masses (belly, horns) stay.

    Also trims yellow→white eye fills: keep white only next to ink (pupil /
    outline) so a full yellow sclera does not become a giant white cheek
    after downscale — Gen 1 readable eyes are a small white+black cluster.
    """
    from collections import deque

    img = img.convert("RGBA")
    if len(colors) < 4:
        return img
    body = tuple(colors[1][:3])
    accent = tuple(colors[2][:3])
    ink = tuple(colors[3][:3])
    white = tuple(colors[0][:3])
    w, h = img.size
    out = img.copy()
    px = out.load()
    seen = [[False] * w for _ in range(h)]

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y][3] >= 128

    def near_ink(x, y, radius=2):
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                nx, ny = x + dx, y + dy
                if opaque(nx, ny) and px[nx, ny][:3] == ink:
                    return True
        return False

    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or px[x0, y0][3] < 128 or px[x0, y0][:3] != accent:
                continue
            blob = []
            q = deque([(x0, y0)])
            seen[y0][x0] = True
            while q:
                x, y = q.popleft()
                blob.append((x, y))
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                        if px[nx, ny][3] >= 128 and px[nx, ny][:3] == accent:
                            seen[ny][nx] = True
                            q.append((nx, ny))
            if len(blob) >= min_accent:
                continue
            for x, y in blob:
                body_n = ink_n = 0
                rim = False
                for dx, dy in (
                    (-1, 0), (1, 0), (0, -1), (0, 1),
                    (-1, -1), (1, -1), (-1, 1), (1, 1),
                ):
                    nx, ny = x + dx, y + dy
                    if not opaque(nx, ny):
                        rim = True
                        continue
                    c = px[nx, ny][:3]
                    if c == body:
                        body_n += 1
                    elif c == ink:
                        ink_n += 1
                if rim and ink_n > body_n:
                    px[x, y] = ink + (255,)
                else:
                    px[x, y] = body + (255,)

    # Trim yellow→white eye fills that aren't next to a pupil/ink.  Only when
    # white is a minority highlight (Treecko eyes) — skip when white is a
    # primary body fill (Gardevoir gown, Blissey, …).
    white_n = opaque_n = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 128:
                continue
            opaque_n += 1
            if px[x, y][:3] == white:
                white_n += 1
    if opaque_n and white_n < opaque_n * 0.12:
        for y in range(h):
            for x in range(w):
                if px[x, y][3] < 128 or px[x, y][:3] != white:
                    continue
                if not near_ink(x, y, radius=1):
                    px[x, y] = body + (255,)
    return out


def clean_midtone_bleed(img, colors, min_blob=10):
    """Scrub small body↔accent freckles (Metagross arm/body bleed).

    After nearest-quantize, anti-aliased edges between two midtones spray
    1–4px islands of the other color.  Drop islands smaller than min_blob
    into the surrounding midtone.  Large masses (X plate, belly, claws) stay.
    Then a 3x3 midtone majority pass kills leftover checkerboard bleed.
    """
    from collections import deque

    img = img.convert("RGBA")
    if len(colors) < 4:
        return img
    body = tuple(colors[1][:3])
    accent = tuple(colors[2][:3])
    w, h = img.size
    out = img.copy()
    px = out.load()

    def scrub(target, fill):
        seen = [[False] * w for _ in range(h)]
        for y0 in range(h):
            for x0 in range(w):
                if seen[y0][x0] or px[x0, y0][3] < 128 or px[x0, y0][:3] != target:
                    continue
                blob = []
                q = deque([(x0, y0)])
                seen[y0][x0] = True
                while q:
                    x, y = q.popleft()
                    blob.append((x, y))
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                            if px[nx, ny][3] >= 128 and px[nx, ny][:3] == target:
                                seen[ny][nx] = True
                                q.append((nx, ny))
                if len(blob) >= min_blob:
                    continue
                other = 0
                for x, y in blob:
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 128:
                            if px[nx, ny][:3] == fill:
                                other += 1
                if other >= max(1, len(blob)):
                    for x, y in blob:
                        px[x, y] = fill + (255,)

    scrub(body, accent)
    scrub(accent, body)

    # 3x3 majority among body/accent only — collapses AA checkerboard
    # without touching white/ink structure.  Rare accent marks (Sableye
    # gems, Electrike sparks) must not be majority-voted into body.
    accent_total = sum(
        1
        for y in range(h)
        for x in range(w)
        if px[x, y][3] >= 128 and px[x, y][:3] == accent
    )
    protect_rare_accent = accent_total > 0 and accent_total <= 12

    src = out.copy()
    sp = src.load()
    for y in range(h):
        for x in range(w):
            c = sp[x, y]
            if c[3] < 128 or c[:3] not in (body, accent):
                continue
            if protect_rare_accent and c[:3] == accent:
                continue
            bc = ac = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    n = sp[nx, ny]
                    if n[3] < 128:
                        continue
                    if n[:3] == body:
                        bc += 1
                    elif n[:3] == accent:
                        ac += 1
            if bc == 0 and ac == 0:
                continue
            if bc > ac:
                px[x, y] = body + (255,)
            elif ac > bc:
                px[x, y] = accent + (255,)
    return out


def repair_eye_sclera(img, colors):
    """Close W·W gaps so Treecko-style eyes stay a solid white mass.

    After yellow→white + downscale, a 1px body speck often sits between two
    white columns (W.W / WKW).  That reads as a broken socket, not an eye.
    Flip body pixels sandwiched by white (orth) to white when white is still
    a minority highlight, then strip stray interior ink that is not a clean
    pupil slit.
    """
    img = img.convert("RGBA")
    if len(colors) < 4:
        return img
    white = tuple(colors[0][:3])
    body = tuple(colors[1][:3])
    ink = tuple(colors[3][:3])
    w, h = img.size
    out = img.copy()
    px = out.load()

    white_n = opaque_n = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 128:
                continue
            opaque_n += 1
            if px[x, y][:3] == white:
                white_n += 1
    if not opaque_n or white_n >= opaque_n * 0.12:
        return out

    # Close single-pixel body gaps between whites.
    src = out.copy()
    sp = src.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] < 128 or sp[x, y][:3] != body:
                continue
            left = x > 0 and sp[x - 1, y][3] >= 128 and sp[x - 1, y][:3] == white
            right = x + 1 < w and sp[x + 1, y][3] >= 128 and sp[x + 1, y][:3] == white
            up = y > 0 and sp[x, y - 1][3] >= 128 and sp[x, y - 1][:3] == white
            down = y + 1 < h and sp[x, y + 1][3] >= 128 and sp[x, y + 1][:3] == white
            if (left and right) or (up and down):
                px[x, y] = white + (255,)
    return out


def ensure_white_eye_pupils(img, colors, max_blob=24, max_bw=8, max_bh=6):
    """Punch a black pupil into white eye blobs that lost their ink.

    Yellow→white sclera + majority downscale often votes away the 1px
    pupil, leaving an empty white oval (Treecko).  Repair W·W gaps first,
    then place a short vertical slit in the blob interior — never treat
    outline ink as a pupil.

    max_blob / max_bw / max_bh: tighten on a second pass after outline/ink
    so cheek whites are not treated as eyes.
    """
    from collections import deque

    img = repair_eye_sclera(img, colors)
    img = img.convert("RGBA")
    if len(colors) < 4:
        return img
    white = tuple(colors[0][:3])
    body = tuple(colors[1][:3])
    ink = tuple(colors[3][:3])
    w, h = img.size
    out = img.copy()
    px = out.load()

    # Skip when white is a primary fill (gowns).
    white_n = opaque_n = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 128:
                continue
            opaque_n += 1
            if px[x, y][:3] == white:
                white_n += 1
    if not opaque_n or white_n >= opaque_n * 0.12:
        return out

    seen = [[False] * w for _ in range(h)]
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or px[x0, y0][3] < 128 or px[x0, y0][:3] != white:
                continue
            blob = []
            q = deque([(x0, y0)])
            seen[y0][x0] = True
            while q:
                x, y = q.popleft()
                blob.append((x, y))
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                        if px[nx, ny][3] >= 128 and px[nx, ny][:3] == white:
                            seen[ny][nx] = True
                            q.append((nx, ny))
            if len(blob) < 2:
                continue
            xs = [p[0] for p in blob]
            ys = [p[1] for p in blob]
            bw = max(xs) - min(xs) + 1
            bh = max(ys) - min(ys) + 1
            # Eyes are compact.  Tall white snakes (sclera + cheek speck):
            # keep the top band only.
            if bw > max_bw or bh > max_bh or len(blob) > max_blob:
                y_min = min(ys)
                blob = [p for p in blob if p[1] <= y_min + 4]
                if len(blob) < 2:
                    continue
            blob_set = set(blob)
            xs = [p[0] for p in blob]
            ys = [p[1] for p in blob]
            cx = sum(xs) / len(blob)
            y_lo, y_hi = min(ys), max(ys)

            def is_outline_ink(ix, iy):
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = ix + dx, iy + dy
                    if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] < 128:
                        return True
                return False

            def side_white(ix, iy):
                for sx in (ix - 1, ix + 1):
                    if (sx, iy) in blob_set:
                        return True
                    if 0 <= sx < w and px[sx, iy][3] >= 128 and px[sx, iy][:3] == white:
                        return True
                return False

            # Prefer an EXISTING interior pupil column (ink with sclera on a
            # side).  Filling leftover side-whites instead is what turned a
            # good WKW eye into a solid KKK block on the second pass.
            pupil_cols = set()
            for x in range(min(xs) - 1, max(xs) + 2):
                if not (0 <= x < w):
                    continue
                for y in range(y_lo, y_hi + 1):
                    if px[x, y][3] < 128 or px[x, y][:3] != ink:
                        continue
                    if is_outline_ink(x, y):
                        continue
                    if side_white(x, y):
                        pupil_cols.add(x)
                        break

            if pupil_cols:
                best_x = min(pupil_cols, key=lambda x: abs(x - cx))
            else:
                col_whites = {}
                for x, y in blob:
                    col_whites.setdefault(x, []).append(y)
                best_x = min(
                    col_whites.keys(),
                    key=lambda x: (abs(x - cx), -len(col_whites[x])),
                )

            # Continuous top→bottom slit: always ink white/body holes in the
            # pupil column across the eye's vertical span (fixes the "two
            # dots with a white gap" look when row N is WKW but N-1 is KWK).
            span_ys = [
                y for y in range(y_lo, y_hi + 1)
                if (best_x, y) in blob_set
                or (
                    0 <= best_x < w
                    and px[best_x, y][3] >= 128
                    and px[best_x, y][:3] == ink
                    and not is_outline_ink(best_x, y)
                )
            ]
            if not span_ys:
                continue
            y_a, y_b = min(span_ys), max(span_ys)
            # Stretch through any white still sitting in this column inside
            # the full eye band (trimmed blob may have dropped cheek rows
            # that still leave a hole above the slit).
            for y in range(y_lo, y_hi + 1):
                if (best_x, y) in blob_set:
                    y_a, y_b = min(y_a, y), max(y_b, y)
            if y_b == y_a:
                for ny in (y_a + 1, y_a - 1):
                    if (best_x, ny) in blob_set:
                        y_a, y_b = min(y_a, ny), max(y_b, ny)
                        break

            for y in range(y_a, y_b + 1):
                if px[best_x, y][3] < 128:
                    continue
                if px[best_x, y][:3] == ink and is_outline_ink(best_x, y):
                    continue
                if px[best_x, y][:3] in (white, body, ink):
                    px[best_x, y] = ink + (255,)
    return out


def bridge_same_tone_cracks(img, colors, max_gap=2):
    """Rejoin hairline cracks that fragment a limb without closing armpits.

    Metagross legs were splitting into a detached blue column with a white
    hairline — majority-empty resize over-preserved those.  Fill a short
    transparent run (1–max_gap px) when both ends are the *same* body/accent
    midtone.  Wider openings and ink-bordered gaps stay open.
    """
    img = img.convert("RGBA")
    if len(colors) < 4:
        return img
    body = tuple(colors[1][:3])
    accent = tuple(colors[2][:3])
    ink = tuple(colors[3][:3])
    tones = (body, accent)
    w, h = img.size
    out = img.copy()
    px = out.load()

    def tone_at(x, y):
        if not (0 <= x < w and 0 <= y < h):
            return None
        c = px[x, y]
        if c[3] < 128 or c[:3] not in tones:
            return None
        return c[:3]

    # Horizontal runs.
    for y in range(h):
        x = 0
        while x < w:
            if px[x, y][3] >= 128:
                x += 1
                continue
            x0 = x
            while x < w and px[x, y][3] < 128:
                x += 1
            gap = x - x0
            if 1 <= gap <= max_gap:
                left = tone_at(x0 - 1, y)
                right = tone_at(x, y)
                if left is not None and left == right:
                    for fx in range(x0, x):
                        px[fx, y] = left + (255,)
    # Vertical runs.
    for x in range(w):
        y = 0
        while y < h:
            if px[x, y][3] >= 128:
                y += 1
                continue
            y0 = y
            while y < h and px[x, y][3] < 128:
                y += 1
            gap = y - y0
            if 1 <= gap <= max_gap:
                up = tone_at(x, y0 - 1)
                down = tone_at(x, y)
                if up is not None and up == down:
                    for fy in range(y0, y):
                        px[x, fy] = up + (255,)

    # Jump a single ink pixel that splits a midtone run (outline sitting in
    # a notch): tone | ink | gap | tone  → fill the gap with tone.
    for y in range(h):
        x = 1
        while x < w - 1:
            t_left = tone_at(x - 1, y)
            if t_left is None:
                x += 1
                continue
            if px[x, y][3] < 128 or px[x, y][:3] != ink:
                x += 1
                continue
            # ink at x; scan gap after it
            g0 = x + 1
            g = g0
            while g < w and px[g, y][3] < 128:
                g += 1
            gap = g - g0
            if 1 <= gap <= max_gap and tone_at(g, y) == t_left:
                for fx in range(g0, g):
                    px[fx, y] = t_left + (255,)
            x += 1
    for x in range(w):
        y = 1
        while y < h - 1:
            t_up = tone_at(x, y - 1)
            if t_up is None:
                y += 1
                continue
            if px[x, y][3] < 128 or px[x, y][:3] != ink:
                y += 1
                continue
            g0 = y + 1
            g = g0
            while g < h and px[x, g][3] < 128:
                g += 1
            gap = g - g0
            if 1 <= gap <= max_gap and tone_at(x, g) == t_up:
                for fy in range(g0, g):
                    px[x, fy] = t_up + (255,)
            y += 1

    # Small floating midtone islands next to a larger same-tone mass (often
    # separated by a single outline pixel).  Bridge the shortest transparent
    # gap so a detached Metagross claw/arm rejoins without filling armpits.
    from collections import deque

    def components(target):
        seen = [[False] * w for _ in range(h)]
        blobs = []
        for y0 in range(h):
            for x0 in range(w):
                if seen[y0][x0] or px[x0, y0][3] < 128 or px[x0, y0][:3] != target:
                    continue
                blob = []
                q = deque([(x0, y0)])
                seen[y0][x0] = True
                while q:
                    x, y = q.popleft()
                    blob.append((x, y))
                    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                            if px[nx, ny][3] >= 128 and px[nx, ny][:3] == target:
                                seen[ny][nx] = True
                                q.append((nx, ny))
                blobs.append(blob)
        return blobs

    for tone in tones:
        blobs = components(tone)
        if len(blobs) < 2:
            continue
        big = max(blobs, key=len)
        if len(big) < 20:
            continue
        big_set = set(big)
        for blob in blobs:
            if len(blob) > 24 or len(blob) < 2:
                continue
            if set(blob) <= big_set:
                continue
            best = None
            for x, y in blob:
                for dx in range(-3, 4):
                    for dy in range(-3, 4):
                        if dx == 0 and dy == 0:
                            continue
                        nx, ny = x + dx, y + dy
                        if (nx, ny) not in big_set:
                            continue
                        dist = abs(dx) + abs(dy)
                        if best is None or dist < best[0]:
                            best = (dist, x, y, nx, ny)
            if best is None or best[0] > 4:
                continue
            _, x0, y0, x1, y1 = best
            steps = max(abs(x1 - x0), abs(y1 - y0), 1)
            for i in range(1, steps):
                t = i / steps
                fx = int(round(x0 + (x1 - x0) * t))
                fy = int(round(y0 + (y1 - y0) * t))
                if not (0 <= fx < w and 0 <= fy < h):
                    continue
                c = px[fx, fy]
                if c[3] < 128 or c[:3] == ink:
                    px[fx, fy] = tone + (255,)
    return out


def smooth_silhouette_stairs(img, ink_only=True):
    """Mild chamfer of convex 2-step outer corners (Treecko head stairs).

    One pass: if an opaque pixel is a convex silhouette corner (exactly two
    adjacent orth neighbors opaque, open diagonal transparent), shave it.
    Default ink_only keeps body mass and only rounds the black rim — enough
    to kill harsh staircase without cartoon-blobbing the silhouette.
    """
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    def is_ink(x, y):
        c = src[x, y]
        return c[3] >= 128 and c[0] + c[1] + c[2] < 48

    # (dx1,dy1), (dx2,dy2) = the two orth dirs that are opaque;
    # diagonal toward the open quadrant is (dx1+dx2, dy1+dy2).
    corners = (
        ((-1, 0), (0, -1)),
        ((1, 0), (0, -1)),
        ((-1, 0), (0, 1)),
        ((1, 0), (0, 1)),
    )
    for y in range(h):
        for x in range(w):
            if not opaque(x, y):
                continue
            if ink_only and not is_ink(x, y):
                continue
            orth = []
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                if opaque(x + dx, y + dy):
                    orth.append((dx, dy))
            if len(orth) != 2:
                continue
            (dx1, dy1), (dx2, dy2) = orth
            # Must be a corner (perpendicular), not a straight edge.
            if dx1 * dx2 != 0 or dy1 * dy2 != 0:
                continue
            # Open diagonal = into the empty quadrant.
            ox, oy = x - dx1 - dx2, y - dy1 - dy2
            if opaque(ox, oy):
                continue
            # Inward diagonal should be solid (real corner, not a 1px whisker).
            ix, iy = x + dx1 + dx2, y + dy1 + dy2
            if not opaque(ix, iy):
                continue
            dst[x, y] = (0, 0, 0, 0)
    return out


def ink_midtone_seams(img, colors):
    """Draw 1px black creases where body and accent midtones meet.

    Metagross silver X / blue body share AA edges; without a crease the two
    midtones checkerboard into each other.  Only mark a pixel ink when it
    has 2+ orthogonal neighbors of the *other* midtone (true seam, not a
    single corner touch).
    """
    img = img.convert("RGBA")
    if len(colors) < 4:
        return img
    body = tuple(colors[1][:3])
    accent = tuple(colors[2][:3])
    ink = tuple(colors[3][:3])
    w, h = img.size
    src = img.copy()
    sp = src.load()
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            c = sp[x, y]
            if c[3] < 128 or c[:3] not in (body, accent):
                continue
            other = accent if c[:3] == body else body
            n_other = 0
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] >= 128:
                    if sp[nx, ny][:3] == other:
                        n_other += 1
            if n_other >= 2:
                px[x, y] = ink + (255,)
    return out


def ink_structure_creases(
    quantized,
    source,
    colors,
    dark_ratio=0.70,
    min_contrast=26,
    valley_delta=20,
):
    """Recover jaw / limb / fold lines lost when same-hue shades collapse.

    Gen 2/3 art defines necks, jaws, and arm joins with *darker body* pixels
    (Treecko olive jaw, Metagross deep blue armpits).  Nearest-4 snap maps
    those onto the single body midtone, so the feature vanishes.  Read the
    pre-quantize source luma and force midtone pixels to ink when they are:

      • a local luma valley (H or V minimum with enough depth), or
      • a very dark same-hue body shade with local contrast

    Accent masses (belly red, silver X) stay chromatic unless they sit in a
    true valley.  Isolated freckles near eye-white are dropped so sclera
    does not grow a black halo.
    """
    if len(colors) < 4:
        return quantized
    q = quantized.convert("RGBA")
    s = source.convert("RGBA")
    if q.size != s.size:
        return quantized
    w, h = q.size
    qp = q.load()
    sp = s.load()
    out = q.copy()
    op = out.load()
    body = tuple(colors[1][:3])
    accent = tuple(colors[2][:3])
    ink = tuple(colors[3][:3])
    white = tuple(colors[0][:3])
    body_l = _pixel_luma(body)
    dark_cut = body_l * dark_ratio
    mark = [[False] * w for _ in range(h)]

    def src_luma(x, y):
        c = sp[x, y]
        if c[3] < 200:
            return None
        return _pixel_luma(c)

    for y in range(1, h - 1):
        for x in range(1, w - 1):
            qc = qp[x, y]
            if qc[3] < 128 or qc[:3] not in (body, accent):
                continue
            p = sp[x, y]
            if p[3] < 200 or max(p[0], p[1], p[2]) < 40:
                continue
            L = _pixel_luma(p)
            if L >= body_l - 8:
                continue
            is_accent = qc[:3] == accent
            left = src_luma(x - 1, y)
            right = src_luma(x + 1, y)
            up = src_luma(x, y - 1)
            down = src_luma(x, y + 1)
            orth = [v for v in (left, right, up, down) if v is not None]
            if len(orth) < 3:
                continue

            valley = False
            if left is not None and right is not None:
                if (
                    L + 6 < left
                    and L + 6 < right
                    and (left + right) / 2 - L >= valley_delta
                ):
                    valley = True
            if up is not None and down is not None:
                if (
                    L + 6 < up
                    and L + 6 < down
                    and (up + down) / 2 - L >= valley_delta
                ):
                    valley = True
            if (
                sum(1 for n in orth if n >= L + valley_delta) >= 3
                and L <= dark_cut + 5
            ):
                valley = True

            sat = max(p[0], p[1], p[2]) - min(p[0], p[1], p[2])
            # Broad dark body shade only when very dark — mid face AA must
            # not become a black freckle grid.
            dark_shade = (
                (not is_accent)
                and L <= min(dark_cut, 105)
                and sat >= 18
                and (max(orth) - L) >= min_contrast
            )
            if valley or dark_shade:
                mark[y][x] = True

    for y in range(h):
        for x in range(w):
            if not mark[y][x]:
                continue
            n_mark = n_ink = n_white = 0
            for dx, dy in (
                (-1, 0), (1, 0), (0, -1), (0, 1),
                (-1, -1), (1, -1), (-1, 1), (1, 1),
            ):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                if mark[ny][nx]:
                    n_mark += 1
                nc = qp[nx, ny]
                if nc[3] < 128:
                    continue
                if nc[:3] == ink:
                    n_ink += 1
                elif nc[:3] == white:
                    n_white += 1
            # Drop lone marks hugging sclera (eye AA), keep deep folds.
            if n_white >= 2 and n_mark == 0 and _pixel_luma(sp[x, y]) > 100:
                continue
            if n_mark >= 1 or n_ink >= 1 or _pixel_luma(sp[x, y]) < 95:
                op[x, y] = ink + (255,)
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

            # Keep rim white (eye sclera / highlights) — converting it to ink
            # is what makes Gen 2/3 faces read as empty sockets.
            if min(src[x, y][0], src[x, y][1], src[x, y][2]) >= 230:
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


def ensure_contrast_outline(img, luma_floor=110):
    """Light outline for dark / busy sprites (Murkrow, Sableye, …).

    Only ink exterior pixels that would vanish on a white battle BG.  Dark
    body already reads against white, so forcing a full black rim just
    thickens the silhouette into an unreadable blob.
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
            if not (
                not opaque(x - 1, y)
                or not opaque(x + 1, y)
                or not opaque(x, y - 1)
                or not opaque(x, y + 1)
            ):
                continue
            # Never overwrite rim white — Treecko eyes sit on the head edge;
            # inking them leaves an empty black socket.
            if min(src[x, y][0], src[x, y][1], src[x, y][2]) >= 230:
                continue
            body = src[x, y]
            for nx, ny in (
                (x, y + 1), (x - 1, y), (x + 1, y), (x, y - 1),
            ):
                if opaque(nx, ny):
                    body = src[nx, ny]
                    break
            if _pixel_luma(body) >= luma_floor:
                dst[x, y] = black
    return out


def lift_near_black_body(img, lift_rgb=(56, 56, 88), preserve_chroma_dither=False):
    """Raise interior near-black fills so dark mons keep a mid-tone body.

    Crystal Murkrow / Sableye art is mostly near-black; without a lift the
    DMG shade map collapses the whole body into outline ink.

    preserve_chroma_dither: leave black pixels that sit next to chromatic
    navy/purple alone — those are the shadow half of Crystal-style dither,
    not solid fill.  Only lift contiguous black slabs.
    """
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    lr, lg, lb = lift_rgb
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a < 128 or r + g + b >= 48:
                continue
            exterior = False
            next_to_chroma = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] < 128:
                    exterior = True
                    continue
                nr, ng, nb, _ = src[nx, ny]
                nsat = max(nr, ng, nb) - min(nr, ng, nb)
                if nsat >= 28 and nr + ng + nb >= 48:
                    next_to_chroma = True
            # Leave silhouette edge black; lift solid interior fills.
            if exterior:
                continue
            if preserve_chroma_dither and next_to_chroma:
                continue
            dst[x, y] = (lr, lg, lb, 255)
    return out


def thin_double_outline(img, body_rgb=(88, 88, 168)):
    """Collapse Crystal-style 2px black rims to a 1px Gen 1 outline.

    Inner-ring black that touches body on one side and an exterior black on
    the other becomes body fill.  True silhouette ink and interior shadow
    dither are left alone.
    """
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    body = (int(body_rgb[0]), int(body_rgb[1]), int(body_rgb[2]), 255)

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 128

    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a < 128 or r + g + b >= 24:
                continue
            has_trans = False
            has_body = False
            has_exterior_black = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if not opaque(nx, ny):
                    has_trans = True
                    continue
                nr, ng, nb, _ = src[nx, ny]
                if nr + ng + nb < 24:
                    for dx2, dy2 in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                        if not opaque(nx + dx2, ny + dy2):
                            has_exterior_black = True
                            break
                elif nr + ng + nb >= 48:
                    has_body = True
            if has_body and has_exterior_black and not has_trans:
                dst[x, y] = body
    return out


def clean_indexed_accent_ink(indexed_img, accent_index=3, ink_index=4):
    """Pull stray ink out of yellow/red accent blobs (beak, gems).

    If a black pixel is surrounded by mostly accent neighbors, it is almost
    always resize noise — not a mouth line (those keep ≥1 non-accent side).
    """
    w, h = indexed_img.size
    px = indexed_img.load()
    fixes = []
    for y in range(h):
        for x in range(w):
            if px[x, y] != ink_index:
                continue
            accent_n = 0
            opaque_n = 0
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                v = px[nx, ny]
                if v == 0:
                    continue
                opaque_n += 1
                if v == accent_index:
                    accent_n += 1
            if opaque_n >= 3 and accent_n >= 3:
                fixes.append((x, y))
    for x, y in fixes:
        px[x, y] = accent_index
    return indexed_img


# ---------------------------------------------------------------------------
# Per-species sprite overrides
#
# Prefer style profiles (GEN3_STYLE_PROFILES / GEN3_BACK_STYLE_PROFILES)
# over listing every knob.  Pin fronts with "style"; backs with "back_style"
# (falls back to "style" when unset).  Palette / lift / clean_accent stay
# here as true one-offs.
#
# Gen 2 (dex 152–251): FAITHFUL_DEFAULTS — left alone.
# Gen 3 (dex 252–386): GEN3_UNIFIED_DEFAULTS → style profile → override.
# ---------------------------------------------------------------------------

# Stage 0 chroma thresholds (channel sat = max-min, 0..255).
LOW_CHROMA_MEAN_SAT = 50.0
LOW_BODY_MID_SAT = 40.0
# Clear accent (belly/mane/gem) — force nearest so body_mid cannot mute it.
CLEAR_ACCENT_SAT = 55.0
# 90th-percentile sat ≥ this ⇒ vibrant accent cluster (0.6 × 255).
HIGH_SAT_P90 = 153.0
# Midtone luma gap below this ⇒ needs_contrast_stretch (conservative).
PALETTE_CONTRAST_MIN_MID_SPAN = 36.0

# Crystal-faithful path (Gen 2 only for now).
FAITHFUL_DEFAULTS = {
    "shade": "nearest",
    "outline": "soft",
    "outline_luma": 100,
    "depth": False,
    "dilate": False,
    "stem": False,
    "seal": False,
    "quantize_first": True,
    "ink_midtone_seams": True,
    "structure_creases": False,
    "bridge_cracks": True,
    "smooth_stairs": True,
    "flat_dither": False,
    "orphan_min": 2,
    "close_gap": 0,
}

# Gen 3 fronts: Gen 1 *style* defaults (silhouette readability, not Emerald
# fidelity).  Backs override locally to a heavier survival stack.
GEN3_UNIFIED_DEFAULTS = {
    "outline": "soft",
    "outline_luma": 110,
    "depth": False,
    "dilate": False,  # only when shrink ≥1.4× (see bake)
    "stem": True,
    "seal": True,
    "ink_midtone_seams": False,
    "structure_creases": False,
    "bridge_cracks": True,
    "smooth_stairs": True,
    "flat_dither": None,  # backs on by default
    "orphan_min": 2,
    "close_gap": 1,  # fronts keep intentional negative space
    "lift_darks": False,
    "preserve_ink": True,
    "ink_luma_max": 48,
    "ink_soft_luma_max": 62,  # plate seams (dark blue) without shading soup
    "ink_contrast_delta": 26,
    "ink_mask_min_blob": 3,
    "readable_fallback": True,
}

# Gen 3 backs (32×32 from padded Emerald 64/96 sheets).  Same profile idea
# as fronts, but tuned for steep shrink + no face-band: volume, ink survival,
# tight crop, and front-palette borrow so Advanced colors stay consistent.
#
# Merge order: GEN3_BACK_UNIFIED_DEFAULTS → back profile → species override
# (back_style pin wins over style for profile pick).
GEN3_BACK_UNIFIED_DEFAULTS = {
    "outline": "soft",
    "outline_luma": 95,
    "depth": True,
    "dilate": True,
    "stem": False,
    "seal": True,
    "ink_midtone_seams": True,
    "structure_creases": True,
    "bridge_cracks": True,
    "smooth_stairs": True,
    "flat_dither": True,
    "orphan_min": 2,
    "close_gap": 1,
    "lift_darks": False,
    "preserve_ink": True,
    "preserve_gaps": False,
    "carve_seams": False,
    "reinforce_seams": False,
    "tight_crop": True,
    "prefer_front_palette": True,
    "boost_light_mid": True,
    "ink_luma_max": 48,
    "ink_soft_luma_max": 60,
    "ink_contrast_delta": 26,
    "ink_mask_min_blob": 3,
    "readable_fallback": True,
}

# Deprecated alias — Gen3 backs use GEN3_BACK_* via _process_sprite_gen3.
GEN3_BACK_FAITHFUL_DEFAULTS = dict(GEN3_BACK_UNIFIED_DEFAULTS)

# Named style branches — reusable filter sets for recurring Emerald→Gen1
# failure modes.  Stage 0 picks one automatically; pin with
# SPRITE_OVERRIDES[species]["style"] = "plated" when auto mis-classifies.
#
# Merge order: GEN3_UNIFIED_DEFAULTS → profile → species override.
GEN3_STYLE_PROFILES = {
    # Ordinary chromatic / mixed mons (Treecko, Torchic, …).
    "default": {},
    # High-contrast organic with a clear accent — prefer hue-aware nearest,
    # light stem, soft rim.  Stage 0 shade already leans nearest here.
    "organic": {
        "outline": "soft",
        "stem": True,
        "seal": True,
        "close_gap": 1,
        "dilate": False,
        "structure_creases": False,
        "ink_soft_luma_max": 55,
        "ink_mask_min_blob": 3,
    },
    # Stripe / patch / brush-tail mons (Zigzagoon): protect light bands,
    # no stem fatten or midtone scrub that dissolves cream into brown mush.
    "patterned": {
        "outline": "soft",
        "stem": False,
        "seal": False,
        "close_gap": 0,
        "dilate": False,
        "structure_creases": True,
        "ink_midtone_seams": True,
        "depth": False,
        "bridge_cracks": False,
        "boost_light_mid": True,
        "skip_midtone_bleed": True,
        "ink_soft_luma_max": 55,
        "ink_mask_min_blob": 3,
        "min_accent": 10,
    },
    # Plated / multi-limb mechanical (Metagross, Aggron): keep *source*
    # negative space, define limb joins with reinforced black ink — never
    # invent cutouts (that eats claws/toes and punches pink holes in arms).
    "plated": {
        "outline": "soft",
        "outline_luma": 100,
        "dilate": False,
        "stem": False,
        "seal": False,
        "close_gap": 0,
        "bridge_cracks": False,
        "structure_creases": False,
        "ink_midtone_seams": False,
        "depth": False,
        "preserve_ink": True,
        "preserve_gaps": True,
        "carve_seams": False,
        "reinforce_seams": True,
        "smooth_stairs": False,
        "ink_soft_luma_max": 64,
        "ink_contrast_delta": 24,
        "ink_mask_min_blob": 3,
        "readable_fallback": False,
    },
    # Near-black bodies (Sableye-class): lift midtone body, no fattening rim.
    "dark_body": {
        "outline": "none",
        "dilate": False,
        "stem": False,
        "seal": False,
        "close_gap": 0,
        "lift_darks": True,
        "preserve_dither": True,
        "structure_creases": False,
        "ink_midtone_seams": False,
        "depth": False,
        "ink_soft_luma_max": 50,
        "ink_mask_min_blob": 4,
    },
    # Thin antennae / multi-leg insects: protect gaps, minimal thicken.
    "delicate": {
        "outline": "soft",
        "dilate": False,
        "stem": False,
        "seal": False,
        "close_gap": 0,
        "bridge_cracks": False,
        "structure_creases": False,
        "ink_soft_luma_max": 55,
        "ink_mask_min_blob": 3,
    },
}

# Back-specific subsets (32×32).  Same names as fronts where the failure mode
# matches; `patterned` is back-only for stripe/spot survival (Zigzagoon).
GEN3_BACK_STYLE_PROFILES = {
    "default": {},
    # Starters / chromatic bipeds — limb and tail creases, volume, no sausage stems.
    "organic": {
        "structure_creases": True,
        "ink_midtone_seams": True,
        "depth": True,
        "dilate": True,
        "stem": False,
        "seal": True,
        "outline": "soft",
        "outline_luma": 95,
        "ink_soft_luma_max": 55,
        "boost_light_mid": True,
    },
    # Stripe / patch / brush-tail mons — protect light mid, skip depth freckles.
    "patterned": {
        "structure_creases": True,
        "ink_midtone_seams": True,
        "depth": False,
        "dilate": True,
        "stem": False,
        "seal": True,
        "close_gap": 0,
        "outline": "soft",
        "boost_light_mid": True,
        "ink_soft_luma_max": 58,
        "flat_dither": False,
    },
    # Mechanical multi-limb — keep source gaps, reinforce ink, never fatten.
    "plated": {
        "outline": "soft",
        "outline_luma": 100,
        "dilate": False,
        "stem": False,
        "seal": False,
        "close_gap": 0,
        "bridge_cracks": False,
        "structure_creases": False,
        "ink_midtone_seams": False,
        "depth": False,
        "preserve_gaps": True,
        "reinforce_seams": True,
        "carve_seams": False,
        "smooth_stairs": False,
        "boost_light_mid": False,
        "readable_fallback": False,
        "ink_soft_luma_max": 64,
    },
    "dark_body": {
        "outline": "none",
        "dilate": False,
        "stem": False,
        "seal": False,
        "close_gap": 0,
        "lift_darks": True,
        "preserve_dither": True,
        "structure_creases": False,
        "ink_midtone_seams": False,
        "depth": False,
        "boost_light_mid": False,
        "ink_soft_luma_max": 50,
    },
    "delicate": {
        "outline": "soft",
        "dilate": False,
        "stem": False,
        "seal": False,
        "close_gap": 0,
        "bridge_cracks": False,
        "structure_creases": True,
        "preserve_gaps": True,
        "depth": True,
        "boost_light_mid": True,
        "ink_soft_luma_max": 55,
    },
}

# Soft retry when readability metrics fail (still no per-species hand path).
GEN3_SOFT_FALLBACK = {
    "dilate": False,
    "stem": False,
    "seal": False,
    "outline": "soft",
    "structure_creases": False,
    "ink_midtone_seams": False,
    "depth": False,
    "close_gap": 1,
    "ink_soft_luma_max": 50,
    "ink_mask_min_blob": 4,
    "preserve_ink": True,
}

# Back-compat alias
GEN2_FAITHFUL_DEFAULTS = FAITHFUL_DEFAULTS


SPRITE_OVERRIDES = {
    # Curated Advanced palettes where auto-extract is weak.
    "TREECKO": {
        "palette": [
            (255, 255, 255),
            (152, 208, 72),   # lime body
            (208, 80, 56),    # brick-red belly
            (0, 0, 0),
        ],
        "back_style": "organic",
    },
    "ZIGZAGOON": {
        "palette": [
            (255, 255, 255),
            (224, 208, 168),  # cream stripes / brush tail
            (168, 120, 88),   # brown body
            (0, 0, 0),
        ],
        "style": "patterned",
        "back_style": "patterned",
    },
    "LINOONE": {
        "style": "patterned",
        "back_style": "patterned",
    },
    "METAGROSS": {
        "style": "plated",
        "palette": [
            (255, 255, 255),
            (144, 136, 144),  # silver X / metal mid
            (56, 96, 176),    # steel blue body
            (0, 0, 0),
        ],
    },
    "METANG": {
        "style": "plated",
    },
    "BELDUM": {
        "style": "plated",
    },
    "AGGRON": {
        "style": "plated",
    },
    "LAIRON": {
        "style": "plated",
    },
    "ARON": {
        "style": "plated",
    },
    "REGISTEEL": {
        "style": "plated",
    },
    "LUNATONE": {
        "palette": [
            (255, 255, 255),
            (232, 208, 120),  # cream moon rock
            (144, 96, 56),    # warm brown crater
            (0, 0, 0),
        ],
    },
    "ELECTRIKE": {
        "palette": [
            (255, 255, 255),
            (72, 176, 88),    # green body
            (232, 216, 40),   # yellow mane / sparks
            (0, 0, 0),
        ],
    },
    "GULPIN": {
        "palette": [
            (255, 255, 255),
            (112, 192, 72),   # leaf green body
            (56, 128, 48),    # darker green
            (0, 0, 0),
        ],
    },
    "SEVIPER": {
        "palette": [
            (255, 255, 255),
            (216, 176, 120),  # tan / cream belly
            (104, 56, 128),   # purple body
            (0, 0, 0),
        ],
    },
    "SOLROCK": {
        "palette": [
            (255, 255, 255),
            (240, 184, 56),   # gold sun rock
            (192, 96, 40),    # orange face
            (0, 0, 0),
        ],
    },
    # Gen 2 dark-body escape hatch (Gen 2 pipeline left unchanged).
    "MURKROW": {
        "faithful": False,
        "dilate": False,
        "stem": False,
        "depth": False,
        "seal": False,
        "outline": "none",
        "orphan_min": 2,
        "shade": "nearest",
        "lift_darks": False,
        "flat_dither": False,
        "palette": [
            (255, 255, 255),
            (214, 214, 25),   # yellow face/feet
            (58, 58, 140),    # navy body
            (0, 0, 0),
        ],
    },
    # White shell contiguous with Crystal matte — key_out must keep body white.
    # Back uses v1 geometry; faithful majority-vote collapses the shell.
    "FORRETRESS": {
        "back_v1": True,
        "dilate": True,
        "stem": False,
        "depth": False,
        "seal": True,
        "outline": "soft",
        "close_gap": 1,
        "shade": "nearest",
        "palette": [
            (255, 255, 255),
            (197, 90, 214),   # purple band
            (156, 16, 74),    # dark magenta
            (0, 0, 0),
        ],
    },
    # Near-black body — dark_body profile + tiny-gem knobs.
    "SABLEYE": {
        "style": "dark_body",
        "thin_outline": True,
        "clean_accent": True,
        "flat_dither": False,
        "min_accent": 3,
        "midtone_min_blob": 1,
        "midtone_min_blob_small": 1,
        "contrast_stretch": False,
        "shade": "nearest",
        "palette": [
            (255, 255, 255),
            (168, 136, 200),  # purple BODY → DMG shade 1
            (232, 72, 72),    # gem red → DMG shade 2
            (0, 0, 0),
        ],
    },
    # Dark robe + cream skull: body_mid treats luma≥90 as shade-1, so the
    # olive body paints as cream/white in Advanced.  Hue-nearest keeps body
    # on slot 2 and skull on slot 1.
    "DUSKULL": {
        "shade": "nearest",
        "palette": [
            (255, 255, 255),
            (216, 208, 168),  # skull
            (104, 104, 88),   # body
            (0, 0, 0),
        ],
    },
    # Same body_mid trap: gray gown luma~175 → pure white.
    "DUSCLOPS": {
        "shade": "nearest",
        "palette": [
            (255, 255, 255),
            (176, 176, 160),  # body
            (80, 56, 48),     # shadow / eye ring
            (0, 0, 0),
        ],
    },
    # Same washout class (auto-caught by Stage 0; pins keep palettes stable).
    "SLAKING": {"shade": "nearest"},
    "SHEDINJA": {"shade": "nearest"},
    "SPOINK": {"shade": "nearest"},
    "ANORITH": {"shade": "nearest"},
    "SHIFTRY": {"shade": "nearest"},
}


def dex_from_sprite_path(path):
    """Parse `{dex}_front.png` / `{dex}_back.png` cache names."""
    import re
    m = re.search(r"(?:^|[/\\])(\d+)_(?:front|back)\.png$", str(path))
    return int(m.group(1)) if m else None


def is_gen2_dex(dex):
    return dex is not None and 152 <= int(dex) <= 251


def is_gen3_dex(dex):
    return dex is not None and 252 <= int(dex) <= 386


def sprite_override(species_id):
    if not species_id:
        return {}
    return dict(SPRITE_OVERRIDES.get(str(species_id).upper(), {}))


def resolve_sprite_opts(species_id=None, dex=None, input_path=None):
    """Merge generation defaults with per-species overrides.

    Overrides win.  Gen 2 → FAITHFUL_DEFAULTS; Gen 3 → GEN3_UNIFIED_DEFAULTS
    only (style profiles are applied later in _process_sprite_gen3 once the
    source image is available for auto-classification).
    """
    if dex is None and input_path:
        dex = dex_from_sprite_path(input_path)
    opts = {}
    override = sprite_override(species_id)
    if is_gen3_dex(dex):
        opts.update(GEN3_UNIFIED_DEFAULTS)
    elif is_gen2_dex(dex) and override.get("faithful", True):
        opts.update(FAITHFUL_DEFAULTS)
    # Defer style/profile merge for Gen 3; still apply non-style override keys
    # so callers that only use resolve_sprite_opts see palette etc.
    for key, value in override.items():
        if key == "style":
            continue
        opts[key] = value
    return opts


def count_interior_transparent_holes(img):
    """Count fully enclosed transparent pockets inside the silhouette.

    Exterior background (touches the image edge) is ignored.  Used to detect
    plated / multi-limb art whose negative space is load-bearing (Metagross
    armpits, Aggron legs).
    """
    from collections import deque

    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    exterior = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if px[x, y][3] < 128 and not exterior[y][x]:
                exterior[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if px[x, y][3] < 128 and not exterior[y][x]:
                exterior[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (
                0 <= nx < w
                and 0 <= ny < h
                and not exterior[ny][nx]
                and px[nx, ny][3] < 128
            ):
                exterior[ny][nx] = True
                q.append((nx, ny))

    seen = [[False] * w for _ in range(h)]
    holes = 0
    for y in range(h):
        for x in range(w):
            if seen[y][x] or exterior[y][x] or px[x, y][3] >= 128:
                continue
            holes += 1
            qq = deque([(x, y)])
            seen[y][x] = True
            while qq:
                cx, cy = qq.popleft()
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if (
                        0 <= nx < w
                        and 0 <= ny < h
                        and not seen[ny][nx]
                        and not exterior[ny][nx]
                        and px[nx, ny][3] < 128
                    ):
                        seen[ny][nx] = True
                        qq.append((nx, ny))
    return holes


def count_silhouette_bays(img):
    """Count transparent pixels pinched between opaque on opposite sides.

    Metagross armpits / Aggron leg gaps usually open to the exterior, so they
    are not enclosed holes — but they are still load-bearing negative space.
    A horizontal or vertical opaque–empty–opaque pinch is a 'bay'.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    def opaque(x, y):
        return 0 <= x < w and 0 <= y < h and px[x, y][3] >= 128

    bays = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= 128:
                continue
            if opaque(x - 1, y) and opaque(x + 1, y):
                bays += 1
            elif opaque(x, y - 1) and opaque(x, y + 1):
                bays += 1
    return bays


def mean_opaque_luma(img):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    total = 0.0
    n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            total += _pixel_luma((r, g, b))
            n += 1
    return (total / n) if n else 255.0


def choose_gen3_style(img, decision, override=None):
    """Pick a GEN3_STYLE_PROFILES key from measurements (or a pinned override)."""
    override = override or {}
    pinned = override.get("style")
    if pinned:
        name = str(pinned).lower()
        if name in GEN3_STYLE_PROFILES:
            return name
    holes = count_interior_transparent_holes(img)
    bays = count_silhouette_bays(img)
    mean_luma = mean_opaque_luma(img)
    decision["interior_holes"] = holes
    decision["silhouette_bays"] = bays
    decision["mean_luma"] = mean_luma

    # Near-black fills: dark_body before plated (Sableye has gaps too).
    if mean_luma < 58 and decision.get("mean_sat", 99) < 70:
        return "dark_body"
    # Low-chroma + pinched limb gaps + mid/dark overall → plated mechanical.
    # Skip bright gowns (Gardevoir) that trip low_chroma via gray dress mids.
    gappy = holes >= 2 or bays >= 12
    if (
        decision.get("low_chroma")
        and gappy
        and mean_luma < 140
        and decision.get("body_sat", 99) < 55
    ):
        return "plated"
    if bays >= 24 and decision.get("body_sat", 99) < 45 and mean_luma < 130:
        return "plated"
    # Chromatic identity accent → organic; muted cream/tan stripe accents
    # → patterned so midtone scrub cannot dissolve the bands.
    if decision.get("clear_accent") and not decision.get("low_chroma"):
        if decision.get("accent_sat", 99) < 100:
            return "patterned"
        return "organic"
    return "default"


def choose_gen3_back_style(img, decision, override=None):
    """Pick a GEN3_BACK_STYLE_PROFILES key (or pinned back_style / style)."""
    override = override or {}
    pinned = override.get("back_style") or override.get("style")
    if pinned:
        name = str(pinned).lower()
        if name in GEN3_BACK_STYLE_PROFILES:
            return name
        # Front-only pin name unknown on backs → fall through to measure.
    holes = count_interior_transparent_holes(img)
    bays = count_silhouette_bays(img)
    mean_luma = mean_opaque_luma(img)
    decision["interior_holes"] = holes
    decision["silhouette_bays"] = bays
    decision["mean_luma"] = mean_luma

    if mean_luma < 58 and decision.get("mean_sat", 99) < 70:
        return "dark_body"
    gappy = holes >= 2 or bays >= 12
    if (
        decision.get("low_chroma")
        and gappy
        and mean_luma < 140
        and decision.get("body_sat", 99) < 55
    ):
        return "plated"
    if bays >= 24 and decision.get("body_sat", 99) < 45 and mean_luma < 130:
        return "plated"
    # Light identity accent on a back → patterned (stripes/patches/tail tip).
    if decision.get("clear_accent") and not decision.get("low_chroma"):
        light = decision.get("accent_is_light")
        if light is None:
            # Cream/tan accents read as patterned; vivid chroma → organic.
            light = decision.get("accent_sat", 99) < 90
        return "patterned" if light else "organic"
    if bays >= 16:
        return "delicate"
    return "default"


def apply_gen3_style_profile(override, style_name):
    """GEN3_UNIFIED_DEFAULTS → style profile → species override (minus style)."""
    opts = dict(GEN3_UNIFIED_DEFAULTS)
    profile = GEN3_STYLE_PROFILES.get(style_name) or {}
    opts.update(profile)
    for key, value in (override or {}).items():
        if key in ("style", "back_style"):
            continue
        opts[key] = value
    opts["style"] = style_name
    return opts


def apply_gen3_back_style_profile(override, style_name):
    """GEN3_BACK_UNIFIED_DEFAULTS → back profile → species override."""
    opts = dict(GEN3_BACK_UNIFIED_DEFAULTS)
    profile = GEN3_BACK_STYLE_PROFILES.get(style_name) or {}
    opts.update(profile)
    for key, value in (override or {}).items():
        if key in ("style", "back_style"):
            continue
        opts[key] = value
    opts["style"] = style_name
    opts["back_style"] = style_name
    return opts

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


def dither_indexed_flats(indexed_img, density=8):
    """Sparse black grit in flat mid fills — Raticate fur, not hatch.

    density: modulo period for grit marks (lower = denser).  Dark birds like
    Murkrow need denser grit so lifted body flats still read in B&W.
    """
    w, h = indexed_img.size
    px = indexed_img.load()
    density = max(2, int(density))
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
            if (x * 5 + y * 11) % density == 0:
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


def extract_crystal_palette(img):
    """Pull the sheet's own ≤4 tones when Crystal art is already indexed.

    Returns light→dark RGB triples, or None if the source is continuous-tone
    (Gen 3 Emerald, etc.) and needs body/accent clustering.
    """
    from collections import Counter

    img = img.convert("RGBA")
    counts = Counter()
    for r, g, b, a in img.getdata():
        if a < 128:
            continue
        # Flat white/off-white matte is keyed out; do not treat as a body tone.
        if r >= 248 and g >= 248 and b >= 248:
            continue
        counts[(r, g, b)] += 1
    if not counts or len(counts) > 6:
        return None

    colors = [c for c, _ in counts.most_common()]
    colors.sort(
        key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
        reverse=True,
    )
    # Ensure SGB endpoints exist, then pin them.
    if not any(r + g + b >= 720 for r, g, b in colors):
        colors.insert(0, (255, 255, 255))
    if not any(r + g + b <= 48 for r, g, b in colors):
        colors.append((0, 0, 0))
    while len(colors) < 4:
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
        mid = ((a[0] + b[0]) // 2, (a[1] + b[1]) // 2, (a[2] + b[2]) // 2)
        if mid not in colors:
            colors.append(mid)
        else:
            colors.append((85, 85, 85))
    colors = colors[:4]
    colors.sort(
        key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2],
        reverse=True,
    )
    colors[0] = (255, 255, 255)
    colors[3] = (0, 0, 0)
    return colors


def _rgb_luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _rgb_sat(c):
    return max(c[0], c[1], c[2]) - min(c[0], c[1], c[2])


def _rgb_hue(c):
    r, g, b = c[0] / 255.0, c[1] / 255.0, c[2] / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d < 1e-6:
        return None
    if mx == r:
        h = (g - b) / d
    elif mx == g:
        h = 2.0 + (b - r) / d
    else:
        h = 4.0 + (r - g) / d
    return (h * 60.0) % 360.0


def _hue_dist(a, b):
    if a is None or b is None:
        return 0.0
    d = abs(a - b)
    return min(d, 360.0 - d)


def extract_emerald_palette(img):
    """Body + accent from continuous-tone Emerald art → 4 SGB colors.

    Still forced to white / mid / mid / black.  Picks the largest chromatic
    body mass, then a real-area accent (silver X, horns) — not 7px eyes.
    Cluster color is the mode of source pixels so Metagross stays steel-blue
    instead of a mean-shifted royal blue.
    """
    import math
    from collections import Counter, defaultdict

    img = img.convert("RGBA")
    pixels = []
    for r, g, b, a in img.getdata():
        if a < 128:
            continue
        if r + g + b < 24:
            continue
        if _rgb_luma((r, g, b)) >= 242:
            continue
        pixels.append((r, g, b))
    if not pixels:
        return [(255, 255, 255), (170, 170, 170), (85, 85, 85), (0, 0, 0)]

    side = max(8, int(len(pixels) ** 0.5) + 1)
    canvas = Image.new("RGB", (side, side), (0, 0, 0))
    canvas.putdata(pixels + [(0, 0, 0)] * (side * side - len(pixels)))
    try:
        quantized = canvas.quantize(colors=10, method=Image.Quantize.MAXCOVERAGE)
    except Exception:
        quantized = canvas.quantize(colors=8)
    raw = quantized.getpalette() or []
    centers = [(raw[i], raw[i + 1], raw[i + 2]) for i in range(0, min(30, len(raw)), 3)]
    if not centers:
        return [(255, 255, 255), (170, 170, 170), (85, 85, 85), (0, 0, 0)]

    buckets = defaultdict(list)
    for p in pixels:
        best_i, best_d = 0, None
        for i, c in enumerate(centers):
            d = (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2
            if best_d is None or d < best_d:
                best_i, best_d = i, d
        buckets[best_i].append(p)

    def cluster_rgb(pts):
        """Most common mid-band source color (true sheet swatch, not a mean)."""
        if not pts:
            return (85, 85, 85)
        # Include lime / cream bodies (luma up to ~210); only drop near-white.
        mid = [p for p in pts if 45 <= _rgb_luma(p) <= 210]
        use = mid if len(mid) >= max(3, len(pts) // 5) else pts
        return Counter(use).most_common(1)[0][0]

    n = len(pixels)
    min_cluster = max(3, int(n * 0.006))
    # Accents need real surface area (Metagross X, Ralts horn) — not 7px eyes.
    min_accent = max(12, int(n * 0.018))
    clusters = []
    for pts in buckets.values():
        if len(pts) < min_cluster:
            continue
        rgb = cluster_rgb(pts)
        if _rgb_luma(rgb) >= 242 or sum(rgb) < 30:
            continue
        clusters.append(
            {
                "rgb": rgb,
                "n": len(pts),
                "sat": _rgb_sat(rgb),
                "luma": _rgb_luma(rgb),
                "hue": _rgb_hue(rgb),
            }
        )
    if not clusters:
        return [(255, 255, 255), (170, 170, 170), (85, 85, 85), (0, 0, 0)]

    chromatic = [c for c in clusters if c["sat"] >= 28]
    pool = chromatic if chromatic else clusters

    def body_score(c):
        return c["n"] * (0.85 + 0.15 * min(c["luma"], 200) / 200.0) * (
            1.0 + 0.15 * min(c["sat"], 100) / 100.0
        )

    body = max(pool, key=body_score)
    # Prefer a vivid identity color when a large dull mass (dress gray) wins
    # on area alone — Ralts hair green vs lavender dress.
    vivid = [c for c in pool if c["sat"] >= 55]
    if vivid:
        top_vivid = max(vivid, key=body_score)
        if top_vivid["n"] >= body["n"] * 0.32 and top_vivid["sat"] >= body["sat"] + 12:
            body = top_vivid

    accent = None
    best = -1.0
    for c in clusters:
        if c is body:
            continue
        if c["n"] < min_accent:
            continue
        # Near-black ink/shadow is not an accent (Metagross had a 16,16,16 blob).
        if c["luma"] < 42 or sum(c["rgb"]) < 70:
            continue
        hd = _hue_dist(body["hue"], c["hue"])
        # Same hue = body highlight/shadow. Neutrals (hue None) are never
        # "same family" — silver X / gray metal must compete as accents.
        same_family = (
            body["hue"] is not None
            and c["hue"] is not None
            and hd < 30
        )
        luma_sep = abs(c["luma"] - body["luma"])
        chroma = c["sat"] / 255.0
        # Area matters as much as chroma — silver X beats 7 red eye pixels.
        score = (
            math.log(c["n"] + 1.0) * 18.0
            + chroma * 55.0
            + hd * 0.3
            + min(luma_sep, 80) * 0.15
            + (12.0 if c["sat"] >= 90 else 0.0)
        )
        if same_family:
            # Darker/lighter shade of the same body hue is shading, not an accent.
            score *= 0.08
        if c["sat"] < 28:
            # Metallic / silver accents (Metagross X) when luma-separated.
            if luma_sep >= 28 and c["n"] >= max(min_accent, int(body["n"] * 0.05)):
                score *= 1.15
            else:
                score *= 0.3
        # Prefer true hue accents over a second body shade.
        if hd >= 40:
            score *= 1.2
        if score > best:
            best, accent = score, c

    if accent is None:
        others = [c for c in clusters if c is not body and c["n"] >= min_accent]
        if not others:
            others = [c for c in clusters if c is not body]
        accent = max(others, key=lambda c: c["n"]) if others else {"rgb": (85, 85, 85)}

    def dist2(a, b):
        return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2

    mids = [body["rgb"], accent["rgb"]]
    if dist2(mids[0], mids[1]) < 40 * 40:
        for c in sorted(clusters, key=lambda x: dist2(x["rgb"], body["rgb"]), reverse=True):
            if c is body or c["n"] < min_accent:
                continue
            if dist2(c["rgb"], body["rgb"]) >= 40 * 40:
                mids[1] = c["rgb"]
                break
    mids.sort(key=_rgb_luma, reverse=True)
    return [(255, 255, 255), mids[0], mids[1], (0, 0, 0)]


def opaque_saturation_stats(img):
    """Return (mean_sat, p90_sat, n) over opaque source pixels."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    sats = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            sats.append(max(r, g, b) - min(r, g, b))
    if not sats:
        return 0.0, 0.0, 0
    sats.sort()
    n = len(sats)
    mean_sat = sum(sats) / n
    p90_sat = float(sats[min(n - 1, int(0.9 * (n - 1)))])
    return mean_sat, p90_sat, n


def mean_opaque_saturation(img):
    """Average chroma (max-min channel) over opaque source pixels."""
    mean_sat, _p90, _n = opaque_saturation_stats(img)
    return mean_sat


def palette_mid_luma_span(colors):
    """Luma gap between the two mid palette slots (1 and 2)."""
    if not colors or len(colors) < 3:
        return 0.0
    return abs(_rgb_luma(colors[1]) - _rgb_luma(colors[2]))


def analyze_sprite_decisions(img, colors):
    """Stage 0 — measure source art; return shade_mode + contrast flag.

    Decision record drives every Gen 3 pipeline choice downstream.  Overrides
    may still pin shade_mode; this is the automatic baseline.
    """
    mean_sat, p90_sat, _n = opaque_saturation_stats(img)
    body_sat = _rgb_sat(colors[1]) if colors and len(colors) > 1 else 0.0
    accent_sat = _rgb_sat(colors[2]) if colors and len(colors) > 2 else 0.0
    mid_span = palette_mid_luma_span(colors)
    clear_accent = accent_sat >= CLEAR_ACCENT_SAT

    # Desaturated mass, or gray/silver body mid (Metagross: blue pulls mean
    # up but slot-1 silver is still low-chroma structure).
    low_chroma = mean_sat < LOW_CHROMA_MEAN_SAT or body_sat < LOW_BODY_MID_SAT

    # Clear identity accent (red belly, yellow mane, gem) on a chromatic body
    # → nearest.  Gray/silver body + blue accent (Metagross) stays body_mid;
    # its sat≥80 gate already protects the accent.
    if clear_accent and body_sat >= LOW_BODY_MID_SAT:
        low_chroma = False

    # Edge case: large gray body + tiny vibrant accents can drag the mean
    # down.  If p90 shows a real high-sat cluster AND the body mid itself
    # is chromatic, prefer nearest so accents stay hue-matched.
    if (
        p90_sat >= HIGH_SAT_P90
        and body_sat >= LOW_BODY_MID_SAT
        and mean_sat >= 35.0
    ):
        low_chroma = False

    # Stretch only when the palette is truly collapsed *and* low-chroma —
    # stretching a saturated accent palette desaturates identity colors.
    needs_stretch = bool(low_chroma and mid_span < PALETTE_CONTRAST_MIN_MID_SPAN)

    shade_mode = "body_mid" if low_chroma else "nearest"
    # Light mid + darker fill (Duskull robe, Spoink body, Slaking fur):
    # body_mid's luma≥90→shade1 paints the dark mass with the cream/pearl
    # slot so Advanced looks whitewashed.  Prefer hue-nearest when the sheet
    # is overall dark-ish and slot 2 is clearly the darker structural fill.
    # Bright gowns / ice / birds (Gardevoir, Absol, Regice) keep body_mid.
    if (
        low_chroma
        and colors
        and len(colors) >= 3
        and _rgb_luma(colors[2]) + 24 < _rgb_luma(colors[1])
        and mean_opaque_luma(img) < 150
    ):
        shade_mode = "nearest"

    return {
        "shade_mode": shade_mode,
        "needs_contrast_stretch": needs_stretch,
        "low_chroma": low_chroma,
        "clear_accent": clear_accent,
        "mean_sat": mean_sat,
        "p90_sat": p90_sat,
        "body_sat": body_sat,
        "accent_sat": accent_sat,
        "mid_luma_span": mid_span,
    }


def stretch_palette_contrast(colors, min_span=110):
    """Widen midtone luma gaps when the 4-color pick is too clustered.

    Brushed-metal / flat Emerald art often yields four colors sitting in a
    narrow luma band — shade mapping then collapses to 2–3 effective tones.
    Keep endpoints pinned to white/black; redistribute slots 1–2 across a
    healthier span.  No-ops when the palette already has enough contrast.

    Prefer calling this only when Stage 0 set needs_contrast_stretch, and
    ideally after downscale so majority-vote shrink sees natural gradients.
    """
    if not colors or len(colors) < 4:
        return colors
    cols = [tuple(c[:3]) for c in colors[:4]]
    cols[0] = (255, 255, 255)
    cols[3] = (0, 0, 0)
    lumas = [_rgb_luma(c) for c in cols]
    # Span between the two mids (ignore forced W/B which always span ~255).
    mid_span = abs(lumas[1] - lumas[2])
    full_span = lumas[0] - lumas[3]
    if mid_span >= min_span * 0.45 and full_span >= min_span:
        return cols

    # Target ladder: white → light mid → dark mid → black.
    targets = [255.0, 170.0, 85.0, 0.0]
    out = [cols[0], None, None, cols[3]]
    for i in (1, 2):
        r, g, b = cols[i]
        L = lumas[i] if lumas[i] > 1 else 1.0
        # Preserve hue/chroma; scale toward target luma.
        scale = targets[i] / L
        # Blend so we don't nuke accent chroma entirely.
        nr = int(max(0, min(255, r * scale * 0.65 + targets[i] * 0.35)))
        ng = int(max(0, min(255, g * scale * 0.65 + targets[i] * 0.35)))
        nb = int(max(0, min(255, b * scale * 0.65 + targets[i] * 0.35)))
        out[i] = (nr, ng, nb)
    # Ensure slot1 is lighter than slot2 after stretch.
    if _rgb_luma(out[1]) < _rgb_luma(out[2]):
        out[1], out[2] = out[2], out[1]
    return out


def extract_species_palette(img, stretch=False):
    """4 RGB triples (lightest first) from opaque pixels — Gen 1 SGB shape.

    Crystal sheets: use the indexed tones as-is.
    Emerald sheets: body + accent clustering (not raw MEDIANCUT).

    stretch=False by default so Stage 0 can measure the natural midtone
    span; Gen 3 applies stretch_palette_contrast only when flagged, and
    after downscale.  Pass stretch=True for callers that want the old
    eager-widen behavior.
    """
    crystal = extract_crystal_palette(img)
    colors = crystal if crystal else extract_emerald_palette(img)
    if stretch:
        return stretch_palette_contrast(colors)
    return [tuple(c[:3]) for c in colors[:4]]


def nearest_palette_index(r, g, b, colors, hue_aware=False):
    best_i, best_d = 0, None
    pix = (r, g, b)
    pix_sat = _rgb_sat(pix)
    pix_luma = _rgb_luma(pix)
    pix_hue = _rgb_hue(pix) if pix_sat >= 28 else None

    # Bright yellow eyes → white sclera.  Lime body is RGB-near yellow so
    # raw nearest collapses the eye into green.  Keep this NARROW (true
    # yellow only) — orange belly-adjacent rim pixels must stay off white
    # or the whole cheek becomes a white blob.  Skip when accent itself is
    # yellow (Ampharos) so the accent slot still receives those pixels.
    if (
        hue_aware
        and pix_sat >= 80
        and pix_luma >= 175
        and pix_hue is not None
        and 32 <= pix_hue <= 55
        and len(colors) >= 3
    ):
        accent = colors[2]
        accent_sat = _rgb_sat(accent)
        accent_hue = _rgb_hue(accent) if accent_sat >= 28 else None
        accent_is_yellow = accent_hue is not None and 28 <= accent_hue <= 70
        if not accent_is_yellow:
            return 0

    for i, (cr, cg, cb) in enumerate(colors):
        d = (r - cr) * (r - cr) + (g - cg) * (g - cg) + (b - cb) * (b - cb)
        if hue_aware and pix_sat >= 28 and pix_luma >= 50 and i == 3:
            # Chromatic mid-tones must not collapse into outline ink just
            # because black is an un-penalized RGB neighbor.
            d += 90 * 90
        if hue_aware and pix_sat >= 28 and pix_luma < 200 and i == 0:
            # Chromatic body/shadow must not flee to white either — teal
            # Treecko-tail shadows are hue-far from lime body, so without
            # this the hue gate below dumps them on white and the tail
            # grows a highlight blob.
            d += 100 * 100
        # Chromatic pixels must stay on the matching hue family — otherwise
        # Treecko olive shadows snap to belly-red by raw RGB distance.
        if hue_aware and pix_hue is not None and i not in (0, 3):
            cs = _rgb_sat((cr, cg, cb))
            ch = _rgb_hue((cr, cg, cb))
            if cs >= 28 and ch is not None:
                hd = _hue_dist(pix_hue, ch)
                if hd > 55:
                    # Soft penalty inside the same broad green/blue family
                    # (teal shadow vs lime body); hard penalty across families
                    # (olive vs belly-red).
                    same_green = 70 <= pix_hue <= 170 and 70 <= ch <= 170
                    same_blue = 170 <= pix_hue <= 260 and 170 <= ch <= 260
                    if same_green or same_blue:
                        d += int((hd * 2) ** 2)
                    else:
                        d += int((hd * 5) ** 2)
        if best_d is None or d < best_d:
            best_i, best_d = i, d
    return best_i


def shade_for_pixel(r, g, b, colors, mode=None):
    """Map a source pixel to a 0..3 shade index.

    Explicit modes only — there is no silent 3-band fallback:

      luma       — classic v1.0.0 brightness bands (Gen 3 backs).
      body_mid   — 4-band luma ramp with high-chroma accent gate.
      nearest    — hue-aware nearest palette slot; for normal_chroma.
      keep_chroma — Gen 2 dark-bird escape hatch (Murkrow).

    Unknown / None mode resolves to nearest so nothing falls through a
    gap-having default ramp.
    """
    if r + g + b < 24:
        return 3
    sat = max(r, g, b) - min(r, g, b)
    luma = 0.299 * r + 0.587 * g + 0.114 * b
    if mode == "luma":
        # Exact v1.0.0 thresholds.
        if luma > 192:
            return 0
        if luma > 128:
            return 1
        if luma > 64:
            return 2
        return 3
    if mode == "body_mid":
        # Keep near-black as ink; everything else stays on body/accent slots so
        # dark purple/blue mons do not collapse into a solid silhouette.
        if r + g + b < 30:
            return 3
        if sat >= 80 and luma >= 90:
            idx = nearest_palette_index(r, g, b, colors)
            return 2 if idx == 3 else idx
        if luma >= 170:
            return 0
        if luma >= 90:
            return 1
        return 2
    if mode == "keep_chroma":
        # Crystal-era dark birds (Murkrow): body is chromatic navy, not ink.
        # Never force saturated darks to black — that erases hat/wing dither.
        # Slot 1 is body mid; slot 2 is the yellow/red accent.
        if r + g + b < 28:
            return 3
        if sat >= 28:
            idx = nearest_palette_index(r, g, b, colors)
            if idx == 3 and r + g + b >= 28:
                return 1
            return idx
        if luma >= 175 or min(r, g, b) >= 170:
            return 0
        if luma >= 110:
            return 1
        return 1
    # nearest (default): hue-aware snap to the species' 4 SGB colors.
    return nearest_palette_index(r, g, b, colors, hue_aware=True)


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



# Gen 1 battle fronts are 40 / 48 / 56 px (frontSize 5 / 6 / 7 tiles).
# Kanto Reforged sprites used to be force-fitted to 56x56, so small mons like
# Aron drew as large as Onix. Map dex height onto those three buckets so
# proportions roughly match Gen 1 (Geodude-sized rocks stay small).


def ensure_silhouette_outline(img, protect_white=True):
    """Hard 1px black rim on every exterior opaque pixel.

    Unlike ensure_selective_outline, lit chromatic tops are NOT left soft —
    Gen 3 v1 bakes otherwise leave Treecko's crown / arm tops open against
    the white battle BG.
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
            if not (
                not opaque(x - 1, y)
                or not opaque(x + 1, y)
                or not opaque(x, y - 1)
                or not opaque(x, y + 1)
            ):
                continue
            if protect_white and min(src[x, y][0], src[x, y][1], src[x, y][2]) >= 230:
                continue
            dst[x, y] = black
    return out


def demote_small_midtone_islands(indexed_img, mid_index=3, body_index=2):
    """Keep only the largest mid-shade blob; fold the rest into body.

    Indexed PNG: 0=transparent, 1..4 = white→black.  When cheeks and belly
    share shade-2, Advanced paints both with the accent — keep the belly.
    """
    from collections import deque

    w, h = indexed_img.size
    px = indexed_img.load()
    seen = [[False] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if seen[y][x] or px[x, y] != mid_index:
                continue
            q = deque([(x, y)])
            seen[y][x] = True
            cells = []
            while q:
                cx, cy = q.popleft()
                cells.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if (
                        0 <= nx < w
                        and 0 <= ny < h
                        and not seen[ny][nx]
                        and px[nx, ny] == mid_index
                    ):
                        seen[ny][nx] = True
                        q.append((nx, ny))
            comps.append(cells)
    if len(comps) <= 1:
        return indexed_img
    comps.sort(key=len, reverse=True)
    for cells in comps[1:]:
        for x, y in cells:
            px[x, y] = body_index
    return indexed_img


def ink_treecko_face_guides(indexed_img):
    """Add jaw / mouth / cheek creases under Treecko's eye whites.

    Runs on the indexed PNG (1=white … 4=black).  Applies a short stroke
    under every substantial eye blob — the near-eye jaw row is often already
    ink from structure_creases, so the far eye still needs the pass.
    """
    from collections import deque

    w, h = indexed_img.size
    px = indexed_img.load()
    WHITE, BODY, INK = 1, 2, 4

    seen = [[False] * w for _ in range(h)]
    eyes = []
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0][x0] or px[x0, y0] != WHITE:
                continue
            blob = []
            q = deque([(x0, y0)])
            seen[y0][x0] = True
            while q:
                x, y = q.popleft()
                blob.append((x, y))
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if (
                        0 <= nx < w
                        and 0 <= ny < h
                        and not seen[ny][nx]
                        and px[nx, ny] == WHITE
                    ):
                        seen[ny][nx] = True
                        q.append((nx, ny))
            if len(blob) >= 2:
                eyes.append(blob)
    if not eyes:
        return indexed_img

    def set_ink(x, y):
        if 0 <= x < w and 0 <= y < h and px[x, y] == BODY:
            px[x, y] = INK

    eyes.sort(key=len, reverse=True)
    for blob in eyes:
        if len(blob) < 4:
            # Tiny far-eye sliver: just keep a 1px mark, no long jaw.
            continue
        xs = [p[0] for p in blob]
        ys = [p[1] for p in blob]
        x0, x1 = min(xs), max(xs)
        y_bot = max(ys)
        jaw_y = y_bot + 2
        if jaw_y >= h:
            continue
        # Jaw under the eye, extended slightly toward the snout ( +x ).
        for x in range(max(0, x0 - 1), min(w, x1 + 4)):
            set_ink(x, jaw_y)
        mid = (x0 + x1) // 2
        mouth_y = jaw_y + 1
        if mouth_y < h:
            for x in range(mid - 1, mid + 3):
                set_ink(x, mouth_y)
        # Cheek crease behind the eye.
        for y in range(y_bot, min(h, y_bot + 4)):
            set_ink(x0 - 1, y)
            set_ink(x0 - 2, y)

    return indexed_img


def accent_slot_coverage(img, colors):
    """Fraction of opaque pixels nearest the accent slot (colors[2]).

    Used on backs: front-curated palettes often put a belly/mane accent in
    slot 2 that never appears on the rear view.  Luma-band midtones then
    become that accent in Advanced (Treecko shadows → pink).
    """
    if not colors or len(colors) < 3:
        return 0.0
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    accent = tuple(colors[2][:3])
    accent_sat = max(accent) - min(accent)
    accent_n = 0
    opaque_n = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            opaque_n += 1
            if nearest_palette_index(r, g, b, colors, hue_aware=True) != 2:
                continue
            # Require the pixel to actually look like the accent (not a
            # dark body shade that merely lost a nearest-slot tie).
            sat = max(r, g, b) - min(r, g, b)
            if accent_sat >= 40 and sat < max(28, accent_sat // 3):
                continue
            accent_n += 1
    if opaque_n == 0:
        return 0.0
    return accent_n / float(opaque_n)


def accent_missing_on_view(view_img, colors, front_img=None):
    """True when slot-2 accent is a front-only color for this view."""
    view_c = accent_slot_coverage(view_img, colors)
    if view_c >= 0.05:
        return False
    if front_img is None:
        return view_c < 0.05
    front_c = accent_slot_coverage(front_img, colors)
    # Front has a real accent; this view barely does.
    if front_c >= 0.05 and view_c < front_c * 0.35:
        return True
    return view_c < 0.04


def process_sprite_v1(
    input_path,
    output_path,
    target_size,
    palette_override=None,
    shade_mode="nearest",
    demote_small_mids=False,
    outline="full",
    close_gap=1,
    structure_creases=False,
    face_guides=False,
    crease_dark_ratio=0.75,
    crease_valley_delta=16,
    crease_min_contrast=24,
    avoid_accent_slot=False,
    guard_edge_white=False,
):
    """v1.0.0 geometry (nearest scale) + hue-aware palette shade assignment.

    Layout matches original v1.0.0 (crop → NEAREST fit → center).  Shades are
    chosen by snapping to the species palette (not raw luma).  close_gap fills
    thin silhouette bites NEAREST often opens (Metagross body↔leg joins).

    avoid_accent_slot: when the shared Advanced palette's accent (slot 2) is
    absent from this view, never write DMG shade 2 — those pixels would paint
    as the wrong hue (Treecko back midtones → belly red).  Midtones become a
    body↔ink dither instead of a flat fill.

    guard_edge_white: demote silhouette-edge "white" to body so AA glitter
    does not read as stray highlights.
    """
    try:
        img = key_out_flat_background(Image.open(input_path))

        if palette_override:
            display_colors = [tuple(c) for c in palette_override[:4]]
            while len(display_colors) < 4:
                display_colors.append((0, 0, 0))
            display_colors[0] = (255, 255, 255)
            display_colors[3] = (0, 0, 0)
        else:
            display_colors = extract_species_palette(img)

        # Crop transparency border (v1.0.0 — no 1px halo).
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)

        # Scale nearest neighbor to preserve sharp pixel art edges
        w, h = img.size
        ratio = min(target_size[0] / w, target_size[1] / h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        if new_w < 1:
            new_w = 1
        if new_h < 1:
            new_h = 1
        img_resized = img.resize((new_w, new_h), Image.NEAREST)

        # Center in target frame
        new_img = Image.new("RGBA", target_size, (255, 255, 255, 0))
        x = (target_size[0] - new_w) // 2
        y = (target_size[1] - new_h) // 2
        new_img.paste(img_resized, (x, y))

        # Rejoin thin bridges NEAREST dropped (body↔limb bites).
        if close_gap and close_gap > 0:
            new_img = close_small_holes(new_img, max_gap=int(close_gap))

        # Optional source-luma creases (jaw / folds) before the rim pass.
        if structure_creases:
            src_resized = new_img.copy()
            snapped = quantize_rgba_to_palette(new_img, display_colors)
            new_img = ink_structure_creases(
                snapped,
                src_resized,
                display_colors,
                dark_ratio=float(crease_dark_ratio),
                min_contrast=int(crease_min_contrast),
                valley_delta=int(crease_valley_delta),
            )

        # Outer rim before shade map so ink lands on DMG shade 3.
        if outline == "full":
            new_img = ensure_silhouette_outline(new_img)
        elif outline == "selective":
            new_img = ensure_selective_outline(new_img)
        elif outline == "soft":
            new_img = ensure_contrast_outline(new_img)

        # Palette-aware shade map (hue gate keeps body/accent families apart).
        px = new_img.load()
        tw, th = target_size
        indexed_img = Image.new("P", target_size, 0)

        def touches_empty(x, y):
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if not (0 <= nx < tw and 0 <= ny < th) or px[nx, ny][3] < 128:
                    return True
            return False

        for py in range(th):
            for px_x in range(tw):
                r, g, b, a = px[px_x, py]
                if a < 128:
                    indexed_img.putpixel((px_x, py), 0)
                elif r + g + b < 24:
                    indexed_img.putpixel((px_x, py), 4)
                else:
                    shade = shade_for_pixel(
                        r, g, b, display_colors, mode=shade_mode
                    )
                    luma = 0.299 * r + 0.587 * g + 0.114 * b
                    # Edge AA often reads as "white highlight" and looks like
                    # glitter on lime bodies — keep white for interior only.
                    if shade == 0 and (guard_edge_white or avoid_accent_slot):
                        if touches_empty(px_x, py) or luma < 220:
                            shade = 1
                    # Shared Advanced palette: shade 2 == accent slot.  If this
                    # view has no accent, fake a mid with body↔ink dither so
                    # the body is not a flat slab and we never paint pink.
                    if avoid_accent_slot and shade == 2:
                        prefer_ink = luma < 100
                        if ((px_x + py) & 1) == (0 if prefer_ink else 1):
                            shade = 3
                        else:
                            shade = 1
                    indexed_img.putpixel((px_x, py), shade + 1)

        if demote_small_mids:
            indexed_img = demote_small_midtone_islands(indexed_img)
        if face_guides:
            indexed_img = ink_treecko_face_guides(indexed_img)

        palette = [
            255, 255, 255,  # 0: Transparent
            255, 255, 255,  # 1: White
            170, 170, 170,  # 2: Light Gray
            85, 85, 85,     # 3: Dark Gray
            0, 0, 0,        # 4: Black
        ]
        palette += [0] * (768 - len(palette))
        indexed_img.putpalette(palette)

        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
        indexed_img.save(output_path, transparency=0)
        return True, display_colors
    except Exception as e:
        print(f"Failed processing sprite {input_path}: {e}")
        return False, None



def resolve_species_palette(input_path, override=None, prefer_front=False):
    """Pick the 4-color Advanced palette for a sprite bake.

    Order: species override → optional front-sheet extract (backs) →
    extract from this image.
    """
    override = override or {}
    if override.get("palette"):
        return _normalize_palette(override["palette"])
    if prefer_front and input_path and "_back." in str(input_path):
        front_path = str(input_path).replace("_back.", "_front.")
        if os.path.exists(front_path):
            try:
                front_img = key_out_flat_background(Image.open(front_path))
                return _normalize_palette(
                    extract_species_palette(front_img, stretch=True)
                )
            except Exception:
                pass
    img = key_out_flat_background(Image.open(input_path))
    return _normalize_palette(extract_species_palette(img, stretch=True))


def process_sprite(input_path, output_path, target_size, species_id=None, dex=None):
    """Build a Gen 1-style 4-shade sprite.

    Returns (ok, palette) where palette is 4 RGB triples lightest-first, or
    (False, None) on failure.  Callers register `palette` under the species
    id so Advanced color mode stops falling through to MEWMON.

    Gen 3 fronts → measurement-driven unified pipeline + style profiles.
    Gen 3 backs  → v1.0.0 NEAREST geometry + luma bands (was readable);
                   palette still from override / front / extract for Advanced.
    Gen 2        → Crystal-faithful quantize path (unchanged).
    Else         → v1.0.0 geometry path.
    """
    if dex is None:
        dex = dex_from_sprite_path(input_path)
    override = sprite_override(species_id)
    is_back = target_size == (32, 32)
    if is_gen3_dex(dex):
        if is_back:
            # v1.0.0 backs were good — keep that geometry.  Palette still
            # comes from override / front so Advanced matches the species.
            # If the accent slot is absent on this rear view, scrub shade 2
            # so midtones do not paint as belly/mane color (Treecko pink).
            palette = resolve_species_palette(
                input_path, override, prefer_front=True
            )
            src = key_out_flat_background(Image.open(input_path))
            front_img = None
            if "_back." in str(input_path):
                fp = str(input_path).replace("_back.", "_front.")
                if os.path.exists(fp):
                    try:
                        front_img = key_out_flat_background(Image.open(fp))
                    except Exception:
                        front_img = None
            avoid_accent = accent_missing_on_view(src, palette, front_img)
            return process_sprite_v1(
                input_path,
                output_path,
                target_size,
                palette_override=palette,
                shade_mode="luma",
                outline="none",
                close_gap=0,
                avoid_accent_slot=avoid_accent,
                guard_edge_white=True,
            )
        opts = resolve_sprite_opts(species_id=species_id, dex=dex, input_path=input_path)
        return _process_sprite_gen3(
            input_path, output_path, target_size, opts, override=override
        )
    if is_gen2_dex(dex):
        # White-shell backs (Forretress): v1 NEAREST keeps the body; the
        # faithful majority-vote path shrinks it to a handful of pixels.
        if is_back and override.get("back_v1"):
            return process_sprite_v1(
                input_path,
                output_path,
                target_size,
                palette_override=override.get("palette"),
                shade_mode=override.get("shade", "nearest"),
                outline=override.get("outline", "soft"),
                close_gap=int(override["close_gap"]) if override.get("close_gap") is not None else 1,
            )
        opts = resolve_sprite_opts(species_id=species_id, dex=dex, input_path=input_path)
        return _process_sprite_faithful(
            input_path, output_path, target_size, opts, override=override
        )
    return process_sprite_v1(
        input_path,
        output_path,
        target_size,
        palette_override=override.get("palette"),
        shade_mode=override.get("shade", "nearest"),
        demote_small_mids=bool(override.get("demote_small_mids")),
        outline=override.get("outline", "full"),
        close_gap=int(override["close_gap"]) if override.get("close_gap") is not None else 1,
        structure_creases=bool(override.get("structure_creases")),
        face_guides=bool(override.get("face_guides")),
        crease_dark_ratio=float(override.get("crease_dark_ratio", 0.75)),
        crease_valley_delta=int(override.get("crease_valley_delta", 16)),
        crease_min_contrast=int(override.get("crease_min_contrast", 24)),
    )


def _process_sprite_faithful(input_path, output_path, target_size, opts, override=None):
    """Gen 2 Crystal-faithful quantize path (shared helper body)."""
    override = override or {}
    try:
        img = key_out_flat_background(Image.open(input_path))
        quantize_first = bool(opts.get("quantize_first", False))
        shade_mode = opts.get("shade", "nearest")

        # Crop transparency, but keep a 1px halo so tight silhouettes are
        # not shaved by getbbox before the dilate / resize.
        # Faithful Gen2 path: SKIP tight crop when quantize_first — Crystal
        # sheets are already square; cropping then scaling makes a
        # non-integer ratio that majority-votes tiny features away.
        # Gen 3 backs opt back in via tight_crop (padded Emerald sheets).
        is_back = target_size == (32, 32)
        if (not quantize_first) or opts.get("tight_crop"):
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
        if opts.get("palette"):
            species_colors = [tuple(c) for c in opts["palette"][:4]]
            while len(species_colors) < 4:
                species_colors.append((0, 0, 0))
            species_colors[0] = (255, 255, 255)
            species_colors[3] = (0, 0, 0)
        elif opts.get("prefer_front_palette") and is_back:
            # Emerald backs are often flatter / more shaded than fronts —
            # auto-extract can collapse cream stripes into mud.  Borrow the
            # front sheet's colors when the cache has one.
            species_colors = None
            front_path = None
            if input_path and "_back." in str(input_path):
                front_path = str(input_path).replace("_back.", "_front.")
            if front_path and os.path.exists(front_path):
                try:
                    front_img = key_out_flat_background(Image.open(front_path))
                    species_colors = extract_species_palette(front_img, stretch=True)
                except Exception:
                    species_colors = None
            if not species_colors:
                species_colors = extract_species_palette(img, stretch=True)
        else:
            species_colors = extract_species_palette(img, stretch=True)

        w, h = img.size
        # Backs may render taller than 32 then shift down so feet clip off.
        clip = BACK_BOTTOM_CLIP if is_back else 0
        fit_w = target_size[0]
        fit_h = target_size[1] + clip

        do_dilate = opts.get("dilate", True)
        do_stem = opts.get("stem", True)
        do_depth = opts.get("depth", True)
        do_seal = opts.get("seal", True)
        outline_mode = opts.get("outline", "full")
        outline_luma = int(opts.get("outline_luma", 110))
        orphan_min = int(opts.get("orphan_min", 4))
        # 0 = skip hole-fill (keeps Metagross leg gaps / intentional bites).
        close_gap = opts.get("close_gap")
        if close_gap is None:
            close_gap = 0 if quantize_first else (2 if not is_back else 1)
        close_gap = int(close_gap)

        # Gen 2 detail path: lock to 4 colors at full res BEFORE shrink so
        # eyes / horns / tiny marks are already clean slots the majority vote
        # can preserve (with white/black boost).  Scrub AA accent freckles,
        # then restore same-hue shadow creases (jaw, limb joins) from source.
        src_for_creases = img.copy() if quantize_first else None
        if quantize_first:
            img = quantize_rgba_to_palette(img, species_colors)
            img = clean_quantized_freckles(
                img,
                species_colors,
                min_accent=int(opts.get("min_accent", 14)),
            )
            img = clean_midtone_bleed(
                img,
                species_colors,
                min_blob=int(opts.get("midtone_min_blob", 10)),
            )
            if opts.get("structure_creases", False):
                img = ink_structure_creases(
                    img,
                    src_for_creases,
                    species_colors,
                    dark_ratio=float(opts.get("crease_dark_ratio", 0.70)),
                    min_contrast=int(opts.get("crease_min_contrast", 26)),
                    valley_delta=int(opts.get("crease_valley_delta", 20)),
                )
            if opts.get("ink_midtone_seams", False):
                img = ink_midtone_seams(img, species_colors)
            # Solidify eyes at FULL res before shrink — yellow→white sclera
            # is only a few px and majority-vote otherwise leaves W·W gaps.
            img = ensure_white_eye_pupils(img, species_colors)
            w, h = img.size

        # Light pre-dilate — fronts when dilate=True; Gen3 backs when
        # back_dilate so thin limbs survive ~3× shrink after tight crop.
        want_dilate = bool(do_dilate) if not is_back else bool(
            opts.get("back_dilate") or do_dilate
        )
        if (w > fit_w or h > fit_h) and want_dilate:
            img = dilate_opaque(img)
            img = close_small_holes(img, max_gap=1)
            w, h = img.size

        ratio = min(fit_w / w, fit_h / h)
        new_w, new_h = max(1, int(round(w * ratio))), max(1, int(round(h * ratio)))
        new_w = min(new_w, fit_w)
        new_h = min(new_h, fit_h)
        # Majority-block shrink keeps folds; NEAREST alone drops them.
        # Gen3 backs: boost the light mid (cream stripes, pale belly) so
        # majority vote does not bury it under body brown/green.
        boost = None
        if is_back and quantize_first and len(species_colors) >= 2:
            boost = [species_colors[1]]
        img_resized = resize_pixel_art(
            img,
            new_w,
            new_h,
            preserve_features=quantize_first,
            boost_rgbs=boost,
        )
        if close_gap > 0:
            img_resized = close_small_holes(img_resized, max_gap=close_gap)
        if quantize_first:
            img_resized = clean_midtone_bleed(
                img_resized,
                species_colors,
                min_blob=int(opts.get("midtone_min_blob_small", 6)),
            )
            if opts.get("bridge_cracks", True):
                img_resized = bridge_same_tone_cracks(img_resized, species_colors)
        if not is_back and do_stem:
            img_resized = thicken_narrow_stems(img_resized, min_width=7)
            if do_seal:
                img_resized = seal_outline_breaks(img_resized)

        # Backs: shift down so the bottom `clip` rows fall off the canvas.
        new_img = Image.new("RGBA", target_size, (255, 255, 255, 0))
        x = (target_size[0] - new_w) // 2
        if is_back:
            y = target_size[1] - new_h + clip
        else:
            y = (target_size[1] - new_h) // 2
        new_img.paste(img_resized, (x, y), img_resized)
        if close_gap > 0:
            new_img = close_small_holes(new_img, max_gap=close_gap)
        if quantize_first:
            new_img = clean_midtone_bleed(
                new_img,
                species_colors,
                min_blob=int(opts.get("midtone_min_blob_small", 6)),
            )
            if opts.get("bridge_cracks", True):
                new_img = bridge_same_tone_cracks(new_img, species_colors)
            if opts.get("ink_midtone_seams", False):
                new_img = ink_midtone_seams(new_img, species_colors)
        if not is_back and do_stem:
            if do_seal:
                new_img = seal_outline_breaks(new_img)
            new_img = thicken_narrow_stems(new_img, min_width=7)
        # Venusaur-style volume: interior black crevices + white top hits +
        # stipple.  Stronger on backs, which otherwise read as flat slabs.
        if do_depth:
            new_img = gen1_depth_pass(new_img, strong=is_back)
        if opts.get("lift_darks"):
            lift_rgb = (56, 56, 88)
            if opts.get("lift_rgb") and len(opts["lift_rgb"]) >= 3:
                lift_rgb = tuple(int(v) for v in opts["lift_rgb"][:3])
            elif opts.get("palette") and len(opts["palette"]) >= 2:
                # Default: lift toward palette shade-1 body (index 1).
                # Dark birds that put accent in slot 1 should set lift_rgb.
                slot = int(opts.get("lift_palette_slot", 1))
                slot = max(1, min(2, slot))
                lift_rgb = tuple(int(v) for v in opts["palette"][slot][:3])
            new_img = lift_near_black_body(
                new_img,
                lift_rgb=lift_rgb,
                preserve_chroma_dither=bool(opts.get("preserve_dither", False)),
            )
            if opts.get("thin_outline"):
                new_img = thin_double_outline(new_img, body_rgb=lift_rgb)
        new_img = drop_orphan_pixels(new_img, min_blob=orphan_min)
        if do_seal:
            new_img = seal_outline_breaks(new_img)
        if outline_mode == "full":
            new_img = ensure_selective_outline(new_img)
        elif outline_mode == "soft":
            new_img = ensure_contrast_outline(new_img, luma_floor=outline_luma)
        # outline_mode == "none": keep sealed silhouette only

        # Mild stair chamfer on the rim (after outline so we round the final
        # black edge, not pre-outline body stairs).
        if opts.get("smooth_stairs", False):
            new_img = smooth_silhouette_stairs(new_img, ink_only=True)

        # Last: punch pupils into empty white eye blobs (after every pass that
        # might otherwise swallow the 1px ink).
        if quantize_first:
            new_img = ensure_white_eye_pupils(new_img, species_colors)

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
                    shade = shade_for_pixel(r, g, b, species_colors, mode=shade_mode)
                    indexed_img.putpixel((px_x, py), shade + 1)

        if opts.get("clean_accent"):
            # Yellow/red accents land on shade 2 → PNG index 3 when body is shade 1.
            accent_png = int(opts.get("accent_index", 3))
            indexed_img = clean_indexed_accent_ink(
                indexed_img, accent_index=accent_png, ink_index=4
            )

        # Sparse grit: backs default on; Gen 2 faithful sets flat_dither False.
        do_flat = opts.get("flat_dither")
        if do_flat is None:
            do_flat = is_back
        if do_flat:
            indexed_img = dither_indexed_flats(
                indexed_img, density=int(opts.get("flat_dither_density", 8))
            )

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


def _normalize_palette(colors):
    cols = [tuple(c[:3]) for c in (colors or [])[:4]]
    while len(cols) < 4:
        cols.append((0, 0, 0))
    cols[0] = (255, 255, 255)
    cols[3] = (0, 0, 0)
    return cols


def _process_sprite_gen3(input_path, output_path, target_size, opts, override=None):
    """Gen 3 unified pipeline — Stage 0 analysis drives shade + stretch.

    Stages:
      0 Analyze   — palette + sat/luma metrics → decision record + style
      1 Prep      — halo crop, quantize, freckle/crease/eye cleanup
      2 Pre-dilate— fronts only when shrink is steep; backs per profile
      3 Shrink    — majority-vote color + OR-pool ink mask
      4 Compose   — paste, post-clean, depth, lift, outline
      5 Shade     — body_mid (low_chroma) or nearest (normal);
                    composite preserved ink as forced black
      6 Finish    — eye re-punch, accent clean, dither, indexed PNG
    """
    override = override or {}
    is_back = target_size == (32, 32)
    try:
        img = key_out_flat_background(Image.open(input_path))

        # ---- Stage 0: Analyze ------------------------------------------------
        # Seed colors for measurement; final palette may prefer the front sheet
        # on backs so Advanced mode stays consistent with belly/stripe identity.
        if override.get("palette"):
            measure_colors = _normalize_palette(override["palette"])
        else:
            measure_colors = _normalize_palette(
                extract_species_palette(img, stretch=False)
            )

        decision = analyze_sprite_decisions(img, measure_colors)
        if is_back:
            style_name = choose_gen3_back_style(img, decision, override)
            opts = apply_gen3_back_style_profile(override, style_name)
        else:
            style_name = choose_gen3_style(img, decision, override)
            opts = apply_gen3_style_profile(override, style_name)

        if opts.get("palette"):
            species_colors = _normalize_palette(opts["palette"])
        elif is_back and opts.get("prefer_front_palette"):
            species_colors = None
            front_path = None
            if input_path and "_back." in str(input_path):
                front_path = str(input_path).replace("_back.", "_front.")
            if front_path and os.path.exists(front_path):
                try:
                    front_img = key_out_flat_background(Image.open(front_path))
                    species_colors = _normalize_palette(
                        extract_species_palette(front_img, stretch=True)
                    )
                except Exception:
                    species_colors = None
            if not species_colors:
                species_colors = _normalize_palette(
                    extract_species_palette(img, stretch=True)
                )
        else:
            species_colors = _normalize_palette(
                extract_species_palette(img, stretch=False)
            )

        shade_mode = override.get("shade") or decision["shade_mode"]
        needs_stretch = bool(decision["needs_contrast_stretch"])
        # Hand-pinned shade wins; stretch still follows measurement unless
        # the override explicitly disables it.
        if "contrast_stretch" in override:
            needs_stretch = bool(override["contrast_stretch"])

        # Low-chroma metal/rock: creases + front depth + midtone seams read as
        # freckle noise on flat brushed surfaces.  Keep them for chromatic mons.
        # Back profiles that already set these win; only auto-clear on fronts.
        if shade_mode == "body_mid" and not is_back:
            if "structure_creases" not in override:
                opts["structure_creases"] = False
            if "depth" not in override:
                opts["depth"] = False
            if "ink_midtone_seams" not in override:
                opts["ink_midtone_seams"] = False

        # ---- Stage 1: Prep (full resolution) ---------------------------------
        # Fronts: keep pre-framed Emerald 64×64 / 96×96 so 64→48 stays an
        # exact 3/4 majority block.  Backs: always tight-crop padded sheets
        # or the art shrinks to a postage stamp in 32×32.
        sw, sh = img.size
        do_tight_crop = bool(opts.get("tight_crop")) or not (
            sw == sh and sw in (64, 96, 128)
        )
        if is_back:
            do_tight_crop = True
        if do_tight_crop:
            bbox = img.getbbox()
            if bbox:
                l, t, r, b = bbox
                l = max(0, l - 1)
                t = max(0, t - 1)
                r = min(img.size[0], r + 1)
                b = min(img.size[1], b + 1)
                img = img.crop((l, t, r, b))

        src_for_creases = img.copy()
        # Artist ink seams — extracted before quantize/shrink so majority-vote
        # cannot erase 1px limb/plate boundaries.  OR-pooled later.
        ink_mask = None
        gap_mask = None
        if opts.get("preserve_ink", True):
            ink_mask = filter_ink_mask(
                extract_ink_mask(
                    src_for_creases,
                    luma_max=int(opts.get("ink_luma_max", 48)),
                    soft_luma_max=int(opts.get("ink_soft_luma_max", 62)),
                    contrast_delta=int(opts.get("ink_contrast_delta", 26)),
                ),
                min_blob=int(opts.get("ink_mask_min_blob", 3)),
            )
        if opts.get("preserve_gaps", False) or opts.get("carve_seams", False):
            gap_mask = extract_gap_mask(src_for_creases)

        img = quantize_rgba_to_palette(img, species_colors)
        # Fold palette-black into the ink mask — seams that snapped to ink
        # during quantize but sat above the soft luma cut still count.
        if ink_mask is not None:
            ink_mask = _union_quantized_black_into_ink(
                ink_mask, img, species_colors
            )
            ink_mask = filter_ink_mask(
                ink_mask, min_blob=int(opts.get("ink_mask_min_blob", 3))
            )
            if opts.get("carve_seams", False):
                # Optional aggressive cutouts — off for plated (eats toes/arms).
                # Kept for experiments / future delicate multi-leg work.
                img, gap_mask, ink_mask = open_limb_gaps_along_ink(
                    img,
                    ink_mask,
                    gap_mask,
                    max_steps=int(opts.get("gap_grow_steps", 8)),
                )
                img, ink_mask = ink_gap_rims(img, gap_mask, ink_mask)
            elif opts.get("reinforce_seams", False) or opts.get(
                "preserve_gaps", False
            ):
                # Plated default: thicken body↔body ink so joins stay black
                # after shrink, without carving the silhouette open.
                img, ink_mask = reinforce_interior_ink(img, ink_mask)
                if gap_mask is not None:
                    img, ink_mask = ink_gap_rims(img, gap_mask, ink_mask)

        img = clean_quantized_freckles(
            img,
            species_colors,
            min_accent=int(opts.get("min_accent", 14)),
        )
        # Midtone bleed dissolves thin cream stripes into body brown — skip
        # for patterned mons (and when carving seams open).
        if not opts.get("carve_seams", False) and not opts.get(
            "skip_midtone_bleed", False
        ):
            img = clean_midtone_bleed(
                img,
                species_colors,
                min_blob=int(opts.get("midtone_min_blob", 10)),
            )
        if opts.get("structure_creases", False):
            img = ink_structure_creases(
                img,
                src_for_creases,
                species_colors,
                dark_ratio=float(opts.get("crease_dark_ratio", 0.70)),
                min_contrast=int(opts.get("crease_min_contrast", 26)),
                valley_delta=int(opts.get("crease_valley_delta", 20)),
            )
        if opts.get("ink_midtone_seams", False):
            img = ink_midtone_seams(img, species_colors)
        img = ensure_white_eye_pupils(img, species_colors)

        w, h = img.size
        is_back = target_size == (32, 32)
        clip = BACK_BOTTOM_CLIP if is_back else 0
        fit_w = target_size[0]
        fit_h = target_size[1] + clip
        close_gap = int(opts.get("close_gap", 1))
        do_dilate = bool(opts.get("dilate", False))
        do_stem = bool(opts.get("stem", True))
        do_depth = bool(opts.get("depth", False))
        do_seal = bool(opts.get("seal", True))
        outline_mode = opts.get("outline", "soft")
        outline_luma = int(opts.get("outline_luma", 110))
        orphan_min = int(opts.get("orphan_min", 2))

        # Back survival knobs live in GEN3_BACK_* profiles — do not clobber
        # plated/patterned choices with the old hard-coded 32×32 stack.
        if not is_back:
            close_gap = min(1, close_gap)
        else:
            close_gap = min(2, close_gap)

        # Stem width scales with canvas — 7 on 56px only; thinner on 48.
        if is_back:
            stem_min = 6
        elif fit_w >= 56:
            stem_min = 7
        elif fit_w >= 48:
            stem_min = 6
        else:
            stem_min = 5

        # ---- Stage 2: Pre-dilate (backs always if enabled; fronts only ≥1.4×)
        shrink_ratio = max(w / float(fit_w), h / float(fit_h))
        shrink_steep = shrink_ratio >= 1.4
        if do_dilate and (is_back or shrink_steep):
            img = dilate_opaque(img)
            img = close_small_holes(img, max_gap=1)
            w, h = img.size

        # ---- Stage 3: Shrink -------------------------------------------------
        ratio = min(fit_w / w, fit_h / h)
        new_w = min(fit_w, max(1, int(round(w * ratio))))
        new_h = min(fit_h, max(1, int(round(h * ratio))))
        face_mask = None if is_back else build_face_priority_mask(img)
        boost = [species_colors[2]]
        boost_weight = 8
        if opts.get("boost_light_mid") and len(species_colors) >= 2:
            boost = [species_colors[1], species_colors[2]]
            boost_weight = 14
        img_resized = resize_pixel_art(
            img,
            new_w,
            new_h,
            preserve_features=True,
            boost_rgbs=boost,
            boost_mask=face_mask,
            preserve_gaps=bool(opts.get("preserve_gaps", False)),
            gap_mask=gap_mask,
            boost_weight=boost_weight,
        )
        ink_resized = None
        if ink_mask is not None:
            ink_resized = resize_ink_mask_or(ink_mask, new_w, new_h)
        gap_resized = None
        if gap_mask is not None:
            gap_resized = resize_ink_mask_or(gap_mask, new_w, new_h)
            img_resized = carve_gap_mask(img_resized, gap_resized)
        if close_gap > 0:
            img_resized = close_small_holes(img_resized, max_gap=close_gap)
        if not opts.get("carve_seams", False) and not opts.get(
            "skip_midtone_bleed", False
        ):
            img_resized = clean_midtone_bleed(
                img_resized,
                species_colors,
                min_blob=int(opts.get("midtone_min_blob_small", 6)),
            )
        if opts.get("bridge_cracks", True):
            img_resized = bridge_same_tone_cracks(img_resized, species_colors)
        if do_stem:
            img_resized = thicken_narrow_stems(img_resized, min_width=stem_min)
            if do_seal:
                img_resized = seal_outline_breaks(img_resized)

        # ---- Stage 4: Compose ------------------------------------------------
        new_img = Image.new("RGBA", target_size, (255, 255, 255, 0))
        x = (target_size[0] - new_w) // 2
        if is_back:
            y = target_size[1] - new_h + clip
        else:
            y = (target_size[1] - new_h) // 2
        new_img.paste(img_resized, (x, y), img_resized)

        # Place OR-pooled ink / gaps on the canvas at the same origin as the art.
        ink_canvas = None
        if ink_resized is not None:
            ink_canvas = Image.new("1", target_size, 0)
            ink_canvas.paste(ink_resized, (x, y))
        gap_canvas = None
        if gap_resized is not None:
            gap_canvas = Image.new("1", target_size, 0)
            gap_canvas.paste(gap_resized, (x, y))
            new_img = carve_gap_mask(new_img, gap_canvas)

        if close_gap > 0:
            new_img = close_small_holes(new_img, max_gap=close_gap)
        if not opts.get("carve_seams", False) and not opts.get(
            "skip_midtone_bleed", False
        ):
            new_img = clean_midtone_bleed(
                new_img,
                species_colors,
                min_blob=int(opts.get("midtone_min_blob_small", 6)),
            )
        if opts.get("bridge_cracks", True):
            new_img = bridge_same_tone_cracks(new_img, species_colors)
        if opts.get("ink_midtone_seams", False):
            new_img = ink_midtone_seams(new_img, species_colors)
        # Second stem pass: backs only (or extremely steep fronts).  Front
        # double-stem is what turns limbs into sausages.
        if is_back and do_stem and do_seal:
            new_img = seal_outline_breaks(new_img)
            new_img = thicken_narrow_stems(new_img, min_width=stem_min)
        elif shrink_steep and do_stem and do_seal and not is_back:
            new_img = seal_outline_breaks(new_img)

        if do_depth:
            new_img = gen1_depth_pass(new_img, strong=is_back)
        elif is_back:
            # Low-chroma fronts disable depth; backs still need volume.
            new_img = gen1_depth_pass(new_img, strong=True)
        if opts.get("lift_darks"):
            lift_rgb = (56, 56, 88)
            if opts.get("lift_rgb") and len(opts["lift_rgb"]) >= 3:
                lift_rgb = tuple(int(v) for v in opts["lift_rgb"][:3])
            elif opts.get("palette") and len(opts["palette"]) >= 2:
                slot = int(opts.get("lift_palette_slot", 1))
                slot = max(1, min(2, slot))
                lift_rgb = tuple(int(v) for v in opts["palette"][slot][:3])
            new_img = lift_near_black_body(
                new_img,
                lift_rgb=lift_rgb,
                preserve_chroma_dither=bool(opts.get("preserve_dither", False)),
            )
            if opts.get("thin_outline"):
                new_img = thin_double_outline(new_img, body_rgb=lift_rgb)

        new_img = drop_orphan_pixels(new_img, min_blob=orphan_min)
        if do_seal:
            new_img = seal_outline_breaks(new_img)
        if outline_mode == "full":
            new_img = ensure_selective_outline(new_img)
        elif outline_mode == "soft":
            new_img = ensure_contrast_outline(new_img, luma_floor=outline_luma)
        if opts.get("smooth_stairs", True):
            new_img = smooth_silhouette_stairs(new_img, ink_only=True)

        # Stage 6 lead-in: re-punch pupils after outline/depth may have eaten them.
        new_img = ensure_white_eye_pupils(new_img, species_colors)

        # Re-apply artist ink LAST so no prior pass can erase plate/limb seams.
        # only_opaque keeps intentional gaps (Metagross armpits) open.
        if ink_canvas is not None:
            new_img = composite_ink_mask(new_img, ink_canvas, only_opaque=True)
        # Re-carve gaps after ink so OR-pooled ink cannot re-clog limb joins.
        if gap_canvas is not None:
            new_img = carve_gap_mask(new_img, gap_canvas)
        if ink_canvas is not None or gap_canvas is not None:
            # Stricter second eye pass after forced ink / gap carve.
            new_img = ensure_white_eye_pupils(
                new_img, species_colors, max_blob=14, max_bw=6, max_bh=5
            )
        else:
            new_img = ensure_white_eye_pupils(
                new_img, species_colors, max_blob=16, max_bw=7, max_bh=5
            )

        # Contrast stretch AFTER downscale (edge case 2) so majority-vote
        # worked on natural gradients.  Curated hand palettes skip stretch
        # unless contrast_stretch is explicitly True in the override.
        if needs_stretch and not override.get("palette"):
            species_colors = stretch_palette_contrast(species_colors)
        elif override.get("contrast_stretch"):
            species_colors = stretch_palette_contrast(species_colors)

        # ---- Stage 5: Shade mapping -----------------------------------------
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
                    shade = shade_for_pixel(r, g, b, species_colors, mode=shade_mode)
                    indexed_img.putpixel((px_x, py), shade + 1)

        # Belt-and-suspenders: ink mask wins over shade choices on those pixels.
        if ink_canvas is not None:
            indexed_img = force_indexed_ink(indexed_img, ink_canvas)

        # ---- Stage 6: Finish -------------------------------------------------
        if opts.get("clean_accent"):
            accent_png = int(opts.get("accent_index", 3))
            indexed_img = clean_indexed_accent_ink(
                indexed_img, accent_index=accent_png, ink_index=4
            )

        do_flat = opts.get("flat_dither")
        if do_flat is None:
            do_flat = is_back
        if do_flat:
            indexed_img = dither_indexed_flats(
                indexed_img, density=int(opts.get("flat_dither_density", 8))
            )

        palette = [
            255, 255, 255,  # 0: Transparent
            255, 255, 255,  # 1: White
            170, 170, 170,  # 2: Light Gray
            85, 85, 85,     # 3: Dark Gray
            0, 0, 0,        # 4: Black
        ]
        palette += [0] * (768 - len(palette))
        indexed_img.putpalette(palette)

        # Readability self-check: if the primary front bake is muddy, retry
        # with the soft option set and keep whichever scores higher.
        if (
            not is_back
            and not opts.get("_gen3_soft")
            and opts.get("readable_fallback", True)
        ):
            score = indexed_readability_score(
                indexed_readability_metrics(indexed_img)
            )
            if score < 0:
                soft_opts = dict(opts)
                soft_opts.update(GEN3_SOFT_FALLBACK)
                soft_opts.update(override)
                soft_opts["_gen3_soft"] = True
                tmp_path = output_path + ".soft.tmp.png"
                ok2, colors2 = _process_sprite_gen3(
                    input_path,
                    tmp_path,
                    target_size,
                    soft_opts,
                    override=override,
                )
                if ok2:
                    try:
                        soft_img = Image.open(tmp_path)
                        score2 = indexed_readability_score(
                            indexed_readability_metrics(soft_img)
                        )
                        if score2 > score:
                            os.replace(tmp_path, output_path)
                            return True, colors2
                    finally:
                        try:
                            os.remove(tmp_path)
                        except OSError:
                            pass

        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
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


def resolve_front_size(height_ft, height_in, species_id=None, dex=None):
    """Height bucket, then SPRITE_OVERRIDES front_size, then Gen2/3 floor.

    Gen 2/3 faithful path benefits from a 48px floor so eyes/jaws survive.
    """
    front_size = front_size_for_dex_entry(height_ft, height_in)
    opts = sprite_override(species_id) if species_id else {}
    if opts.get("front_size"):
        front_size = int(opts["front_size"])
    elif dex is not None and (is_gen2_dex(dex) or is_gen3_dex(dex)):
        front_size = max(front_size, 6)
    return max(5, min(7, front_size))


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
        f.write("-- Generated by generate_pokemon_mod.py. DO NOT EDIT by hand;\n")
        f.write("-- tune SPRITE_OVERRIDES in generate_pokemon_mod.py and --resprite.\n")
        f.write("-- Per-species SGB palettes so Advanced color mode does not fall\n")
        f.write("-- through to MEWMON (peach/purple).\n")
        f.write("return {\n")
        for species_id in sorted(palettes_by_species.keys()):
            colors = palettes_by_species[species_id]
            f.write(f"  {species_id} = {{\n")
            for r, g, b in colors:
                f.write(f"    {{ {int(r)}, {int(g)}, {int(b)} }},\n")
            f.write("  },\n")
        f.write("}\n")


def load_species_palettes_lua(path):
    """Best-effort parse of species_palettes.lua into {id: [(r,g,b)*4]}."""
    import re
    if not os.path.exists(path):
        return {}
    text = open(path, "r", encoding="utf-8").read()
    out = {}
    for m in re.finditer(
        r"([A-Z0-9_]+)\s*=\s*\{\s*"
        r"\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}\s*,\s*"
        r"\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}\s*,\s*"
        r"\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}\s*,\s*"
        r"\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}\s*,?\s*"
        r"\}",
        text,
    ):
        name = m.group(1)
        nums = [int(m.group(i)) for i in range(2, 14)]
        out[name] = [
            (nums[0], nums[1], nums[2]),
            (nums[3], nums[4], nums[5]),
            (nums[6], nums[7], nums[8]),
            (nums[9], nums[10], nums[11]),
        ]
    return out


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


def resprite_kanto_reforged(outdir, only=None, gen=None):
    """Re-bake front sprites from the PokéAPI cache using height-based
    frontSize, and rewrite frontSize fields in pokemon_data.lua.
    Does not re-fetch species tables.

    `only` is an optional set of SPECIES_IDs to process (others keep current
    assets / palette entries).
    `gen` is 2 or 3 to limit by dex band (152–251 / 252–386).
    """
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
    palette_path = os.path.join(outdir, "species_palettes.lua")
    species_palettes = load_species_palettes_lua(palette_path)
    only_set = {s.upper() for s in only} if only else None

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
        front_size = resolve_front_size(
            int(ft_m.group(1)), int(in_m.group(1)), species_id=name, dex=dex
        )
        counts[front_size] = counts.get(front_size, 0) + 1
        canvas = front_canvas_px(front_size)

        if only_set is not None and name not in only_set:
            out_parts.append(f"\n  {name} = {{{body}")
            continue
        if gen == 2 and not (152 <= dex <= 251):
            out_parts.append(f"\n  {name} = {{{body}")
            continue
        if gen == 3 and not (252 <= dex <= 386):
            out_parts.append(f"\n  {name} = {{{body}")
            continue

        front_cache = os.path.join(cache_dir, f"{dex}_front.png")
        front_mod = os.path.join(outdir, "assets", f"{name.lower()}_front.png")
        back_cache = os.path.join(cache_dir, f"{dex}_back.png")
        back_mod = os.path.join(outdir, "assets", f"{name.lower()}_back.png")
        if os.path.exists(front_cache):
            ok, colors = process_sprite(
                front_cache, front_mod, (canvas, canvas),
                species_id=name, dex=dex,
            )
            if ok:
                resprited += 1
                if colors:
                    species_palettes[name] = colors
            else:
                missing.append(name)
        else:
            missing.append(name)

        if os.path.exists(back_cache):
            ok_b, colors_b = process_sprite(
                back_cache, back_mod, (32, 32),
                species_id=name, dex=dex,
            )
            if ok_b and colors_b and name not in species_palettes:
                species_palettes[name] = colors_b

        # Castform weather forms (same as full gen path).
        if name == "CASTFORM":
            for form_suffix, form_dex in [("sunny", 10013), ("rainy", 10014), ("snowy", 10015)]:
                f_cache = os.path.join(cache_dir, f"{form_dex}_front.png")
                b_cache = os.path.join(cache_dir, f"{form_dex}_back.png")
                f_mod = os.path.join(outdir, "assets", f"castform_{form_suffix}_front.png")
                b_mod = os.path.join(outdir, "assets", f"castform_{form_suffix}_back.png")
                if os.path.exists(f_cache):
                    process_sprite(
                        f_cache, f_mod, (canvas, canvas),
                        species_id=name, dex=form_dex,
                    )
                if os.path.exists(b_cache):
                    process_sprite(
                        b_cache, b_mod, (32, 32),
                        species_id=name, dex=form_dex,
                    )
        body = re.sub(r'frontSize\s*=\s*\d+', f'frontSize = {front_size}', body, count=1)
        if not re.search(r'frontSize\s*=', body):
            if re.search(r'spriteBack\s*=', body):
                body = re.sub(
                    r'(spriteBack\s*=\s*"[^"]*",)',
                    rf'\1\n    frontSize = {front_size},',
                    body,
                    count=1,
                )
            else:
                body = f'    frontSize = {front_size},\n' + body
        body = ensure_palette_field(body, name)
        out_parts.append(f"\n  {name} = {{{body}")

    # Remainder after last body (closing of return table etc.)
    if i < len(species_chunks):
        out_parts.append(species_chunks[i])

    with open(lua_path, "w", encoding="utf-8") as f:
        f.write("".join(out_parts))

    if species_palettes:
        write_species_palettes_lua(palette_path, species_palettes)
        print(f"Wrote {len(species_palettes)} species palettes")

    scope = f"only {sorted(only_set)}" if only_set else "all"
    if gen:
        scope = f"gen{gen}" + (f" {scope}" if only_set else "")
    print(
        f"Resprited {resprited} fronts by dex height ({scope}) "
        f"(5={counts.get(5,0)} 6={counts.get(6,0)} 7={counts.get(7,0)})"
    )
    if missing:
        print(f"Missing cache for {len(missing)} species (first 8): {missing[:8]}")


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
        "--special-stat-patches-only",
        action="store_true",
        help="Only regenerate Kanto SpA/SpD patches for the SP.ATK/SP.DEF toggle",
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
    parser.add_argument(
        "--only",
        type=str,
        default="",
        help="Comma-separated SPECIES_IDs to resprite (requires --resprite). "
             "Example: --resprite --only LUNATONE,MURKROW,SABLEYE",
    )
    parser.add_argument(
        "--gen",
        type=int,
        choices=[2, 3],
        default=None,
        help="With --resprite, only bake that generation (2=Johto 152–251, "
             "3=Hoenn 252–386). Gen 2 defaults to Crystal-faithful quantize.",
    )
    args = parser.parse_args()
    
    os.makedirs(args.outdir, exist_ok=True)

    if args.berry_farm_only:
        generate_berry_farm_assets(args.outdir)
        return

    if args.resprite:
        only = [s.strip() for s in args.only.split(",") if s.strip()] or None
        resprite_kanto_reforged(args.outdir, only=only, gen=args.gen)
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

    if args.special_stat_patches_only:
        print("Collecting SpA/SpD patches for Kanto species...")
        special_patches = collect_special_stat_patches(1, 151)
        write_special_stat_patches_lua(
            os.path.join(args.outdir, "special_stat_patches.lua"),
            special_patches,
        )
        print(f"Done: {len(special_patches)} Kanto SpA/SpD patches")
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
            # (height + Gen2/3 floor + per-species override).
            h_dm = poke_data.get("height") or 0
            inches = h_dm * 3.937
            front_size = resolve_front_size(
                int(inches // 12), int(round(inches % 12)),
                species_id=p_name, dex=pid,
            )
            front_px = front_canvas_px(front_size)

            front_cache_path = os.path.join("tools", ".cache", "sprites", f"{pid}_front.png")
            back_cache_path = os.path.join("tools", ".cache", "sprites", f"{pid}_back.png")
            
            front_mod_path = os.path.join(args.outdir, "assets", f"{p_name.lower()}_front.png")
            back_mod_path = os.path.join(args.outdir, "assets", f"{p_name.lower()}_back.png")

            species_palette = None
            if front_url and download_sprite_file(front_url, front_cache_path):
                ok, colors = process_sprite(
                    front_cache_path, front_mod_path, (front_px, front_px),
                    species_id=p_name, dex=pid,
                )
                if ok and colors:
                    species_palette = colors
            if back_url and download_sprite_file(back_url, back_cache_path):
                ok_b, colors_b = process_sprite(
                    back_cache_path, back_mod_path, (32, 32),
                    species_id=p_name, dex=pid,
                )
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
                        process_sprite(
                            f_front_cache, f_front_mod, (front_px, front_px),
                            species_id=p_name, dex=form_id,
                        )
                    if form_back and download_sprite_file(form_back, f_back_cache):
                        process_sprite(
                            f_back_cache, f_back_mod, (32, 32),
                            species_id=p_name, dex=form_id,
                        )
                        
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

    # Drop evolution *sources* outside Gen 1–3 (Gen 4 babies like Bonsly).
    # Keeping those edges would mark adults as mid-stage with no catchable baby.
    for species_id in list(evolutions_map.keys()):
        if species_id not in allowed_species:
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
