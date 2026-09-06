extends Area3D

var velocity := Vector3.ZERO
var damage: float = 75.0
var blast_radius: float = 5.5
var fuse_time: float = 1.35
var source: Node = null
var _exploded: bool = false
var _flight_time: float = 0.0
var _arc_peak_pos: Vector3 = Vector3.ZERO
var _arc_peak_initialized: bool = false
const MAX_FLIGHT_TIME := 12.0
const SPAWN_GRACE := 0.12
const CONTACT_MASK := 1 | 4
const SWEEP_STEP := 0.35
const MIN_WORLD_Y := -12.0

func _ready() -> void:
	monitoring = true
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	collision_layer = 0
	collision_mask = CONTACT_MASK
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.3, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 1.5
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	if not _arc_peak_initialized:
		_arc_peak_pos = global_position
		_arc_peak_initialized = true
	_flight_time += delta
	if _flight_time >= MAX_FLIGHT_TIME:
		_explode()
		return
	var old_pos := global_position
	velocity.y -= GrenadeManager.GRENADE_GRAVITY * delta
	var new_pos := old_pos + velocity * delta
	if _sweep_motion(old_pos, new_pos):
		return
	global_position = new_pos
	if global_position.y >= _arc_peak_pos.y:
		_arc_peak_pos = global_position
	if global_position.y < MIN_WORLD_Y:
		_explode()

func _sweep_motion(from: Vector3, to: Vector3) -> bool:
	var motion := to - from
	var dist := motion.length()
	if dist < 0.001:
		return false
	var dir := motion / dist
	var traveled := 0.0
	var seg_start := from
	while traveled < dist:
		var seg_len := minf(SWEEP_STEP, dist - traveled)
		var seg_end := seg_start + dir * seg_len
		if _sweep_for_contact(seg_start, seg_end):
			return true
		seg_start = seg_end
		traveled += seg_len
	return false

func _sweep_for_contact(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = CONTACT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if _flight_time >= SPAWN_GRACE and is_instance_valid(source) and source is CollisionObject3D:
		query.exclude = [source.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	global_position = hit.position + hit.normal * 0.04
	_explode()
	return true

func _on_body_entered(body: Node) -> void:
	if _flight_time < SPAWN_GRACE:
		return
	if body == source:
		return
	_explode()

func _explode() -> void:
	if _exploded or not is_inside_tree():
		return
	_exploded = true
	var impact_pos := global_position
	if has_meta("debug_throw_id") and has_meta("debug_camera"):
		var debug_id: int = get_meta("debug_throw_id")
		var cam: Camera3D = get_meta("debug_camera")
		if is_instance_valid(cam):
			GrenadeDebug.register_impact(debug_id, impact_pos, cam, _arc_peak_pos)
	if has_meta("debug_aim_shot_id") and has_meta("debug_aim_camera"):
		var aim_debug_id: int = get_meta("debug_aim_shot_id")
		var aim_cam: Camera3D = get_meta("debug_aim_camera")
		if is_instance_valid(aim_cam):
			AimDebug.register_impact(aim_debug_id, impact_pos, aim_cam)
	set_physics_process(false)
	set_deferred("monitoring", false)
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		var enemy := node as Node3D
		if enemy.global_position.distance_to(global_position) > blast_radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, source if source else self)
	CombatFeedback.screen_shake(0.35 + blast_radius * 0.03)
	AudioManager.play_sfx("ability_aoe", 0.95, 0.85)
	_spawn_blast_vfx()
	queue_free()

func _spawn_blast_vfx() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = blast_radius * 0.35
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.05)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	mesh_instance.global_position = global_position + Vector3(0, 0.4, 0)
	var tween := mesh_instance.create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3(2.8, 2.8, 2.8), 0.35)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(mesh_instance.queue_free)
