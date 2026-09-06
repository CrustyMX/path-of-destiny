# Path of Destiny — Development Roadmap

**Vision:** Start as a tight **looter shooter** (Outriders / Destiny cadence), then evolve toward **Path of Exile 2** depth: skill gems → passive tree → crafting/currency.

This document maps each phase to the existing codebase so work stays incremental, not a rewrite.

---

## Current State (baseline)

| Area | Status | Key files |
|------|--------|-----------|
| Third-person shooter combat | Working | `scripts/player/player_controller.gd`, `weapon_controller.gd` |
| 3-slot weapon loadout | Bolter / Sniper / Chainsword | `scripts/autoload/weapon_library.gd` |
| ADS + weapon-specific zoom | Bolter ADS; sniper 4× scope | `player_controller.gd`, `weapon_library.gd` |
| Reload + ammo | Per-weapon mags | `weapon_controller.gd`, `hud.gd` |
| Grenades | Reticle-arc throws, contact detonation | `grenade_manager.gd`, `grenade.gd`, `grenade_debug.gd` |
| Loot + rarity | Drops, auto-equip | `loot_manager.gd`, `systems/loot_pickup.gd` |
| Stat pipeline | Phase 1.1 complete | `stat_manager.gd` |
| Enemies + spawner | Mobs + F5 toggle | `mob_enemy.gd`, `enemy_spawner.gd` |
| Boss fight | 3-phase arena | `boss.gd`, `boss_arena.gd` |
| HUD / feedback | Health, weapon bar, crosshair, ammo | `hud.gd`, `crosshair.gd`, `combat_feedback.gd` |
| Debug tools | Aim (F3/F4), grenade arc (F6/F7) | `aim_debug.gd`, `grenade_debug.gd` |
| Shared install | `/opt/path-of-destiny` | `install_shared.sh` |

**Default loadout:** Slot 1 Bolter Mk VII · Slot 2 Long Las Mk IV (sniper, 4× ADS) · Slot 3 Chainsword · Q Frag Grenade

**Autoloads today:** `GameManager`, `LootManager`, `AbilityManager`, `WeaponLibrary`, `StatManager`, `CombatFeedback`, `AimDebug`, `GrenadeDebug`, `GrenadeManager`, `AudioManager`

**Retired from player controls (Phase 2 target):** lock-on, fixed 1–4 ability bar — `AbilityManager` remains for future gem migration.

---

## Architecture Principles (apply in every phase)

1. **Data over code** — abilities, weapons, affixes, gems as dictionaries/Resources, not logic buried in `player_controller.gd`.
2. **Stat pipeline** — all combat numbers flow through one modifier layer (even if gear is the only source at first).
3. **Item schema** — every item: `base_id`, `rarity`, `affixes[]`, optional `sockets[]` (empty until Phase 2).
4. **Player stays dumb** — player reads equipped loadout; it does not hardcode build rules.

Target stat flow (Phase 1.1 live; affixes in 1.2):

```
Base stat (weapon/armor/gem definition)
  → Gear affixes (LootManager)          ← Phase 1.2
  → Passive tree (Phase 3)
  → Temporary buffs (abilities, auras)
  → Final value used in combat
```

---

## Phase 1 — Looter Shooter Core

**Goal:** *“One more run for loot.”* Fun gunplay, meaningful drops, repeatable content.

### Exit criteria (move to Phase 2 when most are checked)

- [x] 3+ weapons feel distinct (DPS, burst, melee swap)
- [x] Rolled affixes on weapons/armor (not just flat damage/defense)
- [x] Inventory UI — compare, equip, stash overflow
- [ ] Zone loop: enter → fight → boss/elite → reward chest
- [ ] Enemy variety: at least 3 mob behaviors + 1 elite modifier
- [ ] Boss victory flow: loot shower, return to hub/explore
- [x] `StatManager` autoload resolves damage/defense/cooldown from gear

### Milestones

#### 1.1 — Stat pipeline (foundation for everything later)

| Task | Status | Files |
|------|--------|-------|
| Add `StatManager` autoload | Done | `scripts/autoload/stat_manager.gd` |
| Register in project | Done | `project.godot` autoload section |
| Define stat IDs | Done | `damage`, `fire_rate`, `crit_chance`, `armor`, `move_speed`, `cooldown_reduction` |
| Modifier sources enum | Done | `BASE`, `GEAR`, `PASSIVE`, `BUFF` (passive unused until Phase 3) |
| Wire weapon damage | Done | `weapon_controller.gd` → `StatManager.get_stat("damage")` |
| Wire armor mitigation | Done | `player_controller.gd` `take_damage()` → `StatManager.get_stat("armor")` |
| Wire ability cooldowns | Done | `ability_manager.gd` → `get_cooldown_duration()` |
| Wire move speed | Done | `player_controller.gd` → `StatManager.get_stat("move_speed")` |

