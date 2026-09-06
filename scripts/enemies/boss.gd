extends CharacterBody3D
class_name BossEnemy

signal phase_changed(phase: int)
signal health_changed(current: float, maximum: float)
signal boss_died

const BOSS_NAME := "The Corrupted Warmaster"
const MAX_HEALTH := 800.0
const WALK_SPEED := 3.5
const ATTACK_RANGE := 4.0
const GRAVITY := 20.0

enum Phase { PHASE_1, PHASE_2, ENRAGED }

@onready var model_container: Node3D = $Model
@onready var attack_area: Area3D = $AttackArea
@onready var hitbox: Area3D = $Hitbox

var health: float = MAX_HEALTH
var current_phase: Phase = Phase.PHASE_1
var target: Node3D = null
var attack_timer: float = 0.0
var attack_cooldown: float = 2.5
var is_attacking: bool = false
var is_active: bool = false
var aoe_timer: float = 0.0
var arena_center: Vector3 = Vector3.ZERO
var arena_radius: float = 14.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	_load_model()
	_build_crit_spots()
	health_changed.emit(health, MAX_HEALTH)

func _build_crit_spots() -> void:
	var root := Node3D.new()
	root.name = "CritSpots"
	add_child(root)
	_add_crit_spot(root, Vector3(0, 3.6, 0), Vector3(0.76, 0.76, 0.76), 2.25, "helm")
	_add_crit_spot(root, Vector3(0, 2.1, -0.35), Vector3(0.84, 0.84, 0.84), 1.85, "core")

func _add_crit_spot(parent: Node3D, local_pos: Vector3, size: Vector3, multiplier: float, label: String) -> void:
	var spot := Area3D.new()
	spot.name = "Crit_%s" % label
	spot.add_to_group("enemy_crit_spot")
	spot.collision_layer = 4
	spot.collision_mask = 0
	spot.position = local_pos
	spot.set_meta("crit_multiplier", multiplier)
	spot.set_meta("crit_label", label)
	spot.set_meta("crit_size", size)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	spot.add_child(col)
	var vis := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size * 0.94
	vis.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.34)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.08)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vis.material_override = mat
	spot.add_child(vis)
	parent.add_child(spot)

func _point_in_crit_box(local: Vector3, center: Vector3, size: Vector3, padding: float = 0.05) -> bool:
	var half := size * 0.5 + Vector3.ONE * padding
	var delta := local - center
	return absf(delta.x) <= half.x and absf(delta.y) <= half.y and absf(delta.z) <= half.z

func _segment_hits_crit_box(from: Vector3, to: Vector3, center: Vector3, size: Vector3, padding: float = 0.02) -> bool:
	var half := size * 0.5 + Vector3.ONE * padding
	var box_min := center - half
	var box_max := center + half
	var dir := to - from
	var tmin := 0.0
	var tmax := 1.0
	for axis in 3:
		if absf(dir[axis]) < 0.00001:
			if from[axis] < box_min[axis] or from[axis] > box_max[axis]:
				return false
			continue
		var inv_d := 1.0 / dir[axis]
		var t1 := (box_min[axis] - from[axis]) * inv_d
		var t2 := (box_max[axis] - from[axis]) * inv_d
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return false
	return true

func evaluate_crit_zone(hit_pos: Vector3, from: Vector3 = Vector3.INF, to: Vector3 = Vector3.INF) -> Dictionary:
	var zones := [
		{"pos": Vector3(0, 3.6, 0), "size": Vector3(0.76, 0.76, 0.76), "mult": 2.25, "label": "helm"},
		{"pos": Vector3(0, 2.1, -0.35), "size": Vector3(0.84, 0.84, 0.84), "mult": 1.85, "label": "core"},
	]
	for zone in zones:
		if hit_pos != Vector3.INF:
			var local_hit := to_local(hit_pos)
			if _point_in_crit_box(local_hit, zone["pos"], zone["size"]):
				return zone
		if from != Vector3.INF and to != Vector3.INF:
			var local_from := to_local(from)
			var local_to := to_local(to)
			if _segment_hits_crit_box(local_from, local_to, zone["pos"], zone["size"]):
				return zone
	return {}

func get_hit_region(hit_pos: Vector3) -> String:
	if hit_pos == Vector3.INF:
		return "unknown"
	var zone := evaluate_crit_zone(hit_pos)
	if not zone.is_empty():
		return str(zone.get("label", "weak spot"))
	var local := to_local(hit_pos)
	if local.y >= 2.6:
		return "upper"
	if local.y >= 1.4:
		return "torso"
	return "legs"

