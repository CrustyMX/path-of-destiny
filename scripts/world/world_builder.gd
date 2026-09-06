extends Node3D
class_name WorldBuilder

const MAP_HALF_SIZE := 120.0
const MAP_SIZE := MAP_HALF_SIZE * 2.0
const SPAWN_POSITION := Vector3(0.0, 0.0, 98.0)
const BOSS_CENTER := Vector3.ZERO
const BOSS_CLEAR_RADIUS := 22.0

const ZONE_LAYOUT := {
	"zone_ruins": {"name": "Ruined Outpost", "pos": Vector3(62, 0, -52)},
	"zone_scrap": {"name": "Scrap Yard", "pos": Vector3(-58, 0, -60)},
	"zone_vent": {"name": "Ash Vent", "pos": Vector3(68, 0, 58)},
	"zone_hollow": {"name": "Plague Hollow", "pos": Vector3(-64, 0, 54)},
}
const WORLD_COLLISION_LAYER := 1

@export var build_landmarks: bool = true

@onready var _ground: StaticBody3D = $"../Ground"
@onready var _landmarks: Node3D = $Landmarks

func _ready() -> void:
	_build_ground()
	if build_landmarks:
		_build_world_landmarks()

static func is_inside_playable(pos: Vector3, inset: float = 4.0) -> bool:
	return absf(pos.x) <= MAP_HALF_SIZE - inset and absf(pos.z) <= MAP_HALF_SIZE - inset

static func is_near_boss(pos: Vector3, padding: float = BOSS_CLEAR_RADIUS) -> bool:
	var flat := Vector2(pos.x - BOSS_CENTER.x, pos.z - BOSS_CENTER.z)
	return flat.length() < padding

static func random_map_position(min_dist: float, max_dist: float, min_from_center: float = BOSS_CLEAR_RADIUS) -> Vector3:
	for _attempt in range(24):
		var angle := randf() * TAU
		var dist := randf_range(min_dist, max_dist)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if not is_inside_playable(pos):
			continue
		if is_near_boss(pos, min_from_center):
			continue
		for zone_data in ZONE_LAYOUT.values():
			var zone_pos: Vector3 = zone_data["pos"]
			if Vector2(pos.x - zone_pos.x, pos.z - zone_pos.z).length() < 16.0:
				pos = Vector3.INF
				break
		if pos != Vector3.INF:
			pos.y = 0.5
			return pos
	return Vector3(cos(randf() * TAU) * min_dist, 0.5, sin(randf() * TAU) * min_dist)

func _build_ground() -> void:
	if _ground == null:
		return
	var mesh_inst: MeshInstance3D = _ground.get_node("MeshInstance3D")
	var col: CollisionShape3D = _ground.get_node("CollisionShape3D")
	var plane := BoxMesh.new()
	plane.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.09, 0.07)
	mat.roughness = 0.92
	mesh_inst.material_override = mat
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	col.shape = shape
	_ground.position = Vector3(0, -0.1, 0)

func _build_world_landmarks() -> void:
	_build_spawn_camp(SPAWN_POSITION)
	_build_boss_crater(BOSS_CENTER)
	for zone_id in ZONE_LAYOUT:
		var data: Dictionary = ZONE_LAYOUT[zone_id]
		_build_zone_landmark(zone_id, data["name"], data["pos"])
	_build_trail_markers()
	_scatter_rocks(52)
	_scatter_scrap_piles(18)
	_build_boundary_rim()
	_build_elevated_ridges()

func _build_spawn_camp(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "SpawnCamp"
	root.position = pos
	_landmarks.add_child(root)
	_add_disc(root, 7.0, Color(0.25, 0.55, 0.95, 0.22), Color(0.35, 0.75, 1.0), 0.04)
	for i in range(5):
		var angle := -PI * 0.5 + (float(i) / 4.0 - 0.5) * deg_to_rad(70.0)
		var wall := _make_cover_box(Vector3(2.8, 2.2, 0.45), Color(0.18, 0.17, 0.16), Color(0.35, 0.32, 0.28), 0.2)
		wall.position = Vector3(cos(angle) * 5.5, 0, sin(angle) * 5.5)
		wall.rotation.y = -angle + PI * 0.5
		root.add_child(wall)
	var beacon := _make_cover_box(Vector3(0.35, 5.5, 0.35), Color(0.85, 0.55, 0.15), Color(1.0, 0.65, 0.2), 1.6)
	beacon.position = Vector3(0, 0, -2.0)
	root.add_child(beacon)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.55, 0.18)
	fire.light_energy = 2.4
	fire.omni_range = 14.0
	fire.position = Vector3(0, 1.2, 1.5)
	root.add_child(fire)
	var label := _make_label("Drop Zone — Ashfall Expanse")
	label.position = Vector3(0, 4.8, 0)
	root.add_child(label)

