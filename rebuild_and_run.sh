#!/usr/bin/env bash
# Export Blender models, auto-import into Godot, then launch the game.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="${GODOT:-/godot/Godot_v4.7.2-stable_linux.x86_64}"

"$SCRIPT_DIR/rebuild_assets.sh"

echo "==> Launching Path of Destiny..."
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" --path "$SCRIPT_DIR" "$@"
