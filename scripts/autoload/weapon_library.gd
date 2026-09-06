extends Node

signal weapon_changed(weapon_id: String)
signal loadout_changed(active_slot: int, weapon_id: String)

enum WeaponKind { MELEE, RANGED, HEAVY_RANGED }

const DEFAULT_LOADOUT: Array[String] = ["bolter", "sniper_rifle", "chainsword"]

const WEAPONS := {
	"chainsword": {
		"name": "Chainsword",
		"kind": WeaponKind.MELEE,
		"damage": 18,
		"heavy_damage": 35,
		"fire_rate": 0.55,
		"heavy_rate": 1.1,
		"range": 2.8,
		"projectile_speed": 0.0,
		"spread": 0.0,
		"magazine_size": 0,
		"reload_time": 0.0,
		"color": Color(0.55, 0.55, 0.6),
		"emission": Color(0.8, 0.15, 0.1),
		"model_scale": Vector3(0.12, 0.5, 0.08),
		"model_type": "blade",
		"loadout_slot": 2,
	},
	"bolter": {
		"name": "Bolter Mk VII",
		"kind": WeaponKind.RANGED,
		"damage": 25,
		"heavy_damage": 40,
		"fire_rate": 0.12,
		"heavy_rate": 0.9,
		"range": 70.0,
		"projectile_speed": 55.0,
		"spread": 1.0,
		"ads_spread": 0.05,
		"move_spread": 0.8,
		"magazine_size": 30,
		"reload_time": 1.75,
		"color": Color(0.2, 0.22, 0.25),
		"emission": Color(1.0, 0.5, 0.1),
		"model_scale": Vector3(0.1, 0.35, 0.12),
		"model_type": "gun",
		"loadout_slot": 0,
		"sfx_fire": "gunfire_rifle",
		"sfx_heavy": "gunfire_heavy",
		"shake": 0.14,
		"recoil_pitch": 0.42,
	},
	"sniper_rifle": {
		"name": "Long Las Mk IV",
		"kind": WeaponKind.RANGED,
		"damage": 95,
		"heavy_damage": 140,
		"fire_rate": 1.05,
		"heavy_rate": 1.45,
		"range": 140.0,
		"projectile_speed": 120.0,
		"spread": 0.35,
		"ads_spread": 0.0,
		"move_spread": 1.2,
		"magazine_size": 6,
		"reload_time": 2.1,
		"ads_zoom": 4.0,
		"ads_sensitivity_mult": 0.35,
		"ads_move_mult": 0.42,
		"color": Color(0.18, 0.2, 0.22),
		"emission": Color(0.35, 0.75, 1.0),
		"model_scale": Vector3(0.09, 0.45, 0.1),
		"model_type": "long_rifle",
		"loadout_slot": 1,
		"sfx_fire": "gunfire_sniper",
		"sfx_heavy": "gunfire_heavy",
		"shake": 0.48,
		"recoil_pitch": 1.35,
	},
	"plasma_caster": {
		"name": "Plasma Caster",
		"kind": WeaponKind.HEAVY_RANGED,
		"damage": 45,
		"heavy_damage": 90,
		"fire_rate": 0.65,
		"heavy_rate": 1.4,
		"range": 50.0,
		"projectile_speed": 35.0,
		"spread": 0.0,
		"ads_spread": 0.0,
		"move_spread": 0.0,
		"magazine_size": 8,
		"reload_time": 2.35,
		"color": Color(0.15, 0.35, 0.5),
		"emission": Color(0.2, 0.8, 1.0),
		"model_scale": Vector3(0.14, 0.55, 0.14),
		"model_type": "plasma_caster",
		"loadout_slot": 2,
		"sfx_fire": "gunfire_melta",
		"sfx_heavy": "gunfire_melta",
		"shake": 0.28,
		"recoil_pitch": 0.48,
	},
	"void_reaper": {
		"name": "Void Reaper",
		"kind": WeaponKind.MELEE,
		"damage": 80,
		"heavy_damage": 140,
		"fire_rate": 0.85,
		"heavy_rate": 1.6,
		"range": 3.8,
		"projectile_speed": 0.0,
		"spread": 0.0,
		"magazine_size": 0,
		"reload_time": 0.0,
		"color": Color(0.3, 0.1, 0.5),
		"emission": Color(0.6, 0.1, 0.9),
		"model_scale": Vector3(0.18, 0.75, 0.06),
		"model_type": "greatblade",
		"loadout_slot": 2,
	},
	"autopistol": {
		"name": "Autopistol Mk III",
		"kind": WeaponKind.RANGED,
		"damage": 18,
		"heavy_damage": 28,
		"fire_rate": 0.08,
		"heavy_rate": 0.55,
		"range": 45.0,
		"projectile_speed": 50.0,
		"spread": 1.8,
		"ads_spread": 0.35,
		"move_spread": 1.4,
		"magazine_size": 18,
		"reload_time": 1.35,
		"color": Color(0.22, 0.24, 0.28),
		"emission": Color(0.9, 0.55, 0.15),
		"model_scale": Vector3(0.08, 0.22, 0.1),
		"model_type": "gun",
		"loadout_slot": 1,
		"sfx_fire": "gunfire_pistol",
		"sfx_heavy": "gunfire_rifle",
		"shake": 0.1,
		"recoil_pitch": 0.28,
	},
	"meltagun": {
		"name": "Meltagun Mk I",
		"kind": WeaponKind.HEAVY_RANGED,
		"damage": 55,
		"heavy_damage": 95,
		"fire_rate": 0.75,
		"heavy_rate": 1.5,
		"range": 42.0,
		"projectile_speed": 38.0,
		"spread": 0.5,
		"ads_spread": 0.0,
		"move_spread": 0.6,
		"magazine_size": 5,
		"reload_time": 2.5,
		"color": Color(0.28, 0.14, 0.1),
		"emission": Color(1.0, 0.35, 0.08),
		"model_scale": Vector3(0.16, 0.48, 0.16),
		"model_type": "meltagun",
		"loadout_slot": 2,
		"sfx_fire": "gunfire_melta",
		"sfx_heavy": "gunfire_melta",
		"shake": 0.32,
		"recoil_pitch": 0.55,
	},
	"chainaxe": {
		"name": "Chainaxe",
		"kind": WeaponKind.MELEE,
		"damage": 42,
		"heavy_damage": 72,
		"fire_rate": 0.62,
		"heavy_rate": 1.15,
		"range": 3.2,
		"projectile_speed": 0.0,
		"spread": 0.0,
		"magazine_size": 0,
		"reload_time": 0.0,
		"color": Color(0.42, 0.38, 0.34),
		"emission": Color(0.95, 0.25, 0.12),
		"model_scale": Vector3(0.14, 0.58, 0.1),
		"model_type": "blade",
		"loadout_slot": 1,
	},
	"smg": {
		"name": "Autogun SMG",
		"kind": WeaponKind.RANGED,
		"damage": 12,
		"heavy_damage": 20,
		"fire_rate": 0.06,
		"heavy_rate": 0.38,
		"range": 38.0,
		"projectile_speed": 48.0,
		"spread": 2.2,
		"ads_spread": 0.48,
		"move_spread": 1.65,
		"magazine_size": 32,
		"reload_time": 1.55,
		"ads_zoom": 1.35,
		"color": Color(0.24, 0.26, 0.3),
		"emission": Color(0.85, 0.72, 0.2),
		"model_scale": Vector3(0.1, 0.28, 0.14),
		"model_type": "smg",
		"loadout_slot": 0,
		"sfx_fire": "gunfire_smg",
		"sfx_heavy": "gunfire_smg",
		"shake": 0.08,
		"recoil_pitch": 0.16,
	},
	"scout_rifle": {
		"name": "Scout Rifle Mk II",
		"kind": WeaponKind.RANGED,
		"damage": 38,
		"heavy_damage": 58,
		"fire_rate": 0.28,
		"heavy_rate": 0.82,
		"range": 88.0,
		"projectile_speed": 78.0,
		"spread": 0.75,
		"ads_spread": 0.08,
		"move_spread": 1.0,
		"magazine_size": 15,
		"reload_time": 1.85,
		"ads_zoom": 2.2,
		"ads_sensitivity_mult": 0.5,
		"ads_move_mult": 0.55,
		"color": Color(0.2, 0.24, 0.22),
		"emission": Color(0.45, 0.9, 0.55),
		"model_scale": Vector3(0.1, 0.52, 0.11),
		"model_type": "long_rifle",
		"loadout_slot": 0,
		"sfx_fire": "gunfire_rifle",
		"sfx_heavy": "gunfire_sniper",
		"shake": 0.22,
		"recoil_pitch": 0.62,
	},
	"grenade_launcher": {
		"name": "Frag Launcher",
		"kind": WeaponKind.RANGED,
		"damage": 68,
		"heavy_damage": 115,
		"fire_rate": 0.95,
		"heavy_rate": 1.55,
		"range": 92.0,
		"spread": 0.15,
		"ads_spread": 0.0,
		"move_spread": 0.5,
		"magazine_size": 4,
		"reload_time": 2.15,
		"color": Color(0.28, 0.3, 0.26),
		"emission": Color(0.95, 0.55, 0.15),
		"model_scale": Vector3(0.14, 0.38, 0.16),
		"model_type": "grenade_launcher",
		"loadout_slot": 1,
		"projectile_type": "arc_explosive",
		"blast_radius": 6.5,
		"lob_speed": 46.0,
		"lob_speed_heavy": 54.0,
		"lob_range": 92.0,
		"lob_range_heavy": 112.0,
		"sfx_fire": "gunfire_launcher",
		"sfx_heavy": "gunfire_launcher",
		"shake": 0.42,
		"recoil_pitch": 0.85,
	},
	"rocket_launcher": {
		"name": "Krak Launcher",
		"kind": WeaponKind.HEAVY_RANGED,
		"damage": 125,
		"heavy_damage": 205,
		"fire_rate": 1.25,
		"heavy_rate": 2.05,
		"range": 62.0,
		"projectile_speed": 34.0,
		"spread": 0.0,
		"ads_spread": 0.0,
		"move_spread": 0.35,
		"magazine_size": 3,
		"reload_time": 2.75,
		"color": Color(0.32, 0.22, 0.18),
		"emission": Color(1.0, 0.28, 0.1),
		"model_scale": Vector3(0.18, 0.62, 0.18),
		"model_type": "rocket_launcher",
		"loadout_slot": 2,
		"traveling_projectile": true,
		"sfx_fire": "gunfire_launcher",
		"sfx_heavy": "gunfire_heavy",
		"shake": 0.58,
		"recoil_pitch": 1.05,
	},
	"lmg": {
		"name": "Heavy Stubber LMG",
		"kind": WeaponKind.HEAVY_RANGED,
		"damage": 22,
		"heavy_damage": 36,
		"fire_rate": 0.09,
		"heavy_rate": 0.48,
		"range": 78.0,
		"projectile_speed": 58.0,
		"spread": 1.6,
		"ads_spread": 0.45,
		"move_spread": 1.2,
		"magazine_size": 80,
		"reload_time": 3.1,
		"color": Color(0.26, 0.28, 0.32),
		"emission": Color(0.75, 0.82, 0.95),
		"model_scale": Vector3(0.12, 0.48, 0.14),
		"model_type": "lmg",
		"loadout_slot": 2,
		"sfx_fire": "gunfire_lmg",
		"sfx_heavy": "gunfire_lmg",
		"shake": 0.18,
		"recoil_pitch": 0.38,
	},
}

