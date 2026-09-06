extends Node

signal stats_rebuilt

enum ModifierSource { BASE, GEAR, PASSIVE, BUFF }
enum ModifierOp { ADD, MULTIPLY }

const STAT_IDS := [
	"damage",
	"fire_rate",
	"crit_chance",
	"armor",
	"move_speed",
	"cooldown_reduction",
	"radar_range",
	"health_pots",
]

const COOLDOWN_REDUCTION_CAP := 0.75
const MAX_HEALTH_POT_BONUS := 5.0

var _modifiers: Dictionary = {}

func _ready() -> void:
	for stat_id in STAT_IDS:
		_modifiers[stat_id] = []
	WeaponLibrary.weapon_changed.connect(_on_weapon_changed)
	LootManager.inventory_changed.connect(_rebuild_gear_modifiers)
	_rebuild_gear_modifiers()

func get_stat(stat_id: String, context: Dictionary = {}) -> float:
	match stat_id:
		"damage":
			return _resolve_damage(context.get("heavy", false))
		"fire_rate":
			return _resolve_fire_rate(context.get("heavy", false))
		"armor", "crit_chance", "move_speed", "cooldown_reduction", "radar_range", "health_pots":
			return _evaluate(stat_id, _default_base(stat_id))
		_:
			push_warning("StatManager: unknown stat '%s'" % stat_id)
			return 0.0

func get_cooldown_duration(base_cooldown: float) -> float:
	var cdr := get_stat("cooldown_reduction")
	return maxf(0.25, base_cooldown * (1.0 - cdr))

func add_modifier(stat_id: String, source: ModifierSource, op: ModifierOp, value: float) -> void:
	if not _modifiers.has(stat_id):
		_modifiers[stat_id] = []
	_modifiers[stat_id].append({"source": source, "op": op, "value": value})

func clear_modifiers(source: ModifierSource) -> void:
	for stat_id in STAT_IDS:
		_modifiers[stat_id] = _modifiers[stat_id].filter(
			func(mod: Dictionary) -> bool: return mod["source"] != source
		)

func _on_weapon_changed(_weapon_id: String) -> void:
	stats_rebuilt.emit()

func _rebuild_gear_modifiers() -> void:
	clear_modifiers(ModifierSource.GEAR)
	var armor: Dictionary = LootManager.equipped_armor
	if not armor.is_empty():
		var armor_def: int = armor.get("defense", 0)
		if armor_def > 0:
			add_modifier("armor", ModifierSource.GEAR, ModifierOp.ADD, float(armor_def))
		var radar_bonus: float = float(armor.get("radar_bonus", 0))
		if radar_bonus > 0.0:
			add_modifier("radar_range", ModifierSource.GEAR, ModifierOp.ADD, radar_bonus)
		var pot_bonus: float = float(armor.get("pot_bonus", 0))
		if pot_bonus > 0.0:
			add_modifier("health_pots", ModifierSource.GEAR, ModifierOp.ADD, pot_bonus)
		_apply_item_affixes(armor)
	for slot_weapon in LootManager.equipped_weapons:
		if not slot_weapon.is_empty():
			_apply_item_affixes(slot_weapon)
	stats_rebuilt.emit()

func _apply_item_affixes(item: Dictionary) -> void:
	for affix in item.get("affixes", []):
		if affix is Dictionary:
			AffixLibrary.apply_affix_to_stat_manager(affix)

func _resolve_damage(heavy: bool) -> float:
	var w: Dictionary = WeaponLibrary.get_equipped()
	var base: float = w.get("heavy_damage" if heavy else "damage", 0.0)
	return _evaluate("damage", base)

func _resolve_fire_rate(heavy: bool) -> float:
	var w: Dictionary = WeaponLibrary.get_equipped()
	var base: float = w.get("heavy_rate" if heavy else "fire_rate", 0.5)
	return _evaluate("fire_rate", base)

func _default_base(stat_id: String) -> float:
	match stat_id:
		"armor":
			return 0.0
		"crit_chance":
			return 0.05
		"move_speed":
			return 1.0
		"cooldown_reduction":
			return 0.0
		"radar_range":
			return 24.0
	return 0.0

func _evaluate(stat_id: String, base: float) -> float:
	var add_total := 0.0
	var mult_total := 1.0
	for mod in _modifiers.get(stat_id, []):
		match mod["op"]:
			ModifierOp.ADD:
				add_total += mod["value"]
			ModifierOp.MULTIPLY:
				mult_total *= mod["value"]
	var result := (base + add_total) * mult_total
	match stat_id:
		"cooldown_reduction":
			return clampf(result, 0.0, COOLDOWN_REDUCTION_CAP)
		"crit_chance":
			return clampf(result, 0.0, 1.0)
		"move_speed":
			return maxf(0.1, result)
		"fire_rate":
			return maxf(0.02, result)
		"damage":
			return maxf(0.0, result)
		"radar_range":
			return clampf(result, 24.0, 48.0)
		"health_pots":
			return clampf(result, 0.0, MAX_HEALTH_POT_BONUS)
	return maxf(0.0, result)
