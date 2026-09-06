extends Node

signal panel_changed
signal track_changed
signal snapshot_changed

enum TrackCategory {
	STATS,
	COMBAT,
	PLAYER,
	WEAPONS,
	LOOT,
	AIM,
	GRENADE,
}

const TRACK_KEYS := [
	"stats",
	"combat",
	"player",
	"weapons",
	"loot",
	"aim",
	"grenade",
]

const TRACK_LABELS := {
	"stats": "Stats (StatManager)",
	"combat": "Combat log",
	"player": "Player vitals",
	"weapons": "Weapons & ammo",
	"loot": "Loot & gear",
	"aim": "Aim debug summary",
	"grenade": "Grenade debug summary",
}

const MAX_COMBAT_LOG := 10

var panel_visible: bool = false
var track_enabled: Dictionary = {
	"stats": true,
	"combat": true,
	"player": true,
	"weapons": true,
	"loot": true,
	"aim": false,
	"grenade": false,
}

var _combat_log: Array[String] = []
var _session_log: Array[String] = []
var _session_active: bool = false
var _last_outgoing: Dictionary = {}
var _last_incoming: Dictionary = {}
var _last_enemy_hit: Dictionary = {}
var _last_loot: Dictionary = {}
var _weapon_controller: Node = null

func _ready() -> void:
	StatManager.stats_rebuilt.connect(_on_snapshot_changed)
	WeaponLibrary.weapon_changed.connect(_on_snapshot_changed)
	WeaponLibrary.loadout_changed.connect(_on_snapshot_changed)
	LootManager.loot_collected.connect(_on_loot_collected)
	LootManager.inventory_changed.connect(_on_snapshot_changed)
	AimDebug.overlay_changed.connect(_on_snapshot_changed)
	GrenadeDebug.overlay_changed.connect(_on_snapshot_changed)
	call_deferred("_try_connect_player")

func _process(_delta: float) -> void:
	if _weapon_controller == null or not is_instance_valid(_weapon_controller):
		_try_connect_player()

func toggle_panel() -> void:
	panel_visible = not panel_visible
	if panel_visible:
		_begin_session()
	else:
		_end_session()
	print("Diag Panel: ", "ON" if panel_visible else "OFF")
	panel_changed.emit()

func is_tracking(key: String) -> bool:
	return track_enabled.get(key, false)

func set_tracking(key: String, enabled: bool) -> void:
	if not track_enabled.has(key):
		return
	if track_enabled[key] == enabled:
		return
	track_enabled[key] = enabled
	track_changed.emit()
	snapshot_changed.emit()

func toggle_tracking(key: String) -> void:
	set_tracking(key, not is_tracking(key))

func register_outgoing_damage(weapon_id: String, damage: float) -> void:
	_last_outgoing = _build_outgoing(weapon_id, damage)
	if is_tracking("combat"):
		var weapon_name: String = str(WeaponLibrary.get_weapon(weapon_id).get("name", weapon_id))
		_push_combat_log("OUT  %s → %.0f dmg (%s)" % [weapon_name, damage, weapon_id])
	snapshot_changed.emit()

func register_damage_taken(raw: float, reduced: float, source = null) -> void:
	_last_incoming = {
		"raw": raw,
		"reduced": reduced,
		"armor": StatManager.get_stat("armor"),
		"source": _describe_source(source),
		"time": Time.get_ticks_msec(),
	}
	if is_tracking("combat"):
		_push_combat_log("IN   %.0f → %.0f dmg (%s, armor %.0f)" % [
			raw, reduced, _last_incoming["source"], _last_incoming["armor"]
		])
	snapshot_changed.emit()

func register_enemy_hit(enemy: Node3D, amount: float, is_crit: bool, crit_spot: bool, is_kill: bool, hit_pos: Vector3 = Vector3.INF, hit_region: String = "") -> void:
	var target_name := "Enemy"
	if is_instance_valid(enemy):
		if enemy.is_in_group("boss"):
			target_name = "Boss"
		elif enemy.get("mob_id"):
			target_name = str(enemy.mob_id)
	var region := hit_region if hit_region != "" else "body"
	_last_enemy_hit = {
		"target": target_name,
		"amount": amount,
		"is_crit": is_crit,
		"crit_spot": crit_spot,
		"is_kill": is_kill,
		"region": region,
		"time": Time.get_ticks_msec(),
	}
	if is_tracking("combat"):
		var tag := "HIT"
		if crit_spot:
			tag = "CRIT SPOT"
		elif is_crit:
			tag = "CRIT"
		if is_kill:
			tag += " KILL"
		var extra := ""
		if hit_pos != Vector3.INF and is_instance_valid(enemy):
			var model := enemy.get_node_or_null("Model") as Node3D
			var local := model.to_local(hit_pos) if model else enemy.to_local(hit_pos)
			var space := "mdl" if model else "root"
			extra = " @%s(%.2f, %.2f, %.2f)" % [space, local.x, local.y, local.z]
		_push_combat_log("%s  %.0f dmg → %s [%s]%s" % [tag, amount, target_name, region, extra])
	snapshot_changed.emit()

