extends Node

signal loot_collected(item: Dictionary)
signal inventory_changed
signal gear_equipped(item: Dictionary)
signal inventory_full(item: Dictionary)
signal item_scrapped(item: Dictionary, scrap_gain: int)

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY, EXOTIC }

const SCRAP_MATERIAL_NAME := "Scrap Alloy"

const SCRAP_BASE_BY_RARITY := {
	Rarity.COMMON: 4,
	Rarity.UNCOMMON: 10,
	Rarity.RARE: 24,
	Rarity.LEGENDARY: 50,
	Rarity.EXOTIC: 90,
}

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.7, 0.7, 0.7),
	Rarity.UNCOMMON: Color(0.2, 0.8, 0.2),
	Rarity.RARE: Color(0.2, 0.4, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.6, 0.0),
	Rarity.EXOTIC: Color(0.8, 0.2, 0.9),
}

const RARITY_NAMES := {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.LEGENDARY: "Legendary",
	Rarity.EXOTIC: "Exotic",
}

const LOOT_TABLES := {
	"exploration": [
		{"name": "Scrap Alloy", "type": "material", "rarity": Rarity.COMMON, "value": 5},
		{"name": "Power Cell", "type": "material", "rarity": Rarity.UNCOMMON, "value": 15},
		{"name": "Plasma Cell", "type": "material", "rarity": Rarity.UNCOMMON, "value": 20},
		{"name": "Void Shard", "type": "material", "rarity": Rarity.RARE, "value": 50},
		{"name": "Archeotech Wire", "type": "material", "rarity": Rarity.RARE, "value": 35},
		{"name": "Relic Fragment", "type": "relic", "rarity": Rarity.LEGENDARY, "value": 200},
		{"name": "Ember Relic", "type": "relic", "rarity": Rarity.LEGENDARY, "value": 120},
		{"name": "Destiny Core", "type": "relic", "rarity": Rarity.EXOTIC, "value": 500},
	],
	"weapon": [
		{"name": "Autopistol Mk III", "type": "weapon", "rarity": Rarity.COMMON, "damage": 18},
		{"name": "Autogun SMG", "type": "weapon", "rarity": Rarity.COMMON, "damage": 12},
		{"name": "Bolter Mk VII", "type": "weapon", "rarity": Rarity.UNCOMMON, "damage": 25},
		{"name": "Scout Rifle Mk II", "type": "weapon", "rarity": Rarity.UNCOMMON, "damage": 38},
		{"name": "Chainaxe", "type": "weapon", "rarity": Rarity.UNCOMMON, "damage": 42},
		{"name": "Long Las Mk IV", "type": "weapon", "rarity": Rarity.RARE, "damage": 95},
		{"name": "Frag Launcher", "type": "weapon", "rarity": Rarity.RARE, "damage": 68},
		{"name": "Heavy Stubber LMG", "type": "weapon", "rarity": Rarity.RARE, "damage": 22},
		{"name": "Plasma Caster", "type": "weapon", "rarity": Rarity.RARE, "damage": 45},
		{"name": "Meltagun Mk I", "type": "weapon", "rarity": Rarity.RARE, "damage": 55},
		{"name": "Meltagun Mk I", "type": "weapon", "rarity": Rarity.RARE, "damage": 55},
		{"name": "Krak Launcher", "type": "weapon", "rarity": Rarity.LEGENDARY, "damage": 125},
		{"name": "Void Reaper", "type": "weapon", "rarity": Rarity.LEGENDARY, "damage": 80},
	],
	"armor": [
		{"name": "Flak Vest", "type": "armor", "rarity": Rarity.COMMON, "defense": 8},
		{"name": "Scout Carapace", "type": "armor", "rarity": Rarity.UNCOMMON, "defense": 15, "radar_bonus": 12},
		{"name": "Carapace Layer", "type": "armor", "rarity": Rarity.UNCOMMON, "defense": 20, "pot_bonus": 1},
		{"name": "Tactical Plating", "type": "armor", "rarity": Rarity.RARE, "defense": 30},
		{"name": "Aegis Terminator", "type": "armor", "rarity": Rarity.LEGENDARY, "defense": 55},
		{"name": "Gravis Dreadplate", "type": "armor", "rarity": Rarity.EXOTIC, "defense": 70},
	],
}

