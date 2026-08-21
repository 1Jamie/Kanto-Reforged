#!/usr/bin/env bash
# Safari Zone Block Mapping & Dungeon Re-Processing Pipeline
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"

echo "======================================================================"
echo "1. Launching Safari Zone Human-in-the-Loop Block Mapper GUI..."
echo "======================================================================"
python3 "$DIR/block_mapper_gui.py" \
    --g1 "$DIR/blocksets/gen1_safari_blocks.png" \
    --g2 "$DIR/blocksets/gen2_kanto_blocks.png" \
    --out "$DIR/safari_g1_to_g2.py"

echo ""
echo "======================================================================"
echo "2. Rebuilding Restored Dungeons & Safari Zone Game Data..."
echo "======================================================================"
python3 "$DIR/restore_kanto_dungeons.py"

echo ""
echo "✔ Safari Zone maps successfully reprocessed and ready to test!"
