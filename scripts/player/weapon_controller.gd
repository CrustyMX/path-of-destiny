extends Node3D

signal fired(weapon_id: String, damage: float)
signal ammo_changed(current: int, maximum: int, is_reloading: bool)
signal reload_progress_changed(remaining: float, total: float, is_reloading: bool)

const PROJECTILE_SCENE := preload("res://scenes/weapons/projectile.tscn")
const PROJECTILE_SCRIPT := preload("res://scripts/weapons/projectile.gd")
const CD := preload("res://scripts/systems/combat_damage.gd")
const FPS_WEAPON_POS := Vector3(0.42, -0.24, -0.55)
const FPS_WEAPON_POS_ADS := Vector3(0.1, -0.17, -0.42)
const FPS_WEAPON_POS_HEAVY := Vector3(0.54, -0.36, -0.62)
const FPS_WEAPON_POS_HEAVY_ADS := Vector3(0.16, -0.24, -0.48)
const FPS_WEAPON_ROT := Vector3(deg_to_rad(-3.0), 0.0, deg_to_rad(1.0))
const FPS_WEAPON_ROT_ADS := Vector3(deg_to_rad(-1.5), 0.0, 0.0)
const FPS_WEAPON_SCALE := Vector3(1.35, 1.35, 1.35)
const TPS_WEAPON_HAND := Vector3(-0.36, 1.08, -0.14)
const TPS_WEAPON_HAND_ADS := Vector3(-0.30, 1.12, -0.08)
const TPS_WEAPON_SCALE := Vector3(0.9, 0.9, 0.9)
const MUZZLE_FLASH_RADIUS := 0.035
const FPS_MUZZLE_FLASH_SCALE := Vector3(0.32, 0.32, 0.32)
const TPS_MUZZLE_FLASH_SCALE := Vector3(0.85, 0.85, 0.85)
const FPS_MUZZLE_FLASH_ENERGY := 1.25
const TPS_MUZZLE_FLASH_ENERGY := 3.0

@onready var player: CharacterBody3D = get_parent()
@onready var tps_socket: Node3D = player.get_node("Model/WeaponSocket")
@onready var fps_socket: Node3D = player.get_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D/FPSWeaponSocket")
@onready var model: Node3D = player.get_node("Model")
@onready var camera: Camera3D = player.get_node("CameraPivot/ShoulderRig/SpringArm3D/Camera3D")
@onready var attack_area: Area3D = player.get_node("AttackArea")

var socket: Node3D = null
var weapon_mesh: Node3D = null
var fire_timer: float = 0.0
var muzzle_flash: MeshInstance3D = null
var _flash_mat: StandardMaterial3D = null
var _last_fps_state: bool = false
var _ammo_state: Dictionary = {}
var _reload_timer: float = 0.0
var _reload_total: float = 0.0
var _is_reloading: bool = false

func _ready() -> void:
	socket = tps_socket
	if player.has_signal("camera_mode_changed"):
		player.camera_mode_changed.connect(_on_camera_mode_changed)
	WeaponLibrary.weapon_changed.connect(_on_weapon_changed)
	_build_weapon_visual(WeaponLibrary.equipped_id)