func get_combat_log() -> Array[String]:
	return _active_combat_log().duplicate()

func get_session_log() -> Array[String]:
	return _session_log.duplicate()

func build_copy_text() -> String:
	var lines: PackedStringArray = ["=== Path of Destiny — Diag Report ===", ""]
	if is_tracking("stats"):
		lines.append("--- Stats ---")
		lines.append(_build_stats_text())
		lines.append("")
	if is_tracking("player"):
		lines.append("--- Player ---")
		lines.append(_build_player_text())
		lines.append("")
	if is_tracking("weapons"):
		lines.append("--- Weapons ---")
		lines.append(_build_weapons_text())
		lines.append("")
	if is_tracking("loot"):
		lines.append("--- Loot ---")
		lines.append(_build_loot_text())
		lines.append("")
	if is_tracking("combat"):
		lines.append("--- Combat ---")
		if _last_outgoing.is_empty():
			lines.append("Last outgoing: (none)")
		else:
			lines.append("Last outgoing: %s %.0f dmg" % [_last_outgoing.get("weapon_name", "?"), _last_outgoing.get("damage", 0.0)])
		if _last_incoming.is_empty():
			lines.append("Last incoming: (none)")
		else:
			lines.append("Last incoming: %.0f raw → %.0f after armor (%s)" % [
				_last_incoming.get("raw", 0.0),
				_last_incoming.get("reduced", 0.0),
				_last_incoming.get("source", "?"),
			])
		if _last_enemy_hit.is_empty():
			lines.append("Last enemy hit: (none)")
		else:
			var hit := _last_enemy_hit
			var kind := str(hit.get("region", "body"))
			if hit.get("crit_spot", false):
				kind = "%s (weak spot)" % kind
			elif hit.get("is_crit", false):
				kind = "%s (crit roll)" % kind
			lines.append("Last enemy hit: %.0f dmg [%s] → %s%s" % [
				hit.get("amount", 0.0),
				kind,
				hit.get("target", "?"),
				" KILL" if hit.get("is_kill", false) else "",
			])
		for entry in _active_combat_log():
			lines.append("  %s" % entry)
		if _session_active:
			lines.append("  (recording — %d events so far)" % _session_log.size())
		elif not _session_log.is_empty():
			lines.append("  (session: %d events)" % _session_log.size())
		lines.append("")
	if is_tracking("aim"):
		lines.append("--- Aim Debug ---")
		lines.append("Enabled: %s" % ("Yes" if AimDebug.enabled else "No"))
		var last_aim := AimDebug.get_last_report()
		if last_aim.is_empty():
			lines.append("Last shot: (none)")
		else:
			lines.append("Shot #%d: %s (%.0fpx)" % [
				last_aim.get("id", 0),
				AimDebug.describe_offset(last_aim),
				last_aim.get("distance_px", 0.0),
			])
		lines.append("")
	if is_tracking("grenade"):
		lines.append("--- Grenade Debug ---")
		lines.append("Enabled: %s" % ("Yes" if GrenadeDebug.enabled else "No"))
		var last_g := GrenadeDebug.get_last_report()
		if last_g.is_empty():
			lines.append("Last throw: (none)")
		else:
			lines.append(GrenadeDebug.describe_offset(last_g))
		lines.append("")
	lines.append("Tracked: %s" % ", ".join(_enabled_track_names()))
	return "\n".join(lines)