const LOOT_TO_WEAPON := {
	"Bolter Mk VII": "bolter",
	"Long Las Mk IV": "sniper_rifle",
	"Plasma Caster": "plasma_caster",
	"Void Reaper": "void_reaper",
	"Autopistol Mk III": "autopistol",
	"Meltagun Mk I": "meltagun",
	"Chainaxe": "chainaxe",
	"Autogun SMG": "smg",
	"Scout Rifle Mk II": "scout_rifle",
	"Frag Launcher": "grenade_launcher",
	"Krak Launcher": "rocket_launcher",
	"Heavy Stubber LMG": "lmg",
}

const LOADOUT_SLOT_COLORS := {
	0: Color(1.0, 1.0, 1.0),
	1: Color(0.25, 0.9, 0.35),
	2: Color(0.72, 0.38, 1.0),
}

const LOADOUT_SLOT_LABELS := {
	0: "Primary",
	1: "Secondary",
	2: "Heavy",
}

var equipped_id: String = "bolter"
var loadout: Array[String] = []
var active_slot: int = 0

func _ready() -> void:
	loadout = DEFAULT_LOADOUT.duplicate()
	equip_slot(0)

func apply_loot_weapon(item: Dictionary) -> void:
	var wid := weapon_id_from_loot(item)
	if wid.is_empty():
		return
	var slot: int = int(WEAPONS.get(wid, {}).get("loadout_slot", active_slot))
	if slot >= 0 and slot < loadout.size():
		loadout[slot] = wid
		equip_slot(slot)
	else:
		equip(wid)

