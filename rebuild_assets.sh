#!/usr/bin/env bash
# Export Blender models and auto-import into Godot (no manual reimport needed).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR"
GODOT="${GODOT:-/godot/Godot_v4.7.2-stable_linux.x86_64}"
BLENDER="${BLENDER:-/blender/blender}"

echo "==> Exporting player..."
"$BLENDER" --background --python "$PROJECT/blender/build_player.py"

echo "==> Exporting environment..."
"$BLENDER" --background --python "$PROJECT/blender/build_environment.py"

echo "==> Exporting boss..."
"$BLENDER" --background --python "$PROJECT/blender/build_boss.py"

echo "==> Importing assets into Godot..."
GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" --path "$PROJECT" --headless --import

echo "==> Done. Assets exported and imported."
