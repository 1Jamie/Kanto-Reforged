#!/usr/bin/env bash
# Launch the in-UI block mapper (Setup → Mapper ↔ Map Preview).
# Restore is available from Mapper via "Run restore after export", or --restore-only.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="safari_kanto"
RESTORE_ONLY=0
DO_RESTORE=0
EXTRA_ARGS=()

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [-- mapper-args...]

Options:
  --profile NAME   Pre-select profile in Setup (default: safari_kanto)
                   Known: safari_kanto, forest_kanto, cavern_cave
  --restore-only   Skip GUI; only run restore_kanto_dungeons.py
  --with-restore   After GUI exits, also run restore_kanto_dungeons.py
  -h, --help       Show this help

The GUI opens on Setup. Use Process / Run, then Mapper / Map Preview.
Export from Mapper; optionally check "Run restore after export".
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --restore-only)
      RESTORE_ONLY=1
      shift
      ;;
    --with-restore|--no-skip-restore)
      DO_RESTORE=1
      shift
      ;;
    --skip-restore)
      # Default is already GUI-only; kept for compatibility
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

cd "$DIR"

if [[ "$RESTORE_ONLY" -eq 1 ]]; then
  ROOT="$(cd "$DIR/../../.." && pwd)"
  (cd "$ROOT" && python3 "$DIR/restore_kanto_dungeons.py")
  exit 0
fi

echo "Launching Block Mapper GUI [profile=$PROFILE]…"
python3 "$DIR/block_mapper_gui.py" --profile "$PROFILE" "${EXTRA_ARGS[@]}"

if [[ "$DO_RESTORE" -eq 1 ]]; then
  echo "Running restore_kanto_dungeons.py…"
  ROOT="$(cd "$DIR/../../.." && pwd)"
  (cd "$ROOT" && python3 "$DIR/restore_kanto_dungeons.py")
fi