func _process(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	_update_reload(delta)
	var fps := _is_fps()
	if fps != _last_fps_state:
		_last_fps_state = fps
		_attach_weapon_to_active_socket()
	if fps:
		_orient_weapon_fps()
	else:
		_orient_weapon_tps()

func _is_fps() -> bool:
	return player.has_method("is_first_person") and player.is_first_person()

func _on_camera_mode_changed(_mode: int) -> void:
	_last_fps_state = not _is_fps()
	_attach_weapon_to_active_socket()

func _attach_weapon_to_active_socket() -> void:
	var target: Node3D = fps_socket if _is_fps() else tps_socket
	socket = target
	if not weapon_mesh or not is_instance_valid(weapon_mesh):
		return
	var current_parent := weapon_mesh.get_parent()
	if current_parent != target:
		if current_parent:
			current_parent.remove_child(weapon_mesh)
		target.add_child(weapon_mesh)
	weapon_mesh.position = Vector3.ZERO
	weapon_mesh.rotation = Vector3.ZERO
	if _is_fps():
		weapon_mesh.scale = FPS_WEAPON_SCALE
	else:
		weapon_mesh.scale = TPS_WEAPON_SCALE
	_sync_muzzle_flash()

func _orient_weapon_fps() -> void:
	if weapon_mesh and weapon_mesh.get_parent() != fps_socket:
		_attach_weapon_to_active_socket()
	var ads := _is_ads()
	var pos := _get_fps_weapon_pos(ads)
	var rot := FPS_WEAPON_ROT.lerp(FPS_WEAPON_ROT_ADS, 1.0 if ads else 0.0)
	fps_socket.position = pos
	fps_socket.rotation = rot
	weapon_mesh.rotation = Vector3.ZERO
	if player.has_method("get_aim_point"):
		_converge_muzzle_to_aim(player.get_aim_point(), 4, weapon_mesh)

func _get_fps_weapon_pos(ads: bool) -> Vector3:
	var w: Dictionary = WeaponLibrary.get_equipped()
	if w.get("kind") == WeaponLibrary.WeaponKind.HEAVY_RANGED:
		return FPS_WEAPON_POS_HEAVY.lerp(FPS_WEAPON_POS_HEAVY_ADS, 1.0 if ads else 0.0)
	return FPS_WEAPON_POS.lerp(FPS_WEAPON_POS_ADS, 1.0 if ads else 0.0)

func _is_ads() -> bool:
	return player.has_method("is_aiming_down_sights") and player.is_aiming_down_sights()

func _sync_weapon_orientation() -> void:
	if _is_fps():
		_orient_weapon_fps()
	else:
		_orient_weapon_tps()

func _orient_weapon_tps() -> void:
	if weapon_mesh and weapon_mesh.get_parent() != tps_socket:
		_attach_weapon_to_active_socket()
	var ads := _is_ads()
	tps_socket.position = TPS_WEAPON_HAND.lerp(TPS_WEAPON_HAND_ADS, 1.0 if ads else 0.0)
	if not player.has_method("get_aim_point"):
		return
	var aim_point: Vector3 = player.get_aim_point()
	_safe_look_at(tps_socket, aim_point)
	_converge_muzzle_to_aim(aim_point)

func _converge_muzzle_to_aim(target: Vector3, passes: int = 4, pivot: Node3D = null) -> void:
	if not muzzle_flash:
		return
	var node := pivot if pivot else tps_socket
	for _i in range(passes):
		var to_target := target - muzzle_flash.global_position
		if to_target.length_squared() < 0.0001:
			break
		var want_dir := to_target.normalized()
		var barrel_dir := -muzzle_flash.global_transform.basis.z
		if barrel_dir.dot(want_dir) > 0.9995:
			break
		var axis := barrel_dir.cross(want_dir)
		if axis.length_squared() < 0.0000001:
			break
		node.rotate(axis.normalized(), barrel_dir.angle_to(want_dir))

func _get_muzzle_forward() -> Vector3:
	if muzzle_flash:
		return (-muzzle_flash.global_transform.basis.z).normalized()
	if socket:
		return (-socket.global_transform.basis.z).normalized()
	return _get_aim_direction()

func _safe_look_at(node: Node3D, target: Vector3, up: Vector3 = Vector3.UP) -> void:
	if node.global_position.distance_squared_to(target) < 0.0001:
		return
	var dir := (target - node.global_position).normalized()
	if abs(dir.dot(up)) > 0.998:
		up = Vector3.RIGHT
	node.look_at(target, up)

func _get_aim_direction() -> Vector3:
	if player.has_method("get_aim_direction"):
		return player.get_aim_direction()
	return (-camera.global_transform.basis.z).normalized()

func _on_weapon_changed(weapon_id: String) -> void:
	_is_reloading = false
	_reload_timer = 0.0
	_reload_total = 0.0
	_build_weapon_visual(weapon_id)
	_emit_ammo_state()
	reload_progress_changed.emit(0.0, 0.0, false)

func _ensure_ammo_state(weapon_id: String) -> Dictionary:
	if not _ammo_state.has(weapon_id):
		var w: Dictionary = WeaponLibrary.get_weapon(weapon_id)
		var mag_size: int = w.get("magazine_size", 0)
		_ammo_state[weapon_id] = {"mag": mag_size}
	return _ammo_state[weapon_id]

func _emit_ammo_state() -> void:
	var wid := WeaponLibrary.equipped_id
	var w: Dictionary = WeaponLibrary.get_weapon(wid)
	var mag_size: int = w.get("magazine_size", 0)
	if mag_size <= 0:
		ammo_changed.emit(0, 0, false)
		return
	var state: Dictionary = _ensure_ammo_state(wid)
	ammo_changed.emit(state["mag"], mag_size, _is_reloading)

func is_reloading() -> bool:
	return _is_reloading

func try_reload() -> bool:
	var wid := WeaponLibrary.equipped_id
	if not WeaponLibrary.uses_ammo(wid):
		return false
	if _is_reloading:
		return false
	var w: Dictionary = WeaponLibrary.get_weapon(wid)
	var mag_size: int = w.get("magazine_size", 0)
	var state: Dictionary = _ensure_ammo_state(wid)
	if state["mag"] >= mag_size:
		return false
	_is_reloading = true
	_reload_total = w.get("reload_time", 2.0)
	_reload_timer = _reload_total
	_emit_ammo_state()
	reload_progress_changed.emit(_reload_timer, _reload_total, true)
	AudioManager.play_sfx("ability_shield", 0.35, 1.4)
	return true

func refill_weapon_ammo(weapon_id: String = "") -> void:
	var wid := weapon_id if not weapon_id.is_empty() else WeaponLibrary.equipped_id
	if not WeaponLibrary.uses_ammo(wid):
		return
	var w: Dictionary = WeaponLibrary.get_weapon(wid)
	var state: Dictionary = _ensure_ammo_state(wid)
	state["mag"] = int(w.get("magazine_size", 0))
	if wid == WeaponLibrary.equipped_id:
		_is_reloading = false
		_reload_timer = 0.0
		_reload_total = 0.0
		_emit_ammo_state()
		reload_progress_changed.emit(0.0, 0.0, false)

func get_reload_progress() -> Dictionary:
	return {
		"remaining": _reload_timer,
		"total": _reload_total,
		"is_reloading": _is_reloading,
	}

func _update_reload(delta: float) -> void:
	if not _is_reloading:
		return
	_reload_timer = maxf(0.0, _reload_timer - delta)
	reload_progress_changed.emit(_reload_timer, _reload_total, true)
	if _reload_timer > 0.0:
		return
	_is_reloading = false
	var wid := WeaponLibrary.equipped_id
	var w: Dictionary = WeaponLibrary.get_weapon(wid)
	var state: Dictionary = _ensure_ammo_state(wid)
	state["mag"] = w.get("magazine_size", 0)
	_emit_ammo_state()
	reload_progress_changed.emit(0.0, _reload_total, false)

func _build_weapon_visual(weapon_id: String) -> void:
	if weapon_mesh:
		weapon_mesh.queue_free()
		weapon_mesh = null
	var w: Dictionary = WeaponLibrary.get_weapon(weapon_id)
	weapon_mesh = Node3D.new()
	weapon_mesh.name = "WeaponModel"
	var body := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = w["color"]
	mat.emission_enabled = true
	mat.emission = w["emission"]
	mat.emission_energy_multiplier = 1.2
	mat.metallic = 0.8
	mat.roughness = 0.3
	body.material_override = mat
	var muzzle_z := -0.62
	match w.get("model_type", "gun"):
		"gun":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.12, 0.14, 0.55)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.34)
		"smg":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.11, 0.13, 0.42)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.28)
		"long_rifle":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.1, 0.12, 0.82)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.48)
			var scope := MeshInstance3D.new()
			var scope_mesh := BoxMesh.new()
			scope_mesh.size = Vector3(0.08, 0.08, 0.14)
			scope.mesh = scope_mesh
			scope.position = Vector3(0, 0.09, -0.22)
			var scope_mat := StandardMaterial3D.new()
			scope_mat.albedo_color = Color(0.08, 0.08, 0.1)
			scope_mat.emission_enabled = true
			scope_mat.emission = w["emission"]
			scope_mat.emission_energy_multiplier = 0.35
			scope.material_override = scope_mat
			weapon_mesh.add_child(scope)
		"grenade_launcher":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.14, 0.16, 0.58)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.36)
			var tube := MeshInstance3D.new()
			var tube_mesh := CylinderMesh.new()
			tube_mesh.top_radius = 0.06
			tube_mesh.bottom_radius = 0.06
			tube_mesh.height = 0.22
			tube.mesh = tube_mesh
			tube.rotation.x = PI / 2
			tube.position = Vector3(0, 0.04, -0.58)
			tube.material_override = mat
			weapon_mesh.add_child(tube)
		"rocket_launcher":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.16, 0.18, 0.72)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.42)
			var tube := MeshInstance3D.new()
			var tube_mesh := CylinderMesh.new()
			tube_mesh.top_radius = 0.08
			tube_mesh.bottom_radius = 0.08
			tube_mesh.height = 0.38
			tube.mesh = tube_mesh
			tube.rotation.x = PI / 2
			tube.position = Vector3(0, 0.02, -0.72)
			tube.material_override = mat
			weapon_mesh.add_child(tube)
		"lmg":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.13, 0.15, 0.78)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.46)
			var drum := MeshInstance3D.new()
			var drum_mesh := CylinderMesh.new()
			drum_mesh.top_radius = 0.1
			drum_mesh.bottom_radius = 0.1
			drum_mesh.height = 0.12
			drum.mesh = drum_mesh
			drum.rotation.x = PI / 2
			drum.position = Vector3(0, -0.06, -0.12)
			drum.material_override = mat
			weapon_mesh.add_child(drum)
		"meltagun":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.12, 0.14, 0.34)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.2)
			var tank := MeshInstance3D.new()
			var tank_mesh := CylinderMesh.new()
			tank_mesh.top_radius = 0.065
			tank_mesh.bottom_radius = 0.065
			tank_mesh.height = 0.18
			tank.mesh = tank_mesh
			tank.rotation.x = PI / 2
			tank.position = Vector3(0, 0.02, -0.36)
			tank.material_override = mat
			weapon_mesh.add_child(tank)
			var nozzle := MeshInstance3D.new()
			var nozzle_mesh := CylinderMesh.new()
			nozzle_mesh.top_radius = 0.035
			nozzle_mesh.bottom_radius = 0.045
			nozzle_mesh.height = 0.16
			nozzle.mesh = nozzle_mesh
			nozzle.rotation.x = PI / 2
			nozzle.position = Vector3(0, 0.01, -0.52)
			nozzle.material_override = mat
			weapon_mesh.add_child(nozzle)
			muzzle_z = -0.58
		"plasma_caster":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.11, 0.13, 0.32)
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.18)
			var coil := MeshInstance3D.new()
			var coil_mesh := CylinderMesh.new()
			coil_mesh.top_radius = 0.055
			coil_mesh.bottom_radius = 0.055
			coil_mesh.height = 0.2
			coil.mesh = coil_mesh
			coil.rotation.x = PI / 2
			coil.position = Vector3(0, 0.01, -0.34)
			coil.material_override = mat
			weapon_mesh.add_child(coil)
			var emitter := MeshInstance3D.new()
			var emitter_mesh := SphereMesh.new()
			emitter_mesh.radius = 0.045
			emitter_mesh.height = 0.09
			emitter.mesh = emitter_mesh
			emitter.position = Vector3(0, 0.01, -0.48)
			var emitter_mat := StandardMaterial3D.new()
			emitter_mat.albedo_color = w["color"]
			emitter_mat.emission_enabled = true
			emitter_mat.emission = w["emission"]
			emitter_mat.emission_energy_multiplier = 2.0
			emitter.material_override = emitter_mat
			weapon_mesh.add_child(emitter)
			muzzle_z = -0.54
		"staff":
			var mesh := CylinderMesh.new()
			mesh.top_radius = w["model_scale"].x
			mesh.bottom_radius = w["model_scale"].x * 0.8
			mesh.height = w["model_scale"].y * 2.0
			body.mesh = mesh
			body.rotation.x = PI / 2
			body.position = Vector3(0, 0, -0.45)
		"blade", "greatblade":
			var mesh := BoxMesh.new()
			mesh.size = w["model_scale"] * 2.0
			body.mesh = mesh
			body.position = Vector3(0, 0, -0.3)
			body.rotation.y = PI / 2
	weapon_mesh.add_child(body)
	muzzle_flash = MeshInstance3D.new()
	var flash_sphere := SphereMesh.new()
	flash_sphere.radius = MUZZLE_FLASH_RADIUS
	muzzle_flash.mesh = flash_sphere
	muzzle_flash.visible = false
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.emission_enabled = true
	_flash_mat.emission = w["emission"]
	_flash_mat.emission_energy_multiplier = TPS_MUZZLE_FLASH_ENERGY
	muzzle_flash.material_override = _flash_mat
	muzzle_flash.position = Vector3(0, 0, muzzle_z)
	weapon_mesh.add_child(muzzle_flash)
	_attach_weapon_to_active_socket()
	_emit_ammo_state()

