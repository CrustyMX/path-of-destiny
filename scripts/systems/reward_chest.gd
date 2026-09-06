extends Area3D
class_name RewardChest

signal chest_opened
signal chest_loot_spawned

const LOOT_PICKUP_SCENE := preload("res://scenes/systems/loot_pickup.tscn")

@export var interact_range: float = 3.2
@export var use_boss_loot: bool = false
@export var auto_open_delay: float = -1.0

var opened: bool = false
var _loot_kinds: Array[String] = []
var _mesh_root: Node3D
var _label: Label3D
var _lid: MeshInstance3D

func configure(kinds: Array, boss_loot: bool = false, auto_open: float = -1.0) -> void:
	_loot_kinds.clear()
	for kind in kinds:
		_loot_kinds.append(str(kind))
	use_boss_loot = boss_loot
	auto_open_delay = auto_open

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 8
	collision_mask = 2
	_build_visual()
	_update_prompt()
	if auto_open_delay >= 0.0:
		get_tree().create_timer(auto_open_delay).timeout.connect(_open)

func _build_visual() -> void:
	for child in get_children():
		child.queue_free()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 0.9, 0.85)
	col.shape = shape
	col.position = Vector3(0, 0.45, 0)
	add_child(col)
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.28, 0.22, 0.14)
	body_mat.emission_enabled = true
	body_mat.emission = Color(1.0, 0.65, 0.15)
	body_mat.emission_energy_multiplier = 0.5
	body_mat.metallic = 0.55
	body_mat.roughness = 0.4
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.95, 0.72, 0.18)
	lid_mat.emission_enabled = true
	lid_mat.emission = Color(1.0, 0.78, 0.2)
	lid_mat.emission_energy_multiplier = 1.4
	lid_mat.metallic = 0.7
	lid_mat.roughness = 0.25
	var crate := BoxMesh.new()
	crate.size = Vector3(1.0, 0.55, 0.75)
	var crate_inst := MeshInstance3D.new()
	crate_inst.mesh = crate
	crate_inst.material_override = body_mat
	crate_inst.position.y = 0.28
	_mesh_root.add_child(crate_inst)
	var lid := BoxMesh.new()
	lid.size = Vector3(1.05, 0.14, 0.8)
	_lid = MeshInstance3D.new()
	_lid.name = "Lid"
	_lid.mesh = lid
	_lid.material_override = lid_mat
	_lid.position = Vector3(0, 0.62, -0.08)
	_mesh_root.add_child(_lid)
	var beacon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.12
	cyl.height = 0.5
	beacon.mesh = cyl
	beacon.material_override = lid_mat
	beacon.position = Vector3(0, 1.05, 0)
	_mesh_root.add_child(beacon)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.2)
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3(0, 1.2, 0)
	_mesh_root.add_child(light)
	_label = Label3D.new()
	_label.name = "PromptLabel"
	_label.pixel_size = 0.008
	_label.font_size = 28
	_label.outline_size = 4
	_label.position = Vector3(0, 1.45, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

func _process(delta: float) -> void:
	if opened or _mesh_root == null:
		return
	_mesh_root.rotation.y += delta * 0.35
	_update_prompt()

func _update_prompt() -> void:
	if _label == null:
		return
	if opened:
		_label.text = ""
		return
	var player := GameManager.player
	if player and player.global_position.distance_to(global_position) <= interact_range:
		_label.text = "★ Reward Chest — Press E"
		_label.modulate = Color(1.0, 0.85, 0.35)
	else:
		_label.text = "★ Reward Chest"
		_label.modulate = Color(0.85, 0.75, 0.45)

func get_interact_range() -> float:
	return interact_range

func can_interact(player: Node3D) -> bool:
	return not opened and is_instance_valid(player) and player.global_position.distance_to(global_position) <= interact_range

func try_interact(_player: Node3D) -> bool:
	if opened:
		return false
	_open()
	return true

func _open() -> void:
	if opened:
		return
	opened = true
	AudioManager.play_sfx("chest_open", 0.75)
	chest_opened.emit()
	if _label:
		_label.text = "Opening..."
	if _lid:
		var tween := create_tween()
		tween.tween_property(_lid, "rotation:x", deg_to_rad(-108.0), 0.35).set_ease(Tween.EASE_OUT)
	_spawn_loot()
	await get_tree().create_timer(0.4).timeout
	chest_loot_spawned.emit()

func _spawn_loot() -> void:
	var kinds := _loot_kinds
	if kinds.is_empty():
		if use_boss_loot:
			kinds = ["weapon", "weapon", "armor", "armor", "relic", "material"]
		else:
			kinds = ["weapon", "armor", "material"]
	var parent := get_parent()
	if parent == null:
		return
	for i in range(kinds.size()):
		var pickup := LOOT_PICKUP_SCENE.instantiate()
		var item: Dictionary
		if use_boss_loot:
			item = LootManager.roll_boss_loot(kinds[i])
		else:
			item = LootManager.roll_loot(kinds[i], 0.15)
		pickup.configure_loot(item)
		var angle := (float(i) / kinds.size()) * TAU + randf_range(-0.25, 0.25)
		var dist := randf_range(1.0, 2.4)
		pickup.global_position = global_position + Vector3(cos(angle) * dist, 0.6, sin(angle) * dist)
		parent.add_child(pickup)
	if _label:
		_label.text = ""
	var fade := create_tween()
	fade.tween_property(_mesh_root, "scale", Vector3(0.85, 0.85, 0.85), 0.5)
	await fade.finished
	queue_free()
