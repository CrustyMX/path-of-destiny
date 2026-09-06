extends Node

signal player_died
signal boss_defeated(boss_name: String)
signal boss_fight_started(boss: Node3D)
signal zone_entered(zone_name: String)
signal zone_cleared(zone_id: String)
signal zone_combat_started(zone_id: String, zone_name: String)
signal game_state_changed(state: GameState)
signal enemy_spawning_changed(enabled: bool)

enum GameState { EXPLORING, COMBAT, BOSS_FIGHT, LOOTING, PAUSED, DEAD }

var current_state: GameState = GameState.EXPLORING
var player: Node3D = null
var current_zone: String = "Ashfall Expanse"
const OVERWORLD_ZONE_NAME := "Ashfall Expanse"
var active_zone_id: String = ""
var zones_cleared: Array[String] = []
var bosses_defeated: Array[String] = []
var play_time: float = 0.0
var respawn_position: Vector3 = Vector3(0, 2, 98)
var boss_arena_position: Vector3 = Vector3.ZERO
var boss_arena_center: Vector3 = Vector3.ZERO
var boss_arena_radius: float = 15.0
var boss_fight_active: bool = false
var enemy_spawning_enabled: bool = true
var last_death_info: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_ensure_unpaused")

func _ensure_unpaused() -> void:
	if current_state != GameState.DEAD and current_state != GameState.PAUSED and current_state != GameState.LOOTING:
		get_tree().paused = false

func _process(delta: float) -> void:
	if current_state != GameState.PAUSED and current_state != GameState.DEAD and current_state != GameState.LOOTING:
		play_time += delta

func register_player(p: Node3D) -> void:
	player = p
	respawn_position = p.global_position

func set_state(state: GameState) -> void:
	current_state = state
	game_state_changed.emit(state)
	match state:
		GameState.PAUSED, GameState.DEAD, GameState.LOOTING:
			get_tree().paused = true
		_:
			get_tree().paused = false

func on_player_died(death_info: Dictionary = {}) -> void:
	last_death_info = death_info
	_clear_enemy_player_targets()
	set_state(GameState.DEAD)
	player_died.emit()

func is_player_alive() -> bool:
	if current_state == GameState.DEAD:
		return false
	if player == null or not is_instance_valid(player):
		return false
	return not player.is_dead

func _clear_enemy_player_targets() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.has_method("clear_player_target"):
			node.clear_player_target()
		elif node.get("target") != null:
			node.set("target", null)

func on_boss_fight_started(boss: Node3D) -> void:
	boss_fight_active = true
	set_state(GameState.BOSS_FIGHT)
	boss_fight_started.emit(boss)

func on_boss_defeated(boss_name: String) -> void:
	bosses_defeated.append(boss_name)
	boss_fight_active = false
	boss_defeated.emit(boss_name)
	set_state(GameState.EXPLORING)

func respawn_player() -> void:
	if player and player.has_method("respawn"):
		player.respawn(respawn_position)
	set_state(GameState.EXPLORING)
	get_tree().paused = false

func enter_zone(zone_name: String) -> void:
	current_zone = zone_name
	zone_entered.emit(zone_name)

func enter_combat_zone(zone_id: String, zone_name: String) -> void:
	active_zone_id = zone_id
	enter_zone(zone_name)
	set_state(GameState.COMBAT)
	zone_combat_started.emit(zone_id, zone_name)

func on_zone_cleared(zone_id: String) -> void:
	if zone_id != "" and zone_id not in zones_cleared:
		zones_cleared.append(zone_id)
	active_zone_id = ""
	zone_cleared.emit(zone_id)
	enter_zone(OVERWORLD_ZONE_NAME)
	set_state(GameState.EXPLORING)

func is_zone_cleared(zone_id: String) -> bool:
	return zone_id in zones_cleared

func count_zone_enemies(zone_id: String) -> int:
	if zone_id == "":
		return 0
	var count := 0
	for node in get_tree().get_nodes_in_group("zone_%s_enemies" % zone_id):
		if not is_instance_valid(node):
			continue
		if node.get("is_dead") == true:
			continue
		count += 1
	return count

func evict_enemies_from_area(center: Vector3, radius: float, exclude_boss: bool = true) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if exclude_boss and node.is_in_group("boss"):
			continue
		if not is_instance_valid(node):
			continue
		var flat := Vector2(node.global_position.x - center.x, node.global_position.z - center.z)
		if flat.length() > radius:
			continue
		var push_dir := flat
		if push_dir.length_squared() < 0.01:
			push_dir = Vector2(0.0, 1.0)
		else:
			push_dir = push_dir.normalized()
		var push_dist := radius + 3.0
		node.global_position = Vector3(
			center.x + push_dir.x * push_dist,
			node.global_position.y,
			center.z + push_dir.y * push_dist
		)
		if node.has_method("clear_player_target"):
			node.clear_player_target()

func set_enemy_spawning(enabled: bool, clear_existing: bool = false) -> void:
	if enemy_spawning_enabled == enabled and not (clear_existing and not enabled):
		return
	enemy_spawning_enabled = enabled
	if not enabled and clear_existing:
		clear_spawned_enemies()
	enemy_spawning_changed.emit(enabled)
	print("Enemy spawning: ", "ON" if enabled else "OFF")

func toggle_enemy_spawning(clear_on_disable: bool = true) -> void:
	set_enemy_spawning(not enemy_spawning_enabled, clear_on_disable)

func clear_spawned_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.is_in_group("boss"):
			continue
		if is_instance_valid(node):
			node.queue_free()

func is_inside_boss_arena(world_pos: Vector3, inset: float = 0.0) -> bool:
	if boss_arena_radius <= 0.0:
		return false
	var flat := Vector2(world_pos.x - boss_arena_center.x, world_pos.z - boss_arena_center.z)
	return flat.length() <= maxf(0.0, boss_arena_radius - inset)

func get_boss_arena_push_out_position(world_pos: Vector3, padding: float = 2.5) -> Vector3:
	var flat_pos := Vector2(world_pos.x - boss_arena_center.x, world_pos.z - boss_arena_center.z)
	if flat_pos.length_squared() < 0.01:
		flat_pos = Vector2(0.0, 1.0)
	else:
		flat_pos = flat_pos.normalized()
	var dist := boss_arena_radius + padding
	return Vector3(
		boss_arena_center.x + flat_pos.x * dist,
		world_pos.y,
		boss_arena_center.z + flat_pos.y * dist
	)

func evict_enemies_from_boss_arena(exclude_boss: bool = true) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if exclude_boss and node.is_in_group("boss"):
			continue
		if not is_instance_valid(node):
			continue
		if not is_inside_boss_arena(node.global_position):
			continue
		node.global_position = get_boss_arena_push_out_position(node.global_position)
		if node.has_method("clear_player_target"):
			node.clear_player_target()
