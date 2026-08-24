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
    g2_palette_env="CAVE",
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
    preview_tilesets=["CAVERN"],
    favorites=[
        {"g2_id": 25, "src_q": 0, "name": "Cave Floor", "coll": 0x00},
        {"g2_id": 1, "src_q": 0, "name": "Wall", "coll": 0x07},
        {"g2_id": 16, "src_q": 0, "name": "Top Wall", "coll": 0x07},
        {"g2_id": 10, "src_q": 0, "name": "Left Wall", "coll": 0x07},
        {"g2_id": 8, "src_q": 0, "name": "Right Wall", "coll": 0x07},
        {"g2_id": 120, "src_q": 3, "name": "Sign BR", "coll": 0x82},
        {"g2_id": 43, "src_q": 0, "name": "Ladder", "coll": 0x2B},
        {"g2_id": 121, "src_q": 3, "name": "Sign/Water", "coll": 0x82},
    ],
    building_dropins=[],
    quad_presets=[
        {"label": "Cave Floor", "g2_id": 25, "src_q": 0, "coll": 0x00},
        {"label": "Solid Wall", "g2_id": 1, "src_q": 0, "coll": 0x07},
        {"label": "Ladder", "g2_id": 43, "src_q": 0, "coll": 0x2B},
        {"label": "Sign BR", "g2_id": 120, "src_q": 3, "coll": 0x82},
        {"label": "Water", "g2_id": 25, "src_q": 0, "coll": 0x29},
        {"label": "Pit", "g2_id": 25, "src_q": 0, "coll": 0x21},
        {"label": "Ledge Down", "g2_id": 25, "src_q": 2, "coll": 0xA0},
        {"label": "Sign/Water BR", "g2_id": 121, "src_q": 3, "coll": 0x82},
    ],
    whole_block_dropins=[
        {"label": "Full Floor", "g2_id": 25},
        {"label": "Full Ladder", "g2_id": 43},
        {"label": "Floor Sign", "g2_id": 120},
        {"label": "Water Sign", "g2_id": 121},
    ],
    synthesize=synthesize,
)
