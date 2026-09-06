extends CharacterBody3D
class_name MobEnemy

signal died(mob: MobEnemy)

const GRAVITY := 20.0
const ENEMY_PROJECTILE := preload("res://scenes/enemies/enemy_projectile.tscn")
const LOOT_PICKUP := preload("res://scenes/systems/loot_pickup.tscn")
const CD := preload("res://scripts/systems/combat_damage.gd")

const MOB_TYPES := {
	"cultist": {
		"name": "Heretic Cultist",
		"archetype": "melee",
		"health": 45.0,
		"speed": 4.8,
		"damage": 12.0,
		"attack_range": 2.2,
		"attack_cooldown": 1.1,
		"detect_range": 28.0,
		"color": Color(0.75, 0.12, 0.1),
		"emission": Color(1.0, 0.2, 0.1),
		"scale": Vector3(0.55, 0.9, 0.45),
		"shape": "humanoid",
		"hitbox": {"body_r": 0.13, "body_h": 0.86, "body_y": 0.40, "hit_r": 0.17, "hit_h": 0.98, "hit_y": 0.52},
		"headshot_min_y": 99.0,
		"crit_zones": [{"model_pos": Vector3(0, 1.28, -0.06), "model_size": Vector3(0.30, 0.28, 0.28), "mult": 2.5, "label": "head"}],
	},
	"drone": {
		"name": "Scavenger Drone",
		"archetype": "ranged",
		"health": 32.0,
		"speed": 3.2,
		"damage": 9.0,
		"attack_range": 22.0,
		"preferred_range": 14.0,
		"attack_cooldown": 1.8,
		"projectile_speed": 32.0,
		"projectile_spread": 3.5,
		"detect_range": 32.0,
		"color": Color(0.15, 0.55, 0.35),
		"emission": Color(0.2, 1.0, 0.5),
		"scale": Vector3(0.7, 0.7, 0.7),
		"shape": "sphere",
		"hover_lift": 1.0,
		"hover_height": 1.2,
		"hitbox": {
			"use_box": true,
			"model_pos": Vector3(0, 0.30, 0),
			"model_size": Vector3(0.92, 0.52, 0.92),
			"follow_model": true,
		},
		"headshot_min_y": 99.0,
		"crit_zones": [],
	},
	"brute": {
		"name": "Plague Brute",
		"archetype": "melee",
		"health": 130.0,
		"speed": 2.8,
		"damage": 24.0,
		"attack_range": 2.8,
		"attack_cooldown": 1.8,
		"detect_range": 24.0,
		"color": Color(0.18, 0.22, 0.16),
		"emission": Color(0.4, 0.9, 0.15),
		"scale": Vector3(0.85, 1.15, 0.75),
		"shape": "brute",
		"hitbox": {"body_r": 0.26, "body_h": 1.28, "body_y": 0.68, "hit_r": 0.32, "hit_h": 1.45, "hit_y": 0.72},
		"headshot_min_y": 99.0,
		"crit_zones": [{"model_pos": Vector3(0, 1.68, 0.02), "model_size": Vector3(0.38, 0.36, 0.36), "mult": 2.5, "label": "head"}],
	},
}

const ELITE_MODIFIERS := {
	"fortified": {"name": "Fortified", "hp_mult": 2.35, "dmg_mult": 1.2, "speed_mult": 0.9},
	"enraged": {"name": "Enraged", "hp_mult": 1.7, "dmg_mult": 1.5, "speed_mult": 1.08},
	"swift": {"name": "Swift", "hp_mult": 1.4, "dmg_mult": 1.12, "speed_mult": 1.32},
}

@export var mob_id: String = "cultist"

@onready var model_container: Node3D = $Model
@onready var hitbox: Area3D = $Hitbox
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var name_label: Label3D = $NameLabel

var zone_id: String = ""
var is_elite: bool = false
var elite_modifier_id: String = ""
var health: float = 45.0
var max_health: float = 45.0
var target: Node3D = null
var attack_timer: float = 0.0
var is_attacking: bool = false
var is_dead: bool = false
var _data: Dictionary = {}
var _hover_offset: float = 0.0
var _hover_lift: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	_data = MOB_TYPES.get(mob_id, MOB_TYPES["cultist"]).duplicate()
	max_health = _data["health"]
	health = max_health
	_build_visual()
	if _is_hoverer():
		call_deferred("_snap_hover_spawn")
	else:
		call_deferred("_snap_to_ground")
	if zone_id != "":
		_apply_zone_group()
	if name_label:
		name_label.text = "☠ %s" % _data.get("name", "Enemy")
		name_label.modulate = Color(1.0, 0.3, 0.15, 1.0)

