extends Node

signal ability_used(ability: Dictionary)
signal ability_ready(slot: int)
signal cooldown_updated(slot: int, remaining: float, total: float)

const ABILITIES := [
	{
		"name": "Void Strike",
		"description": "Dash to targeted foe and detonate void energy for 60 damage.",
		"cooldown": 4.0,
		"mana_cost": 0,
		"damage": 60,
		"type": "dash_attack",
		"range": 22.0,
		"color": Color(0.3, 0.1, 0.8),
	},
	{
		"name": "Plasma Nova",
		"description": "Detonate plasma on the targeted enemy. 80 damage in a 6m blast.",
		"cooldown": 8.0,
		"mana_cost": 0,
		"damage": 80,
		"type": "aoe",
		"radius": 6.0,
		"range": 26.0,
		"color": Color(1.0, 0.4, 0.1),
	},
	{
		"name": "Aegis Barrier",
		"description": "Raise an energy shield. Blocks damage for 3 seconds.",
		"cooldown": 12.0,
		"mana_cost": 0,
		"damage": 0,
		"type": "shield",
		"duration": 3.0,
		"color": Color(0.1, 0.7, 0.9),
	},
	{
		"name": "Chain Lightning",
		"description": "Strike targeted enemy; chains to 2 nearby foes for 45 damage each.",
		"cooldown": 6.0,
		"mana_cost": 0,
		"damage": 45,
		"type": "chain",
		"chains": 3,
		"range": 30.0,
		"chain_range": 10.0,
		"color": Color(0.2, 0.9, 1.0),
	},
]

var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var shield_active: bool = false

func _process(delta: float) -> void:
	for i in range(cooldowns.size()):
		if cooldowns[i] > 0:
			cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
			cooldown_updated.emit(i, cooldowns[i], get_cooldown_total(i))
			if cooldowns[i] <= 0:
				ability_ready.emit(i)

func can_use(slot: int) -> bool:
	if slot < 0 or slot >= ABILITIES.size():
		return false
	return cooldowns[slot] <= 0

func use_ability(slot: int) -> Dictionary:
	if not can_use(slot):
		return {}
	var ability: Dictionary = ABILITIES[slot]
	cooldowns[slot] = StatManager.get_cooldown_duration(ability["cooldown"])
	ability_used.emit(ability)
	return ability

func get_cooldown_total(slot: int) -> float:
	if slot < 0 or slot >= ABILITIES.size():
		return 0.0
	return StatManager.get_cooldown_duration(ABILITIES[slot]["cooldown"])

func get_ability(slot: int) -> Dictionary:
	if slot < 0 or slot >= ABILITIES.size():
		return {}
	return ABILITIES[slot]

func is_shield_active() -> bool:
	return shield_active

func set_shield_active(active: bool) -> void:
	shield_active = active
