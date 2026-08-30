"""Gen1 CAVERN blocks → Gold TILESET_CAVE."""

from .common import COLLISION_PRESETS, base_profile


def synthesize(g1_raw_blocks, g2_raw_blocks):
    """Copy Gen1 cave sign blocks into G2 slots 120 (floor) / 121 (water)."""
    from PIL import Image

    if len(g1_raw_blocks) <= 42:
        return
    if len(g2_raw_blocks) == 0:
        return

    bw, bh = g2_raw_blocks[0].size
    while len(g2_raw_blocks) <= 121:
        g2_raw_blocks.append(Image.new("RGB", (bw, bh), (0, 0, 0)))

    # Prefer exact Gen1 metatile art so CV / thumbnails match the patched tiles.
    g2_raw_blocks[120] = g1_raw_blocks[42].resize((bw, bh), Image.NEAREST)
    if len(g1_raw_blocks) > 117:
        g2_raw_blocks[121] = g1_raw_blocks[117].resize((bw, bh), Image.NEAREST)
    else:
        g2_raw_blocks[121] = g2_raw_blocks[120].copy()
    print("Synthesized Gen1 cave wooden signs (#120 floor, #121 water) into Gen 2 pool.")


# Cave-oriented collision list (ledges, water, pits, warps first-class).
CAVE_COLLISION_PRESETS = list(COLLISION_PRESETS)

# Regirock Rock Tunnel ladder niche (legend_regis.lua LADDER_NICHE) — synthetic G1 block #128.
REGIROCK_LADDER_NICHE_TILES = [
    4, 41, 41, 41,
    49, 5, 5, 5,
    49, 5, 10, 11,
    40, 16, 26, 27,
]

PROFILE = base_profile(
    id="cavern_cave",
    title="CAVERN → TILESET_CAVE",
    g1_sheet="gen1_cavern_blocks.png",
    g2_sheet="gen2_cave_blocks.png",
    g1_card_sheet=False,
    g2_card_sheet=False,
    g1_max_blocks=128,
    g2_max_blocks=128,
    g1_tileset_id="CAVERN",
    g2_tileset_id="TILESET_CAVE",
    g1_palette_env="CAVERN",
    g2_palette_env="CAVE",
    # NITE = dark cave interior (matches Gold Diglett's / Mt. Moon). Do NOT use DAY here:
    # DAY re-tints wall tiles through outdoor palette slots (gold/yellow). Water tile 20
    # is flagged via g2_water_tiles instead of making everything daytime.
    g2_palette_daytime="NITE",
    g2_water_tiles={20},
    # Patched sign tiles + dark floor clone on composed cave.png (see tools/tileset_quad_patches.py).
    g2_tile_palette_overrides={90: 6, 91: 6, 92: 6, 93: 6, 62: 6},
    dict_name="CAVE_G1_TO_G2",
    custom_blocks_name="CUSTOM_CAVE_BLOCKS_GENERATED",
    out="cave_g1_to_g2.py",
    exclude_buildings=False,
    gen2_building_blocks=set(),
    gen1_building_blocks=set(),
    # Walls / ladders / floors + Gen1 cave sign blocks (42 floor, 117 water).
    gen1_feature_blocks={1, 21, 22, 24, 25, 26, 28, 29, 42, 43, 44, 62, 117},
    feature_bar_title="Cave Signs, Ladders & Walls (Click piece to apply & advance):",
    custom_blocks_source="CUSTOM_CAVE_BLOCKS",
    collision_presets=CAVE_COLLISION_PRESETS,
    test_map_id="DIGLETTS_CAVE",
    preview_map_ids=["REGIROCK_CHAMBER", "ROCK_TUNNEL_B1F"],
    preview_tilesets=["CAVERN"],
    synthetic_g1_blocks=[
        {"name": "Regirock Rock Tunnel ladder niche", "tiles": REGIROCK_LADDER_NICHE_TILES},
    ],
    # Dark floor = t62 (t1 2bpp shifted darker, same palette slot 6 as light floor).
    g2_pool_uniform_tiles=[
        {"tile": 62, "export_tile": 62, "g2_id": 8062, "label": "t62 dark floor"},
    ],
    favorites=[
        # Block 25 q0/q1 = plateau surface (tiles 12/13/28/29, coll 0x07).
        # Block 25 q2/q3 / block 2 = walkable lower floor (tile 1, coll 0x00).
        {"g2_id": 8001, "src_q": 0, "name": "Light Floor", "coll": 0x00, "tile_key": (1, 1, 1, 1)},
        {
            "g2_id": 8062,
            "src_q": 0,
            "name": "Dark Floor",
            "coll": 0x00,
            "tile_key": (62, 62, 62, 62),
            "export_tile": 62,
        },
        {"g2_id": 25, "src_q": 0, "name": "Plateau Top", "coll": 0x07},
        {"g2_id": 45, "src_q": 0, "name": "Wall", "coll": 0x07},
        {"g2_id": 16, "src_q": 0, "name": "Top Wall", "coll": 0x07},
        {"g2_id": 10, "src_q": 0, "name": "Left Wall", "coll": 0x07},
        {"g2_id": 8, "src_q": 0, "name": "Right Wall", "coll": 0x07},
        {"g2_id": 120, "src_q": 3, "name": "Sign BR", "coll": 0x82},
        {"g2_id": 43, "src_q": 0, "name": "Ladder", "coll": 0x2B},
        {"g2_id": 121, "src_q": 3, "name": "Sign/Water", "coll": 0x82},
    ],
    building_dropins=[],
    quad_presets=[
        {"label": "Light Floor", "g2_id": 8001, "src_q": 0, "coll": 0x00, "tile_key": (1, 1, 1, 1)},
        {
            "label": "Dark Floor",
            "g2_id": 8062,
            "src_q": 0,
            "coll": 0x00,
            "tile_key": (62, 62, 62, 62),
            "export_tile": 62,
        },
        {"label": "Plateau (upper)", "g2_id": 25, "src_q": 0, "coll": 0x07},
        {"label": "Solid Wall", "g2_id": 45, "src_q": 0, "coll": 0x07},
        {"label": "Ladder", "g2_id": 43, "src_q": 0, "coll": 0x2B},
        {"label": "Sign BR", "g2_id": 120, "src_q": 3, "coll": 0x82},
        {"label": "Water", "g2_id": 20, "src_q": 0, "coll": 0x29},
        {"label": "Pit", "g2_id": 2, "src_q": 0, "coll": 0x21},
        {"label": "Ledge Down", "g2_id": 25, "src_q": 2, "coll": 0xA0},
        {"label": "Sign/Water BR", "g2_id": 121, "src_q": 3, "coll": 0x82},
    ],
    whole_block_dropins=[
        {"label": "Full Floor", "g2_id": 2},
        {"label": "Full Ladder", "g2_id": 43},
        {"label": "Floor Sign", "g2_id": 120},
        {"label": "Water Sign", "g2_id": 121},
    ],
    synthesize=synthesize,
)