var inventory: Array[Dictionary] = []
var equipped_weapons: Array[Dictionary] = [{}, {}, {}]
var equipped_armor: Dictionary = {}
var total_loot_collected: int = 0

const MAX_GEAR_ITEMS := 48
const LOADOUT_SLOT_COUNT := 3

func _ready() -> void:
	consolidate_material_stacks()

func roll_loot(table_name: String, luck_bonus: float = 0.0) -> Dictionary:
	var table: Array = LOOT_TABLES.get(table_name, LOOT_TABLES["exploration"])
	var roll := randf() + luck_bonus
	var rarity: Rarity
	if roll > 0.95:
		rarity = Rarity.EXOTIC
	elif roll > 0.85:
		rarity = Rarity.LEGENDARY
	elif roll > 0.65:
		rarity = Rarity.RARE
	elif roll > 0.35:
		rarity = Rarity.UNCOMMON
	else:
		rarity = Rarity.COMMON
	var candidates: Array[Dictionary] = []
	for item in table:
		if item["rarity"] == rarity:
			candidates.append(item)
	if candidates.is_empty():
		candidates.append(table[0])
	var result: Dictionary = candidates[randi() % candidates.size()].duplicate()
	result["rarity"] = rarity
	return _finalize_gear_item(result)

func roll_boss_loot(kind: String) -> Dictionary:
	match kind:
		"weapon":
			return _roll_boss_gear("weapon", "damage")
		"armor":
			return _roll_boss_gear("armor", "defense")
		"relic":
			return _finalize_boss_gear({
				"name": "Destiny Core",
				"type": "relic",
				"rarity": Rarity.EXOTIC,
				"value": 500,
			})
		"material":
			return _finalize_boss_gear({
				"name": "Void Shard",
				"type": "material",
				"rarity": Rarity.RARE,
				"value": 50,
				"quantity": randi_range(6, 14),
			})
	return roll_loot(kind, 0.35)

func _roll_boss_gear(table_name: String, stat_key: String) -> Dictionary:
	var table: Array = LOOT_TABLES.get(table_name, [])
	if table.is_empty():
		return roll_loot(table_name, 0.35)
	var base_item := _pick_best_loot_base(table, stat_key)
	var rarity := Rarity.LEGENDARY if randf() > 0.42 else Rarity.EXOTIC
	base_item["rarity"] = rarity
	return _finalize_boss_gear(base_item)

func _pick_best_loot_base(table: Array, stat_key: String) -> Dictionary:
	var best: Dictionary = table[0].duplicate()
	for entry in table:
		if int(entry.get(stat_key, 0)) > int(best.get(stat_key, 0)):
			best = entry.duplicate()
	return best

func _finalize_boss_gear(item: Dictionary) -> Dictionary:
	item["id"] = str(randi())
	item["collected_at"] = Time.get_ticks_msec()
	item["affixes"] = []
	item["boss_loot"] = true
	if item.get("type") in ["weapon", "armor"]:
		AffixLibrary.assign_base_id(item)
		item["affixes"] = AffixLibrary.roll_boss_affixes(item["type"], item.get("rarity", Rarity.LEGENDARY))
	elif item.get("type") in ["material", "relic"]:
		item["quantity"] = maxi(1, int(item.get("quantity", 1)))
	return item

func is_stackable_resource(item_type: String) -> bool:
	return _is_stackable_resource(item_type)

func _is_stackable_resource(item_type: String) -> bool:
	return item_type == "material" or item_type == "relic"

func collect_loot(item: Dictionary) -> bool:
	var item_type: String = str(item.get("type", ""))
	if item_type in ["weapon", "armor"] and _gear_item_count() >= MAX_GEAR_ITEMS:
		inventory_full.emit(item.duplicate(true))
		return false
	var stored := item.duplicate(true)
	if not stored.has("collected_at"):
		stored["collected_at"] = Time.get_ticks_msec()
	if not stored.has("id"):
		stored["id"] = str(randi())
	var stored_item: Dictionary
	if _is_stackable_resource(stored.get("type", "")):
		stored_item = _add_resource_stack(stored)
	else:
		inventory.insert(0, stored)
		stored_item = stored
	total_loot_collected += 1
	loot_collected.emit(stored_item)
	inventory_changed.emit()
	return true