func _sync_muzzle_flash() -> void:
	if not muzzle_flash:
		return
	if _is_fps():
		muzzle_flash.visible = false
		return
	muzzle_flash.scale = TPS_MUZZLE_FLASH_SCALE
	if _flash_mat:
		_flash_mat.emission_energy_multiplier = TPS_MUZZLE_FLASH_ENERGY

func try_attack(heavy: bool) -> bool:
	if _is_reloading:
		return false
	var w: Dictionary = WeaponLibrary.get_equipped()
	var wid := WeaponLibrary.equipped_id
	if WeaponLibrary.uses_ammo(wid):
		var state: Dictionary = _ensure_ammo_state(wid)
		if state["mag"] <= 0:
			try_reload()
			return false
	var rate: float = StatManager.get_stat("fire_rate", {"heavy": heavy})
	if fire_timer > 0:
		return false
	_sync_weapon_orientation()
	fire_timer = rate
	if WeaponLibrary.is_ranged():
		if WeaponLibrary.uses_ammo(wid):
			var ammo_state: Dictionary = _ensure_ammo_state(wid)
			ammo_state["mag"] -= 1
			_emit_ammo_state()
		_fire_projectile(w, heavy)
	else:
		_melee_attack(w, heavy)
		if heavy:
			CombatFeedback.screen_shake(0.38)
			_play_weapon_sfx(w, true)
	fired.emit(WeaponLibrary.equipped_id, StatManager.get_stat("damage", {"heavy": heavy}))
	return true

