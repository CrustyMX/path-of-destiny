extends CharacterBody3D
class_name PlayerController

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal attack_landed(damage: float)
signal dodged
signal camera_mode_changed(mode: int)
signal ads_changed(is_ads: bool)

enum CameraMode { THIRD_PERSON, FIRST_PERSON }

const MMB_HOLD_THRESHOLD := 0.22

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.5
const DODGE_SPEED := 12.0
const DODGE_DURATION := 0.4
const JUMP_VELOCITY := 7.5
const DOUBLE_TAP_WINDOW := 0.28
const GRAVITY := 20.0
const ROTATION_SPEED := 12.0
const ATTACK_COOLDOWN := 0.6
const HEAVY_ATTACK_COOLDOWN := 1.2
const MAX_HEALTH := 100.0
const MAX_SHIELD := 50.0
const SHIELD_RECHARGE_DELAY := 3.0
const SHIELD_RECHARGE_RATE := 35.0
const MAX_STAMINA := 100.0
const STAMINA_REGEN := 20.0
const DODGE_STAMINA_COST := 25.0
const ATTACK_STAMINA_COST := 15.0
const RANGED_STAMINA_COST := 3.0
const SHOULDER_OFFSET := Vector3(1.08, 0.48, 0.12)
const EXPLORE_CAMERA_OFFSET := Vector3(0.55, 0.22, 0.08)
const AIM_SPRING_LENGTH := 1.75
const EXPLORE_SPRING_LENGTH := 3.0
const TPS_CAMERA_LOCAL := Vector3(0, 0.22, 0)
const AIM_RAY_LENGTH := 200.0
const CAMERA_PITCH_MIN := -1.55
const CAMERA_PITCH_MAX := 0.85
const FPS_FOV := 85.0
const TPS_FOV := 72.0
const FPS_ADS_FOV := 52.0
const TPS_ADS_FOV := 40.0
const ADS_SPRING_LENGTH := 1.25
const ADS_SHOULDER_OFFSET := Vector3(0.82, 0.38, 0.14)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var shoulder_rig: Node3D = $CameraPivot/ShoulderRig
@onready var spring_arm: SpringArm3D = $CameraPivot/ShoulderRig/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/ShoulderRig/SpringArm3D/Camera3D
@onready var fps_weapon_socket: Node3D = $CameraPivot/ShoulderRig/SpringArm3D/Camera3D/FPSWeaponSocket
@onready var model: Node3D = $Model
@onready var attack_area: Area3D = $AttackArea
@onready var weapon_controller: Node3D = $WeaponController

var health: float = MAX_HEALTH
var shield: float = MAX_SHIELD
var stamina: float = MAX_STAMINA
var is_dodging: bool = false
var is_attacking: bool = false
var dodge_timer: float = 0.0
var attack_timer: float = 0.0
var camera_rotation_h: float = 0.0
var camera_rotation_v: float = -0.25
var mouse_sensitivity := 0.003
var dodge_direction := Vector3.ZERO
var camera_mode: CameraMode = CameraMode.THIRD_PERSON
var is_ads: bool = false
var is_invulnerable: bool = false
var is_dead: bool = false
var _player_collision_layer: int = 2
var _shake_amount: float = 0.0
var _last_damage_source: Node = null
var _last_damage_amount: float = 0.0
var _mmb_press_time: float = -1.0
var _mmb_heavy_triggered: bool = false
var _last_space_press: float = -999.0
var _last_damage_time: float = -999.0

func _ready() -> void:
	add_to_group("player")
	_player_collision_layer = collision_layer
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.register_player(self)
	health_changed.emit(health, MAX_HEALTH)
	shield_changed.emit(shield, MAX_SHIELD)
	stamina_changed.emit(stamina, MAX_STAMINA)
	_load_model()

func _load_model() -> void:
	if ResourceLoader.exists("res://assets/models/player.glb"):
		var scene = load("res://assets/models/player.glb")
		if scene is PackedScene:
			var instance := (scene as PackedScene).instantiate()
			model.add_child(instance)
		else:
			push_warning("player.glb did not load as PackedScene")
			_add_fallback_mesh()
	else:
		push_warning("player.glb not found")
		_add_fallback_mesh()

