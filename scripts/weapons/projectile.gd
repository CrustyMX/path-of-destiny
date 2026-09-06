extends Area3D

const CD := preload("res://scripts/systems/combat_damage.gd")

var speed: float = 40.0
var damage: float = 20.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 3.0
var max_range: float = 120.0
var source: Node = null
var debug_shot_id: int = -1
var debug_camera: Camera3D = null
var use_tps_visual: bool = false
var visual_camera: Camera3D = null
var _dead: bool = false
var _hit_radius: float = 0.03
var _sweep_radius: float = 0.08
var _distance_traveled: float = 0.0
var _mesh_inst: MeshInstance3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_destroy)

func setup_bullet(color: Color, heavy: bool = false) -> void:
	_mesh_inst = $MeshInstance3D
	var tracer := BoxMesh.new()
	tracer.size = Vector3(0.02, 0.02, 0.07) if not heavy else Vector3(0.028, 0.028, 0.11)
	_mesh_inst.mesh = tracer
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	_mesh_inst.material_override = mat
	_hit_radius = 0.03 if not heavy else 0.04
	_sweep_radius = clampf(maxf(_hit_radius, speed * 0.0012), 0.05, 0.14)
	var col: CollisionShape3D = $CollisionShape3D
	var shape := SphereShape3D.new()
	shape.radius = _hit_radius
	col.shape = shape
	if use_tps_visual:
		_update_tps_visual()
	else:
		_mesh_inst.position = Vector3.ZERO
		_orient_to_direction()

func _orient_to_direction() -> void:
	if direction.length_squared() < 0.001:
		return
	var target := global_position + direction
	if global_position.distance_squared_to(target) < 0.0001:
		return
	if abs(direction.normalized().dot(Vector3.UP)) > 0.998:
		look_at(target, Vector3.RIGHT)
	else:
		look_at(target, Vector3.UP)

func _update_tps_visual() -> void:
	if not use_tps_visual or not _mesh_inst:
		return
	var cam := visual_camera if is_instance_valid(visual_camera) else get_viewport().get_camera_3d()
	if not cam:
		_mesh_inst.position = Vector3.ZERO
		return
	var cam_pos := cam.global_position
	var cam_fwd := (-cam.global_transform.basis.z).normalized()
	var depth := (global_position - cam_pos).dot(cam_fwd)
	if depth <= 0.05:
		_mesh_inst.position = Vector3.ZERO
		_orient_to_direction()
		return
	_mesh_inst.global_position = cam_pos + cam_fwd * depth
	var look_target := _mesh_inst.global_position + cam_fwd
	if abs(cam_fwd.dot(Vector3.UP)) > 0.998:
		_mesh_inst.look_at(look_target, Vector3.RIGHT)
	else:
		_mesh_inst.look_at(look_target, Vector3.UP)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var step := direction * speed * delta
	var max_substep := minf(0.12, _sweep_radius * 0.85)
	var remaining := step
	while remaining.length_squared() > 0.0001:
		var sub := remaining
		if sub.length() > max_substep:
			sub = sub.normalized() * max_substep
		var step_len := sub.length()
		if _distance_traveled + step_len > max_range:
			sub = direction * (max_range - _distance_traveled)
			step_len = sub.length()
			if step_len <= 0.0001:
				_destroy()
				return
		var from := global_position
		var hit := _cast_segment(from, sub)
		if not hit.is_empty():
			global_position = hit.position
			_update_tps_visual()
			_handle_collision(hit.collider, hit.position, from, from + sub)
			return
		global_position = from + sub
		_distance_traveled += step_len
		remaining -= sub
		_update_tps_visual()

func _cast_segment(from: Vector3, motion: Vector3) -> Dictionary:
	return cast_segment(get_world_3d().direct_space_state, from, motion, _exclude_rids(), _sweep_radius)

