extends RefCounted
class_name CombatDamage

const CRIT_SPOT_GROUP := "enemy_crit_spot"
const DEFAULT_CRIT_SPOT_MULT := 2.5
const STAT_CRIT_DAMAGE_MULT := 2.0

static func find_enemy_from_node(node: Node) -> Node:
	var current: Node = node
	while current:
		if current.has_method("take_damage") and current.is_in_group("enemies"):
			return current
		current = current.get_parent()
	return null

static func parse_projectile_hit(collider: Object, hit_pos: Vector3 = Vector3.INF, from: Vector3 = Vector3.INF, to: Vector3 = Vector3.INF) -> Dictionary:
	var result := {
		"target": null,
		"crit_spot": false,
		"crit_multiplier": 1.0,
	}
	if collider is Area3D and (collider as Area3D).is_in_group(CRIT_SPOT_GROUP):
		result["target"] = find_enemy_from_node(collider as Node)
		result["crit_spot"] = result["target"] != null
		result["crit_multiplier"] = float(collider.get_meta("crit_multiplier", DEFAULT_CRIT_SPOT_MULT))
		return result
	if collider is Area3D:
		var area := collider as Area3D
		var owner := find_enemy_from_node(area)
		if owner == null and area.get_parent() and area.get_parent().has_method("take_damage"):
			owner = area.get_parent()
		if owner:
			result["target"] = owner
	elif collider is Node and (collider as Node).has_method("take_damage"):
		result["target"] = collider
	if result["target"] != null and hit_pos != Vector3.INF:
		if result["target"].has_method("evaluate_crit_zone"):
			var zone: Dictionary = result["target"].evaluate_crit_zone(hit_pos, from, to)
			if not zone.is_empty():
				result["crit_spot"] = true
				result["crit_multiplier"] = float(zone.get("mult", DEFAULT_CRIT_SPOT_MULT))
				return result
		var crit := find_crit_spot_on_enemy(result["target"], hit_pos, from, to)
		if crit:
			result["crit_spot"] = true
			result["crit_multiplier"] = float(crit.get_meta("crit_multiplier", DEFAULT_CRIT_SPOT_MULT))
	return result

static func find_crit_spot_on_enemy(enemy: Node, hit_pos: Vector3, from: Vector3 = Vector3.INF, to: Vector3 = Vector3.INF) -> Area3D:
	if not is_instance_valid(enemy):
		return null
	if enemy.has_method("evaluate_crit_zone"):
		return null
	for spot in enemy.find_children("*", "Area3D", true, false):
		if not spot.is_in_group(CRIT_SPOT_GROUP):
			continue
		var col := spot.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col == null:
			continue
		if col.shape is BoxShape3D:
			if hit_pos != Vector3.INF and _point_in_or_near_box(spot, col, hit_pos, 0.06):
				return spot
			if from != Vector3.INF and to != Vector3.INF and _segment_intersects_box(spot, col, from, to, 0.06):
				return spot
		elif col.shape is SphereShape3D:
			var radius: float = (col.shape as SphereShape3D).radius + 0.06
			if hit_pos != Vector3.INF and spot.global_position.distance_to(hit_pos) <= radius:
				return spot
			if from != Vector3.INF and to != Vector3.INF and segment_passes_near_sphere(from, to, spot.global_position, radius):
				return spot
	return null

static func _point_in_or_near_box(spot: Node3D, col: CollisionShape3D, world_point: Vector3, padding: float) -> bool:
	var local := spot.global_transform.affine_inverse() * world_point - col.position
	var half := (col.shape as BoxShape3D).size * 0.5 + Vector3.ONE * padding
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z

static func _segment_intersects_box(spot: Node3D, col: CollisionShape3D, from: Vector3, to: Vector3, padding: float) -> bool:
	return _point_in_or_near_box(spot, col, from.lerp(to, 0.5), padding)

static func segment_passes_near_sphere(from: Vector3, to: Vector3, center: Vector3, radius: float) -> bool:
	var seg := to - from
	var len_sq := seg.length_squared()
	if len_sq < 0.0001:
		return from.distance_to(center) <= radius
	var t := clampf((center - from).dot(seg) / len_sq, 0.0, 1.0)
	var closest := from + seg * t
	return closest.distance_to(center) <= radius

static func roll_player_damage(base: float, source: Node, crit_spot: bool, crit_multiplier: float) -> Dictionary:
	var amount := base
	var is_crit := false
	if crit_spot:
		amount *= crit_multiplier
		is_crit = true
	elif is_instance_valid(source) and source.is_in_group("player") and randf() < StatManager.get_stat("crit_chance"):
		amount *= STAT_CRIT_DAMAGE_MULT
		is_crit = true
	return {"amount": amount, "is_crit": is_crit}

static func has_line_of_sight(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return true
	var world := tree.root.get_world_3d()
	if world == null:
		return true
	var space := world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	return hit.is_empty()