#### 1.2 — Affixes on loot

| Task | Status | Files |
|------|--------|-------|
| Affix pool definitions | Done | `scripts/systems/affix_library.gd` |
| Roll 1–3 affixes on drop | Done | `loot_manager.gd` `roll_loot()` |
| Item shape: `{ base_id, rarity, affixes: [{id, value}] }` | Done | `loot_manager.gd` |
| Apply affixes to stats | Done | `stat_manager.gd` via `AffixLibrary` |
| Show affix text on pickup | Done | `hud.gd` `_on_loot_collected()` |

#### 1.3 — Gunfeel + content

| Task | Status | Files |
|------|--------|-------|
| Sniper with scoped ADS | Done | `weapon_library.gd` (`sniper_rifle`, 4× zoom) |
| SMG + scout rifle variants | Done | `weapon_library.gd`, loot tables — per-weapon SFX/recoil/shake |
| Elite enemies (more HP, affix) | Done | `mob_enemy.gd` (`ELITE_MODIFIERS`), `enemy_spawner.gd` |
| Mission/zone trigger | Done | `scripts/world/zone_trigger.gd`, `scenes/world/open_world.tscn` |
| Reward chest on boss kill | Done | `boss_arena.gd` — auto-opens after 1.25s loot shower |
| Replace procedural SFX | Partial | `audio_manager.gd` — distinct weapon profiles + chest open; real `.wav` assets still TODO |

#### 1.4 — Inventory UI

| Task | Status | Files |
|------|--------|-------|
| Inventory panel (Tab or I) | Done | `scenes/ui/inventory.tscn`, `scripts/ui/inventory.gd`, `scripts/ui/loadout_doll.gd` |
| PoE-style loadout doll | Done | `loadout_doll.gd` — slot grid with placeholders for future gear |
| Equip weapon/armor manually | Done | `loot_manager.gd` — per-slot `equipped_weapons`, no auto-equip on pickup |
| Item tooltip + compare | Done | `inventory.gd` — affix hover, slot-matched stat deltas |
| Stash capacity + overflow | Done | `loot_manager.gd` `MAX_GEAR_ITEMS`, pickup blocked + HUD notice |
| Hook into pause/input | Done | `hud.gd`, `project.godot` (`Tab` + `I`) |

---

## Phase 2 — Skill Gems

**Goal:** *“My build is the gems I socketed.”* Abilities become loot, not fixed hotkeys.

### Exit criteria

- [ ] Active gems drop from enemies/chests
- [ ] Gear has socket slots (weapon/armor/helmet/gloves — start with 2 slots)
- [ ] Ability bar reads from socketed gems, not `ABILITIES` constant
- [ ] 8+ distinct active gems
- [ ] Gem level or quality affects damage/cooldown

### Milestones

#### 2.1 — Gem data model

| Task | Files |
|------|-------|
| Gem definitions (migrate current 4 abilities) | **New** `scripts/systems/gem_library.gd` |
| Gem item type in loot | `loot_manager.gd` — `type: "gem"`, `gem_id`, `level` |
| Socket schema on gear | `{ sockets: [{ type: "active", gem: Dictionary\|null }] }` |
| `GemManager` or extend `AbilityManager` | `ability_manager.gd` refactor |

#### 2.2 — Socket UI

| Task | Files |
|------|-------|
| Socket panel on inventory item | `inventory.gd` |
| Drag gem ↔ socket | UI logic + `LootManager` / `GemManager` |
| Ability bar reflects sockets | `hud.gd` (replaces weapon bar slot or separate bar) |
| Default starter gems on new game | `game_manager.gd` or player `_ready` |

#### 2.3 — Combat integration

| Task | Files |
|------|-------|
| `get_ability(slot)` reads socketed gem | `ability_manager.gd` |
| Player ability execution | Re-hook `player_controller.gd` — uses `type` field (`dash_attack`, `aoe`, etc.) |
| Gem damage scales via `StatManager` | tag modifiers: `"spell"`, `"attack"`, `"projectile"` |

#### 2.4 — Support gems (optional stretch)

| Task | Files |
|------|-------|
| Support gem type (+% damage, +chains, etc.) | `gem_library.gd` |
| Link support → active in same item sockets | socket rules in `gem_manager.gd` |
| UI shows linked supports | `inventory.gd` |

---

## Phase 3 — Passive Tree

**Goal:** *“Long-term character planning.”* PoE-style web of passive nodes.

### Exit criteria

- [ ] 30–50 node tree (one ascendancy/class to start)
- [ ] Points earned on level-up or major milestones
- [ ] Nodes feed `StatManager` as `PASSIVE` modifiers
- [ ] Respec option (currency sink — ties to Phase 4)
- [ ] Tree UI pan/zoom