func _add_fallback_mesh() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.92)
	body.material_override = mat
	model.add_child(body)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseMotion and not is_dodging:
		var sens := mouse_sensitivity
		if is_ads and WeaponLibrary.is_ranged():
			sens *= WeaponLibrary.get_ads_sensitivity_mult()
		camera_rotation_h -= event.relative.x * sens
		camera_rotation_v -= event.relative.y * sens
		camera_rotation_v = clampf(camera_rotation_v, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
	if event.is_action_pressed("toggle_camera"):
		_toggle_camera_mode()
	if event.is_action_pressed("weapon_1"):
		WeaponLibrary.equip_slot(0)
	if event.is_action_pressed("weapon_2"):
		WeaponLibrary.equip_slot(1)
	if event.is_action_pressed("weapon_3"):
		WeaponLibrary.equip_slot(2)
	if event.is_action_pressed("grenade"):
		_throw_grenade()
	if event.is_action_pressed("health_potion"):
		_use_health_potion()
	if event.is_action_pressed("reload"):
		_try_reload()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_mmb_press_time = Time.get_ticks_msec() / 1000.0
			_mmb_heavy_triggered = false
		else:
			if not _mmb_heavy_triggered:
				WeaponLibrary.cycle_primary_secondary()
			_mmb_press_time = -1.0
	if event.is_action_pressed("attack") and attack_timer <= 0 and not is_dodging and not weapon_controller.is_reloading():
		_perform_attack(false)
	if event.is_action_pressed("heavy_attack") and attack_timer <= 0 and not is_dodging:
		if not WeaponLibrary.is_ranged():
			_perform_attack(true)
	# Space: jump; double-tap quickly to dodge
	if event.is_action_pressed("jump"):
		_handle_jump_input()
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	var best: Node = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node):
			continue
		if node.has_method("can_interact") and not node.can_interact(self):
			continue
		var range_limit := 3.0
		if node.has_method("get_interact_range"):
			range_limit = node.get_interact_range()
		var dist := global_position.distance_to(node.global_position)
		if dist <= range_limit and dist < best_dist:
			best = node
			best_dist = dist
	if best and best.has_method("try_interact"):
		best.try_interact(self)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if is_dodging:
		dodge_timer -= delta
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		if is_on_floor():
			velocity.y = 0.0
		elif not is_on_floor():
			velocity.y -= GRAVITY * delta
		if dodge_timer <= 0:
			is_dodging = false
			is_invulnerable = false
	else:
		_handle_movement(delta)
	_update_ads()
	_update_aim_rotation(delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	if not is_dodging and not is_attacking:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
		stamina_changed.emit(stamina, MAX_STAMINA)
	_update_shield_recharge(delta)
	if GameManager.current_state != GameManager.GameState.DEAD and GameManager.current_state != GameManager.GameState.PAUSED and GameManager.current_state != GameManager.GameState.LOOTING:
		if Input.is_action_pressed("attack") and attack_timer <= 0 and not is_dodging and not weapon_controller.is_reloading() and WeaponLibrary.is_ranged():
			_perform_attack(false)
	_update_middle_mouse_hold()
	_update_camera(delta)
	move_and_slide()

func _update_shield_recharge(delta: float) -> void:
	if is_dead or shield >= MAX_SHIELD:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < SHIELD_RECHARGE_DELAY:
		return
	shield = minf(MAX_SHIELD, shield + SHIELD_RECHARGE_RATE * delta)
	shield_changed.emit(shield, MAX_SHIELD)

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0
	right = right.normalized()
	var direction := (forward * -input_dir.y + right * input_dir.x).normalized()
	var move_mult := StatManager.get_stat("move_speed")
	var speed := (SPRINT_SPEED if Input.is_action_pressed("sprint") and stamina > 0 else WALK_SPEED) * move_mult
	if is_ads and WeaponLibrary.is_ranged():
		speed *= WeaponLibrary.get_ads_move_mult()
	elif Input.is_action_pressed("sprint") and direction.length() > 0:
		stamina = maxf(0, stamina - 10 * delta)
		stamina_changed.emit(stamina, MAX_STAMINA)
	if direction.length() > 0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 3 * delta)

func get_aim_direction() -> Vector3:
	return (-camera.global_transform.basis.z).normalized()

func get_aim_point() -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + get_aim_direction() * AIM_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return to
	return hit.position

var _last_grenade_effective_range: float = 42.0