func _gear_item_count() -> int:
	var count := 0
	for item in inventory:
		var item_type: String = str(item.get("type", ""))
		if item_type == "weapon" or item_type == "armor":
			count += 1
	return count

func get_gear_capacity() -> Dictionary:
	var count := _gear_item_count()
	return {"used": count, "max": MAX_GEAR_ITEMS, "full": count >= MAX_GEAR_ITEMS}

func get_equipped_weapon_for_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= equipped_weapons.size():
		return {}
	return equipped_weapons[slot]

func get_equipped_weapon() -> Dictionary:
	return get_equipped_weapon_for_slot(WeaponLibrary.active_slot)

func find_material_by_name(material_name: String) -> Dictionary:
	return find_resource_stack_by_name(material_name)

func find_resource_stack_by_name(resource_name: String) -> Dictionary:
	for item in inventory:
		if _is_stackable_resource(item.get("type", "")) and item.get("name", "") == resource_name:
			return item
	return {}

func consolidate_material_stacks() -> void:
	var seen: Dictionary = {}
	var merged: Array[Dictionary] = []
	for item in inventory:
		if not _is_stackable_resource(item.get("type", "")):
			merged.append(item)
			continue
		var resource_name: String = str(item.get("name", ""))
		if resource_name.is_empty():
			merged.append(item)
			continue
		var qty: int = maxi(1, int(item.get("quantity", 1)))
		if seen.has(resource_name):
			var idx: int = int(seen[resource_name])
			var stack: Dictionary = merged[idx]
			stack["quantity"] = int(stack.get("quantity", 1)) + qty
			stack["collected_at"] = maxi(
				int(stack.get("collected_at", 0)),
				int(item.get("collected_at", 0))
			)
			continue
		var stack_item := item.duplicate(true)
		stack_item["quantity"] = qty
		seen[resource_name] = merged.size()
		merged.append(stack_item)
	inventory.clear()
	for item in merged:
		inventory.append(item)

func _add_resource_stack(item: Dictionary) -> Dictionary:
	var resource_name: String = str(item.get("name", ""))
	if resource_name.is_empty():
		inventory.insert(0, item)
		return item
	var add_qty: int = maxi(1, int(item.get("quantity", 1)))
	var existing := find_resource_stack_by_name(resource_name)
	if not existing.is_empty():
		existing["quantity"] = int(existing.get("quantity", 1)) + add_qty
		existing["collected_at"] = maxi(
			int(existing.get("collected_at", 0)),
			int(item.get("collected_at", Time.get_ticks_msec()))
		)
		_promote_inventory_item(existing)
		return existing
	var stack := item.duplicate(true)
	stack["quantity"] = add_qty
	if not stack.has("id"):
		stack["id"] = str(randi())
	inventory.insert(0, stack)
	return stack

func _add_material_stack(item: Dictionary) -> Dictionary:
	return _add_resource_stack(item)

func find_item(item_id: String) -> Dictionary:
	for item in inventory:
		if str(item.get("id", "")) == item_id:
			return item
	return {}

