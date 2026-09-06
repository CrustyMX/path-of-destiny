extends Node

signal grenades_changed(count: int, max_count: int)
signal throw_cooldown_updated(remaining: float, total: float)
signal recharge_updated(remaining: float, total: float)

const GRENADE_SCRIPT := preload("res://scripts/weapons/grenade.gd")

const MAX_GRENADES := 3
const THROW_COOLDOWN := 0.9
const GRENADE_RECHARGE_TIME := 10.0
const GRENADE_DAMAGE := 75.0
const GRENADE_RADIUS := 5.5
const GRENADE_FUSE := 1.35
const GRENADE_THROW_SPEED := 22.0
const GRENADE_MAX_RANGE := 42.0
const GRENADE_GRAVITY := 18.0
const GRENADE_CLOSE_LOB_RANGE := 8.0
const GRENADE_LAND_PITCH_REF := 0.78
const GRENADE_LAND_MIN_FRAC := 0.58
const GRENADE_LAND_FALLOFF_EXP := 0.48

var grenade_count: int = MAX_GRENADES
var _cooldown: float = 0.0
var _recharge_timer: float = 0.0

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
		throw_cooldown_updated.emit(_cooldown, THROW_COOLDOWN)
	if grenade_count < MAX_GRENADES:
		if _recharge_timer > 0.0:
			_recharge_timer = maxf(0.0, _recharge_timer - delta)
			recharge_updated.emit(_recharge_timer, GRENADE_RECHARGE_TIME)
		if _recharge_timer <= 0.0:
			grenade_count += 1
			grenades_changed.emit(grenade_count, MAX_GRENADES)
			if grenade_count < MAX_GRENADES:
				_recharge_timer = GRENADE_RECHARGE_TIME
				recharge_updated.emit(_recharge_timer, GRENADE_RECHARGE_TIME)
			else:
				_recharge_timer = 0.0
				recharge_updated.emit(0.0, GRENADE_RECHARGE_TIME)

func can_throw() -> bool:
	return grenade_count > 0 and _cooldown <= 0.0