func _play_weapon_sfx(w: Dictionary, heavy: bool) -> void:
	var sfx_key: String = w.get("sfx_heavy" if heavy else "sfx_fire", "")
	if sfx_key.is_empty():
		sfx_key = "gunfire_heavy" if heavy else "gunfire"
	var vol: float = w.get("sfx_volume", 0.85 if heavy else 0.7)
	AudioManager.play_sfx(sfx_key, vol)

func _apply_weapon_kick(w: Dictionary, heavy: bool) -> void:
	var shake: float = w.get("shake_heavy" if heavy else "shake", 0.0)
	if shake > 0.0:
		CombatFeedback.screen_shake(shake * (1.25 if heavy else 1.0))
	var recoil: float = w.get("recoil_pitch", 0.0)
	if recoil > 0.0 and player.has_method("apply_recoil"):
		player.apply_recoil(recoil * (1.35 if heavy else 1.0))

func _fire_projectile(w: Dictionary, heavy: bool) -> void:
	var dmg: float = StatManager.get_stat("damage", {"heavy": heavy})
	var spread_deg: float = _get_spread_degrees(w, heavy)
	var fire_data := _get_fire_origin_and_direction()
	var dir: Vector3 = _get_shot_direction(fire_data, spread_deg)
	if w.get("projectile_type", "") == "arc_explosive":
		_spawn_arc_explosive(w, heavy, fire_data, dir, dmg, spread_deg)
	elif w.get("traveling_projectile", false):
		_spawn_traveling_projectile(w, heavy, fire_data, dir, dmg, spread_deg)
	else:
		_fire_hitscan(w, heavy, fire_data, dir, dmg, spread_deg)
	_flash_muzzle()
	_apply_weapon_kick(w, heavy)
	_play_weapon_sfx(w, heavy)

