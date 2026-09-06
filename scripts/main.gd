extends Node3D

@onready var world: Node3D = $OpenWorld
@onready var player: Node3D = $OpenWorld/Player
@onready var hud = $OpenWorld/HUD
@onready var boss_arena = $OpenWorld/BossArena

func _ready() -> void:
	_setup_environment()
	hud.connect_player(player)
	if boss_arena.has_node("Boss"):
		var boss: Node3D = boss_arena.get_node("Boss")
		hud.register_boss(boss)
	call_deferred("_register_boss_waypoint")

func _register_boss_waypoint() -> void:
	GameManager.boss_arena_position = boss_arena.global_position
	hud.set_boss_waypoint(boss_arena.global_position)

func _setup_environment() -> void:
	if ResourceLoader.exists("res://assets/models/environment.glb"):
		var scene = load("res://assets/models/environment.glb")
		if scene is PackedScene:
			var env_model := (scene as PackedScene).instantiate()
			var env_root: Node3D = world.get_node("Environment/EnvironmentModel")
			env_root.add_child(env_model)
			env_model.scale = Vector3(2.4, 2.4, 2.4)
			print("Environment loaded: ", env_model.get_child_count(), " nodes")
		else:
			push_warning("environment.glb did not load as PackedScene")