static func cast_segment(
	space: PhysicsDirectSpaceState3D,
	from: Vector3,
	motion: Vector3,
	exclude: Array[RID] = [],
	sweep_radius: float = 0.08
) -> Dictionary:
	if space == null or motion.length_squared() <= 0.0001:
		return {}
	var to := from + motion
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return hit
	var samples := maxi(2, int(ceil(motion.length() / maxf(0.08, sweep_radius * 0.5))))
	for i in range(samples):
		var t := float(i + 1) / float(samples)
		var sample_pos := from.lerp(to, t)
		var sweep_hit := _query_enemy_at_static(space, sample_pos, exclude, sweep_radius)
		if not sweep_hit.is_empty():
			return sweep_hit
	return {}

static func _query_enemy_at_static(
	space: PhysicsDirectSpaceState3D,
	pos: Vector3,
	exclude: Array[RID],
	sweep_radius: float
) -> Dictionary:
	var shape_query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = sweep_radius
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis.IDENTITY, pos)
	shape_query.collision_mask = 4
	shape_query.collide_with_areas = true
	shape_query.collide_with_bodies = true
	shape_query.exclude = exclude
	var overlaps := space.intersect_shape(shape_query, 8)
	for overlap in overlaps:
		var collider: Object = overlap.collider
		if collider is Area3D and (collider as Area3D).is_in_group("enemy_crit_spot"):
			continue
		return {"position": pos, "collider": collider}
	return {}

func _exclude_rids() -> Array[RID]:
	var exclude: Array[RID] = []
	if is_instance_valid(source) and source is CollisionObject3D:
		exclude.append((source as CollisionObject3D).get_rid())
	return exclude

func _query_enemy_at(pos: Vector3, exclude: Array[RID]) -> Dictionary:
	return _query_enemy_at_static(get_world_3d().direct_space_state, pos, exclude, _sweep_radius)

func _on_body_entered(body: Node3D) -> void:
	_handle_collision(body, global_position)

func _on_area_entered(area: Area3D) -> void:
	_handle_collision(area, global_position)

func _handle_collision(collider: Object, hit_pos: Vector3, from: Vector3 = Vector3.INF, to: Vector3 = Vector3.INF) -> void:
	if _dead:
		return
	if is_instance_valid(source) and collider == source:
		return
	var hit: Dictionary = CD.parse_projectile_hit(collider, hit_pos, from, to)
	var target: Node = hit.get("target")
	if target and (not is_instance_valid(source) or target != source):
		var damage_source = source if is_instance_valid(source) else null
		var rolled: Dictionary = CD.roll_player_damage(
			damage,
			damage_source,
			hit.get("crit_spot", false),
			float(hit.get("crit_multiplier", 1.0))
		)
		target.take_damage(rolled["amount"], damage_source, rolled["is_crit"], hit_pos, hit.get("crit_spot", false))
		_notify_hit(rolled["amount"])
		_destroy(hit_pos, false)
		return
	if collider is StaticBody3D:
		_destroy(hit_pos, true)
		return
	if collider is CharacterBody3D:
		_destroy(hit_pos, false)

func _resolve_damage_target(collider: Object) -> Node:
	if collider is Area3D:
		var parent := (collider as Area3D).get_parent()
		if parent and parent.has_method("take_damage"):
			return parent
	if collider is Node and (collider as Node).has_method("take_damage"):
		return collider as Node
	return null

func _notify_hit(amount: float) -> void:
	if source and source.has_signal("attack_landed"):
		source.attack_landed.emit(amount)

func _destroy(hit_pos: Vector3 = Vector3.INF, wall_hit: bool = false) -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	visible = false
	var impact_pos := global_position if hit_pos == Vector3.INF else hit_pos
	if debug_shot_id >= 0 and debug_camera and is_instance_valid(debug_camera):
		AimDebug.register_impact(debug_shot_id, impact_pos, debug_camera)
	if hit_pos != Vector3.INF:
		_spawn_hit_vfx(hit_pos)
		if wall_hit:
			CombatFeedback.register_wall_hit()
	queue_free()

func _spawn_hit_vfx(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	flash.mesh = s
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1, 0.6, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	flash.material_override = mat
	get_parent().add_child(flash)
	flash.global_position = pos
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3(0.05, 0.05, 0.05), 0.12)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)