func _spawn_arc_explosive(
	w: Dictionary,
	heavy: bool,
	fire_data: Dictionary,
	dir: Vector3,
	dmg: float,
	spread_deg: float
) -> void:
	var lob_range: float = w.get("lob_range_heavy", 100.0) if heavy else w.get("lob_range", 88.0)
	var lob_speed: float = w.get("lob_speed_heavy", 48.0) if heavy else w.get("lob_speed", 40.0)
	var blast_radius: float = w.get("blast_radius", 6.0)
	var aim_point: Vector3 = player.get_aim_point() if player.has_method("get_aim_point") else fire_data.get("aim_point", Vector3.ZERO)
	var aim_dir: Vector3 = player.get_aim_direction() if player.has_method("get_aim_direction") else dir
	var debug_id := -1
	if AimDebug.enabled:
		var debug_data := _build_debug_shot(fire_data, dir, spread_deg)
		debug_data["aim_point"] = aim_point
		debug_data["projectile_type"] = "arc_explosive"
		debug_data["aim_dir"] = aim_dir
		debug_id = AimDebug.register_shot(debug_data)
	var launch_velocity := GrenadeManager.spawn_weapon_grenade(
		player,
		lob_speed,
		lob_range,
		dmg,
		blast_radius,
		debug_id,
		camera
	)
	if debug_id >= 0 and launch_velocity.length_squared() > 0.001:
		AimDebug.patch_shot(debug_id, {"launch_velocity": launch_velocity})

