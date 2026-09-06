extends Area3D
class_name ZoneTrigger

signal zone_started(zone_id: String)
signal zone_finished(zone_id: String)

enum ZonePhase { IDLE, ACTIVE, CLEARED }

@export var zone_id: String = "zone_ruins"
@export var zone_name: String = "Ruined Outpost"
@export var trigger_radius: float = 10.0
@export var barrier_radius: float = 14.0
@export var entrance_gap_degrees: float = 48.0
@export var reward_chest_offset: Vector3 = Vector3.ZERO
@export var reward_loot_kinds: Array[String] = ["weapon", "armor", "material"]
@export var spawner_configs: Array[Dictionary] = [
	{"offset": Vector3(-4, 0, 3), "types": ["cultist", "cultist"], "max": 2},
	{"offset": Vector3(4, 0, -2), "types": ["drone", "cultist"], "max": 2},
]

var phase: ZonePhase = ZonePhase.IDLE
var _inner_trigger: Area3D
var _trigger_label: Label3D
var _markers: Node3D
var _barrier_walls: Node3D
var _spawners_root: Node3D
var _spawners: Array = []
var _checking_clear: bool = false

const ENEMY_SPAWNER_SCRIPT := preload("res://scripts/systems/enemy_spawner.gd")
const REWARD_CHEST_SCENE := preload("res://scenes/systems/reward_chest.tscn")

func _ready() -> void:
	_build_scene_nodes()
	_inner_trigger.body_entered.connect(_on_inner_entered)
	_refresh_label()
	_setup_markers()
	_build_barrier_walls(false)
	_setup_spawners()
	if GameManager.is_zone_cleared(zone_id):
		phase = ZonePhase.CLEARED
		_trigger_label.visible = false

func _build_scene_nodes() -> void:
	_inner_trigger = Area3D.new()
	_inner_trigger.name = "InnerTrigger"
	var inner_col := CollisionShape3D.new()
	var inner_shape := CylinderShape3D.new()
	inner_shape.radius = trigger_radius
	inner_shape.height = 4.0
	inner_col.shape = inner_shape
	_inner_trigger.add_child(inner_col)
	_inner_trigger.collision_layer = 0
	_inner_trigger.collision_mask = 2
	add_child(_inner_trigger)
	_trigger_label = Label3D.new()
	_trigger_label.name = "TriggerLabel"
	_trigger_label.pixel_size = 0.01
	_trigger_label.font_size = 32
	_trigger_label.outline_size = 5
	_trigger_label.position = Vector3(0, 3.5, 0)
	_trigger_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_trigger_label)
	_markers = Node3D.new()
	_markers.name = "Markers"
	add_child(_markers)
	_barrier_walls = Node3D.new()
	_barrier_walls.name = "BarrierWalls"
	add_child(_barrier_walls)
	_spawners_root = Node3D.new()
	_spawners_root.name = "Spawners"
	add_child(_spawners_root)

func _refresh_label() -> void:
	if _trigger_label == null:
		return
	match phase:
		ZonePhase.CLEARED:
			_trigger_label.visible = false
		ZonePhase.ACTIVE:
			_trigger_label.text = "⚔ %s — Clear all hostiles" % zone_name
			_trigger_label.modulate = Color(1.0, 0.45, 0.2)
		_:
			_trigger_label.visible = true
			_trigger_label.text = "▶ Enter: %s" % zone_name
			_trigger_label.modulate = Color(0.55, 0.85, 1.0)

func _setup_markers() -> void:
	var floor_disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = barrier_radius - 1.0
	cylinder.bottom_radius = barrier_radius - 1.0
	cylinder.height = 0.06
	floor_disc.mesh = cylinder
	floor_disc.position.y = 0.03
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.45, 0.85, 0.28)
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.25, 0.65, 1.0)
	floor_mat.emission_energy_multiplier = 1.0
	floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_disc.material_override = floor_mat
	_markers.add_child(floor_disc)

func _setup_spawners() -> void:
	for cfg in spawner_configs:
		var spawner := Node3D.new()
		spawner.name = "ZoneSpawner_%s" % str(cfg.get("offset", Vector3.ZERO))
		spawner.position = cfg.get("offset", Vector3.ZERO)
		spawner.set_script(ENEMY_SPAWNER_SCRIPT)
		spawner.set("mob_types", cfg.get("types", ["cultist"]))
		spawner.set("max_alive", int(cfg.get("max", 2)))
		spawner.set("respawn_delay", 999.0)
		spawner.set("spawn_radius", 5.0)
		spawner.set("activation_range", barrier_radius + 4.0)
		spawner.set("avoid_center", Vector3.ZERO)
		spawner.set("avoid_radius", 0.0)
		spawner.set("zone_id", zone_id)
		spawner.set("respawn_enabled", false)
		spawner.set("zone_controlled", true)
		spawner.set("elite_chance", float(cfg.get("elite_chance", 0.18)))
		spawner.mob_spawned.connect(_on_mob_spawned)
		spawner.mob_died.connect(_on_mob_died)
		_spawners_root.add_child(spawner)
		_spawners.append(spawner)