func get_grenade_debug_range() -> float:
	return _last_grenade_effective_range

func get_grenade_aim_point(max_range: float = 42.0, custom_dir: Vector3 = Vector3.ZERO) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var dir := custom_dir.normalized() if custom_dir.length_squared() > 0.001 else get_aim_direction()
	var effective_range := max_range
	if dir.y < -0.3:
		var steepness := clampf((-dir.y - 0.3) / 0.65, 0.0, 1.0)
		effective_range = lerpf(max_range, GrenadeManager.GRENADE_CLOSE_LOB_RANGE, steepness)
	var aiming_up := dir.y > 0.05
	_last_grenade_effective_range = effective_range
	var to := from + dir * effective_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	if aiming_up:
		return to
	var down_query := PhysicsRayQueryParameters3D.create(to + Vector3(0, 6.0, 0), to + Vector3(0, -40.0, 0))
	down_query.collision_mask = 1 | 4
	var ground_hit := space.intersect_ray(down_query)
	if not ground_hit.is_empty():
		return ground_hit.position
	return to

func is_first_person() -> bool:
	return camera_mode == CameraMode.FIRST_PERSON

func is_aiming_down_sights() -> bool:
	return is_ads

func _update_ads() -> void:
	var wants_ads := Input.is_action_pressed("heavy_attack") and WeaponLibrary.is_ranged() and not is_dodging
	if wants_ads == is_ads:
		return
	is_ads = wants_ads
	ads_changed.emit(is_ads)

func get_camera_mode() -> CameraMode:
	return camera_mode

func _toggle_camera_mode() -> void:
	if camera_mode == CameraMode.THIRD_PERSON:
		camera_mode = CameraMode.FIRST_PERSON
	else:
		camera_mode = CameraMode.THIRD_PERSON
	_apply_camera_mode()
	camera_mode_changed.emit(camera_mode)

func _apply_camera_mode() -> void:
	if is_first_person():
		model.visible = false
		camera.fov = FPS_FOV
		spring_arm.spring_length = 0.0
		shoulder_rig.position = Vector3.ZERO
	else:
		model.visible = true
		camera.fov = TPS_FOV

func get_move_spread_penalty() -> float:
	if is_dodging:
		return 0.0
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal <= WALK_SPEED * 0.35:
		return 0.0
	if Input.is_action_pressed("sprint"):
		return 1.0
	return clampf(horizontal / SPRINT_SPEED, 0.0, 1.0) * 0.65

func get_fire_direction(from_position: Vector3) -> Vector3:
	if is_first_person():
		return get_aim_direction()
	var aim_point := get_aim_point()
	var dir := aim_point - from_position
	if dir.length_squared() < 0.001:
		return get_aim_direction()
	return dir.normalized()

func get_aim_direction_flat() -> Vector3:
	var dir := get_aim_direction()
	dir.y = 0
	if dir.length_squared() < 0.001:
		dir = -model.global_transform.basis.z
		dir.y = 0
	return dir.normalized()

func _is_aiming() -> bool:
	if is_ads:
		return true
	if Input.is_action_pressed("attack") or Input.is_action_pressed("heavy_attack"):
		return true
	if is_attacking:
		return true
	return WeaponLibrary.is_ranged()

func _update_aim_rotation(delta: float) -> void:
	if is_dodging:
		return
	if is_first_person():
		model.rotation.y = camera_rotation_h
		return
	var target_rot: float
	if _is_aiming():
		var aim := get_aim_direction_flat()
		if aim.length_squared() < 0.001:
			return
		target_rot = atan2(aim.x, aim.z)
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if input_dir.length_squared() < 0.001:
			return
		var cam_basis := camera.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := cam_basis.x
		right.y = 0
		right = right.normalized()
		var move_dir := (forward * -input_dir.y + right * input_dir.x).normalized()
		target_rot = atan2(move_dir.x, move_dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_rot, ROTATION_SPEED * delta)