func _get_shot_direction(fire_data: Dictionary, spread_deg: float) -> Vector3:
	var origin: Vector3 = fire_data["origin"]
	var aim_point: Vector3 = fire_data.get("aim_point", origin + fire_data["direction"])
	var to_aim := aim_point - origin
	var base_dir: Vector3 = to_aim.normalized() if to_aim.length_squared() > 0.0001 else Vector3(fire_data["direction"])
	if spread_deg > 0.0:
		return _apply_spread(base_dir, spread_deg)
	return base_dir

func _get_shot_origin(fire_data: Dictionary, dir: Vector3) -> Vector3:
	var origin: Vector3 = fire_data["origin"]
	if dir.length_squared() <= 0.0001:
		return origin
	return origin + dir.normalized() * 0.12

func _spawn_traveling_projectile(
	w: Dictionary,
	heavy: bool,
	fire_data: Dictionary,
	dir: Vector3,
	dmg: float,
	spread_deg: float
) -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	proj.speed = w["projectile_speed"] * (1.2 if heavy else 1.0)
	proj.damage = dmg
	proj.direction = dir
	proj.max_range = w.get("range", 70.0)
	proj.source = player
	proj.use_tps_visual = not _is_fps()
	proj.visual_camera = camera
	proj.debug_camera = camera
	var spawn_parent: Node = player.get_parent()
	spawn_parent.add_child(proj)
	proj.global_position = _get_shot_origin(fire_data, dir)
	if proj.has_method("setup_bullet"):
		proj.setup_bullet(w["emission"], heavy)
	if AimDebug.enabled:
		proj.debug_shot_id = AimDebug.register_shot(_build_debug_shot(fire_data, dir, spread_deg))

