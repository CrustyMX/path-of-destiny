extends Node

signal attack_threat(world_pos: Vector3, duration: float, strength: float)
signal hit_threat(world_pos: Vector3, duration: float, strength: float)

const DAMAGE_NUMBER_SCENE := preload("res://scenes/ui/damage_number.tscn")

func spawn_damage_number(world_pos: Vector3, amount: float, is_kill: bool = false, is_crit: bool = false, height_offset: float = 1.65) -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var label: Label3D
	if DAMAGE_NUMBER_SCENE:
		label = DAMAGE_NUMBER_SCENE.instantiate() as Label3D
	else:
		label = Label3D.new()
	if is_crit:
		label.text = "CRIT -%d" % int(round(amount))
	else:
		label.text = "-%d" % int(round(amount))
	label.font_size = 40 if is_kill else (34 if is_crit else 28)
	label.outline_size = 8
	if is_kill:
		label.modulate = Color(1.0, 0.2, 0.12)
	elif is_crit:
		label.modulate = Color(1.0, 0.55, 0.15)
	else:
		label.modulate = Color(1.0, 0.88, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.007
	root.add_child(label)
	label.global_position = world_pos + Vector3(randf_range(-0.2, 0.2), height_offset, randf_range(-0.2, 0.2))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.1, 0.65)
	tween.tween_property(label, "global_position:x", label.global_position.x + randf_range(-0.15, 0.15), 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(label.queue_free)

func register_enemy_hit(enemy: Node3D, amount: float, is_kill: bool, is_crit: bool = false, hit_pos: Vector3 = Vector3.INF, crit_spot: bool = false) -> void:
	var spawn_pos := hit_pos if hit_pos != Vector3.INF else enemy.global_position
	var height := 4.8 if enemy.is_in_group("boss") else 1.65
	spawn_damage_number(spawn_pos, amount, is_kill, is_crit, height)
	flash_enemy(enemy)
	var region := _resolve_hit_region(enemy, hit_pos)
	GameDiag.register_enemy_hit(enemy, amount, is_crit, crit_spot, is_kill, hit_pos, region)
	if is_crit:
		AudioManager.play_sfx("impact_crit", 0.85)
	else:
		AudioManager.play_sfx("impact_enemy", 0.75)
	if is_crit or amount >= 30.0:
		screen_shake(0.42 if is_kill else 0.28)
	if is_kill:
		AudioManager.play_sfx("enemy_death", 0.8, randf_range(0.9, 1.05))

func _resolve_hit_region(enemy: Node3D, hit_pos: Vector3) -> String:
	if not is_instance_valid(enemy) or hit_pos == Vector3.INF:
		return "unknown"
	if enemy.has_method("get_hit_region"):
		return str(enemy.get_hit_region(hit_pos))
	return "body"

func register_wall_hit() -> void:
	AudioManager.play_sfx("impact_wall", 0.65)

func register_player_hit(damage: float) -> void:
	if GameManager.current_state == GameManager.GameState.DEAD:
		return
	AudioManager.play_sfx("player_hurt", clampf(damage / 30.0, 0.35, 0.9))
	if damage >= 20.0:
		screen_shake(0.5)
	elif damage >= 10.0:
		screen_shake(0.22)

func register_attack_threat(source: Node3D, duration: float = 0.85, strength: float = 1.0) -> void:
	if not is_instance_valid(source):
		return
	var pos := source.global_position + Vector3(0.0, 1.0, 0.0)
	attack_threat.emit(pos, duration, strength)

func register_hit_threat(source: Node3D, duration: float = 1.15, strength: float = 1.0) -> void:
	if not is_instance_valid(source):
		return
	var pos := source.global_position + Vector3(0.0, 1.0, 0.0)
	hit_threat.emit(pos, duration, strength)

func flash_enemy(enemy: Node3D) -> void:
	var container: Node3D = enemy.get_node_or_null("Model") as Node3D
	if not container:
		return
	_flash_meshes_recursive(container)

func _flash_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		if mat:
			var orig_energy := mat.emission_energy_multiplier
			var orig_color := mat.emission
			mat.emission = Color(1.0, 0.35, 0.2)
			mat.emission_energy_multiplier = 3.5
			var tween := mesh.create_tween()
			tween.tween_property(mat, "emission", orig_color, 0.14)
			tween.parallel().tween_property(mat, "emission_energy_multiplier", orig_energy, 0.14)
	for child in node.get_children():
		_flash_meshes_recursive(child)

func screen_shake(intensity: float) -> void:
	var player := GameManager.player
	if player and player.has_method("apply_screen_shake"):
		player.apply_screen_shake(intensity)

func show_fps_shot_pulse(color: Color = Color(1.0, 0.92, 0.75, 0.85)) -> void:
	for node in get_tree().get_nodes_in_group("crosshair"):
		if node.has_method("show_shot_pulse"):
			node.show_shot_pulse(color)
			return