func _update_camera(delta: float) -> void:
	camera_pivot.rotation.y = camera_rotation_h
	camera_pivot.rotation.x = camera_rotation_v
	if is_first_person():
		shoulder_rig.position = shoulder_rig.position.lerp(Vector3.ZERO, 12.0 * delta)
		spring_arm.spring_length = lerpf(spring_arm.spring_length, 0.0, 12.0 * delta)
		camera.position = camera.position.lerp(Vector3.ZERO, 12.0 * delta)
		var fps_fov := WeaponLibrary.get_ads_fov(FPS_FOV, FPS_ADS_FOV) if is_ads else FPS_FOV
		camera.fov = lerpf(camera.fov, fps_fov, 14.0 * delta)
		_apply_screen_shake(delta)
		return
	var aim_blend := 1.0 if WeaponLibrary.is_ranged() or _is_aiming() else 0.0
	var shoulder_base := SHOULDER_OFFSET.lerp(EXPLORE_CAMERA_OFFSET, 1.0 - aim_blend)
	var shoulder_target := shoulder_base.lerp(ADS_SHOULDER_OFFSET, 1.0 if is_ads else 0.0)
	shoulder_rig.position = shoulder_rig.position.lerp(shoulder_target, 10.0 * delta)
	var spring_base := lerpf(AIM_SPRING_LENGTH, EXPLORE_SPRING_LENGTH, 1.0 - aim_blend)
	var spring_target := lerpf(spring_base, ADS_SPRING_LENGTH, 1.0 if is_ads else 0.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, spring_target, 14.0 * delta)
	camera.position = camera.position.lerp(TPS_CAMERA_LOCAL, 10.0 * delta)
	var tps_fov := WeaponLibrary.get_ads_fov(TPS_FOV, TPS_ADS_FOV) if is_ads else TPS_FOV
	camera.fov = lerpf(camera.fov, tps_fov, 14.0 * delta)
	_apply_screen_shake(delta)

func apply_screen_shake(intensity: float) -> void:
	_shake_amount = maxf(_shake_amount, intensity)

func apply_recoil(pitch_deg: float) -> void:
	camera_rotation_v += deg_to_rad(pitch_deg)
	camera_rotation_v = clampf(camera_rotation_v, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)

func _apply_screen_shake(delta: float) -> void:
	if _shake_amount <= 0.001:
		camera.position = camera.position.lerp(TPS_CAMERA_LOCAL if not is_first_person() else Vector3.ZERO, 18.0 * delta)
		return
	_shake_amount = move_toward(_shake_amount, 0.0, delta * 3.5)
	var base := Vector3.ZERO if is_first_person() else TPS_CAMERA_LOCAL
	var offset := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		0.0
	) * _shake_amount * 0.12
	camera.position = base + offset

func _handle_jump_input() -> void:
	if is_dead or is_dodging:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if stamina >= DODGE_STAMINA_COST and (now - _last_space_press) <= DOUBLE_TAP_WINDOW:
		_last_space_press = -999.0
		_perform_dodge()
		return
	_last_space_press = now
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func _perform_dodge() -> void:
	is_dodging = true
	is_invulnerable = true
	dodge_timer = DODGE_DURATION
	stamina -= DODGE_STAMINA_COST
	stamina_changed.emit(stamina, MAX_STAMINA)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length() > 0:
		var cam_basis := camera.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right := cam_basis.x
		right.y = 0
		right = right.normalized()
		dodge_direction = (forward * -input_dir.y + right * input_dir.x).normalized()
	else:
		dodge_direction = -model.global_transform.basis.z
		dodge_direction.y = 0
		dodge_direction = dodge_direction.normalized()
	dodged.emit()

func _perform_attack(heavy: bool) -> void:
	if weapon_controller.is_reloading():
		return
	var w: Dictionary = WeaponLibrary.get_equipped()
	var is_ranged := WeaponLibrary.is_ranged()
	var cost := RANGED_STAMINA_COST if is_ranged else ATTACK_STAMINA_COST
	if stamina < cost:
		return
	if not weapon_controller.try_attack(heavy):
		return
	stamina -= cost
	stamina_changed.emit(stamina, MAX_STAMINA)
	attack_timer = weapon_controller.get_fire_cooldown()
	if is_ranged:
		return
	is_attacking = true
	await get_tree().create_timer(attack_timer * 0.5).timeout
	is_attacking = false

func _throw_grenade() -> void:
	if is_dead or is_dodging:
		return
	if not GrenadeManager.can_throw():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notice"):
			if GrenadeManager.grenade_count <= 0:
				hud.show_notice("No grenades left", 1.2)
			else:
				hud.show_notice("Grenade cooling down", 1.0)
		return
	GrenadeManager.throw_grenade(self, get_grenade_aim_point())