func _fire_hitscan(
	w: Dictionary,
	heavy: bool,
	fire_data: Dictionary,
	dir: Vector3,
	dmg: float,
	spread_deg: float
) -> void:
	var origin: Vector3 = _get_shot_origin(fire_data, dir)
	var max_range: float = w.get("range", 70.0)
	var end: Vector3 = origin + dir * max_range
	var motion := end - origin
	var exclude: Array[RID] = []
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	var space := player.get_world_3d().direct_space_state
	var sweep_radius := 0.08 if not heavy else 0.1
	var hit: Dictionary = PROJECTILE_SCRIPT.cast_segment(space, origin, motion, exclude, sweep_radius)
	var impact: Vector3 = hit.get("position", end) if not hit.is_empty() else end
	_spawn_hitscan_tracer(origin, impact, w["emission"], heavy)
	if not hit.is_empty():
		_apply_hitscan_hit(hit, dmg, origin, end)
	if AimDebug.enabled:
		var debug_id := AimDebug.register_shot(_build_debug_shot(fire_data, dir, spread_deg))
		if debug_id >= 0:
			AimDebug.register_impact(debug_id, impact, camera)

func _apply_hitscan_hit(hit: Dictionary, dmg: float, from: Vector3, to: Vector3) -> void:
	var collider: Object = hit.get("collider")
	if collider == null:
		return
	var hit_pos: Vector3 = hit.get("position", from)
	var parsed: Dictionary = CD.parse_projectile_hit(collider, hit_pos, from, to)
	var target: Node = parsed.get("target")
	if target == null or not is_instance_valid(target) or target == player:
		if collider is StaticBody3D:
			CombatFeedback.register_wall_hit()
		return
	var rolled: Dictionary = CD.roll_player_damage(
		dmg,
		player,
		parsed.get("crit_spot", false),
		float(parsed.get("crit_multiplier", 1.0))
	)
	target.take_damage(rolled["amount"], player, rolled["is_crit"], hit_pos, parsed.get("crit_spot", false))
	if player.has_signal("attack_landed"):
		player.attack_landed.emit(rolled["amount"])
	_spawn_hitscan_impact(hit_pos, rolled.get("is_crit", false))

func _spawn_hitscan_tracer(from: Vector3, to: Vector3, color: Color, heavy: bool) -> void:
	if _is_fps():
		return
	if from.distance_squared_to(to) < 0.0001:
		return
	var parent := player.get_parent()
	if parent == null:
		return
	var tracer := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := from.distance_to(to)
	box.size = Vector3(0.02, 0.02, length) if not heavy else Vector3(0.028, 0.028, length)
	tracer.mesh = box
	var mat := _make_tracer_material(color)
	tracer.material_override = mat
	parent.add_child(tracer)
	tracer.global_position = from.lerp(to, 0.5)
	var aim_target := to
	if from.distance_squared_to(aim_target) < 0.0001:
		aim_target = from + _get_aim_direction()
	if abs((aim_target - from).normalized().dot(Vector3.UP)) > 0.998:
		tracer.look_at(aim_target, Vector3.RIGHT)
	else:
		tracer.look_at(aim_target, Vector3.UP)
	var tween := tracer.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.05)
	tween.tween_callback(tracer.queue_free)

func _make_tracer_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	return mat

func _spawn_hitscan_impact(pos: Vector3, is_crit: bool) -> void:
	var parent := player.get_parent()
	if parent == null:
		return
	var flash := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05 if not is_crit else 0.07
	flash.mesh = s
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.25) if is_crit else Color(1, 0.6, 0.2)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	flash.material_override = mat
	parent.add_child(flash)
	flash.global_position = pos
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3(0.05, 0.05, 0.05), 0.1)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)

func _build_debug_shot(fire_data: Dictionary, dir: Vector3, spread_deg: float) -> Dictionary:
	var muzzle: Vector3 = fire_data.get("muzzle", fire_data["origin"])
	var muzzle_screen := camera.unproject_position(muzzle)
	var origin_screen := camera.unproject_position(fire_data["origin"])
	return {
		"camera_mode": "1st Person" if _is_fps() else "3rd Person",
		"ads": _is_ads(),
		"spread_deg": spread_deg,
		"fire_dir": dir,
		"aim_point": fire_data.get("aim_point", Vector3.ZERO),
		"origin": fire_data["origin"],
		"origin_screen": origin_screen,
		"muzzle_screen": muzzle_screen,
	}

