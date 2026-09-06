extends Node

enum AffixOp { ADD, MULTIPLY }

const AFFIXES := {
	"ferocious": {
		"label": "Ferocious",
		"description": "Adds flat bonus damage to weapons.",
		"stat": "damage",
		"op": AffixOp.ADD,
		"min": 4.0,
		"max": 14.0,
		"types": ["weapon"],
	},
	"swift": {
		"label": "Swift",
		"description": "Reduces time between shots so you fire faster.",
		"stat": "fire_rate",
		"op": AffixOp.MULTIPLY,
		"min": 0.86,
		"max": 0.96,
		"types": ["weapon"],
	},
	"lethal": {
		"label": "Lethal",
		"description": "Increases critical hit chance.",
		"stat": "crit_chance",
		"op": AffixOp.ADD,
		"min": 0.03,
		"max": 0.10,
		"types": ["weapon"],
	},
	"focused": {
		"label": "Focused",
		"description": "Multiplies weapon damage by a percentage.",
		"stat": "damage",
		"op": AffixOp.MULTIPLY,
		"min": 1.05,
		"max": 1.14,
		"types": ["weapon"],
	},
	"reinforced": {
		"label": "Reinforced",
		"description": "Adds flat armor, reducing incoming damage.",
		"stat": "armor",
		"op": AffixOp.ADD,
		"min": 6.0,
		"max": 18.0,
		"types": ["armor"],
	},
	"warded": {
		"label": "Warded",
		"description": "Multiplies total armor by a percentage.",
		"stat": "armor",
		"op": AffixOp.MULTIPLY,
		"min": 1.08,
		"max": 1.22,
		"types": ["armor"],
	},
	"agile": {
		"label": "Agile",
		"description": "Increases movement speed while this gear is equipped.",
		"stat": "move_speed",
		"op": AffixOp.MULTIPLY,
		"min": 1.04,
		"max": 1.12,
		"types": ["armor", "weapon"],
	},
	"efficient": {
		"label": "Efficient",
		"description": "Reduces ability and grenade cooldown times.",
		"stat": "cooldown_reduction",
		"op": AffixOp.ADD,
		"min": 0.04,
		"max": 0.12,
		"types": ["armor", "weapon"],
	},
	"auspex": {
		"label": "Auspex Array",
		"description": "Extends threat radar detection range.",
		"stat": "radar_range",
		"op": AffixOp.ADD,
		"min": 6.0,
		"max": 18.0,
		"types": ["armor"],
	},
	"field_kit": {
		"label": "Field Kit",
		"description": "Adds extra health potion charges.",
		"stat": "health_pots",
		"op": AffixOp.ADD,
		"min": 1.0,
		"max": 3.0,
		"types": ["armor"],
	},
}

const STAT_DESCRIPTIONS := {
	"damage": "Total damage dealt per hit with this gear equipped, including affix bonuses.",
	"fire_rate": "Seconds between shots. Lower values mean a faster rate of fire.",
	"armor": "Damage reduction from gear. Higher armor blocks more incoming hits.",
	"crit_chance": "Chance for attacks to deal critical damage.",
	"move_speed": "Movement speed multiplier while this gear is equipped.",
	"cooldown_reduction": "Percentage reduction applied to grenade recharge and ability cooldowns.",
	"radar_range": "Threat radar reach in meters. Base 24m; armor bonuses extend long-range detection.",
	"health_pots": "Bonus health potion charges beyond the base 3.",
}

const RARITY_AFFIX_COUNT := {
	LootManager.Rarity.COMMON: 0,
	LootManager.Rarity.UNCOMMON: 1,
	LootManager.Rarity.RARE: 2,
	LootManager.Rarity.LEGENDARY: 3,
	LootManager.Rarity.EXOTIC: 3,
}

const RARITY_VALUE_MULT := {
	LootManager.Rarity.COMMON: 1.0,
	LootManager.Rarity.UNCOMMON: 1.0,
	LootManager.Rarity.RARE: 1.12,
	LootManager.Rarity.LEGENDARY: 1.28,
	LootManager.Rarity.EXOTIC: 1.45,
}

const ARMOR_BASE_IDS := {
	"Flak Vest": "flak_vest",
	"Scout Carapace": "scout_carapace",
	"Carapace Layer": "carapace_layer",
	"Tactical Plating": "tactical_plating",
	"Aegis Terminator": "aegis_terminator",
	"Gravis Dreadplate": "gravis_dreadplate",
}