func assign_test_weapon(weapon_id: String) -> bool:
	if not WEAPONS.has(weapon_id):
		return false
	var slot: int = clampi(int(WEAPONS[weapon_id].get("loadout_slot", active_slot)), 0, loadout.size() - 1)
	loadout[slot] = weapon_id
	equip_slot(slot)
	return true

func get_all_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for weapon_id in WEAPONS:
		ids.append(weapon_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return WEAPONS[a]["name"] < WEAPONS[b]["name"]
	)
	return ids

func get_weapon(id: String = "") -> Dictionary:
	var key := id if not id.is_empty() else equipped_id
	return WEAPONS.get(key, WEAPONS["bolter"]).duplicate()

func get_equipped() -> Dictionary:
	return get_weapon(equipped_id)

func get_loadout_weapon(slot: int) -> Dictionary:
	if slot < 0 or slot >= loadout.size():
		return {}
	return get_weapon(loadout[slot])

func equip(id: String) -> void:
	if not WEAPONS.has(id):
		return
	equipped_id = id
	weapon_changed.emit(equipped_id)

func equip_slot(slot: int) -> void:
	if slot < 0 or slot >= loadout.size():
		return
	var wid := loadout[slot]
	if not WEAPONS.has(wid):
		return
	active_slot = slot
	equip(wid)
	loadout_changed.emit(active_slot, equipped_id)