func _get_fire_origin_and_direction() -> Dictionary:
	var cam_dir := _get_aim_direction()
	var cam_pos := camera.global_position
	var aim_point: Vector3 = player.get_aim_point() if player.has_method("get_aim_point") else cam_pos + cam_dir * 100.0
	var muzzle: Vector3 = muzzle_flash.global_position if muzzle_flash else socket.global_position
	if _is_fps():
		return {
			"origin": cam_pos + cam_dir * 0.3,
			"direction": cam_dir,
			"aim_point": aim_point,
			"muzzle": muzzle,
		}
	var fire_dir := _get_muzzle_forward()
	if fire_dir.length_squared() < 0.001:
		fire_dir = cam_dir
	return {
		"origin": muzzle,
		"direction": fire_dir,
		"aim_point": aim_point,
		"muzzle": muzzle,
	}

func _get_spread_degrees(w: Dictionary, heavy: bool) -> float:
	var spread: float = w.get("spread", 0.0)
	if heavy:
		spread *= 1.65
	if _is_ads():
		spread = w.get("ads_spread", spread * 0.25)
	if player.has_method("get_move_spread_penalty"):
		spread += player.get_move_spread_penalty() * w.get("move_spread", 0.0)
	return spread

func _melee_attack(w: Dictionary, heavy: bool) -> void:
	var dmg: float = StatManager.get_stat("damage", {"heavy": heavy})
	var dir: Vector3 = _get_aim_direction()
	var crit_spots := attack_area.get_overlapping_areas()
	await get_tree().create_timer(0.12).timeout
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("take_damage") and body != player:
			var dist := player.global_position.distance_to(body.global_position)
			if dist <= w["range"]:
				var used_crit_spot := false
				for area in crit_spots:
					if area.is_in_group("enemy_crit_spot") and CD.find_enemy_from_node(area) == body:
						var rolled: Dictionary = CD.roll_player_damage(
							dmg,
							player,
							true,
							float(area.get_meta("crit_multiplier", CD.DEFAULT_CRIT_SPOT_MULT))
						)
						body.take_damage(rolled["amount"], player, rolled["is_crit"], Vector3.INF, true)
						used_crit_spot = true
						break
				if not used_crit_spot:
					var rolled: Dictionary = CD.roll_player_damage(dmg, player, false, 1.0)
					body.take_damage(rolled["amount"], player, rolled["is_crit"], Vector3.INF, false)
				if player.has_signal("attack_landed"):
					player.attack_landed.emit(dmg)
	if _is_fps():
		return
	var swipe := MeshInstance3D.new()
	var arc := BoxMesh.new()
	arc.size = Vector3(w["range"] * 2, 0.05, 0.8 if heavy else 0.4)
	swipe.mesh = arc
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = w["emission"]
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.5
	swipe.material_override = mat
	model.add_child(swipe)
	swipe.position = Vector3(0, 0.9, -w["range"] * 0.5)
	var swipe_target := model.global_position + dir
	if swipe.global_position.distance_squared_to(swipe_target) >= 0.0001:
		var up := Vector3.UP
		if abs(dir.normalized().dot(up)) > 0.998:
			up = Vector3.RIGHT
		swipe.look_at(swipe_target, up)
	var tween := create_tween()
	tween.tween_property(swipe, "scale", Vector3(1.2, 1, 1.2), 0.15)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(swipe.queue_free)

func _flash_muzzle() -> void:
	if _is_fps():
		var w: Dictionary = WeaponLibrary.get_equipped()
		CombatFeedback.show_fps_shot_pulse(w.get("emission", Color(1.0, 0.9, 0.65)))
		return
	if not muzzle_flash:
		return
	_sync_muzzle_flash()
	muzzle_flash.visible = true
	var tween := create_tween()
	tween.tween_callback(func(): muzzle_flash.visible = false).set_delay(0.04)

func get_fire_cooldown() -> float:
	return fire_timer

func _apply_spread(dir: Vector3, spread_degrees: float) -> Vector3:
	var spread_rad := deg_to_rad(spread_degrees)
	var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	up = right.cross(dir).normalized()
	var yaw := randf_range(-spread_rad, spread_rad)
	var pitch := randf_range(-spread_rad, spread_rad)
	return (dir + right * tan(yaw) + up * tan(pitch)).normalized()