func _use_health_potion() -> void:
	if is_dead or is_dodging:
		return
	if HealthPotionManager.can_use():
		if HealthPotionManager.use_potion(self):
			return
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud or not hud.has_method("show_notice"):
		return
	if HealthPotionManager.potion_count <= 0:
		hud.show_notice("No health pots left", 1.2)
	elif health >= MAX_HEALTH - 0.5:
		hud.show_notice("Health full", 1.0)
	else:
		hud.show_notice("Potion cooling down", 1.0)

func _try_reload() -> void:
	if is_dead or is_dodging:
		return
	weapon_controller.try_reload()

func _update_middle_mouse_hold() -> void:
	if _mmb_press_time < 0.0:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return
	var elapsed := Time.get_ticks_msec() / 1000.0 - _mmb_press_time
	if not _mmb_heavy_triggered and elapsed >= MMB_HOLD_THRESHOLD:
		_mmb_heavy_triggered = true
		WeaponLibrary.equip_heavy()

func take_damage(amount: float, source = null) -> void:
	if is_dead or GameManager.current_state == GameManager.GameState.DEAD:
		return
	if is_invulnerable:
		return
	var damage_source: Node = _valid_source(source)
	var reduced := maxf(1.0, amount - StatManager.get_stat("armor") * 0.5)
	GameDiag.register_damage_taken(amount, reduced, damage_source)
	_last_damage_source = damage_source
	_last_damage_amount = reduced
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	CombatFeedback.register_player_hit(reduced)
	if damage_source is Node3D:
		CombatFeedback.register_hit_threat(damage_source, 1.15, clampf(reduced / 20.0, 0.65, 1.25))
	var remaining := reduced
	if shield > 0.0:
		var absorbed: float = minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, MAX_SHIELD)
	health -= remaining
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die()

func _valid_source(source) -> Node:
	if source != null and is_instance_valid(source) and source is Node:
		return source
	return null

func _describe_death_source(source: Node) -> String:
	if not source or not is_instance_valid(source):
		return "Unknown assailant"
	if source.is_in_group("boss"):
		if source.get("BOSS_NAME"):
			return str(source.get("BOSS_NAME"))
		return "A boss"
	if source is CharacterBody3D and source.is_in_group("enemies"):
		if source.get("mob_id"):
			var mob_id: String = source.get("mob_id")
			match mob_id:
				"cultist":
					return "Heretic Cultist"
				"drone":
					return "Scavenger Drone"
				"brute":
					return "Plague Brute"
		return "Hostile creature"
	var parent := source.get_parent()
	if parent and parent.is_in_group("enemies"):
		return _describe_death_source(parent)
	return "Ranged attack"

func _build_death_detail(source: Node, damage: float) -> String:
	var who := _describe_death_source(source)
	if source and source.is_in_group("boss"):
		return "Overwhelmed by %s's assault" % who
	if damage >= 20.0:
		return "Fatal blow from %s (%d damage)" % [who, int(damage)]
	return "Fell in combat against %s" % who

func heal(amount: float) -> void:
	health = minf(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)

func respawn(pos: Vector3) -> void:
	is_dead = false
	is_dodging = false
	is_invulnerable = false
	is_attacking = false
	dodge_timer = 0.0
	_shake_amount = 0.0
	collision_layer = _player_collision_layer
	global_position = pos
	health = MAX_HEALTH
	shield = MAX_SHIELD
	stamina = MAX_STAMINA
	_last_damage_time = -999.0
	GrenadeManager.reset_grenades()
	HealthPotionManager.reset_potions()
	health_changed.emit(health, MAX_HEALTH)
	shield_changed.emit(shield, MAX_SHIELD)
	stamina_changed.emit(stamina, MAX_STAMINA)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_dodging = false
	is_attacking = false
	dodge_timer = 0.0
	collision_layer = 0
	_shake_amount = 0.0
	AudioManager.play_sfx("player_death", 1.0, 0.95)
	CombatFeedback.screen_shake(0.75)
	GameManager.on_player_died({
		"source_name": _describe_death_source(_last_damage_source),
		"detail": _build_death_detail(_last_damage_source, _last_damage_amount),
		"damage": _last_damage_amount,
	})