func is_equipped(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var item_id: String = str(item.get("id", ""))
	for slot_weapon in equipped_weapons:
		if not slot_weapon.is_empty() and str(slot_weapon.get("id", "")) == item_id:
			return true
	if not equipped_armor.is_empty() and str(equipped_armor.get("id", "")) == item_id:
		return true
	return false

func can_equip(item: Dictionary) -> bool:
	var item_type: String = item.get("type", "")
	return item_type == "weapon" or item_type == "armor"

func equip_item(item: Dictionary) -> bool:
	if item.is_empty() or not can_equip(item):
		return false
	if not is_equipped(item) and not _contains_item(item):
		return false
	match item.get("type", ""):
		"weapon":
			var slot: int = WeaponLibrary.get_loot_loadout_slot(item)
			slot = clampi(slot, 0, equipped_weapons.size() - 1)
			equipped_weapons[slot] = item
			WeaponLibrary.apply_loot_weapon(item)
		"armor":
			equipped_armor = item
		_:
			return false
	gear_equipped.emit(item)
	inventory_changed.emit()
	return true

func unequip_weapon(slot: int = -1) -> void:
	if slot < 0:
		slot = WeaponLibrary.active_slot
	if slot < 0 or slot >= equipped_weapons.size():
		return
	if get_equipped_weapon_for_slot(slot).is_empty():
		return
	equipped_weapons[slot] = {}
	if slot < WeaponLibrary.DEFAULT_LOADOUT.size():
		WeaponLibrary.loadout[slot] = WeaponLibrary.DEFAULT_LOADOUT[slot]
	if WeaponLibrary.active_slot == slot:
		WeaponLibrary.equip_slot(slot)
	inventory_changed.emit()

func unequip_weapon_item(item: Dictionary) -> void:
	if item.is_empty() or item.get("type", "") != "weapon":
		return
	unequip_weapon(WeaponLibrary.get_loot_loadout_slot(item))

func unequip_armor() -> void:
	if equipped_armor.is_empty():
		return
	equipped_armor = {}
	inventory_changed.emit()

func can_scrap(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	return item.get("type", "") in ["weapon", "armor", "material", "relic"]

func get_scrap_yield(item: Dictionary) -> int:
	if not can_scrap(item):
		return 0
	var amount := 0
	match item.get("type", ""):
		"weapon", "armor":
			var rarity: int = item.get("rarity", Rarity.COMMON)
			amount = SCRAP_BASE_BY_RARITY.get(rarity, 4)
			amount += item.get("affixes", []).size() * 4
			if item.get("type") == "weapon":
				amount += int(item.get("damage", 0)) / 8
			else:
				amount += int(item.get("defense", 0)) / 4
		"material":
			if item.get("name", "") == SCRAP_MATERIAL_NAME:
				return 0
			amount = maxi(2, int(item.get("value", 5)) / 2)
			amount *= maxi(1, int(item.get("quantity", 1)))
		"relic":
			amount = maxi(8, int(item.get("value", 50)) / 5)
	return maxi(1, amount)

func get_scrap_total() -> int:
	return get_material_quantity(SCRAP_MATERIAL_NAME)

func get_material_quantity(material_name: String) -> int:
	var item := find_material_by_name(material_name)
	if item.is_empty():
		return 0
	return int(item.get("quantity", 1))

func scrap_item(item: Dictionary) -> bool:
	if not can_scrap(item) or not _contains_item(item):
		return false
	var gain := get_scrap_yield(item)
	if gain <= 0:
		return false
	if is_equipped(item):
		match item.get("type", ""):
			"weapon":
				unequip_weapon_item(item)
			"armor":
				unequip_armor()
	var scrapped := find_item(str(item.get("id", "")))
	if scrapped.is_empty():
		return false
	_remove_item_by_id(str(scrapped.get("id", "")))
	_grant_scrap(gain)
	item_scrapped.emit(scrapped, gain)
	inventory_changed.emit()
	return true

func _remove_item_by_id(item_id: String) -> void:
	for i in range(inventory.size()):
		if str(inventory[i].get("id", "")) == item_id:
			inventory.remove_at(i)
			return

func _promote_inventory_item(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if item_id.is_empty():
		return
	for i in range(inventory.size()):
		if str(inventory[i].get("id", "")) == item_id:
			if i == 0:
				return
			var promoted: Dictionary = inventory[i]
			inventory.remove_at(i)
			inventory.insert(0, promoted)
			return

func _grant_scrap(amount: int) -> void:
	if amount <= 0:
		return
	_add_material_stack({
		"name": SCRAP_MATERIAL_NAME,
		"type": "material",
		"rarity": Rarity.COMMON,
		"value": 5,
		"quantity": amount,
		"collected_at": Time.get_ticks_msec(),
		"affixes": [],
	})

func get_weapon_damage() -> int:
	return int(StatManager.get_stat("damage"))

func get_armor_defense() -> int:
	return int(StatManager.get_stat("armor"))

func get_rarity_color(rarity: Rarity) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

func get_rarity_name(rarity: Rarity) -> String:
	return RARITY_NAMES.get(rarity, "Unknown")

func get_equipped_affix_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for slot in equipped_weapons.size():
		var slot_weapon: Dictionary = equipped_weapons[slot]
		if slot_weapon.is_empty():
			continue
		var slot_label: String = WeaponLibrary.get_loadout_slot_label(slot)
		for affix in slot_weapon.get("affixes", []):
			if affix is Dictionary:
				lines.append("%s: %s" % [slot_label, AffixLibrary.format_affix(affix)])
	if not equipped_armor.is_empty():
		for affix in equipped_armor.get("affixes", []):
			if affix is Dictionary:
				lines.append("Armor: %s" % AffixLibrary.format_affix(affix))
	return lines

func get_item_summary(item: Dictionary) -> String:
	if item.is_empty():
		return "Select an item"
	var lines: PackedStringArray = []
	lines.append("%s" % item.get("name", "Unknown"))
	lines.append("%s %s" % [get_rarity_name(item.get("rarity", 0)), str(item.get("type", "")).capitalize()])
	match item.get("type", ""):
		"weapon":
			lines.append("Base damage: %d" % item.get("damage", 0))
		"armor":
			lines.append("Base defense: %d" % item.get("defense", 0))
		"material", "relic":
			lines.append("Value: %d" % item.get("value", 0))
	var affix_text := AffixLibrary.format_affix_lines(item.get("affixes", []))
	if not affix_text.is_empty():
		lines.append("")
		lines.append(affix_text)
	if is_equipped(item):
		lines.append("")
		lines.append("Currently equipped")
	return "\n".join(lines)

func get_equipped_gear_for_type(item_type: String) -> Dictionary:
	match item_type:
		"weapon":
			return get_equipped_weapon()
		"armor":
			return equipped_armor
	return {}

func get_equipped_gear_for_compare(item: Dictionary) -> Dictionary:
	match item.get("type", ""):
		"armor":
			return equipped_armor
		"weapon":
			var slot: int = WeaponLibrary.get_loot_loadout_slot(item)
			var slot_weapon: Dictionary = get_equipped_weapon_for_slot(slot)
			if not slot_weapon.is_empty():
				return slot_weapon
			return _baseline_weapon_item_for_slot(slot)
	return {}

func _baseline_weapon_item_for_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= WeaponLibrary.loadout.size():
		return {}
	var wid: String = WeaponLibrary.loadout[slot]
	var weapon: Dictionary = WeaponLibrary.get_weapon(wid)
	var slot_label: String = WeaponLibrary.get_loadout_slot_label(slot)
	return {
		"name": "%s (%s)" % [weapon.get("name", wid), slot_label],
		"type": "weapon",
		"damage": int(weapon.get("damage", 0)),
		"affixes": [],
		"_baseline": true,
	}

func get_baseline_weapon_for_slot(slot: int) -> Dictionary:
	return _baseline_weapon_item_for_slot(slot)

func get_item_compare_bbcode(item: Dictionary) -> String:
	if item.is_empty():
		return "Select an item"
	if item.get("_baseline", false):
		var lines: PackedStringArray = []
		lines.append("[color=#cccccc]%s[/color]" % item.get("name", "Default"))
		lines.append("[color=#aaaaaa]Default loadout weapon[/color]")
		lines.append("Base damage: %d" % item.get("damage", 0))
		return "\n".join(lines)
	var lines: PackedStringArray = []
	var rarity_color := get_rarity_color(item.get("rarity", 0)).to_html(false)
	lines.append("[color=%s]%s[/color]" % [rarity_color, item.get("name", "Unknown")])
	if item.get("boss_loot", false):
		lines.append("[color=#ffcc66]Boss reward[/color]")
	lines.append("%s %s" % [get_rarity_name(item.get("rarity", 0)), str(item.get("type", "")).capitalize()])
	var item_type: String = item.get("type", "")
	if item_type in ["weapon", "armor"]:
		var equipped: Dictionary = get_equipped_gear_for_compare(item)
		if is_equipped(item):
			lines.append("[color=#ffcc66]Currently equipped[/color]")
		elif item_type == "weapon" and equipped.get("_baseline", false):
			var slot_label: String = WeaponLibrary.get_loadout_slot_label(WeaponLibrary.get_loot_loadout_slot(item))
			lines.append("[color=#aaaaaa]Compared to %s slot loadout[/color]" % slot_label)
		lines.append(_format_base_stat_compare_bbcode(item, equipped, item_type))
		var affix_block := _format_affix_compare_bbcode(item, equipped)
		if not affix_block.is_empty():
			lines.append(affix_block)
		lines.append("[color=#88bbff]— Effective stats if equipped —[/color]")
		lines.append(_format_effective_compare_bbcode(item))
		var scrap_yield := get_scrap_yield(item)
		if scrap_yield > 0:
			lines.append("[color=#aaaaaa]Scrap yield: %d %s[/color]" % [scrap_yield, SCRAP_MATERIAL_NAME])
	elif item_type in ["material", "relic"]:
		var qty := int(item.get("quantity", 1))
		lines.append("Quantity: %d" % maxi(1, qty))
		lines.append("Value: %d" % item.get("value", 0))
		var scrap_yield := get_scrap_yield(item)
		if scrap_yield > 0:
			lines.append("[color=#aaaaaa]Scrap yield: %d %s[/color]" % [scrap_yield, SCRAP_MATERIAL_NAME])
	return "\n".join(lines)

func _format_base_stat_compare_bbcode(item: Dictionary, equipped: Dictionary, item_type: String) -> String:
	var stat_label := "Base damage" if item_type == "weapon" else "Base defense"
	var stat_key := "damage" if item_type == "weapon" else "defense"
	var stat_id := "damage" if item_type == "weapon" else "armor"
	var candidate_val: float = float(item.get(stat_key, 0))
	var line := "%s: %d" % [AffixLibrary.format_stat_label_bbcode(stat_id, stat_label), int(candidate_val)]
	if equipped.is_empty() or is_equipped(item):
		if equipped.is_empty() and candidate_val > 0.0:
			line += " [color=#aaaaaa](nothing equipped)[/color]"
		return line
	var equipped_val: float = float(equipped.get(stat_key, 0))
	line += _format_delta_bbcode(equipped_val, candidate_val, true, false)
	line += " vs %s (%d)" % [equipped.get("name", "equipped"), int(equipped_val)]
	return line

func _format_affix_compare_bbcode(item: Dictionary, equipped: Dictionary) -> String:
	var affixes: Array = item.get("affixes", [])
	var equipped_affixes: Array = equipped.get("affixes", []) if not equipped.is_empty() else []
	if affixes.is_empty() and equipped_affixes.is_empty():
		return "Affixes: none"
	var lines: PackedStringArray = ["Affixes:"]
	var eq_map: Dictionary = _affix_map(equipped)
	for affix in affixes:
		if not affix is Dictionary:
			continue
		var affix_id: String = affix.get("id", "")
		var delta := ""
		if equipped.is_empty() or is_equipped(item):
			if not equipped.is_empty():
				delta = _format_affix_delta_bbcode(affix, eq_map.get(affix_id, {}))
			else:
				delta = " [color=#66ff88](new)[/color]"
		elif eq_map.has(affix_id):
			delta = _format_affix_delta_bbcode(affix, eq_map[affix_id])
			eq_map.erase(affix_id)
		else:
			delta = " [color=#66ff88](new)[/color]"
		lines.append("  • %s%s" % [AffixLibrary.format_affix_bbcode(affix), delta])
	if not equipped.is_empty() and not is_equipped(item):
		for affix_id in eq_map:
			var lost: Dictionary = eq_map[affix_id]
			lines.append(
				"  • [color=#ff6666]− [/color]%s[color=#ff6666] (lost if replaced)[/color]" % AffixLibrary.format_affix_bbcode(lost)
			)
	return "\n".join(lines)

func _format_effective_compare_bbcode(item: Dictionary) -> String:
	var current := _compute_player_stats_for_compare(item, false)
	var projected := _compute_player_stats_for_compare(item, true)
	var lines: PackedStringArray = []
	for stat_def in _COMPARE_STATS:
		var stat_id: String = stat_def["id"]
		var cur_val: float = float(current.get(stat_id, 0.0))
		var new_val: float = float(projected.get(stat_id, 0.0))
		if abs(new_val - cur_val) < 0.001 and stat_id not in ["damage", "armor"]:
			continue
		var value_text := _format_stat_value(stat_id, new_val, stat_def)
		var line := "%s: %s" % [AffixLibrary.format_stat_label_bbcode(stat_id, stat_def["label"]), value_text]
		if is_equipped(item):
			line += " [color=#ffcc66](equipped)[/color]"
		else:
			line += _format_delta_bbcode(cur_val, new_val, stat_def["higher_better"], stat_def.get("percent", false))
			if not get_equipped_gear_for_compare(item).is_empty():
				line += " (now %s)" % _format_stat_value(stat_id, cur_val, stat_def)
		lines.append(line)
	return "\n".join(lines)

const _COMPARE_STATS := [
	{"id": "damage", "label": "Damage", "higher_better": true, "percent": false},
	{"id": "fire_rate", "label": "Fire rate", "higher_better": false, "percent": false, "seconds": true},
	{"id": "armor", "label": "Armor", "higher_better": true, "percent": false},
	{"id": "crit_chance", "label": "Crit chance", "higher_better": true, "percent": true},
	{"id": "move_speed", "label": "Move speed", "higher_better": true, "percent": true},
	{"id": "cooldown_reduction", "label": "Cooldown reduction", "higher_better": true, "percent": true},
]

func _project_stats_with_item(item: Dictionary) -> Dictionary:
	return _compute_player_stats_for_compare(item, true)

func _compute_player_stats_for_compare(item: Dictionary, use_preview: bool) -> Dictionary:
	var item_type: String = item.get("type", "")
	var gear_armor: Dictionary = equipped_armor
	var compare_slot: int = WeaponLibrary.active_slot
	var preview_weapon: Dictionary = {}
	var preview_slot: int = -1
	if item_type == "armor":
		if use_preview:
			gear_armor = item
	elif item_type == "weapon":
		compare_slot = WeaponLibrary.get_loot_loadout_slot(item)
		if use_preview:
			preview_weapon = item
			preview_slot = compare_slot
		else:
			var slot_gear: Dictionary = get_equipped_weapon_for_slot(compare_slot)
			if not slot_gear.is_empty():
				preview_weapon = slot_gear
				preview_slot = compare_slot
	return _compute_player_stats_at_slot(compare_slot, gear_armor, preview_weapon, preview_slot)

func _compute_player_stats_at_slot(slot: int, gear_armor: Dictionary, preview_weapon: Dictionary = {}, preview_slot: int = -1) -> Dictionary:
	var mods := _gear_modifiers_for_loadout(preview_weapon, gear_armor, preview_slot)
	var weapon_id: String = WeaponLibrary.equipped_id
	if slot >= 0 and slot < WeaponLibrary.loadout.size():
		weapon_id = WeaponLibrary.loadout[slot]
	if not preview_weapon.is_empty():
		var loot_wid: String = WeaponLibrary.weapon_id_from_loot(preview_weapon)
		if not loot_wid.is_empty():
			weapon_id = loot_wid
	var weapon: Dictionary = WeaponLibrary.get_weapon(weapon_id)
	return {
		"damage": _eval_gear_stat("damage", float(weapon.get("damage", 0)), mods),
		"fire_rate": _eval_gear_stat("fire_rate", float(weapon.get("fire_rate", 0.5)), mods),
		"armor": _eval_gear_stat("armor", 0.0, mods),
		"crit_chance": _eval_gear_stat("crit_chance", 0.05, mods),
		"move_speed": _eval_gear_stat("move_speed", 1.0, mods),
		"cooldown_reduction": _eval_gear_stat("cooldown_reduction", 0.0, mods),
	}

func _compute_player_stats(gear_weapon: Dictionary, gear_armor: Dictionary) -> Dictionary:
	var preview_slot := -1
	var slot := WeaponLibrary.active_slot
	if not gear_weapon.is_empty():
		slot = WeaponLibrary.get_loot_loadout_slot(gear_weapon)
		preview_slot = slot
	return _compute_player_stats_at_slot(slot, gear_armor, gear_weapon, preview_slot)

func _gear_modifiers_for_loadout(preview_weapon: Dictionary, gear_armor: Dictionary, preview_slot: int) -> Dictionary:
	var mods: Dictionary = {}
	for stat_id in StatManager.STAT_IDS:
		mods[stat_id] = {"add": 0.0, "mult": 1.0}
	if not gear_armor.is_empty():
		var defense: int = gear_armor.get("defense", 0)
		if defense > 0:
			mods["armor"]["add"] += float(defense)
		_apply_affixes_to_mods(gear_armor, mods)
	for i in equipped_weapons.size():
		var w: Dictionary = preview_weapon if i == preview_slot and not preview_weapon.is_empty() else equipped_weapons[i]
		if not w.is_empty():
			_apply_affixes_to_mods(w, mods)
	return mods

func _apply_affixes_to_mods(item: Dictionary, mods: Dictionary) -> void:
	for affix in item.get("affixes", []):
		if not affix is Dictionary:
			continue
		var def: Dictionary = AffixLibrary.AFFIXES.get(affix.get("id", ""), {})
		if def.is_empty():
			continue
		var stat_id: String = def.get("stat", "")
		if not mods.has(stat_id):
			continue
		if def.get("op") == AffixLibrary.AffixOp.ADD:
			mods[stat_id]["add"] += float(affix.get("value", 0.0))
		else:
			mods[stat_id]["mult"] *= float(affix.get("value", 1.0))

func _eval_gear_stat(stat_id: String, base: float, mods: Dictionary) -> float:
	var mod: Dictionary = mods.get(stat_id, {"add": 0.0, "mult": 1.0})
	var add_val: float = float(mod.get("add", 0.0))
	var mult_val: float = float(mod.get("mult", 1.0))
	var result: float = (base + add_val) * mult_val
	match stat_id:
		"cooldown_reduction":
			return clampf(result, 0.0, StatManager.COOLDOWN_REDUCTION_CAP)
		"crit_chance":
			return clampf(result, 0.0, 1.0)
		"move_speed":
			return maxf(0.1, result)
		"fire_rate":
			return maxf(0.02, result)
		"damage", "armor":
			return maxf(0.0, result)
	return maxf(0.0, result)

func _affix_map(item: Dictionary) -> Dictionary:
	var map: Dictionary = {}
	if item.is_empty():
		return map
	for affix in item.get("affixes", []):
		if affix is Dictionary:
			map[affix.get("id", "")] = affix
	return map

func _format_affix_delta_bbcode(candidate: Dictionary, equipped_affix: Dictionary) -> String:
	if equipped_affix.is_empty():
		return " [color=#66ff88](new)[/color]"
	var affix_id: String = candidate.get("id", "")
	var def: Dictionary = AffixLibrary.AFFIXES.get(affix_id, {})
	var stat_id: String = def.get("stat", "")
	var higher_better := true
	if stat_id == "fire_rate" and def.get("op") == AffixLibrary.AffixOp.MULTIPLY:
		higher_better = false
	var cur_val: float = float(equipped_affix.get("value", 0.0))
	var new_val: float = float(candidate.get("value", 0.0))
	return _format_delta_bbcode(cur_val, new_val, higher_better, false)

func _format_delta_bbcode(current: float, candidate: float, higher_is_better: bool, as_percent: bool) -> String:
	var diff := candidate - current
	if abs(diff) < 0.001:
		return " [color=#aaaaaa]= same[/color]"
	var better := diff > 0.0 if higher_is_better else diff < 0.0
	var color := "#66ff88" if better else "#ff6666"
	var arrow := "▲" if diff > 0.0 else "▼"
	var amount: float = abs(diff)
	var amount_text := ""
	if as_percent:
		amount_text = "%+.1f%%" % (amount * 100.0)
	elif amount >= 10.0 or amount == floor(amount):
		amount_text = "%+.0f" % amount
	else:
		amount_text = "%+.2f" % amount
	return " [color=%s]%s %s[/color]" % [color, arrow, amount_text]

func _format_stat_value(stat_id: String, value: float, stat_def: Dictionary) -> String:
	if stat_def.get("percent", false):
		if stat_id == "move_speed":
			return "%+.0f%%" % ((value - 1.0) * 100.0)
		return "%.0f%%" % (value * 100.0)
	if stat_def.get("seconds", false):
		return "%.2fs" % value
	if stat_id in ["damage", "armor"]:
		return "%d" % int(round(value))
	return "%.2f" % value

func _finalize_gear_item(item: Dictionary) -> Dictionary:
	item["id"] = str(randi())
	item["collected_at"] = Time.get_ticks_msec()
	item["affixes"] = []
	if item.get("type") in ["material", "relic"]:
		item["quantity"] = maxi(1, int(item.get("quantity", 1)))
	elif item.get("type") in ["weapon", "armor"]:
		AffixLibrary.assign_base_id(item)
		item["affixes"] = AffixLibrary.roll_affixes(item["type"], item.get("rarity", Rarity.COMMON))
	return item

func _contains_item(item: Dictionary) -> bool:
	return not find_item(str(item.get("id", ""))).is_empty()