func roll_affixes(item_type: String, rarity: int) -> Array:
	var count: int = RARITY_AFFIX_COUNT.get(rarity, 0)
	if count <= 0:
		return []
	var pool: Array[String] = []
	for affix_id in AFFIXES:
		var def: Dictionary = AFFIXES[affix_id]
		if item_type in def.get("types", []):
			pool.append(affix_id)
	if pool.is_empty():
		return []
	pool.shuffle()
	var rolled: Array = []
	var used: Dictionary = {}
	for affix_id in pool:
		if rolled.size() >= count:
			break
		if used.has(affix_id):
			continue
		used[affix_id] = true
		rolled.append(_roll_affix_instance(affix_id, rarity))
	return rolled

func assign_base_id(item: Dictionary) -> void:
	match item.get("type", ""):
		"weapon":
			item["base_id"] = WeaponLibrary.weapon_id_from_loot(item)
		"armor":
			item["base_id"] = ARMOR_BASE_IDS.get(item.get("name", ""), "")
		_:
			item["base_id"] = ""

func apply_affix_to_stat_manager(affix: Dictionary) -> void:
	var def: Dictionary = AFFIXES.get(affix.get("id", ""), {})
	if def.is_empty():
		return
	var stat_id: String = def.get("stat", "")
	if stat_id.is_empty():
		return
	var op: int = StatManager.ModifierOp.ADD if def.get("op") == AffixOp.ADD else StatManager.ModifierOp.MULTIPLY
	var value: float = float(affix.get("value", 0.0))
	StatManager.add_modifier(stat_id, StatManager.ModifierSource.GEAR, op, value)

func format_affix(affix: Dictionary) -> String:
	var def: Dictionary = AFFIXES.get(affix.get("id", ""), {})
	if def.is_empty():
		return affix.get("id", "Unknown")
	var label: String = def.get("label", affix.get("id", "Affix"))
	var stat_id: String = def.get("stat", "")
	var value: float = float(affix.get("value", 0.0))
	match stat_id:
		"damage":
			if def.get("op") == AffixOp.MULTIPLY:
				return "%s (+%d%% damage)" % [label, int(round((value - 1.0) * 100.0))]
			return "%s (+%d damage)" % [label, int(round(value))]
		"armor":
			if def.get("op") == AffixOp.MULTIPLY:
				return "%s (+%d%% armor)" % [label, int(round((value - 1.0) * 100.0))]
			return "%s (+%d armor)" % [label, int(round(value))]
		"fire_rate":
			return "%s (%d%% faster fire)" % [label, int(round((1.0 - value) * 100.0))]
		"crit_chance":
			return "%s (+%d%% crit)" % [label, int(round(value * 100.0))]
		"move_speed":
			return "%s (+%d%% move speed)" % [label, int(round((value - 1.0) * 100.0))]
		"cooldown_reduction":
			return "%s (+%d%% cooldown reduction)" % [label, int(round(value * 100.0))]
		"radar_range":
			return "%s (+%dm radar)" % [label, int(round(value))]
		"health_pots":
			return "%s (+%d health pots)" % [label, int(round(value))]
	return "%s" % label

func get_meta_description(meta: String) -> String:
	if meta.begins_with("affix:"):
		return get_affix_description(meta.substr(6))
	if meta.begins_with("stat:"):
		return get_stat_description(meta.substr(5))
	return ""

func get_affix_description(affix_id: String) -> String:
	var def: Dictionary = AFFIXES.get(affix_id, {})
	if def.is_empty():
		return ""
	var lines: PackedStringArray = []
	lines.append(def.get("label", affix_id))
	if def.has("description"):
		lines.append(str(def.get("description", "")))
	lines.append(_get_affix_mechanics(def))
	return "\n".join(lines)

func get_stat_description(stat_id: String) -> String:
	return STAT_DESCRIPTIONS.get(stat_id, "")

func format_affix_bbcode(affix: Dictionary, suffix: String = "") -> String:
	var affix_id: String = affix.get("id", "")
	var text := format_affix(affix) + suffix
	if affix_id.is_empty():
		return text
	return "[url=affix:%s][color=#a8d4ff]%s[/color][/url]" % [affix_id, text]

