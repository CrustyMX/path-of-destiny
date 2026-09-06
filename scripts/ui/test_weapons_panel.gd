extends Control

signal closed

var _item_list: ItemList
var _detail_label: Label
var _assign_button: Button
var _selected_weapon_id: String = ""

func _ready() -> void:
	name = "TestWeaponsPanel"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_build_ui()

func open() -> void:
	visible = true
	_refresh_list()
	if _item_list.get_item_count() > 0 and _item_list.get_selected_items().is_empty():
		_item_list.select(0)
		_on_item_selected(0)

func close() -> void:
	if not visible:
		return
	visible = false
	_selected_weapon_id = ""
	closed.emit()

func is_open() -> bool:
	return visible

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 520)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.07, 0.11, 0.96)
	panel_style.border_color = Color(0.85, 0.55, 0.2, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var title := Label.new()
	title.text = "TEST WEAPONS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	root.add_child(title)
	var hint := Label.new()
	hint.text = "` or Esc to close  |  Assign puts weapon in its loadout slot and equips it with full ammo"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	root.add_child(hint)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(320, 360)
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	body.add_child(_item_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_detail_label = Label.new()
	_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_label.custom_minimum_size = Vector2(340, 360)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	right.add_child(_detail_label)
	_assign_button = Button.new()
	_assign_button.text = "Assign & Equip"
	_assign_button.custom_minimum_size = Vector2(180, 36)
	_assign_button.pressed.connect(_on_assign_pressed)
	right.add_child(_assign_button)

func _refresh_list() -> void:
	var selected_id := _selected_weapon_id
	_item_list.clear()
	var index := 0
	var select_index := -1
	for weapon_id in WeaponLibrary.get_all_weapon_ids():
		var w: Dictionary = WeaponLibrary.get_weapon(weapon_id)
		var slot := int(w.get("loadout_slot", 0))
		var slot_label := WeaponLibrary.get_loadout_slot_label(slot)
		var equipped := weapon_id == WeaponLibrary.equipped_id
		var in_loadout := weapon_id in WeaponLibrary.loadout
		var prefix := "> " if equipped else "  "
		var loadout_mark := " [loadout]" if in_loadout else ""
		_item_list.add_item("%s%s (%s)%s" % [prefix, w.get("name", weapon_id), slot_label, loadout_mark])
		_item_list.set_item_metadata(index, weapon_id)
		var color := WeaponLibrary.get_loadout_slot_color(slot)
		if equipped:
			color = color.lerp(Color(1.0, 0.85, 0.35), 0.35)
		_item_list.set_item_custom_fg_color(index, color)
		if weapon_id == selected_id:
			select_index = index
		index += 1
	if select_index >= 0:
		_item_list.select(select_index)
	elif _item_list.get_item_count() > 0:
		_item_list.select(0)
		_on_item_selected(0)

func _on_item_selected(index: int) -> void:
	_selected_weapon_id = str(_item_list.get_item_metadata(index))
	_update_detail()

func _update_detail() -> void:
	if _selected_weapon_id.is_empty() or not WeaponLibrary.WEAPONS.has(_selected_weapon_id):
		_detail_label.text = "Select a weapon."
		_assign_button.disabled = true
		return
	var w: Dictionary = WeaponLibrary.get_weapon(_selected_weapon_id)
	var slot := int(w.get("loadout_slot", 0))
	var lines: PackedStringArray = []
	lines.append(w.get("name", _selected_weapon_id))
	lines.append("Slot: %s (weapon %d)" % [WeaponLibrary.get_loadout_slot_label(slot), slot + 1])
	lines.append("Kind: %s" % _kind_label(int(w.get("kind", WeaponLibrary.WeaponKind.RANGED))))
	lines.append("Damage: %d / %d heavy" % [int(w.get("damage", 0)), int(w.get("heavy_damage", 0))])
	if WeaponLibrary.uses_ammo(_selected_weapon_id):
		lines.append("Magazine: %d" % int(w.get("magazine_size", 0)))
	lines.append("Range: %.0f" % float(w.get("range", 0.0)))
	if w.get("traveling_projectile", false):
		lines.append("Projectile: traveling (launcher)")
	else:
		lines.append("Projectile: hitscan")
	if _selected_weapon_id == WeaponLibrary.equipped_id:
		lines.append("")
		lines.append("Currently equipped")
	_detail_label.text = "\n".join(lines)
	_assign_button.disabled = false
	_assign_button.text = "Assign & Equip" if _selected_weapon_id != WeaponLibrary.equipped_id else "Reassign & Refill"

func _kind_label(kind: int) -> String:
	match kind:
		WeaponLibrary.WeaponKind.MELEE:
			return "Melee"
		WeaponLibrary.WeaponKind.HEAVY_RANGED:
			return "Heavy Ranged"
	return "Ranged"

func _on_assign_pressed() -> void:
	if _selected_weapon_id.is_empty():
		return
	if not WeaponLibrary.assign_test_weapon(_selected_weapon_id):
		return
	var player := GameManager.player
	if player:
		var wc := player.get_node_or_null("WeaponController")
		if wc and wc.has_method("refill_weapon_ammo"):
			wc.refill_weapon_ammo(_selected_weapon_id)
	var w: Dictionary = WeaponLibrary.get_weapon(_selected_weapon_id)
	for node in get_tree().get_nodes_in_group("hud"):
		if node.has_method("show_notice"):
			node.show_notice("Equipped %s" % w.get("name", _selected_weapon_id), 2.0)
			break
	_refresh_list()
	_update_detail()