func cycle_primary_secondary() -> void:
	if active_slot == 0:
		equip_slot(1)
	elif active_slot == 1:
		equip_slot(0)
	else:
		equip_slot(0)

func equip_heavy() -> void:
	equip_slot(2)

func get_ads_fov(base_fov: float, default_ads_fov: float) -> float:
	var zoom: float = get_equipped().get("ads_zoom", 0.0)
	if zoom > 1.0:
		return base_fov / zoom
	return default_ads_fov

func get_ads_sensitivity_mult() -> float:
	return get_equipped().get("ads_sensitivity_mult", 0.55)

func get_ads_move_mult() -> float:
	return get_equipped().get("ads_move_mult", 0.55)

func weapon_id_from_loot(item: Dictionary) -> String:
	return LOOT_TO_WEAPON.get(item.get("name", ""), "")

func get_loot_loadout_slot(item: Dictionary) -> int:
	var wid := weapon_id_from_loot(item)
	if wid.is_empty():
		return 0
	return int(WEAPONS.get(wid, {}).get("loadout_slot", 0))

func get_loadout_slot_color(slot: int) -> Color:
	return LOADOUT_SLOT_COLORS.get(slot, LOADOUT_SLOT_COLORS[0])

func get_loadout_slot_label(slot: int) -> String:
	return LOADOUT_SLOT_LABELS.get(slot, "Primary")

func is_ranged(id: String = "") -> bool:
	var w := get_weapon(id)
	return w["kind"] == WeaponKind.RANGED or w["kind"] == WeaponKind.HEAVY_RANGED

func is_melee(id: String = "") -> bool:
	return not is_ranged(id)

func uses_ammo(id: String = "") -> bool:
	var w := get_weapon(id)
	return w.get("magazine_size", 0) > 0

func uses_traveling_projectile(id: String = "") -> bool:
	return bool(get_weapon(id).get("traveling_projectile", false))
