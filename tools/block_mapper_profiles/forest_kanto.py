"""Viridian Forest blocks → Gold TILESET_KANTO."""

from .common import GEN1_SIGN_BLOCKS_FOREST, GEN2_BUILDING_BLOCKS, base_profile
from .safari_kanto import synthesize

PROFILE = base_profile(
    id="forest_kanto",
    title="Viridian Forest → TILESET_KANTO",
    g1_sheet="forest_blocks_sheet.png",
    g2_sheet="gen2_kanto_blocks.png",
    g1_card_sheet=True,
    g2_card_sheet=True,
    g1_max_blocks=128,
    g2_max_blocks=161,
    g2_tileset_id="TILESET_KANTO",
    g2_palette_env="ROUTE",
    g2_tile_palette_overrides={77: 1, 78: 1, 83: 1, 84: 1, 96: 1, 97: 1, 98: 1, 99: 1},
    dict_name="FOREST_G1_TO_G2",
    custom_blocks_name="CUSTOM_KANTO_BLOCKS_GENERATED",
    out="forest_g1_to_g2.py",
    exclude_buildings=True,
    gen2_building_blocks=set(GEN2_BUILDING_BLOCKS),
    gen1_building_blocks=set(),
    gen1_feature_blocks=set(GEN1_SIGN_BLOCKS_FOREST),
    feature_bar_title="Wooden Signs & Forest Features (Click piece to apply & advance):",
    custom_blocks_source="CUSTOM_KANTO_BLOCKS",
    test_map_id="VIRIDIAN_FOREST",
    preview_tilesets=["FOREST"],
    favorites=[
        {"g2_id": 1, "src_q": 0, "name": "Plain Grass", "coll": 0x00},
        {"g2_id": 11, "src_q": 0, "name": "Tall Grass", "coll": 0x18},
        {"g2_id": 15, "src_q": 0, "name": "Solid Tree", "coll": 0x07},
        {"g2_id": 160, "src_q": 0, "name": "Wood Sign", "coll": 0x82},
        {"g2_id": 131, "src_q": 0, "name": "Tree|Grass", "coll": 0x07},
        {"g2_id": 132, "src_q": 0, "name": "Grass|Tree", "coll": 0x00},
        {"g2_id": 134, "src_q": 0, "name": "Grass/Tree", "coll": 0x00},
        {"g2_id": 136, "src_q": 0, "name": "South Warp", "coll": 0x70},
    ],
    building_dropins=[],
    quad_presets=[
        {"label": "Plain Grass", "g2_id": 1, "src_q": 0, "coll": 0x00},
        {"label": "Tall Grass", "g2_id": 11, "src_q": 0, "coll": 0x18},
        {"label": "Solid Tree", "g2_id": 15, "src_q": 0, "coll": 0x07},
        {"label": "Wood Sign TL", "g2_id": 160, "src_q": 0, "coll": 0x82},
        {"label": "Ledge Hop", "g2_id": 135, "src_q": 2, "coll": 0xA0},
    ],
    whole_block_dropins=[
        {"label": "Wooden Sign", "g2_id": 160},
    ],
    synthesize=synthesize,
)
