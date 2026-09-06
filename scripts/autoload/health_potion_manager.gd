extends Node

signal potions_changed(count: int, max_count: int)
signal use_cooldown_updated(remaining: float, total: float)

const BASE_MAX_POTIONS := 3
const MAX_POTION_CAP := 8
const USE_COOLDOWN := 0.65
const HEAL_PERCENT := 0.35

var potion_count: int = BASE_MAX_POTIONS
var _cooldown: float = 0.0
var _last_max: int = BASE_MAX_POTIONS

func _ready() -> void:
	if StatManager.has_signal("stats_rebuilt"):
		StatManager.stats_rebuilt.connect(_on_stats_rebuilt)
	_sync_to_max(true)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
		use_cooldown_updated.emit(_cooldown, USE_COOLDOWN)

func get_max_potions() -> int:
	var bonus := int(round(StatManager.get_stat("health_pots")))
	return clampi(BASE_MAX_POTIONS + bonus, BASE_MAX_POTIONS, MAX_POTION_CAP)

func get_bonus_potions() -> int:
	return get_max_potions() - BASE_MAX_POTIONS

func can_use() -> bool:
	return potion_count > 0 and _cooldown <= 0.0

func use_potion(player: Node) -> bool:
	if not can_use() or not is_instance_valid(player):
		return false
	if "is_dead" in player and player.is_dead:
		return false
	if not player.has_method("heal"):
		return false
	var max_hp := float(player.MAX_HEALTH) if "MAX_HEALTH" in player else 100.0
	var current_hp := float(player.health) if "health" in player else max_hp
	if current_hp >= max_hp - 0.5:
		return false
	var heal_amount := max_hp * HEAL_PERCENT
	player.heal(heal_amount)
	potion_count -= 1
	_cooldown = USE_COOLDOWN
	potions_changed.emit(potion_count, get_max_potions())
	use_cooldown_updated.emit(_cooldown, USE_COOLDOWN)
	AudioManager.play_sfx("ability_shield", 0.42, 1.18)
	return true

func reset_potions() -> void:
	potion_count = get_max_potions()
	_cooldown = 0.0
	_last_max = get_max_potions()
	potions_changed.emit(potion_count, get_max_potions())
	use_cooldown_updated.emit(0.0, USE_COOLDOWN)

func _on_stats_rebuilt() -> void:
	_sync_to_max(false)

func _sync_to_max(fill_new: bool) -> void:
	var new_max := get_max_potions()
	if fill_new:
		potion_count = new_max
	elif new_max > _last_max:
		potion_count = mini(potion_count + (new_max - _last_max), new_max)
	else:
		potion_count = mini(potion_count, new_max)
	_last_max = new_max
	potions_changed.emit(potion_count, new_max)