func _build_stats_text() -> String:
	var lines: PackedStringArray = []
	lines.append("damage (light): %.1f" % StatManager.get_stat("damage"))
	lines.append("damage (heavy): %.1f" % StatManager.get_stat("damage", {"heavy": true}))
	lines.append("fire_rate (light): %.3fs" % StatManager.get_stat("fire_rate"))
	lines.append("fire_rate (heavy): %.3fs" % StatManager.get_stat("fire_rate", {"heavy": true}))
	lines.append("armor: %.0f" % StatManager.get_stat("armor"))
	lines.append("move_speed: %.2fx" % StatManager.get_stat("move_speed"))
	lines.append("crit_chance: %.1f%%" % (StatManager.get_stat("crit_chance") * 100.0))
	lines.append("cooldown_reduction: %.1f%%" % (StatManager.get_stat("cooldown_reduction") * 100.0))
	lines.append("radar_range: %.0fm" % StatManager.get_stat("radar_range"))
	lines.append("health_pots bonus: +%.0f (max %d)" % [
		StatManager.get_stat("health_pots"),
		HealthPotionManager.get_max_potions(),
	])
	return "\n".join(lines)

func _build_player_text() -> String:
	var player := GameManager.player
	if not player:
		return "Player not ready"
	var lines: PackedStringArray = []
	lines.append("health: %.0f / %.0f" % [player.health, player.MAX_HEALTH])
	lines.append("stamina: %.0f / %.0f" % [player.stamina, player.MAX_STAMINA])
	lines.append("camera: %s" % ("1st person" if player.is_first_person() else "3rd person"))
	lines.append("ADS: %s" % ("Yes" if player.is_aiming_down_sights() else "No"))
	if player is CharacterBody3D:
		var horizontal := Vector2(player.velocity.x, player.velocity.z).length()
		lines.append("speed: %.1f m/s" % horizontal)
	lines.append("state: %s" % _game_state_name())
	return "\n".join(lines)

func _build_weapons_text() -> String:
	var w: Dictionary = WeaponLibrary.get_equipped()
	var lines: PackedStringArray = []
	lines.append("slot: %d" % (WeaponLibrary.active_slot + 1))
	lines.append("equipped: %s (%s)" % [w.get("name", "?"), WeaponLibrary.equipped_id])
	lines.append("kind: %s" % ("Ranged" if WeaponLibrary.is_ranged() else "Melee"))
	if WeaponLibrary.is_ranged():
		var zoom: float = w.get("ads_zoom", 0.0)
		if zoom > 1.0:
			lines.append("ADS zoom: %.1fx" % zoom)
	lines.append("StatManager dmg: %.0f / %.0f heavy" % [
		StatManager.get_stat("damage"),
		StatManager.get_stat("damage", {"heavy": true}),
	])
	if _weapon_controller and is_instance_valid(_weapon_controller):
		if _weapon_controller.has_method("is_reloading") and _weapon_controller.is_reloading():
			lines.append("ammo: reloading")
		elif WeaponLibrary.uses_ammo():
			lines.append("ammo: see HUD")
	else:
		lines.append("ammo: (controller not linked)")
	for i in range(WeaponLibrary.loadout.size()):
		var loadout_w := WeaponLibrary.get_loadout_weapon(i)
		var marker := ">" if i == WeaponLibrary.active_slot else " "
		lines.append("%s [%d] %s" % [marker, i + 1, loadout_w.get("name", "Empty")])
	return "\n".join(lines)

func _build_loot_text() -> String:
	var lines: PackedStringArray = []
	var armor := LootManager.equipped_armor
	if armor.is_empty():
		lines.append("equipped armor: (none)")
	else:
		lines.append("equipped armor: %s (def %d, %s)" % [
			armor.get("name", "?"),
			armor.get("defense", 0),
			LootManager.get_rarity_name(armor.get("rarity", 0)),
		])
		var armor_affix := AffixLibrary.format_affix_lines(armor.get("affixes", []))
		if not armor_affix.is_empty():
			lines.append(armor_affix)
	var weapon_lines: PackedStringArray = []
	for slot in LootManager.equipped_weapons.size():
		var slot_weapon: Dictionary = LootManager.get_equipped_weapon_for_slot(slot)
		if slot_weapon.is_empty():
			weapon_lines.append("%s: (default)" % WeaponLibrary.get_loadout_slot_label(slot))
		else:
			weapon_lines.append("%s: %s (dmg %d)" % [
				WeaponLibrary.get_loadout_slot_label(slot),
				slot_weapon.get("name", "?"),
				slot_weapon.get("damage", 0),
			])
			var weapon_affix := AffixLibrary.format_affix_lines(slot_weapon.get("affixes", []))
			if not weapon_affix.is_empty():
				weapon_lines.append(weapon_affix)
	if weapon_lines.is_empty():
		lines.append("equipped loot weapons: (none)")
	else:
		lines.append("equipped loot weapons:")
		for weapon_line in weapon_lines:
			lines.append("  %s" % weapon_line)
	lines.append("inventory count: %d" % LootManager.inventory.size())
	lines.append("total collected: %d" % LootManager.total_loot_collected)
	if not _last_loot.is_empty():
		lines.append("last pickup: %s [%s]" % [
			_last_loot.get("name", "?"),
			LootManager.get_rarity_name(_last_loot.get("rarity", 0)),
		])
		var last_affix := AffixLibrary.format_affix_lines(_last_loot.get("affixes", []))
		if not last_affix.is_empty():
			lines.append(last_affix)
	return "\n".join(lines)

