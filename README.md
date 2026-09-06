# Path of Destiny

Open-world SciFi action RPG blending Destiny/Outriders style combat with Path of Exile 2 style gear and ability systems.

## Quick Start

Run the game (no asset rebuild):

```bash
path-of-destiny
# or
/godot/Godot_v4.7.2-stable_linux.x86_64 --path /root/.cursor/projects/ai_projects/path-of-destiny
```

Shared install + Windows sync: `sudo bash install_shared.sh` → `/opt/path-of-destiny` and `\\192.168.1.50\godot\path-of-destiny`

One-time setup for Windows sync:

```bash
cp sync_windows.credentials.example sync_windows.credentials
chmod 600 sync_windows.credentials
# edit sync_windows.credentials and set SMB_PASSWORD
```

After changing Blender models, export + auto-import + run in one step:

```bash
./rebuild_and_run.sh
```

Export and import only (no launch):

```bash
./rebuild_assets.sh
```

Headless validation:

```bash
/godot/Godot_v4.7.2-stable_linux.x86_64 --path /root/.cursor/projects/ai_projects/path-of-destiny --headless --quit-after 3
```

## Controls

| Input | Action |
|-------|--------|
| WASD | Move |
| Shift | Sprint |
| Space | Jump (double-tap to dodge) |
| Mouse | Camera |
| LMB | Fire |
| RMB | Aim down sights |
| R | Reload |
| Q | Throw grenade |
| 1 / 2 / 3 | Equip weapon slot |
| MMB click | Swap primary ↔ secondary |
| MMB hold | Equip melee (slot 3) |
| V | Toggle 1st / 3rd person |
| E | Interact |
| Tab / I | Inventory (pauses game) |
| F3 / F4 | Aim debug toggle / copy report |
| F6 / F7 | Grenade debug toggle / copy report |
| F10 / F11 | Diag panel toggle / copy report |
| F5 | Toggle enemy spawning |
| Esc | Pause |

## Loadout

1. **Bolter Mk VII** — Primary rifle (30 round mag)
2. **Long Las Mk IV** — Sniper rifle (6 round mag, 4× zoom when aiming)
3. **Chainsword** — Melee
4. **Frag Grenade** — 3 grenades, recharges over time (Q)

## Core Loop

1. **Explore** the Ashfall Expanse open zone
2. **Collect loot** with Destiny 2-style rarities (Common → Exotic) — items go to inventory
3. **Fight** The Corrupted Warmaster boss (3 phases, Elden Ring-style)
4. **Equip** weapons and armor from inventory (Tab or I) — Primary, Secondary, and Heavy slots independently

See **[ROADMAP.md](ROADMAP.md)** for the full development plan: looter-shooter first, then skill gems, passive tree, and crafting/currency (PoE-inspired).

## Rebuilding Assets

Use `rebuild_assets.sh` — it exports all GLBs and runs `godot --import` so you never need to manually reimport in the editor.

Individual scripts (if needed):

```bash
/blender/blender --background --python blender/build_player.py
/blender/blender --background --python blender/build_environment.py
/blender/blender --background --python blender/build_boss.py
/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --headless --import
```

## Project Structure

```
path-of-destiny/
├── assets/models/       # GLB exports from Blender
├── blender/             # Asset generation scripts
├── scenes/              # Godot scenes
├── scripts/
│   ├── autoload/        # GameManager, LootManager, AbilityManager
│   ├── player/          # Third-person controller
│   ├── enemies/         # Boss AI
│   ├── systems/         # Loot, boss arena
│   └── ui/              # HUD
└── project.godot
```
