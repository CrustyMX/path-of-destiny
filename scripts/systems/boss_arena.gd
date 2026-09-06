extends Area3D
class_name BossArena

signal arena_entered

@export var boss_name: String = "The Corrupted Warmaster"
@export var inner_trigger_radius: float = 11.0
@export var barrier_radius: float = 15.5
@export var entrance_gap_degrees: float = 40.0

@onready var boss: Node3D = $Boss
@onready var inner_trigger: Area3D = $InnerTrigger
@onready var trigger_label: Label3D = $TriggerLabel
@onready var markers: Node3D = $Markers
@onready var barrier_walls: Node3D = $BarrierWalls

const REWARD_CHEST_SCENE := preload("res://scenes/systems/reward_chest.tscn")

var triggered: bool = false

func _ready() -> void:
	inner_trigger.body_entered.connect(_on_inner_entered)
	trigger_label.visible = true
	trigger_label.text = "⚠ BOSS ARENA: %s" % boss_name
	_setup_visual_markers()
	_build_barrier_walls(false)
	GameManager.boss_arena_position = global_position
	GameManager.boss_arena_center = global_position
	GameManager.boss_arena_radius = barrier_radius

func _setup_visual_markers() -> void:
	var floor_disc := MeshInstance3D.new()
	floor_disc.name = "FloorDisc"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 14.0
	cylinder.bottom_radius = 14.0
	cylinder.height = 0.08
	floor_disc.mesh = cylinder
	floor_disc.position.y = 0.04
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.8, 0.15, 0.05, 0.35)
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(1.0, 0.25, 0.05)
	floor_mat.emission_energy_multiplier = 1.5
	floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	floor_disc.material_override = floor_mat
	markers.add_child(floor_disc)
	var beacon := OmniLight3D.new()
	beacon.name = "Beacon"
	beacon.light_color = Color(1.0, 0.2, 0.05)
	beacon.light_energy = 3.0
	beacon.omni_range = 20.0
	beacon.position = Vector3(0, 6, 0)
	markers.add_child(beacon)
	for i in range(4):
		var angle := (float(i) / 4.0) * TAU + PI
		var px := cos(angle) * 12.0
		var pz := sin(angle) * 12.0
		var pillar := MeshInstance3D.new()
		pillar.name = "TorchPillar_%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.4, 3.0, 0.4)
		pillar.mesh = box
		pillar.position = Vector3(px, 1.5, pz)
		var pillar_mat := StandardMaterial3D.new()
		pillar_mat.albedo_color = Color(0.25, 0.27, 0.3)
		pillar_mat.emission_enabled = true
		pillar_mat.emission = Color(1.0, 0.35, 0.05)
		pillar_mat.emission_energy_multiplier = 0.8
		pillar.material_override = pillar_mat
		markers.add_child(pillar)
		var torch_light := OmniLight3D.new()
		torch_light.light_color = Color(1.0, 0.4, 0.1)
		torch_light.light_energy = 1.2
		torch_light.omni_range = 8.0
		torch_light.position = Vector3(px, 3.2, pz)
		markers.add_child(torch_light)

func _build_barrier_walls(active: bool, leave_entrance_gap: bool = true) -> void:
	for child in barrier_walls.get_children():
		child.queue_free()
	if not active:
		return
	var gap_half := deg_to_rad(entrance_gap_degrees) * 0.5 if leave_entrance_gap else 0.0
	var gap_center := PI * 0.5
	var segments := 20
	for i in range(segments):
		var angle := (float(i) / segments) * TAU
		if leave_entrance_gap:
			var delta := absf(wrapf(angle - gap_center, -PI, PI))
			if delta < gap_half:
				continue
		var px := cos(angle) * barrier_radius
		var pz := sin(angle) * barrier_radius
		var wall := StaticBody3D.new()
		wall.name = "BarrierWall_%d" % i
		wall.collision_layer = 1
		wall.add_to_group("arena_barrier")
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.8, 6.0, 0.8)
		col.shape = shape
		wall.add_child(col)
		wall.position = Vector3(px, 3.0, pz)
		wall.rotation.y = -angle + PI * 0.5
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.8, 6.0, 0.8)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.24, 0.28, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.2, 0.05)
		mat.emission_energy_multiplier = 0.6
		mesh_inst.material_override = mat
		wall.add_child(mesh_inst)
		barrier_walls.add_child(wall)

func _on_inner_entered(body: Node3D) -> void:
	if triggered:
		return
	if body.is_in_group("player") or body.name == "Player":
		_trigger_boss_fight(body)
	elif body.get_parent() and body.get_parent().is_in_group("player"):
		_trigger_boss_fight(body.get_parent())

func _trigger_boss_fight(player: Node3D) -> void:
	triggered = true
	trigger_label.visible = false
	GameManager.evict_enemies_from_boss_arena()
	# Seal the arena completely once the fight starts
	_build_barrier_walls(true, false)
	GameManager.boss_arena_center = global_position
	if boss.has_method("set_arena_bounds"):
		boss.set_arena_bounds(global_position, barrier_radius - 1.0)
	if boss.has_method("activate"):
		boss.activate(player)
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)
	GameManager.on_boss_fight_started(boss)
	arena_entered.emit()

func _on_boss_died() -> void:
	var loot_origin := global_position
	if is_instance_valid(boss):
		loot_origin = boss.global_position
	await get_tree().create_timer(2.0).timeout
	_build_barrier_walls(false)
	_spawn_boss_loot(loot_origin)

func _spawn_boss_loot(origin: Vector3) -> void:
	var drop_kinds: Array[String] = ["weapon", "weapon", "armor", "armor", "relic", "material"]
	var chest := REWARD_CHEST_SCENE.instantiate()
	chest.configure(drop_kinds, true, 1.25)
	chest.global_position = origin + Vector3(0, 0.2, 0)
	get_parent().add_child(chest)
	CombatFeedback.screen_shake(0.55)