func _build_combat_text() -> String:
	var lines: PackedStringArray = []
	if _last_outgoing.is_empty():
		lines.append("Last outgoing: (none)")
	else:
		lines.append("Last outgoing: %s → %.0f" % [
			_last_outgoing.get("weapon_name", "?"),
			_last_outgoing.get("damage", 0.0),
		])
	if _last_incoming.is_empty():
		lines.append("Last incoming: (none)")
	else:
		lines.append("Last incoming: %.0f raw → %.0f mitigated" % [
			_last_incoming.get("raw", 0.0),
			_last_incoming.get("reduced", 0.0),
		])
		lines.append("  source: %s | armor: %.0f" % [
			_last_incoming.get("source", "?"),
			_last_incoming.get("armor", 0.0),
		])
	if _last_enemy_hit.is_empty():
		lines.append("Last enemy hit: (none)")
	else:
		var hit := _last_enemy_hit
		var kind := str(hit.get("region", "body"))
		if hit.get("crit_spot", false):
			kind = "%s (weak spot)" % kind
		elif hit.get("is_crit", false):
			kind = "%s (crit roll)" % kind
		lines.append("Last enemy hit: %.0f dmg [%s] → %s%s" % [
			hit.get("amount", 0.0),
			kind,
			hit.get("target", "?"),
			" KILL" if hit.get("is_kill", false) else "",
		])
	if _active_combat_log().is_empty():
		lines.append("")
		if _session_active:
			lines.append("Session log: (recording — no events yet)")
		elif not _session_log.is_empty():
			lines.append("Session log: (empty — open panel F10 to record)")
		else:
			lines.append("Combat log empty")
	else:
		lines.append("")
		if _session_active:
			lines.append("Session log (%d events):" % _session_log.size())
		elif not _session_log.is_empty():
			lines.append("Last session (%d events):" % _session_log.size())
		else:
			lines.append("Recent:")
		for entry in _active_combat_log():
			lines.append("  %s" % entry)
	return "\n".join(lines)

func _build_aim_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Aim debug: %s (F3 toggle | F4 copy)" % ("ON" if AimDebug.enabled else "OFF"))
	var last := AimDebug.get_last_report()
	if last.is_empty():
		lines.append("Last shot: (none)")
	else:
		lines.append(AimDebug.describe_offset(last))
		lines.append("Distance: %.0fpx | %s | ADS: %s" % [
			last.get("distance_px", 0.0),
			last.get("camera_mode", "?"),
			"Yes" if last.get("ads", false) else "No",
		])
	return "\n".join(lines)

func _build_grenade_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Grenade debug: %s (F6 toggle | F7 copy)" % ("ON" if GrenadeDebug.enabled else "OFF"))
	lines.append("Grenades: %d / %d" % [GrenadeManager.grenade_count, GrenadeManager.MAX_GRENADES])
	var last := GrenadeDebug.get_last_report()
	if last.is_empty():
		lines.append("Last throw: (none)")
	else:
		lines.append("Explosion vs reticle: %s (%.0fpx)" % [
			GrenadeDebug.describe_offset(last),
			last.get("distance_px", 0.0),
		])
		lines.append("Arc peak vs reticle: %s (%.0fpx)" % [
			GrenadeDebug.describe_apex_offset(last),
			last.get("apex_distance_px", 0.0),
		])
	return "\n".join(lines)

func _build_options_text() -> String:
	var lines: PackedStringArray = ["Toggle tracks with checkboxes below.", ""]
	for key in TRACK_KEYS:
		var mark := "[x]" if is_tracking(key) else "[ ]"
		lines.append("%s %s" % [mark, TRACK_LABELS[key]])
	lines.append("")
	lines.append("F10 panel | F11 copy | [ ] tabs while playing")
	lines.append("F3/F4 aim | F6/F7 grenade | ` test weapons")
	return "\n".join(lines)