### Milestones

#### 3.1 — Tree data

| Task | Files |
|------|-------|
| Node graph format | **New** `data/passive_tree.json` or Resource |
| Node types: stat, keystone, notable | `scripts/systems/passive_tree.gd` |
| `PassiveManager` autoload | **New** `scripts/autoload/passive_manager.gd` |
| Allocated nodes → `StatManager` | `stat_manager.gd` |

#### 3.2 — Tree UI

| Task | Files |
|------|-------|
| Full-screen tree view | **New** `scenes/ui/passive_tree.tscn`, `scripts/ui/passive_tree.gd` |
| Open with P or dedicated key | `project.godot`, `hud.gd` |
| Path validation (connected nodes only) | `passive_manager.gd` |

#### 3.3 — Progression hook

| Task | Files |
|------|-------|
| Character level + passive points | **New** fields on `GameManager` or `CharacterProgression` |
| XP from kills/bosses | `mob_enemy.gd`, `boss.gd` |

---

## Phase 4 — Crafting & Currency

**Goal:** *“I farm currency to craft upgrades.”* Materials become purposeful.

### Exit criteria

- [ ] 3+ currency types with distinct uses (reroll affix, add socket, upgrade rarity)
- [ ] Crafting bench UI at hub or portable
- [ ] Materials from `exploration` table used in recipes
- [ ] Economy loop: farm → craft → chase bis gear

### Milestones

#### 4.1 — Currency

| Task | Files |
|------|-------|
| Currency items (reuse material drops) | `loot_manager.gd` — `type: "currency"` |
| Currency stash + counts | `loot_manager.gd` or **New** `currency_manager.gd` |
| Orbs: transmute, alter, augment (PoE-inspired names/theming) | `data/currencies.json` |

#### 4.2 — Crafting recipes

| Task | Files |
|------|-------|
| Recipe definitions | **New** `scripts/systems/crafting_library.gd` |
| Crafting bench scene | **New** `scenes/ui/crafting_bench.tscn` |
| Apply recipe (consume currency + item → new item) | `crafting_library.gd` |

#### 4.3 — Advanced item ops

| Task | Files |
|------|-------|
| Reroll one affix | recipe + `loot_manager.gd` |
| Add/remove socket | recipe |
| Upgrade rarity (risk/reward optional) | recipe |

---

## Suggested File Tree (end state)

```
scripts/
├── autoload/
│   ├── game_manager.gd
│   ├── loot_manager.gd
│   ├── ability_manager.gd      → gem runtime / cooldowns
│   ├── weapon_library.gd
│   ├── stat_manager.gd         ← Phase 1.1 (live)
│   ├── passive_manager.gd      ← Phase 3
│   └── audio_manager.gd
├── systems/
│   ├── affix_library.gd        ← Phase 1.2 (next)
│   ├── gem_library.gd          ← Phase 2
│   ├── crafting_library.gd     ← Phase 4
│   └── passive_tree.gd         ← Phase 3
├── ui/
│   ├── inventory.gd            ← Phase 1.4
│   ├── passive_tree.gd         ← Phase 3
│   └── crafting_bench.gd       ← Phase 4
data/
├── affixes.json
├── gems.json
├── passive_tree.json
└── recipes.json
```

---

## What NOT to build early

| System | Wait until |
|--------|------------|
| Full PoE-scale passive tree (500+ nodes) | Phase 3 proven with small tree |
| Support gem linking | Active gems stable (Phase 2.4+) |
| Trade / auction house | Economy balanced (Phase 4+) |
| Procedural zone generation | Core zone loop fun (Phase 1.3) |

---

## Immediate Next Steps (recommended order)

1. ~~**`StatManager`**~~ — done; damage, armor, fire rate, move speed, cooldown reduction wired.
2. ~~**Affix rolls on loot**~~ — done; 8 affixes, rolled on weapon/armor drops, applied via GEAR modifiers.
3. ~~**Inventory UI**~~ — compare, per-slot equip, stash cap, Tab/I panel done.
4. **Inventory UI** — required before sockets feel good.
5. **Then** migrate `AbilityManager.ABILITIES` → gem drops + sockets.

---

## Phase Summary

| Phase | Player fantasy | Primary new autoload/system |
|-------|----------------|----------------------------|
| **1** Looter shooter | Better guns, better rolls | `StatManager`, affixes, inventory |
| **2** Skill gems | Skills are loot | `GemLibrary`, socket UI |
| **3** Passive tree | Long-term build | `PassiveManager`, tree UI |
| **4** Crafting | Farm and craft | `CraftingLibrary`, currencies |

---

*Last updated: 2026-09-06 — Phase 1.3 gunfeel: elites, per-weapon SFX/recoil, boss loot shower.*
