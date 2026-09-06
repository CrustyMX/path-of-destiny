extends Node3D
class_name EnemySpawner

const MOB_SCENE := preload("res://scenes/enemies/mob_enemy.tscn")

signal mob_spawned(mob: Node)
signal mob_died(mob: Node)

@export var mob_types: Array[String] = ["cultist", "drone", "brute"]
@export var max_alive: int = 2
@export var respawn_delay: float = 18.0
@export var spawn_radius: float = 6.0
@export var activation_range: float = 42.0
@export var avoid_center: Vector3 = Vector3.ZERO
@export var avoid_radius: float = 18.0
@export var zone_id: String = ""
@export var respawn_enabled: bool = true
@export var zone_controlled: bool = false
@export var elite_chance: float = 0.12

var _alive: Array = []
var _respawn_timer: float = 0.0
var _initial_spawn_done: bool = false
var _zone_active: bool = false

func _ready() -> void:
	if zone_controlled:
		_zone_active = false

func set_zone_active(active: bool) -> void:
	_zone_active = active
	if not active:
		_respawn_timer = respawn_delay

func _process(delta: float) -> void:
	if zone_controlled and not _zone_active:
		return
	if not GameManager.enemy_spawning_enabled and not zone_controlled:
		return
	_alive = _alive.filter(func(m): return is_instance_valid(m))
	if _alive.size() >= max_alive:
		return
	if not respawn_enabled and _initial_spawn_done:
		return
	var player := GameManager.player
	if not player:
		return
	if player.global_position.distance_to(global_position) > activation_range:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_spawn_mob()
		_respawn_timer = respawn_delay

func _try_initial_spawn() -> void:
	if zone_controlled and not _zone_active:
		return
	if not GameManager.enemy_spawning_enabled and not zone_controlled:
		_initial_spawn_done = true
		return
	if _initial_spawn_done:
		return
	if not is_inside_tree():
		await get_tree().process_frame
	_initial_spawn_done = true
	for i in range(max_alive):
		if _spawn_mob():
			await get_tree().create_timer(0.15).timeout

func _spawn_mob() -> bool:
	if zone_controlled and not _zone_active:
		return false
	if not GameManager.enemy_spawning_enabled and not zone_controlled:
		return false
	if _alive.size() >= max_alive:
		return false
	var pos := _random_spawn_position()
	if pos == Vector3.INF:
		return false
	var mob = MOB_SCENE.instantiate()
	if not mob.get_script():
		mob.queue_free()
		return false
	mob.mob_id = mob_types[randi() % mob_types.size()]
	if zone_id != "" and mob.has_method("assign_zone"):
		mob.assign_zone(zone_id)
	mob.died.connect(_on_mob_died)
	get_parent().add_child(mob)
	mob.global_position = pos
	if elite_chance > 0.0 and randf() < elite_chance and mob.has_method("configure_elite"):
		mob.configure_elite()
	_alive.append(mob)
	mob_spawned.emit(mob)
	return true

func _random_spawn_position() -> Vector3:
	for _attempt in range(8):
		var angle := randf() * TAU
		var dist := randf_range(spawn_radius * 0.3, spawn_radius)
		var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var pos := global_position + offset
		if avoid_radius > 0.0:
			var flat := Vector2(pos.x - avoid_center.x, pos.z - avoid_center.z)
			if flat.length() < avoid_radius:
				continue
		if GameManager.boss_arena_radius > 0.0 and GameManager.is_inside_boss_arena(pos, 2.0):
			continue
		pos.y = 0.5
		return pos
	return Vector3.INF

func _on_mob_died(mob: Node) -> void:
	if respawn_enabled:
		_respawn_timer = minf(_respawn_timer, respawn_delay * 0.5)
	mob_died.emit(mob)
