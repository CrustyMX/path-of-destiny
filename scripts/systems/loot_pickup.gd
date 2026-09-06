extends Area3D
class_name LootPickup

@export var loot_table: String = "exploration"
@export var auto_collect_range: float = 2.5

var loot_item: Dictionary = {}
var collected: bool = false
var bob_offset: float = 0.0
var _loot_preconfigured: bool = false

@onready var mesh_root: Node3D = $MeshRoot
@onready var label: Label3D = $Label3D

func configure_loot(item: Dictionary) -> void:
	loot_item = item.duplicate(true)
	_loot_preconfigured = true
	if is_node_ready():
		_setup_visual()

func _ready() -> void:
	if not _loot_preconfigured:
		loot_item = LootManager.roll_loot(loot_table)
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _setup_visual() -> void:
	for child in mesh_root.get_children():
		child.queue_free()
	var rarity: int = loot_item.get("rarity", 0)
	var color := LootManager.get_rarity_color(rarity)
	var body_mat := _make_mat(color, 1.2, 0.35)
	var accent_mat := _make_mat(color, 1.9, 0.15)
	match loot_item.get("type", ""):
		"weapon":
			_build_weapon_shape(body_mat, accent_mat)
		"armor":
			_build_armor_shape(body_mat, accent_mat)
		"material":
			_build_material_shape(body_mat, accent_mat)
		"relic":
			_build_relic_shape(body_mat, accent_mat)
		_:
			_build_crate_shape(body_mat, accent_mat)
	_add_ground_ring(color)
	label.text = "◆ %s" % loot_item.get("name", "Loot")
	if loot_item.get("boss_loot", false):
		label.text = "★ %s" % loot_item.get("name", "Loot")
	label.modulate = color
	bob_offset = randf() * TAU

func _make_mat(color: Color, energy: float, darken: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(darken)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.metallic = 0.55
	mat.roughness = 0.32
	return mat

func _add_part(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.rotation = rot
	mesh_root.add_child(inst)

func _build_weapon_shape(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var stock := BoxMesh.new()
	stock.size = Vector3(0.12, 0.14, 0.32)
	_add_part(stock, body_mat, Vector3(0, 0.22, 0.08))
	var receiver := BoxMesh.new()
	receiver.size = Vector3(0.14, 0.16, 0.42)
	_add_part(receiver, body_mat, Vector3(0, 0.24, -0.08))
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.025
	barrel.bottom_radius = 0.025
	barrel.height = 0.72
	_add_part(barrel, accent_mat, Vector3(0, 0.26, -0.48), Vector3(deg_to_rad(90), 0, 0))
	var scope := BoxMesh.new()
	scope.size = Vector3(0.08, 0.08, 0.18)
	_add_part(scope, accent_mat, Vector3(0, 0.34, -0.04))
	var mag := BoxMesh.new()
	mag.size = Vector3(0.08, 0.14, 0.1)
	_add_part(mag, body_mat, Vector3(0, 0.1, 0.02))

func _build_material_shape(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var hub := CylinderMesh.new()
	hub.top_radius = 0.14
	hub.bottom_radius = 0.14
	hub.height = 0.1
	_add_part(hub, body_mat, Vector3(0, 0.24, 0))
	var bore := CylinderMesh.new()
	bore.top_radius = 0.05
	bore.bottom_radius = 0.05
	bore.height = 0.12
	_add_part(bore, accent_mat, Vector3(0, 0.24, 0))
	var tooth_count := 8
	for i in tooth_count:
		var angle := (TAU / float(tooth_count)) * float(i)
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.1, 0.16, 0.07)
		var radius := 0.24
		_add_part(
			tooth,
			accent_mat,
			Vector3(cos(angle) * radius, 0.24, sin(angle) * radius),
			Vector3(0, angle, 0)
		)

func _build_armor_shape(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var chest := BoxMesh.new()
	chest.size = Vector3(0.42, 0.48, 0.28)
	_add_part(chest, body_mat, Vector3(0, 0.28, 0))
	var collar := BoxMesh.new()
	collar.size = Vector3(0.28, 0.1, 0.24)
	_add_part(collar, accent_mat, Vector3(0, 0.52, 0))
	var pauldron_l := BoxMesh.new()
	pauldron_l.size = Vector3(0.16, 0.14, 0.2)
	_add_part(pauldron_l, body_mat, Vector3(-0.3, 0.44, 0), Vector3(0, 0, deg_to_rad(12)))
	var pauldron_r := BoxMesh.new()
	pauldron_r.size = Vector3(0.16, 0.14, 0.2)
	_add_part(pauldron_r, body_mat, Vector3(0.3, 0.44, 0), Vector3(0, 0, deg_to_rad(-12)))
	var belt := BoxMesh.new()
	belt.size = Vector3(0.38, 0.08, 0.26)
	_add_part(belt, accent_mat, Vector3(0, 0.12, 0))

func _build_relic_shape(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var base := CylinderMesh.new()
	base.top_radius = 0.16
	base.bottom_radius = 0.2
	base.height = 0.1
	_add_part(base, body_mat, Vector3(0, 0.08, 0))
	var stem := CylinderMesh.new()
	stem.top_radius = 0.04
	stem.bottom_radius = 0.06
	stem.height = 0.16
	_add_part(stem, body_mat, Vector3(0, 0.2, 0))
	var orb := SphereMesh.new()
	orb.radius = 0.14
	_add_part(orb, accent_mat, Vector3(0, 0.38, 0))
	var halo := TorusMesh.new()
	halo.inner_radius = 0.12
	halo.outer_radius = 0.16
	_add_part(halo, accent_mat, Vector3(0, 0.38, 0), Vector3(deg_to_rad(90), 0, 0))

func _build_crate_shape(body_mat: StandardMaterial3D, accent_mat: StandardMaterial3D) -> void:
	var crate := BoxMesh.new()
	crate.size = Vector3(0.62, 0.28, 0.48)
	_add_part(crate, body_mat, Vector3(0, 0.18, 0))
	var lid := BoxMesh.new()
	lid.size = Vector3(0.66, 0.1, 0.52)
	_add_part(lid, accent_mat, Vector3(0, 0.36, 0))

func _add_ground_ring(color: Color) -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.34
	cyl.height = 0.02
	ring.mesh = cyl
	var mat := _make_mat(color, 1.4, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55
	ring.material_override = mat
	ring.position.y = 0.02
	mesh_root.add_child(ring)

func _process(delta: float) -> void:
	if collected:
		return
	bob_offset += delta * 1.5
	mesh_root.position.y = sin(bob_offset) * 0.08 + 0.15
	mesh_root.rotation.y += delta * 0.6
	var player := GameManager.player
	if player and player.global_position.distance_to(global_position) <= auto_collect_range:
		_collect(player)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_collect(body)

func _collect(_collector: Node) -> void:
	if collected:
		return
	collected = true
	if not LootManager.collect_loot(loot_item):
		collected = false
		return
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(mesh_root, "scale", Vector3(0.05, 0.05, 0.05), 0.3)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(mesh_root, "position:y", mesh_root.position.y + 1.0, 0.3)
	tween.tween_callback(queue_free)
