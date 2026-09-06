extends Area3D

var speed: float = 28.0
var damage: float = 10.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 4.0
var max_range: float = 80.0
var source: Node = null
var _dead: bool = false
var _hit_radius: float = 0.025
var _distance_traveled: float = 0.0

func setup_bullet(color: Color) -> void:
	var mesh_inst: MeshInstance3D = $MeshInstance3D
	var tracer := BoxMesh.new()
	tracer.size = Vector3(0.018, 0.018, 0.06)
	mesh_inst.mesh = tracer
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.5
	mesh_inst.material_override = mat
	var col: CollisionShape3D = $CollisionShape3D
	var shape := SphereShape3D.new()
	shape.radius = _hit_radius
	col.shape = shape
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

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_destroy)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var step := direction * speed * delta
	var step_len := step.length()
	if step_len < 0.0001:
		return
	if _distance_traveled + step_len > max_range:
		step = direction * (max_range - _distance_traveled)
		step_len = step.length()
		if step_len <= 0.0001:
			_destroy()
			return
	var from := global_position
	var hit := _cast_segment(from, step)
	if not hit.is_empty():
		global_position = hit.position
		_handle_hit(hit.collider, hit.position)
		return
	global_position = from + step
	_distance_traveled += step_len

func _cast_segment(from: Vector3, motion: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var to := from + motion
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var exclude: Array[RID] = []
	if is_instance_valid(source) and source is CollisionObject3D:
		exclude.append((source as CollisionObject3D).get_rid())
	query.exclude = exclude
	return space.intersect_ray(query)

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body, global_position)

func _handle_hit(body: Node3D, hit_pos: Vector3) -> void:
	if _dead:
		return
	if is_instance_valid(source) and body == source:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		if GameManager.current_state == GameManager.GameState.DEAD:
			_destroy(hit_pos)
			return
		var damage_source = source if is_instance_valid(source) else null
		body.take_damage(damage, damage_source)
		_destroy(hit_pos)
	elif body is StaticBody3D:
		_destroy(hit_pos)

func _destroy(hit_pos: Vector3 = Vector3.INF) -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	visible = false
	if hit_pos != Vector3.INF:
		_spawn_hit_vfx(hit_pos)
	queue_free()

func _spawn_hit_vfx(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.04
	flash.mesh = s
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.15)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	flash.material_override = mat
	get_parent().add_child(flash)
	flash.global_position = pos
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3(0.05, 0.05, 0.05), 0.1)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)
