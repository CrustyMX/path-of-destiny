extends Node3D
class_name WorldSpawner

@export var loot_spawn_count: int = 48
@export var enemy_spawning_enabled: bool = true

const LOOT_PICKUP_SCENE := preload("res://scenes/systems/loot_pickup.tscn")
const ENEMY_SPAWNER_SCRIPT := preload("res://scripts/systems/enemy_spawner.gd")
const WB := preload("res://scripts/world/world_builder.gd")

const SPAWN_POINTS := [
	{"pos": Vector3(0, 0, 72), "types": ["cultist", "drone"], "max": 2},
	{"pos": Vector3(0, 0, 42), "types": ["cultist", "cultist"], "max": 2},
	{"pos": Vector3(28, 0, 28), "types": ["drone", "cultist"], "max": 2},
	{"pos": Vector3(-26, 0, 30), "types": ["brute", "cultist"], "max": 2},
	{"pos": Vector3(34, 0, -24), "types": ["drone", "drone"], "max": 2},
	{"pos": Vector3(-32, 0, -28), "types": ["cultist", "brute"], "max": 2},
	{"pos": Vector3(52, 0, -8), "types": ["brute"], "max": 1},
	{"pos": Vector3(-48, 0, -10), "types": ["drone", "brute"], "max": 2},
	{"pos": Vector3(46, 0, 36), "types": ["cultist", "drone"], "max": 2},
	{"pos": Vector3(-44, 0, 38), "types": ["brute", "cultist"], "max": 2},
	{"pos": Vector3(18, 0, -52), "types": ["drone", "cultist"], "max": 2},
	{"pos": Vector3(-20, 0, -48), "types": ["cultist", "brute"], "max": 2},
	{"pos": Vector3(58, 0, 18), "types": ["drone", "brute"], "max": 2},
	{"pos": Vector3(-56, 0, 16), "types": ["cultist", "drone", "brute"], "max": 2},
	{"pos": Vector3(10, 0, 82), "types": ["cultist"], "max": 1},
	{"pos": Vector3(-12, 0, 78), "types": ["drone"], "max": 1},
]

func _ready() -> void:
	GameManager.enemy_spawning_enabled = enemy_spawning_enabled
	call_deferred("_spawn_loot")
	call_deferred("_setup_enemy_spawners")
	GameManager.enter_zone("Ashfall Expanse")

func _spawn_loot() -> void:
	var tables := ["exploration", "exploration", "weapon", "armor"]
	for i in range(loot_spawn_count):
		var pickup = LOOT_PICKUP_SCENE.instantiate()
		var pos: Vector3 = WB.random_map_position(18.0, WB.MAP_HALF_SIZE - 8.0)
		pickup.position = pos
		pickup.loot_table = tables[randi() % tables.size()]
		add_child(pickup)

func _setup_enemy_spawners() -> void:
	var spawners := Node3D.new()
	spawners.name = "EnemySpawners"
	add_child(spawners)
	for point in SPAWN_POINTS:
		if WB.is_near_boss(point.pos, WB.BOSS_CLEAR_RADIUS + 2.0):
			continue
		var spawner := Node3D.new()
		spawner.name = "Spawner_%s" % str(point.pos)
		spawner.position = point.pos
		spawner.set_script(ENEMY_SPAWNER_SCRIPT)
		spawner.set("mob_types", point.types)
		spawner.set("max_alive", point.max)
		spawner.set("respawn_delay", randf_range(14.0, 24.0))
		spawner.set("spawn_radius", 8.0)
		spawner.set("activation_range", 58.0)
		spawner.set("avoid_center", WB.BOSS_CENTER)
		spawner.set("avoid_radius", WB.BOSS_CLEAR_RADIUS)
		spawners.add_child(spawner)
		spawner.call_deferred("_try_initial_spawn")