func assign_zone(id: String) -> void:
	zone_id = id
	_apply_zone_group()

func configure_elite(forced_modifier: String = "") -> void:
	if is_elite:
		return
	is_elite = true
	add_to_group("elite_enemies")
	var mod_keys := ELITE_MODIFIERS.keys()
	elite_modifier_id = forced_modifier if ELITE_MODIFIERS.has(forced_modifier) else mod_keys[randi() % mod_keys.size()]
	var mod: Dictionary = ELITE_MODIFIERS[elite_modifier_id]
	max_health *= mod.get("hp_mult", 1.0)
	health = max_health
	_data["damage"] = float(_data.get("damage", 10.0)) * mod.get("dmg_mult", 1.0)
	_data["speed"] = float(_data.get("speed", 4.0)) * mod.get("speed_mult", 1.0)
	if name_label:
		name_label.text = "★ %s %s" % [mod.get("name", "Elite"), _data.get("name", "Enemy")]
		name_label.modulate = Color(1.0, 0.78, 0.18, 1.0)
	_apply_elite_visual()

func _apply_elite_visual() -> void:
	model_container.scale = _data.get("scale", Vector3.ONE) * 1.1
	var ring := model_container.get_node_or_null("HostileRing")
	if ring:
		ring.scale = Vector3(1.35, 1.0, 1.35)
		if ring is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.72, 0.12, 0.65)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.65, 0.08)
			mat.emission_energy_multiplier = 3.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			(ring as MeshInstance3D).material_override = mat
	var crown := MeshInstance3D.new()
	crown.name = "EliteCrown"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.14
	cyl.height = 0.28
	crown.mesh = cyl
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(1.0, 0.82, 0.2)
	crown_mat.emission_enabled = true
	crown_mat.emission = Color(1.0, 0.72, 0.12)
	crown_mat.emission_energy_multiplier = 2.8
	crown.material_override = crown_mat
	crown.position.y = 1.55 if _data.get("shape", "") != "sphere" else 0.85
	model_container.add_child(crown)

func _apply_zone_group() -> void:
	if zone_id == "":
		return
	add_to_group("zone_%s_enemies" % zone_id)

func _make_mat(color: Color, emission: Color, energy: float = 1.4) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.metallic = 0.45
	mat.roughness = 0.45
	return mat