func format_stat_label_bbcode(stat_id: String, label: String) -> String:
	return "[url=stat:%s][color=#a8d4ff]%s[/color][/url]" % [stat_id, label]

func _get_affix_mechanics(def: Dictionary) -> String:
	var stat_id: String = def.get("stat", "")
	match stat_id:
		"damage":
			if def.get("op") == AffixOp.MULTIPLY:
				return "Effect: multiplies weapon damage."
			return "Effect: adds flat damage to each attack."
		"armor":
			if def.get("op") == AffixOp.MULTIPLY:
				return "Effect: multiplies total armor."
			return "Effect: adds flat armor."
		"fire_rate":
			return "Effect: lowers fire interval (higher % = faster shooting)."
		"crit_chance":
			return "Effect: adds to your critical hit chance."
		"move_speed":
			return "Effect: increases run speed while equipped."
		"cooldown_reduction":
			return "Effect: shortens cooldowns on grenades and abilities."
		"radar_range":
			return "Effect: extends threat radar to detect distant enemies."
		"health_pots":
			return "Effect: increases maximum health potion charges."
	return ""

func format_affix_lines(affixes: Array) -> String:
	if affixes.is_empty():
		return ""
	var lines: PackedStringArray = []
	for affix in affixes:
		if affix is Dictionary:
			lines.append(format_affix(affix))
	return "\n".join(lines)

func format_item_with_affixes(item: Dictionary) -> String:
	var header: String = str(item.get("name", "Item"))
	var affix_text: String = format_affix_lines(item.get("affixes", []))
	if affix_text.is_empty():
		return header
	return "%s\n%s" % [header, affix_text]

func roll_boss_affixes(item_type: String, rarity: int) -> Array:
	var roll_rarity: int = maxi(rarity, LootManager.Rarity.LEGENDARY)
	var affixes: Array = roll_affixes(item_type, roll_rarity)
	var used: Dictionary = {}
	for affix in affixes:
		if affix is Dictionary:
			used[affix.get("id", "")] = true
	var pool: Array[String] = []
	for affix_id in AFFIXES:
		var def: Dictionary = AFFIXES[affix_id]
		if item_type in def.get("types", []) and not used.has(affix_id):
			pool.append(affix_id)
	pool.shuffle()
	while affixes.size() < 3 and not pool.is_empty():
		var affix_id: String = pool.pop_front()
		affixes.append(_roll_affix_instance(affix_id, LootManager.Rarity.EXOTIC, true))
	var boss_affixes: Array = []
	for affix in affixes:
		if affix is Dictionary:
			boss_affixes.append(_roll_affix_instance(affix.get("id", ""), LootManager.Rarity.EXOTIC, true))
	return boss_affixes

func _roll_affix_instance(affix_id: String, rarity: int, boss_loot: bool = false) -> Dictionary:
	var def: Dictionary = AFFIXES.get(affix_id, {})
	if def.is_empty():
		return {"id": affix_id, "value": 0.0}
	var roll_rarity := rarity
	if boss_loot:
		roll_rarity = LootManager.Rarity.EXOTIC
	var mult: float = RARITY_VALUE_MULT.get(roll_rarity, 1.0)
	var min_val: float = def.get("min", 0.0)
	var max_val: float = def.get("max", min_val)
	var rolled: float = randf_range(min_val, max_val)
	if boss_loot:
		rolled = lerpf(rolled, max_val, 0.78)
	if def.get("op") == AffixOp.ADD:
		rolled *= mult
	elif def.get("op") == AffixOp.MULTIPLY:
		if rolled >= 1.0:
			rolled = 1.0 + (rolled - 1.0) * mult
		else:
			rolled = 1.0 - (1.0 - rolled) * mult
	if def.get("stat") == "damage" and def.get("op") == AffixOp.ADD:
		rolled = round(rolled)
	elif def.get("stat") == "armor" and def.get("op") == AffixOp.ADD:
		rolled = round(rolled)
	elif def.get("stat") == "crit_chance":
		rolled = snappedf(rolled, 0.01)
	elif def.get("stat") == "cooldown_reduction":
		rolled = snappedf(rolled, 0.01)
	elif def.get("stat") == "health_pots":
		rolled = round(rolled)
	else:
		rolled = snappedf(rolled, 0.01)
	return {"id": affix_id, "value": rolled}
