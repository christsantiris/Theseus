#!/usr/bin/env bash
# Generate lossless panorama joins before importing/exporting the project.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
exec "$GODOT" --headless --path "$ROOT" --script res://tools/bake_landscapes.gd -- "$@"