func throw_grenade(player: Node3D, aim_point: Vector3) -> bool:
	if not can_throw() or not is_instance_valid(player):
		return false
	grenade_count -= 1
	_cooldown = THROW_COOLDOWN
	grenades_changed.emit(grenade_count, MAX_GRENADES)
	throw_cooldown_updated.emit(_cooldown, THROW_COOLDOWN)
	if grenade_count < MAX_GRENADES and _recharge_timer <= 0.0:
		_recharge_timer = GRENADE_RECHARGE_TIME
		recharge_updated.emit(_recharge_timer, GRENADE_RECHARGE_TIME)
	var grenade := Area3D.new()
	grenade.set_script(GRENADE_SCRIPT)
	grenade.damage = GRENADE_DAMAGE
	grenade.blast_radius = GRENADE_RADIUS
	grenade.fuse_time = GRENADE_FUSE
	grenade.source = player
	var origin := _get_throw_origin(player)
	var aim_dir := Vector3.ZERO
	var camera: Camera3D = null
	if player.has_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D"):
		camera = player.get_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D")
	if player.has_method("get_aim_direction"):
		aim_dir = player.get_aim_direction()
	var space := player.get_world_3d().direct_space_state if is_instance_valid(player) else null
	grenade.velocity = _compute_reticle_trajectory(origin, camera, aim_dir, GRENADE_GRAVITY, space)
	var predicted_apex := _predict_apex(origin, grenade.velocity, GRENADE_GRAVITY)
	var debug_id := GrenadeDebug.register_throw(_build_throw_debug(player, origin, predicted_apex, aim_point, grenade.velocity))
	if debug_id >= 0:
		grenade.set_meta("debug_throw_id", debug_id)
		if player.has_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D"):
			grenade.set_meta("debug_camera", player.get_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D"))
	var parent: Node = player.get_parent()
	if parent:
		parent.add_child(grenade)
	var throw_dir: Vector3 = grenade.velocity.normalized()
	if throw_dir.length_squared() > 0.001:
		grenade.global_position = origin + throw_dir * 0.18
	else:
		grenade.global_position = origin
	AudioManager.play_sfx("ability_aoe", 0.55, 1.15)
	return true

func spawn_weapon_grenade(
	player: Node3D,
	throw_speed: float,
	max_range: float,
	damage: float,
	blast_radius: float,
	debug_shot_id: int = -1,
	debug_camera: Camera3D = null
) -> Vector3:
	if not is_instance_valid(player):
		return Vector3.ZERO
	var origin := _get_throw_origin(player)
	var aim_dir := Vector3(0, 0, -1)
	var camera: Camera3D = null
	if player.has_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D"):
		camera = player.get_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D")
	if player.has_method("get_aim_direction"):
		aim_dir = player.get_aim_direction()
	var space := player.get_world_3d().direct_space_state
	var launch_velocity := _compute_reticle_trajectory(origin, camera, aim_dir, GRENADE_GRAVITY, space, throw_speed, max_range)
	var grenade := Area3D.new()
	grenade.set_script(GRENADE_SCRIPT)
	grenade.damage = damage
	grenade.blast_radius = blast_radius
	grenade.fuse_time = 0.0
	grenade.source = player
	grenade.velocity = launch_velocity
	grenade.scale = Vector3(1.28, 1.28, 1.28)
	if debug_shot_id >= 0 and is_instance_valid(debug_camera):
		grenade.set_meta("debug_aim_shot_id", debug_shot_id)
		grenade.set_meta("debug_aim_camera", debug_camera)
		grenade.set_meta("debug_launch_velocity", launch_velocity)
	var parent: Node = player.get_parent()
	if not parent:
		return Vector3.ZERO
	parent.add_child(grenade)
	var launch_dir: Vector3 = grenade.velocity.normalized()
	if launch_dir.length_squared() > 0.001:
		grenade.global_position = origin + launch_dir * 0.18
	else:
		grenade.global_position = origin
	return launch_velocity

func compute_arc_velocity(
	origin: Vector3,
	camera: Camera3D,
	aim_dir: Vector3,
	throw_speed: float,
	max_range: float,
	space: PhysicsDirectSpaceState3D
) -> Vector3:
	return _compute_reticle_trajectory(origin, camera, aim_dir, GRENADE_GRAVITY, space, throw_speed, max_range)

func compute_velocity_to_target(
	origin: Vector3,
	target: Vector3,
	speed: float,
	gravity: float,
	prefer_high_arc: bool = true
) -> Vector3:
	var delta := target - origin
	var horiz := Vector2(delta.x, delta.z)
	var dx := horiz.length()
	var dy := delta.y
	if dx < 0.08:
		if delta.length_squared() < 0.001:
			return Vector3(0, speed, 0)
		return delta.normalized() * speed
	var v2 := speed * speed
	var v4 := v2 * v2
	var disc := v4 - gravity * (gravity * dx * dx + 2.0 * dy * v2)
	if disc < 0.0:
		if prefer_high_arc:
			var low_arc := compute_velocity_to_target(origin, target, speed, gravity, false)
			if low_arc.length_squared() > 0.001:
				return low_arc
		var max_dx := v2 / gravity
		if dx > 0.01 and max_dx < dx:
			var scaled := target
			var scale := max_dx * 0.98 / dx
			scaled.x = origin.x + delta.x * scale
			scaled.z = origin.z + delta.z * scale
			return compute_velocity_to_target(origin, scaled, speed, gravity, true)
		var horiz_dir := Vector3(horiz.x / dx, 0.0, horiz.y / dx)
		return horiz_dir * (speed * cos(0.62)) + Vector3.UP * (speed * sin(0.62))
	var root := sqrt(disc)
	var tan_theta := (v2 + root) / (gravity * dx) if prefer_high_arc else (v2 - root) / (gravity * dx)
	var cos_theta := 1.0 / sqrt(1.0 + tan_theta * tan_theta)
	var sin_theta := tan_theta * cos_theta
	var horiz_dir := Vector3(horiz.x / dx, 0.0, horiz.y / dx)
	return horiz_dir * (speed * cos_theta) + Vector3.UP * (speed * sin_theta)

func _clamp_target_horiz(origin: Vector3, target: Vector3, max_range: float) -> Vector3:
	var horiz := Vector2(target.x - origin.x, target.z - origin.z)
	var dist := horiz.length()
	if dist <= max_range or dist < 0.01:
		return target
	var scale := max_range / dist
	return Vector3(
		origin.x + (target.x - origin.x) * scale,
		target.y,
		origin.z + (target.z - origin.z) * scale
	)

func clamp_throw_target(origin: Vector3, target: Vector3) -> Vector3:
	var offset := target - origin
	var dist := offset.length()
	if dist <= GRENADE_MAX_RANGE or dist < 0.01:
		return target
	return origin + offset / dist * GRENADE_MAX_RANGE

func _get_throw_origin(player: Node3D) -> Vector3:
	var hand := player.global_position + Vector3(0, 1.15, 0)
	if player.has_method("get_aim_direction"):
		return hand + player.get_aim_direction() * 0.35
	return hand

func _compute_reticle_trajectory(
	origin: Vector3,
	camera: Camera3D,
	aim_dir: Vector3,
	gravity: float,
	space: PhysicsDirectSpaceState3D,
	throw_speed: float = GRENADE_THROW_SPEED,
	max_range: float = GRENADE_MAX_RANGE
) -> Vector3:
	var v0 := throw_speed
	var dir := aim_dir.normalized() if aim_dir.length_squared() > 0.001 else Vector3(0, 0, -1)
	if not is_instance_valid(camera):
		return dir * v0
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.001:
		flat = Vector3(0, 0, -1)
	else:
		flat = flat.normalized()
	var first_person := origin.distance_to(camera.global_position) < 1.2
	var yaw_range := 0.05 if first_person else 0.14
	var aim_pitch := asin(clampf(dir.y, -1.0, 1.0))
	var best_vel := _launch_from_pitch_yaw(flat, aim_pitch, 0.0, v0)
	var best_err := INF
	var coarse_pitch_min := aim_pitch - 0.25
	var coarse_pitch_max := minf(maxf(aim_pitch + 1.35, 0.85), aim_pitch + 0.82)
	for pi in range(72):
		var pitch := lerpf(coarse_pitch_min, coarse_pitch_max, float(pi) / 71.0)
		pitch = clampf(pitch, -1.4, 1.45)
		for yi in range(49):
			var yaw := lerpf(-yaw_range, yaw_range, float(yi) / 48.0)
			var vel := _launch_from_pitch_yaw(flat, pitch, yaw, v0)
			if vel.y <= 0.02:
				continue
			var err := _trajectory_screen_error(origin, vel, gravity, camera, center, space, aim_pitch, max_range, throw_speed)
			if err < best_err:
				best_err = err
				best_vel = vel
	var best_launch := best_vel.normalized()
	var best_flat := Vector3(best_launch.x, 0.0, best_launch.z)
	var best_yaw := 0.0
	if best_flat.length_squared() > 0.001:
		best_yaw = atan2(best_flat.x, best_flat.z) - atan2(flat.x, flat.z)
		if best_yaw > PI:
			best_yaw -= TAU
		elif best_yaw < -PI:
			best_yaw += TAU
	var best_pitch := asin(clampf(best_launch.y, -1.0, 1.0))
	var fine_yaw := yaw_range * 0.35
	for pi in range(32):
		var pitch := lerpf(best_pitch - 0.06, best_pitch + 0.06, float(pi) / 31.0)
		pitch = clampf(pitch, -1.4, 1.45)
		for yi in range(24):
			var yaw := lerpf(best_yaw - fine_yaw, best_yaw + fine_yaw, float(yi) / 23.0)
			var vel := _launch_from_pitch_yaw(flat, pitch, yaw, v0)
			if vel.y <= 0.02:
				continue
			var err := _trajectory_screen_error(origin, vel, gravity, camera, center, space, aim_pitch, max_range, throw_speed)
			if err < best_err:
				best_err = err
				best_vel = vel
	if best_vel.y <= 0.05:
		var fallback_pitch := maxf(aim_pitch, 0.28)
		best_vel = _launch_from_pitch_yaw(flat, fallback_pitch, 0.0, v0)
	return best_vel

func _target_landing_horiz(aim_pitch: float, max_range: float = GRENADE_MAX_RANGE) -> float:
	var t := clampf(maxf(aim_pitch, 0.0) / GRENADE_LAND_PITCH_REF, 0.0, 1.0)
	var falloff := pow(t, GRENADE_LAND_FALLOFF_EXP)
	var frac := lerpf(1.0, GRENADE_LAND_MIN_FRAC, falloff)
	return max_range * frac

func _launch_from_pitch_yaw(flat_dir: Vector3, pitch: float, yaw: float, speed: float) -> Vector3:
	var rotated := flat_dir.rotated(Vector3.UP, yaw)
	var cp := cos(pitch)
	var sp := sin(pitch)
	return Vector3(rotated.x * cp, sp, rotated.z * cp) * speed

func _trajectory_screen_error(
	origin: Vector3,
	velocity: Vector3,
	gravity: float,
	camera: Camera3D,
	center: Vector2,
	space: PhysicsDirectSpaceState3D,
	aim_pitch: float,
	max_range: float = GRENADE_MAX_RANGE,
	throw_speed: float = GRENADE_THROW_SPEED
) -> float:
	var apex_err := _apex_screen_error(origin, velocity, gravity, camera, center)
	var err := apex_err * 2.0
	if apex_err > 22.0:
		err += (apex_err - 22.0) * 3.0
	if space == null:
		return err
	var landing := _predict_landing(origin, velocity, gravity, space)
	var land_screen := camera.unproject_position(landing)
	var land_screen_err := land_screen.distance_to(center)
	err += land_screen_err * 0.85
	var land_horiz := Vector2(landing.x - origin.x, landing.z - origin.z).length()
	var target_land := _target_landing_horiz(aim_pitch, max_range)
	var speed_scale := throw_speed / GRENADE_THROW_SPEED
	var range_scale := max_range / GRENADE_MAX_RANGE
	var short_weight := 95.0 * speed_scale * range_scale
	if land_horiz < target_land:
		var short_ratio := (target_land - land_horiz) / maxf(target_land, 1.0)
		err += short_ratio * short_ratio * short_weight
	if land_horiz > max_range:
		var over_ratio := (land_horiz - max_range) / maxf(max_range, 1.0)
		err += over_ratio * over_ratio * 60.0 * range_scale
	return err

func _predict_landing(origin: Vector3, velocity: Vector3, gravity: float, space: PhysicsDirectSpaceState3D) -> Vector3:
	var pos := origin
	var vel := velocity
	var dt := 0.032
	for _i in range(200):
		var next_vel := vel + Vector3(0.0, -gravity * dt, 0.0)
		var mid := pos + vel * dt * 0.5
		var next_pos := pos + vel * dt
		var query := PhysicsRayQueryParameters3D.create(pos, next_pos)
		query.collision_mask = 1 | 4
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit.position
		pos = next_pos
		vel = next_vel
		if pos.y < -15.0:
			break
	return pos

func _apex_screen_error(origin: Vector3, velocity: Vector3, gravity: float, camera: Camera3D, center: Vector2) -> float:
	var apex := _predict_apex(origin, velocity, gravity)
	var screen := camera.unproject_position(apex)
	return screen.distance_to(center)

func _build_throw_debug(player: Node3D, origin: Vector3, apex: Vector3, raw_aim: Vector3, velocity: Vector3) -> Dictionary:
	var delta := apex - origin
	var aim_dir := Vector3.ZERO
	var aim_pitch := 0.0
	var effective_range := 0.0
	var camera_mode := "?"
	if player.has_method("get_aim_direction"):
		aim_dir = player.get_aim_direction()
		aim_pitch = aim_dir.y
	if player.has_method("get_grenade_debug_range"):
		effective_range = player.get_grenade_debug_range()
	if player.has_method("is_first_person"):
		camera_mode = "1st Person" if player.is_first_person() else "3rd Person"
	return {
		"origin": origin,
		"target": apex,
		"raw_aim": raw_aim,
		"velocity": velocity,
		"throw_mode": "reticle_arc",
		"throw_speed": velocity.length(),
		"aim_pitch": aim_pitch,
		"aim_direction": aim_dir,
		"effective_range": effective_range,
		"camera_mode": camera_mode,
		"horizontal_dist": Vector2(delta.x, delta.z).length(),
		"total_dist": delta.length(),
		"predicted_apex": _predict_apex(origin, velocity, GRENADE_GRAVITY),
		"target_landing_horiz": _target_landing_horiz(aim_pitch),
	}

func _predict_apex(origin: Vector3, velocity: Vector3, gravity: float) -> Vector3:
	if velocity.y <= 0.01:
		return origin
	var t_apex := velocity.y / gravity
	return origin + Vector3(
		velocity.x * t_apex,
		velocity.y * t_apex - 0.5 * gravity * t_apex * t_apex,
		velocity.z * t_apex
	)

func add_grenades(amount: int) -> void:
	grenade_count = mini(MAX_GRENADES, grenade_count + amount)
	if grenade_count >= MAX_GRENADES:
		_recharge_timer = 0.0
		recharge_updated.emit(0.0, GRENADE_RECHARGE_TIME)
	grenades_changed.emit(grenade_count, MAX_GRENADES)

func reset_grenades() -> void:
	grenade_count = MAX_GRENADES
	_cooldown = 0.0
	_recharge_timer = 0.0
	grenades_changed.emit(grenade_count, MAX_GRENADES)
	recharge_updated.emit(0.0, GRENADE_RECHARGE_TIME)
