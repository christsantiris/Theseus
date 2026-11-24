#!/usr/bin/env bash
# Preview touch controls on desktop. Optional level matches play_level.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
user_args=("--mobile-controls")
scene_args=()
engine_args=()
if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
  scene_args=("res://scenes/debug/level_select.tscn")
  user_args+=("--level=$1")
  shift
fi

for argument in "$@"; do
  case "$argument" in
    --mobile-render=*) user_args+=("$argument") ;;
    *) engine_args+=("$argument") ;;
  esac
done

exec "$GODOT" --path "$ROOT" "${engine_args[@]+"${engine_args[@]}"}" "${scene_args[@]+"${scene_args[@]}"}" -- "${user_args[@]}"
