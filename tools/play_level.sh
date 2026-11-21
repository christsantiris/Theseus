#!/usr/bin/env bash
# Play-test Theseus from any level or shrine.
#
#   tools/play_level.sh            # level picker
#   tools/play_level.sh 3          # level 3 from its entrance
#   tools/play_level.sh 3 2        # level 3 from its second shrine
#
# Extra Godot flags go after the level numbers, e.g. tools/play_level.sh 2 1 --verbose
# Set GODOT=/path/to/godot if Godot is not on your PATH as `godot`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
SCENE="res://scenes/debug/level_select.tscn"

user_args=()
if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
  user_args+=("--level=$1")
  shift
  if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
    user_args+=("--shrine=$1")
    shift
  fi
fi

exec "$GODOT" --path "$ROOT" "$@" "$SCENE" -- "${user_args[@]+"${user_args[@]}"}"