func _build_barrier_walls(active: bool) -> void:
	for child in _barrier_walls.get_children():
		child.queue_free()
	if not active:
		return
	var gap_half := deg_to_rad(entrance_gap_degrees) * 0.5
	var gap_center := -PI * 0.5
	var segments := 18
	for i in range(segments):
		var angle := (float(i) / segments) * TAU
		var delta := absf(wrapf(angle - gap_center, -PI, PI))
		if delta < gap_half:
			continue
		var px := cos(angle) * barrier_radius
		var pz := sin(angle) * barrier_radius
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.6, 5.5, 0.7)
		col.shape = shape
		wall.add_child(col)
		wall.position = Vector3(px, 2.75, pz)
		wall.rotation.y = -angle + PI * 0.5
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.6, 5.5, 0.7)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.35, 0.55, 0.88)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.65, 1.0)
		mat.emission_energy_multiplier = 0.55
		mesh_inst.material_override = mat
		wall.add_child(mesh_inst)
		_barrier_walls.add_child(wall)

func _on_inner_entered(body: Node3D) -> void:
	if phase != ZonePhase.IDLE:
		return
	var player := _resolve_player(body)
	if player == null:
		return
	_start_zone(player)

func _resolve_player(body: Node3D) -> Node3D:
	if body.is_in_group("player") or body.name == "Player":
		return body
	if body.get_parent() and body.get_parent().is_in_group("player"):
		return body.get_parent()
	return null

func _start_zone(_player: Node3D) -> void:
	phase = ZonePhase.ACTIVE
	_refresh_label()
	GameManager.evict_enemies_from_area(global_position, barrier_radius - 1.0)
	GameManager.set_enemy_spawning(false, false)
	_build_barrier_walls(true)
	GameManager.enter_combat_zone(zone_id, zone_name)
	for spawner in _spawners:
		if spawner.has_method("set_zone_active"):
			spawner.set_zone_active(true)
		spawner.call_deferred("_try_initial_spawn")
	zone_started.emit(zone_id)

func _on_mob_spawned(_mob: Node) -> void:
	_checking_clear = false

func _on_mob_died(_mob: Node) -> void:
	if phase != ZonePhase.ACTIVE:
		return
	call_deferred("_check_zone_clear")

func _check_zone_clear() -> void:
	if phase != ZonePhase.ACTIVE or _checking_clear:
		return
	_checking_clear = true
	await get_tree().process_frame
	_checking_clear = false
	if phase != ZonePhase.ACTIVE:
		return
	if GameManager.count_zone_enemies(zone_id) > 0:
		return
	_finish_zone()

func _finish_zone() -> void:
	phase = ZonePhase.CLEARED
	_refresh_label()
	_build_barrier_walls(false)
	for spawner in _spawners:
		if spawner.has_method("set_zone_active"):
			spawner.set_zone_active(false)
	GameManager.set_enemy_spawning(true, false)
	GameManager.on_zone_cleared(zone_id)
	_spawn_reward_chest()
	zone_finished.emit(zone_id)

func _spawn_reward_chest() -> void:
	var chest := REWARD_CHEST_SCENE.instantiate()
	chest.configure(reward_loot_kinds, false)
	chest.global_position = global_position + _resolve_reward_chest_offset()
	get_parent().add_child(chest)

func _resolve_reward_chest_offset() -> Vector3:
	if reward_chest_offset != Vector3.ZERO:
		return reward_chest_offset
	var candidates: Array[Vector3] = [
		Vector3(5.0, 0.2, 0.0),
		Vector3(-5.0, 0.2, 0.0),
		Vector3(0.0, 0.2, 5.5),
		Vector3(0.0, 0.2, -5.5),
		Vector3(4.0, 0.2, 4.0),
		Vector3(-4.0, 0.2, 4.0),
	]
	for offset in candidates:
		if not _is_chest_position_blocked(global_position + offset):
			return offset
	return Vector3(5.0, 0.2, 0.0)

func _is_chest_position_blocked(world_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.4, 1.2)
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, world_pos + Vector3(0, 0.7, 0))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space.intersect_shape(query, 4).is_empty()