func get_tab_text(tab_key: String) -> String:
	if not is_tracking(tab_key) and tab_key != "options":
		return "Tracking disabled.\nEnable in Options tab."
	match tab_key:
		"stats":
			return _build_stats_text()
		"combat":
			return _build_combat_text()
		"player":
			return _build_player_text()
		"weapons":
			return _build_weapons_text()
		"loot":
			return _build_loot_text()
		"aim":
			return _build_aim_text()
		"grenade":
			return _build_grenade_text()
		"options":
			return _build_options_text()
	return ""

func _try_connect_player() -> void:
	var player := GameManager.player
	if not player or not player.has_node("WeaponController"):
		return
	var wc := player.get_node("WeaponController")
	if _weapon_controller == wc:
		return
	_weapon_controller = wc
	if not wc.fired.is_connected(_on_weapon_fired):
		wc.fired.connect(_on_weapon_fired)
	if wc.has_signal("ammo_changed") and not wc.ammo_changed.is_connected(_on_ammo_changed):
		wc.ammo_changed.connect(_on_ammo_changed)
	snapshot_changed.emit()

func _on_weapon_fired(weapon_id: String, damage: float) -> void:
	register_outgoing_damage(weapon_id, damage)

func _on_ammo_changed(_current: int, _maximum: int, _is_reloading: bool) -> void:
	snapshot_changed.emit()

func _on_loot_collected(item: Dictionary) -> void:
	_last_loot = item.duplicate()
	if is_tracking("loot"):
		var affix_hint := AffixLibrary.format_affix_lines(item.get("affixes", []))
		if affix_hint.is_empty():
			_push_combat_log("LOOT %s [%s]" % [
				item.get("name", "?"),
				LootManager.get_rarity_name(item.get("rarity", 0)),
			])
		else:
			_push_combat_log("LOOT %s [%s] | %s" % [
				item.get("name", "?"),
				LootManager.get_rarity_name(item.get("rarity", 0)),
				affix_hint.replace("\n", ", "),
			])
	snapshot_changed.emit()

func _on_snapshot_changed(_arg = null) -> void:
	snapshot_changed.emit()

func _build_outgoing(weapon_id: String, damage: float) -> Dictionary:
	return {
		"weapon_id": weapon_id,
		"weapon_name": WeaponLibrary.get_weapon(weapon_id).get("name", weapon_id),
		"damage": damage,
		"time": Time.get_ticks_msec(),
	}

func _begin_session() -> void:
	_session_active = true
	_session_log.clear()
	_combat_log.clear()
	_push_combat_log("--- Session started ---")

func _end_session() -> void:
	if _session_active:
		_push_combat_log("--- Session ended (%d events) ---" % maxi(0, _session_log.size() - 1))
	_session_active = false

func _active_combat_log() -> Array[String]:
	if not _session_log.is_empty():
		return _session_log
	return _combat_log

func _push_combat_log(entry: String) -> void:
	if _session_active:
		_session_log.append(entry)
		_combat_log.append(entry)
		return
	_combat_log.append(entry)
	while _combat_log.size() > MAX_COMBAT_LOG:
		_combat_log.pop_front()

func get_enabled_track_names() -> PackedStringArray:
	return _enabled_track_names()

func link_player(_player: Node = null) -> void:
	_try_connect_player()

func _enabled_track_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for key in TRACK_KEYS:
		if is_tracking(key):
			names.append(TRACK_LABELS[key])
	return names

func _describe_source(source) -> String:
	if source == null or not is_instance_valid(source):
		return "Unknown"
	if source.is_in_group("boss"):
		return str(source.get("BOSS_NAME")) if source.get("BOSS_NAME") else "Boss"
	if source.is_in_group("enemies"):
		return str(source.get("mob_id")) if source.get("mob_id") else "Enemy"
	if source.is_in_group("player"):
		return "Self"
	return source.name

func _game_state_name() -> String:
	match GameManager.current_state:
		GameManager.GameState.EXPLORING:
			return "Exploring"
		GameManager.GameState.BOSS_FIGHT:
			return "Boss fight"
		GameManager.GameState.PAUSED:
			return "Paused"
		GameManager.GameState.DEAD:
			return "Dead"
		_:
			return "Unknown"