func _add_part(container: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = mat
	part.position = pos
	part.rotation = rot
	container.add_child(part)

func _build_visual() -> void:
	for child in model_container.get_children():
		child.queue_free()
	var body_mat := _make_mat(_data["color"], _data["emission"])
	var accent_mat := _make_mat(Color(0.08, 0.08, 0.1), _data["emission"], 2.0)
	match _data.get("shape", "humanoid"):
		"sphere":
			_build_drone_visual(body_mat, accent_mat)
		"brute":
			_build_brute_visual(body_mat, accent_mat)
		_:
			_build_cultist_visual(body_mat, accent_mat)
	_add_hostile_marker()
	model_container.scale = _data.get("scale", Vector3.ONE)
	if _is_hoverer():
		_hover_lift = float(_data.get("hover_lift", 1.0))
		model_container.position.y = _hover_lift
	_setup_hitboxes()
	_build_crit_spots()
	if _is_hoverer():
		_sync_floating_hitbox()

func _setup_hitboxes() -> void:
	var cfg: Dictionary = _data.get("hitbox", {})
	if cfg.is_empty():
		return
	var hit_col: CollisionShape3D = hitbox.get_node("CollisionShape3D")
	var scale_vec: Vector3 = _data.get("scale", Vector3.ONE)
	if cfg.get("use_box", false):
		var model_size: Vector3 = cfg.get("model_size", Vector3.ONE)
		var model_pos: Vector3 = cfg.get("model_pos", Vector3.ZERO)
		var body_size := Vector3(
			model_size.x * scale_vec.x,
			model_size.y * scale_vec.y,
			model_size.z * scale_vec.z
		)
		var hit_size := body_size * 1.05
		var body_shape := BoxShape3D.new()
		body_shape.size = body_size
		body_collision.shape = body_shape
		var hit_shape := BoxShape3D.new()
		hit_shape.size = hit_size
		hit_col.shape = hit_shape
		hit_col.position = Vector3.ZERO
		var center := _model_local_to_body_offset(model_pos)
		body_collision.position = center
		hitbox.position = center
		return
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = float(cfg.get("body_r", 0.35))
	body_shape.height = float(cfg.get("body_h", 1.2))
	body_collision.shape = body_shape
	body_collision.position = Vector3(0, float(cfg.get("body_y", 0.65)), 0)
	var hit_shape := CapsuleShape3D.new()
	hit_shape.radius = float(cfg.get("hit_r", 0.45))
	hit_shape.height = float(cfg.get("hit_h", 1.4))
	hit_col.shape = hit_shape
	hit_col.position = Vector3.ZERO
	hitbox.position = Vector3(0, float(cfg.get("hit_y", 0.7)), 0)

func _model_local_to_body_offset(model_pos: Vector3) -> Vector3:
	var scaled := Vector3(
		model_pos.x * model_container.scale.x,
		model_pos.y * model_container.scale.y,
		model_pos.z * model_container.scale.z
	)
	return model_container.position + scaled

func _is_hoverer() -> bool:
	return _data.get("shape") == "sphere"

func _snap_hover_spawn() -> void:
	if not _is_hoverer():
		return
	global_position.y = float(_data.get("hover_height", 1.2))
	velocity.y = 0.0

func _snap_to_ground() -> void:
	if _is_hoverer() or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var probe_from := global_position + Vector3(0, 4.0, 0)
	var probe_to := global_position + Vector3(0, -8.0, 0)
	var query := PhysicsRayQueryParameters3D.create(probe_from, probe_to)
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	global_position.y = float(hit.position.y) - _get_collision_bottom_local()
	velocity.y = 0.0

func _get_collision_bottom_local() -> float:
	var col := body_collision
	if col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		return col.position.y - cap.height * 0.5 - cap.radius
	if col.shape is BoxShape3D:
		var box := col.shape as BoxShape3D
		return col.position.y - box.size.y * 0.5
	return 0.0

func _build_crit_spots() -> void:
	var old := model_container.get_node_or_null("CritSpots")
	if old:
		old.queue_free()
	var root := Node3D.new()
	root.name = "CritSpots"
	model_container.add_child(root)
	for zone in _data.get("crit_zones", []):
		var model_pos: Vector3 = zone.get("model_pos", zone.get("pos", Vector3.ZERO))
		var size: Vector3 = _zone_size(zone)
		_add_crit_spot(root, model_pos, size, float(zone.get("mult", 2.5)), str(zone.get("label", "spot")))

func _zone_size(zone: Dictionary) -> Vector3:
	if zone.has("model_size"):
		return zone["model_size"]
	var radius: float = float(zone.get("model_radius", zone.get("radius", 0.12)))
	return Vector3.ONE * radius * 2.0

func _point_in_crit_box(local: Vector3, center: Vector3, size: Vector3, padding: float = 0.02) -> bool:
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
	for zone in _data.get("crit_zones", []):
		var center: Vector3 = zone.get("model_pos", zone.get("pos", Vector3.ZERO))
		var size: Vector3 = _zone_size(zone)
		if hit_pos != Vector3.INF:
			var local_hit := model_container.to_local(hit_pos)
			if _point_in_crit_box(local_hit, center, size):
				return {
					"mult": float(zone.get("mult", 2.5)),
					"label": str(zone.get("label", "spot")),
				}
		if from != Vector3.INF and to != Vector3.INF:
			var local_from := model_container.to_local(from)
			var local_to := model_container.to_local(to)
			if _segment_hits_crit_box(local_from, local_to, center, size):
				return {
					"mult": float(zone.get("mult", 2.5)),
					"label": str(zone.get("label", "spot")),
				}
	return {}

func get_hit_region(hit_pos: Vector3) -> String:
	if hit_pos == Vector3.INF:
		return "unknown"
	var zone := evaluate_crit_zone(hit_pos)
	if not zone.is_empty():
		return str(zone.get("label", "weak spot"))
	var local := model_container.to_local(hit_pos)
	match _data.get("shape", "humanoid"):
		"sphere":
			if local.y >= 0.08:
				return "body"
			return "legs"
		"brute":
			if local.y >= 0.55:
				return "torso"
			return "legs"
		_:
			if local.y >= 0.45:
				return "torso"
			return "legs"

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
	mat.albedo_color = Color(1.0, 0.55, 0.12, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.42, 0.08)
	mat.emission_energy_multiplier = 1.35
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vis.material_override = mat
	spot.add_child(vis)
	parent.add_child(spot)

func _build_cultist_visual(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 0.95
	_add_part(model_container, body, body_mat, Vector3(0, 0.72, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.30, 0.28, 0.28)
	_add_part(model_container, head, accent_mat, Vector3(0, 1.28, -0.06))
	var shoulder_l := BoxMesh.new()
	shoulder_l.size = Vector3(0.18, 0.12, 0.28)
	_add_part(model_container, shoulder_l, body_mat, Vector3(-0.34, 1.0, 0))
	var shoulder_r := BoxMesh.new()
	shoulder_r.size = Vector3(0.18, 0.12, 0.28)
	_add_part(model_container, shoulder_r, body_mat, Vector3(0.34, 1.0, 0))
	var visor := BoxMesh.new()
	visor.size = Vector3(0.18, 0.05, 0.06)
	_add_part(model_container, visor, accent_mat, Vector3(0, 1.28, -0.19))

func _build_drone_visual(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var core := BoxMesh.new()
	core.size = Vector3(0.55, 0.28, 0.55)
	_add_part(model_container, core, body_mat, Vector3(0, 0.35, 0))
	var core_face := BoxMesh.new()
	core_face.size = Vector3(0.14, 0.14, 0.06)
	_add_part(model_container, core_face, accent_mat, Vector3(0, 0.38, -0.27))
	for i in range(4):
		var angle := (float(i) / 4.0) * TAU
		var leg := BoxMesh.new()
		leg.size = Vector3(0.06, 0.5, 0.06)
		var lx := cos(angle) * 0.38
		var lz := sin(angle) * 0.38
		_add_part(model_container, leg, accent_mat, Vector3(lx, 0.05, lz), Vector3(0.35, angle, 0))

func _build_brute_visual(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var leg_l := BoxMesh.new()
	leg_l.size = Vector3(0.32, 0.44, 0.32)
	_add_part(model_container, leg_l, body_mat, Vector3(-0.22, 0.22, 0))
	var leg_r := BoxMesh.new()
	leg_r.size = Vector3(0.32, 0.44, 0.32)
	_add_part(model_container, leg_r, body_mat, Vector3(0.22, 0.22, 0))
	var torso := BoxMesh.new()
	torso.size = Vector3(0.85, 1.05, 0.55)
	_add_part(model_container, torso, body_mat, Vector3(0, 0.95, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.38, 0.36, 0.36)
	_add_part(model_container, head, accent_mat, Vector3(0, 1.68, 0.02))
	var arm_l := BoxMesh.new()
	arm_l.size = Vector3(0.28, 0.75, 0.28)
	_add_part(model_container, arm_l, body_mat, Vector3(-0.58, 0.88, 0))
	var arm_r := BoxMesh.new()
	arm_r.size = Vector3(0.28, 0.75, 0.28)
	_add_part(model_container, arm_r, body_mat, Vector3(0.58, 0.88, 0))

func _add_hostile_marker() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "HostileRing"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.03
	ring.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.05, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.05)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position.y = 0.02
	model_container.add_child(ring)

func _sync_floating_hitbox() -> void:
	var cfg: Dictionary = _data.get("hitbox", {})
	if not cfg.get("follow_model", false):
		return
	if cfg.get("use_box", false):
		var center := _model_local_to_body_offset(cfg.get("model_pos", Vector3.ZERO))
		body_collision.position = center
		hitbox.position = center
		return
	hitbox.position = model_container.position + Vector3(0, float(cfg.get("hit_y", 0.98)), 0)
	body_collision.position = model_container.position + Vector3(0, float(cfg.get("body_y", 0.95)), 0)

func _apply_gravity(delta: float) -> void:
	if _is_hoverer():
		velocity.y = 0.0
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _is_hoverer():
		_hover_offset += delta * 3.0
		model_container.position.y = _hover_lift + sin(_hover_offset) * 0.12
		_sync_floating_hitbox()
	if not GameManager.is_player_alive():
		target = null
		velocity.x = move_toward(velocity.x, 0, _data["speed"] * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, _data["speed"] * 3 * delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	_apply_gravity(delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	if not target or not is_instance_valid(target):
		_acquire_target()
		move_and_slide()
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > _data.get("detect_range", 25.0):
		target = null
		velocity.x = move_toward(velocity.x, 0, _data["speed"] * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, _data["speed"] * 3 * delta)
		move_and_slide()
		return
	if _enforce_boss_arena_exclusion(delta):
		move_and_slide()
		return
	match _data.get("archetype", "melee"):
		"ranged":
			_ai_ranged(delta, dist)
		_:
			_ai_melee(delta, dist)
	move_and_slide()

func _acquire_target() -> void:
	if not GameManager.is_player_alive():
		target = null
		return
	var player := GameManager.player
	if player and is_instance_valid(player):
		target = player

func clear_player_target() -> void:
	target = null

func _enforce_boss_arena_exclusion(delta: float) -> bool:
	if GameManager.is_inside_boss_arena(global_position, 0.5):
		global_position = GameManager.get_boss_arena_push_out_position(global_position)
		target = null
		velocity.x = move_toward(velocity.x, 0, _data["speed"] * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, _data["speed"] * 3 * delta)
		return true
	if target and is_instance_valid(target):
		if GameManager.is_inside_boss_arena(target.global_position, 1.0):
			if not GameManager.is_inside_boss_arena(global_position, 1.0):
				target = null
				velocity.x = move_toward(velocity.x, 0, _data["speed"] * 3 * delta)
				velocity.z = move_toward(velocity.z, 0, _data["speed"] * 3 * delta)
				return true
	return false

func _clamp_velocity_for_arena(vel: Vector3) -> Vector3:
	if GameManager.boss_arena_radius <= 0.0:
		return vel
	if GameManager.is_inside_boss_arena(global_position, 1.5):
		return Vector3.ZERO
	var next_pos := global_position + Vector3(vel.x, 0.0, vel.z) * 0.2
	if GameManager.is_inside_boss_arena(next_pos, 1.0):
		return Vector3.ZERO
	return vel

func _face_target(delta: float) -> void:
	if not target:
		return
	var dir := target.global_position - global_position
	dir.y = 0
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	model_container.rotation.y = lerp_angle(model_container.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)

func _ai_melee(delta: float, dist: float) -> void:
	var attack_range: float = _data.get("attack_range", 2.0)
	var speed: float = _data["speed"]
	if dist > attack_range and not is_attacking:
		var dir := (target.global_position - global_position).normalized()
		dir.y = 0
		var move_vel := Vector3(dir.x * speed, 0.0, dir.z * speed)
		move_vel = _clamp_velocity_for_arena(move_vel)
		velocity.x = move_vel.x
		velocity.z = move_vel.z
		_face_target(delta)
	elif attack_timer <= 0.0 and not is_attacking:
		_perform_melee_attack()
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 3 * delta)
		_face_target(delta)

func _ai_ranged(delta: float, dist: float) -> void:
	var preferred: float = _data.get("preferred_range", 14.0)
	var speed: float = _data["speed"]
	var dir := (target.global_position - global_position).normalized()
	dir.y = 0
	_face_target(delta)
	if dist < preferred - 2.0:
		var retreat := Vector3(-dir.x * speed, 0.0, -dir.z * speed)
		retreat = _clamp_velocity_for_arena(retreat)
		velocity.x = retreat.x
		velocity.z = retreat.z
	elif dist > preferred + 2.0:
		var advance := Vector3(dir.x * speed * 0.7, 0.0, dir.z * speed * 0.7)
		advance = _clamp_velocity_for_arena(advance)
		velocity.x = advance.x
		velocity.z = advance.z
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 2 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 2 * delta)
	if attack_timer <= 0.0 and dist <= _data.get("attack_range", 22.0):
		if not _can_attack_across_arena():
			return
		if not _has_line_of_sight_to_target():
			return
		_perform_ranged_attack()

func _attack_origin() -> Vector3:
	if _is_hoverer():
		var cfg: Dictionary = _data.get("hitbox", {})
		if cfg.get("use_box", false):
			return global_position + _model_local_to_body_offset(cfg.get("model_pos", Vector3(0, 0.30, 0)))
		return global_position + Vector3(0, _hover_lift + float(cfg.get("body_y", 0.35)), 0)
	return global_position + Vector3(0, 1.2, 0)

func _can_attack_across_arena() -> bool:
	if not target or not is_instance_valid(target):
		return false
	var player_inside := GameManager.is_inside_boss_arena(target.global_position, 1.0)
	var mob_inside := GameManager.is_inside_boss_arena(global_position, 1.0)
	return player_inside == mob_inside

func _has_line_of_sight_to_target() -> bool:
	if not target or not is_instance_valid(target):
		return false
	var from := _attack_origin()
	var to := target.global_position + Vector3(0, 1.2, 0)
	var exclude: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	return CD.has_line_of_sight(from, to, exclude)

func _perform_melee_attack() -> void:
	is_attacking = true
	CombatFeedback.register_attack_threat(self, 1.15, 1.1)
	attack_timer = _data.get("attack_cooldown", 1.2)
	var windup := 0.35 if mob_id == "brute" else 0.25
	await get_tree().create_timer(windup).timeout
	if is_dead or not target or not is_instance_valid(target):
		is_attacking = false
		return
	if global_position.distance_to(target.global_position) <= _data.get("attack_range", 2.0) + 0.45:
		if target.has_method("take_damage"):
			target.take_damage(_data["damage"], self)
		_flash_attack()
	is_attacking = false

func _perform_ranged_attack() -> void:
	is_attacking = true
	CombatFeedback.register_attack_threat(self, 0.95, 1.0)
	attack_timer = _data.get("attack_cooldown", 1.8)
	if not target or not is_instance_valid(target):
		is_attacking = false
		return
	if not _can_attack_across_arena():
		is_attacking = false
		return
	var aim_point := target.global_position + Vector3(0, 1.2, 0)
	if target is CharacterBody3D:
		var lead_time: float = global_position.distance_to(target.global_position) / float(_data.get("projectile_speed", 32.0))
		aim_point += (target as CharacterBody3D).velocity * lead_time * 0.65
	var aim := (aim_point - _attack_origin()).normalized()
	aim = _apply_attack_spread(aim, _data.get("projectile_spread", 3.5))
	var proj := ENEMY_PROJECTILE.instantiate()
	proj.damage = _data["damage"]
	proj.speed = _data.get("projectile_speed", 32.0)
	proj.max_range = _data.get("attack_range", 22.0) + 8.0
	proj.direction = aim
	proj.source = self
	get_parent().add_child(proj)
	proj.global_position = _attack_origin() + aim * 0.5
	if proj.has_method("setup_bullet"):
		proj.setup_bullet(_data["emission"])
	is_attacking = false

func _apply_attack_spread(dir: Vector3, spread_deg: float) -> Vector3:
	var spread_rad := deg_to_rad(spread_deg)
	var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	up = right.cross(dir).normalized()
	var yaw := randf_range(-spread_rad, spread_rad)
	var pitch := randf_range(-spread_rad, spread_rad)
	return (dir + right * tan(yaw) + up * tan(pitch)).normalized()

func take_damage(amount: float, source = null, is_crit: bool = false, hit_pos: Vector3 = Vector3.INF, crit_spot: bool = false) -> void:
	if is_dead:
		return
	health -= amount
	_flash_damage()
	if source != null and is_instance_valid(source) and source.is_in_group("player"):
		CombatFeedback.register_enemy_hit(self, amount, health <= 0.0, is_crit, hit_pos, crit_spot)
	if health <= 0.0:
		_die()

func _flash_damage() -> void:
	if is_dead:
		return
	var base_scale: Vector3 = _data.get("scale", Vector3.ONE)
	var pulse := Vector3(base_scale.x * 1.08, base_scale.y * 1.08, base_scale.z * 1.08)
	var tween := create_tween()
	tween.tween_property(model_container, "scale", pulse, 0.06)
	tween.tween_property(model_container, "scale", base_scale, 0.1)

func _flash_attack() -> void:
	var swipe := MeshInstance3D.new()
	var arc := BoxMesh.new()
	arc.size = Vector3(_data.get("attack_range", 2.0) * 1.6, 0.05, 0.5)
	swipe.mesh = arc
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = _data["emission"]
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.45
	swipe.material_override = mat
	model_container.add_child(swipe)
	swipe.position = Vector3(0, 0.6, -_data.get("attack_range", 2.0) * 0.4)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(swipe.queue_free)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	var drop_pos := global_position
	collision_layer = 0
	died.emit(self)
	var drop_chance := 0.78 if is_elite else 0.35
	if randf() < drop_chance:
		_drop_loot(drop_pos)
	var tween := create_tween()
	tween.tween_property(model_container, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
	tween.tween_callback(queue_free)

func _drop_loot(at_position: Vector3) -> void:
	var parent := get_parent()
	if not parent:
		parent = get_tree().current_scene
	if not parent:
		return
	var pickup := LOOT_PICKUP.instantiate()
	if is_elite:
		var tables: Array[String] = ["weapon", "armor", "exploration"]
		pickup.configure_loot(LootManager.roll_loot(tables[randi() % tables.size()], 0.22))
	else:
		pickup.loot_table = ["exploration", "exploration", "armor"][randi() % 3]
	parent.add_child(pickup)
	pickup.global_position = at_position + Vector3(0, 0.5, 0)
