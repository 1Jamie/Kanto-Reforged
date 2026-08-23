#!/usr/bin/env bash
# Backward-compatible alias → safari profile GUI
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/run_block_mapper.sh" --profile safari_kanto "$@"
