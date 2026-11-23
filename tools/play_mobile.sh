#!/usr/bin/env bash
# Preview touch controls on desktop. Optional level and shrine match play_level.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
user_args=("--mobile-controls")
scene_args=()
if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
  scene_args=("res://scenes/debug/level_select.tscn")
  user_args+=("--level=$1")
  shift
  if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
    user_args+=("--shrine=$1")
    shift
  fi
fi

exec "$GODOT" --path "$ROOT" "$@" "${scene_args[@]+"${scene_args[@]}"}" -- "${user_args[@]}"