func _build_boss_crater(center: Vector3) -> void:
	var root := Node3D.new()
	root.name = "BossCrater"
	root.position = center
	_landmarks.add_child(root)
	_add_disc(root, 19.0, Color(0.85, 0.12, 0.04, 0.18), Color(1.0, 0.22, 0.05), 0.03)
	for i in range(14):
		var angle := (float(i) / 14.0) * TAU
		var dist := randf_range(17.0, 21.0)
		var rock := _make_cover_rock(randf_range(0.8, 1.6))
		rock.position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		rock.rotation.y = randf() * TAU
		root.add_child(rock)

func _build_zone_landmark(zone_id: String, zone_name: String, pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Landmark_%s" % zone_id
	root.position = pos
	_landmarks.add_child(root)
	var accent := _zone_accent(zone_id)
	_add_disc(root, 11.0, accent.darkened(0.55), accent, 0.05)
	match zone_id:
		"zone_ruins":
			for i in range(4):
				var angle := (float(i) / 4.0) * TAU + PI * 0.25
				var wall_h := randf_range(2.0, 4.5)
				var wall := _make_cover_box(Vector3(3.5, wall_h, 0.55), Color(0.2, 0.19, 0.18), accent, 0.15)
				wall.position = Vector3(cos(angle) * 6.0, 0, sin(angle) * 6.0)
				wall.rotation.y = -angle
				root.add_child(wall)
		"zone_scrap":
			for i in range(6):
				var pile_h := randf_range(0.8, 1.8)
				var pile := _make_cover_box(Vector3(randf_range(1.2, 2.4), pile_h, randf_range(1.0, 2.0)), Color(0.16, 0.2, 0.14), Color(0.35, 0.95, 0.35), 0.55)
				pile.position = Vector3(randf_range(-5.0, 5.0), 0, randf_range(-5.0, 5.0))
				pile.rotation.y = randf() * TAU
				root.add_child(pile)
		"zone_vent":
			var vent := _make_cover_cylinder(2.2, 3.5, Color(0.14, 0.14, 0.16), accent, 0.9)
			vent.position = Vector3(0, 0, 0)
			root.add_child(vent)
			for i in range(3):
				var pipe := _make_cover_cylinder(0.35, 4.0, Color(0.22, 0.22, 0.24), accent, 0.35)
				pipe.position = Vector3(cos(float(i) * TAU / 3.0) * 3.5, 0, sin(float(i) * TAU / 3.0) * 3.5)
				root.add_child(pipe)
		"zone_hollow":
			for i in range(5):
				var stump_h := randf_range(1.0, 2.2)
				var stump := _make_cover_cylinder(randf_range(0.5, 0.9), stump_h, Color(0.12, 0.16, 0.1), Color(0.45, 0.95, 0.2), 0.25)
				stump.position = Vector3(randf_range(-6.0, 6.0), 0, randf_range(-6.0, 6.0))
				root.add_child(stump)
	var zone_label := _make_label(zone_name)
	zone_label.position = Vector3(0, 5.5, 0)
	zone_label.modulate = accent.lightened(0.25)
	root.add_child(zone_label)
	var glow := OmniLight3D.new()
	glow.light_color = accent
	glow.light_energy = 1.4
	glow.omni_range = 16.0
	glow.position = Vector3(0, 3.0, 0)
	root.add_child(glow)

func _build_trail_markers() -> void:
	var routes := [
		[SPAWN_POSITION, Vector3(0, 0, 40), BOSS_CENTER],
		[BOSS_CENTER, ZONE_LAYOUT["zone_ruins"]["pos"]],
		[BOSS_CENTER, ZONE_LAYOUT["zone_scrap"]["pos"]],
		[BOSS_CENTER, ZONE_LAYOUT["zone_vent"]["pos"]],
		[BOSS_CENTER, ZONE_LAYOUT["zone_hollow"]["pos"]],
	]
	for route in routes:
		for i in range(route.size() - 1):
			_add_trail_segment(route[i], route[i + 1])

func _add_trail_segment(from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := Vector2(delta.x, delta.z).length()
	if length < 8.0:
		return
	var steps := int(length / 14.0)
	for step in range(1, steps):
		var t := float(step) / float(steps)
		var pos := from.lerp(to, t)
		var marker := _make_box(Vector3(0.35, 1.6, 0.35), Color(0.18, 0.16, 0.14), Color(0.95, 0.55, 0.18), 0.35)
		marker.position = Vector3(pos.x, 0.8, pos.z)
		_landmarks.add_child(marker)

func _scatter_rocks(count: int) -> void:
	for i in range(count):
		var pos := random_map_position(28.0, MAP_HALF_SIZE - 12.0)
		var rock := _make_cover_rock(randf_range(0.7, 2.2))
		rock.position = Vector3(pos.x, 0, pos.z)
		rock.rotation.y = randf() * TAU
		_landmarks.add_child(rock)

func _scatter_scrap_piles(count: int) -> void:
	for i in range(count):
		var pos := random_map_position(20.0, MAP_HALF_SIZE - 10.0)
		var pile_h := randf_range(0.5, 1.2)
		var pile := _make_cover_box(Vector3(randf_range(0.8, 1.8), pile_h, randf_range(0.8, 1.6)), Color(0.15, 0.17, 0.13), Color(0.4, 0.85, 0.35), 0.25)
		pile.position = Vector3(pos.x, 0, pos.z)
		pile.rotation.y = randf() * TAU
		_landmarks.add_child(pile)

func _build_boundary_rim() -> void:
	var rim := Node3D.new()
	rim.name = "BoundaryRim"
	_landmarks.add_child(rim)
	var limit := MAP_HALF_SIZE - 2.0
	for side in range(4):
		for step in range(18):
			var t := -1.0 + (float(step) / 17.0) * 2.0
			var pos := Vector3.ZERO
			match side:
				0: pos = Vector3(t * limit, 0, -limit)
				1: pos = Vector3(t * limit, 0, limit)
				2: pos = Vector3(-limit, 0, t * limit)
				3: pos = Vector3(limit, 0, t * limit)
			var wall_h := randf_range(3.0, 6.0)
			var wall := _make_cover_box(Vector3(8.0, wall_h, 1.2), Color(0.1, 0.09, 0.08), Color(0.25, 0.18, 0.12), 0.08)
			wall.position = pos
			if side < 2:
				wall.rotation.y = PI * 0.5
			rim.add_child(wall)

func _build_elevated_ridges() -> void:
	var ridges := [
		{"pos": Vector3(-35, 0, 0), "size": Vector3(8, 3.5, 34), "rot": 0.0},
		{"pos": Vector3(38, 0, 12), "size": Vector3(10, 2.8, 28), "rot": 0.35},
		{"pos": Vector3(0, 0, -42), "size": Vector3(36, 2.2, 7), "rot": 0.0},
		{"pos": Vector3(12, 0, 36), "size": Vector3(24, 2.6, 8), "rot": 0.22},
	]
	for ridge in ridges:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_COLLISION_LAYER
		body.collision_mask = 0
		body.position = ridge["pos"]
		body.rotation.y = ridge["rot"]
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = ridge["size"]
		col.shape = shape
		col.position = Vector3(0, ridge["size"].y * 0.5, 0)
		body.add_child(col)
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = ridge["size"]
		mesh_inst.mesh = box
		mesh_inst.position = col.position
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.14, 0.12, 0.1)
		mat.roughness = 0.95
		mesh_inst.material_override = mat
		body.add_child(mesh_inst)
		_landmarks.add_child(body)

func _zone_accent(zone_id: String) -> Color:
	match zone_id:
		"zone_scrap": return Color(0.25, 0.95, 0.45)
		"zone_vent": return Color(1.0, 0.45, 0.15)
		"zone_hollow": return Color(0.45, 0.95, 0.2)
		_: return Color(0.35, 0.65, 1.0)

func _add_disc(parent: Node3D, radius: float, fill: Color, emission: Color, height: float) -> void:
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	disc.mesh = cylinder
	disc.position.y = height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fill
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = mat
	parent.add_child(disc)

func _make_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.009
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label

func _make_cover_box(size: Vector3, color: Color, emission: Color, energy: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_COLLISION_LAYER
	body.collision_mask = 0
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = _make_mat(color, emission, energy)
	mesh_inst.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = mesh_inst.position
	body.add_child(col)
	return body

func _make_cover_cylinder(radius: float, height: float, color: Color, emission: Color, energy: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_COLLISION_LAYER
	body.collision_mask = 0
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.92
	cyl.height = height
	mesh_inst.mesh = cyl
	mesh_inst.material_override = _make_mat(color, emission, energy)
	mesh_inst.position = Vector3(0, height * 0.5, 0)
	body.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = mesh_inst.position
	body.add_child(col)
	return body

func _make_cover_rock(scale: float) -> StaticBody3D:
	var size := Vector3(scale, scale * randf_range(0.7, 1.2), scale * randf_range(0.8, 1.1))
	var body := _make_cover_box(size, Color(0.13, 0.12, 0.11), Color(0.22, 0.18, 0.14), 0.05)
	body.rotation.y = randf() * TAU
	return body

func _make_box(size: Vector3, color: Color, emission: Color, energy: float) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.material_override = _make_mat(color, emission, energy)
	return mesh_inst

func _make_cylinder(radius: float, height: float, color: Color, emission: Color, energy: float) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.92
	cyl.height = height
	mesh_inst.mesh = cyl
	mesh_inst.material_override = _make_mat(color, emission, energy)
	return mesh_inst

func _make_mat(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = energy > 0.01
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.88
	mat.metallic = 0.15
	return mat