func _load_model() -> void:
	if ResourceLoader.exists("res://assets/models/boss.glb"):
		var scene := load("res://assets/models/boss.glb") as PackedScene
		if scene:
			var instance := scene.instantiate()
			model_container.add_child(instance)

func set_arena_bounds(center: Vector3, radius: float) -> void:
	arena_center = center
	arena_radius = radius

func activate(player: Node3D) -> void:
	is_active = true
	target = player
	collision_layer = 4
	if arena_center == Vector3.ZERO:
		arena_center = global_position

func clear_player_target() -> void:
	target = null

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if not GameManager.is_player_alive():
		target = null
		return
	if not target or not is_instance_valid(target):
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	# Leash boss inside arena
	var flat_pos := Vector3(global_position.x, 0, global_position.z)
	var flat_center := Vector3(arena_center.x, 0, arena_center.z)
	var from_center := flat_pos - flat_center
	if from_center.length() > arena_radius:
		var pull_dir := (flat_center - flat_pos).normalized()
		velocity.x = pull_dir.x * WALK_SPEED * 1.5
		velocity.z = pull_dir.z * WALK_SPEED * 1.5
		move_and_slide()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	aoe_timer += delta
	var dist := global_position.distance_to(target.global_position)
	# Don't chase player outside arena — hold position at edge
	var target_flat := Vector3(target.global_position.x, 0, target.global_position.z)
	if target_flat.distance_to(flat_center) > arena_radius:
		dist = ATTACK_RANGE + 1.0  # stop advancing
	if dist > ATTACK_RANGE and not is_attacking:
		var dir := (target.global_position - global_position).normalized()
		dir.y = 0
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
		if dir.length() > 0:
			var target_rot := atan2(dir.x, dir.z)
			model_container.rotation.y = lerp_angle(model_container.rotation.y, target_rot, 5.0 * delta)
	elif attack_timer <= 0 and not is_attacking:
		_perform_attack()
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED * 3 * delta)
	if current_phase == Phase.ENRAGED and aoe_timer >= 5.0:
		_perform_aoe_slam()
		aoe_timer = 0.0
	move_and_slide()

func _perform_attack() -> void:
	is_attacking = true
	CombatFeedback.register_attack_threat(self, 1.1, 1.15)
	attack_timer = attack_cooldown
	var damage := 25.0 if current_phase == Phase.PHASE_1 else 40.0
	await get_tree().create_timer(0.6).timeout
	if target and target.global_position.distance_to(global_position) <= ATTACK_RANGE + 1.5:
		if target.has_method("take_damage"):
			target.take_damage(damage, self)
	is_attacking = false

func _perform_aoe_slam() -> void:
	CombatFeedback.register_attack_threat(self, 1.0, 1.2)
	var slam_damage := 35.0
	for node in get_tree().get_nodes_in_group("player"):
		if node.global_position.distance_to(global_position) <= 8.0:
			if node.has_method("take_damage"):
				node.take_damage(slam_damage, self)
	_spawn_slam_vfx()

func _spawn_slam_vfx() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.0
	torus.outer_radius = 8.0
	ring.mesh = torus
	ring.rotation.x = PI / 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.05, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.05)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3(1.5, 1.5, 1.5), 0.8)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.tween_callback(ring.queue_free)

func take_damage(amount: float, source = null, is_crit: bool = false, hit_pos: Vector3 = Vector3.INF, crit_spot: bool = false) -> void:
	if not is_active:
		return
	health -= amount
	health_changed.emit(health, MAX_HEALTH)
	_flash_damage()
	if source != null and is_instance_valid(source) and source.is_in_group("player"):
		CombatFeedback.register_enemy_hit(self, amount, health <= 0.0, is_crit, hit_pos, crit_spot)
	var ratio := health / MAX_HEALTH
	if ratio <= 0.3 and current_phase != Phase.ENRAGED:
		current_phase = Phase.ENRAGED
		attack_cooldown = 1.5
		phase_changed.emit(3)
	elif ratio <= 0.6 and current_phase == Phase.PHASE_1:
		current_phase = Phase.PHASE_2
		attack_cooldown = 2.0
		phase_changed.emit(2)
	if health <= 0:
		_die()

func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(model_container, "scale", model_container.scale * 1.05, 0.08)
	tween.tween_property(model_container, "scale", Vector3.ONE, 0.12)

func _die() -> void:
	is_active = false
	boss_died.emit()
	GameManager.on_boss_defeated(BOSS_NAME)
	var tween := create_tween()
	tween.tween_property(model_container, "scale", Vector3(0.05, 0.05, 0.05), 1.5)
	tween.tween_callback(queue_free)
