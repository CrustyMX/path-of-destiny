extends Control

signal active_slot_pressed(slot_key: String)
signal active_slot_double_pressed(slot_key: String)
signal slot_hovered(slot_key: String)
signal slot_unhovered()

const SLOT_PRIMARY := "primary"
const SLOT_SECONDARY := "secondary"
const SLOT_HEAVY := "heavy"
const SLOT_BODY := "body"
const SLOT_ICON := 44
const SLOT_COL_W := 76
const SLOT_WEAPON_W := 64
const SLOT_WEAPON_H := 92
const SLOT_BODY_W := 80
const SLOT_BODY_H := 100
const SLOT_SMALL := 56
const SLOT_CHARM := 44

var _slots: Dictionary = {}
var _icon_cache: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(340, 400)
	_build_layout()
	LootManager.inventory_changed.connect(refresh)
	LootManager.gear_equipped.connect(func(_i): refresh())
	WeaponLibrary.weapon_changed.connect(func(_w): refresh())
	refresh()

func refresh(_arg = null) -> void:
	_refresh_weapon_slot(SLOT_PRIMARY, 0)
	_refresh_weapon_slot(SLOT_SECONDARY, 1)
	_refresh_weapon_slot(SLOT_HEAVY, 2)
	_refresh_armor_slot()
	for key in ["helmet", "belt", "charm_1", "charm_2", "charm_3", "amulet", "ring_1", "ring_2", "gloves", "boots"]:
		_refresh_locked_slot(key)

func _build_layout() -> void:
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _panel_style())
	add_child(frame)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	frame.add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(columns)
	columns.add_child(_build_weapon_column())
	columns.add_child(_build_armor_column())
	columns.add_child(_build_accessory_column())

func _build_weapon_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(SLOT_COL_W, 380)
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_expand_spacer())
	col.add_child(_make_slot(SLOT_PRIMARY, "PRIMARY", Vector2(SLOT_WEAPON_W, SLOT_WEAPON_H), true))
	col.add_child(_make_slot(SLOT_SECONDARY, "SECONDARY", Vector2(SLOT_WEAPON_W, SLOT_WEAPON_H), true))
	col.add_child(_make_slot(SLOT_HEAVY, "HEAVY", Vector2(SLOT_WEAPON_W, SLOT_WEAPON_H), true))
	col.add_child(_expand_spacer())
	return col

func _build_armor_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(SLOT_BODY_W + 8, 380)
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_expand_spacer())
	col.add_child(_make_slot("helmet", "HELMET", Vector2(SLOT_SMALL, SLOT_SMALL), false))
	col.add_child(_make_slot(SLOT_BODY, "BODY ARMOUR", Vector2(SLOT_BODY_W, SLOT_BODY_H), true))
	col.add_child(_make_slot("belt", "BELT", Vector2(SLOT_BODY_W, 40), false))
	var charms := HBoxContainer.new()
	charms.add_theme_constant_override("separation", 6)
	charms.alignment = BoxContainer.ALIGNMENT_CENTER
	charms.add_child(_make_slot("charm_1", "CHARM", Vector2(SLOT_CHARM, SLOT_CHARM), false))
	charms.add_child(_make_slot("charm_2", "CHARM", Vector2(SLOT_CHARM, SLOT_CHARM), false))
	charms.add_child(_make_slot("charm_3", "CHARM", Vector2(SLOT_CHARM, SLOT_CHARM), false))
	col.add_child(charms)
	col.add_child(_expand_spacer())
	return col

func _build_accessory_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(SLOT_COL_W, 380)
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_expand_spacer())
	col.add_child(_make_slot("amulet", "AMULET", Vector2(SLOT_SMALL, SLOT_SMALL), false))
	col.add_child(_make_slot("ring_1", "RING", Vector2(SLOT_SMALL, SLOT_SMALL), false))
	col.add_child(_make_slot("ring_2", "RING", Vector2(SLOT_SMALL, SLOT_SMALL), false))
	col.add_child(_make_slot("gloves", "GLOVES", Vector2(SLOT_SMALL, SLOT_SMALL), false))
	col.add_child(_make_slot("boots", "BOOTS", Vector2(SLOT_SMALL, SLOT_SMALL), false))
	col.add_child(_expand_spacer())
	return col

func _expand_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 4)
	return spacer

func _make_slot(key: String, label_text: String, size: Vector2, active: bool) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 3)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _slot_style(active, false))
	panel.gui_input.connect(func(event: InputEvent): _on_slot_gui_input(key, active, event))
	panel.mouse_entered.connect(func(): slot_hovered.emit(key))
	panel.mouse_exited.connect(func(): slot_unhovered.emit())
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(inner)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(mini(SLOT_ICON, int(size.x) - 8), mini(SLOT_ICON, int(size.y) - 8))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inner.add_child(icon)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(int(size.x) - 6, 0)
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.66))
	name_label.visible = false
	inner.add_child(name_label)
	var slot_label := Label.new()
	slot_label.text = label_text
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_label.add_theme_font_size_override("font_size", 9)
	slot_label.add_theme_color_override("font_color", Color(0.58, 0.52, 0.46))
	wrap.add_child(panel)
	wrap.add_child(slot_label)
	_slots[key] = {
		"panel": panel,
		"icon": icon,
		"name_label": name_label,
		"active": active,
	}
	return wrap

func _on_slot_gui_input(key: String, active: bool, event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			active_slot_double_pressed.emit(key)
		else:
			active_slot_pressed.emit(key)
		get_viewport().set_input_as_handled()

func _refresh_weapon_slot(key: String, slot_index: int) -> void:
	var slot_ui: Dictionary = _slots.get(key, {})
	if slot_ui.is_empty():
		return
	var loot_weapon: Dictionary = LootManager.get_equipped_weapon_for_slot(slot_index)
	var icon: TextureRect = slot_ui["icon"]
	var name_label: Label = slot_ui["name_label"]
	var panel: PanelContainer = slot_ui["panel"]
	if not loot_weapon.is_empty():
		icon.texture = _item_icon(loot_weapon)
		icon.modulate = Color.WHITE
		name_label.text = loot_weapon.get("name", "")
		name_label.visible = true
		panel.add_theme_stylebox_override("panel", _slot_style(true, false, LootManager.get_rarity_color(loot_weapon.get("rarity", 0))))
	else:
		var default_id: String = WeaponLibrary.loadout[slot_index] if slot_index < WeaponLibrary.loadout.size() else ""
		var default_weapon: Dictionary = WeaponLibrary.get_weapon(default_id)
		icon.texture = _weapon_slot_icon(slot_index)
		icon.modulate = Color(0.72, 0.72, 0.76)
		name_label.text = default_weapon.get("name", "Default")
		name_label.visible = true
		panel.add_theme_stylebox_override("panel", _slot_style(true, false))

func _refresh_armor_slot() -> void:
	var slot_ui: Dictionary = _slots.get(SLOT_BODY, {})
	if slot_ui.is_empty():
		return
	var icon: TextureRect = slot_ui["icon"]
	var name_label: Label = slot_ui["name_label"]
	var panel: PanelContainer = slot_ui["panel"]
	var armor: Dictionary = LootManager.equipped_armor
	if armor.is_empty():
		icon.texture = _placeholder_icon("armor", Color(0.35, 0.32, 0.3))
		icon.modulate = Color(0.55, 0.55, 0.58)
		name_label.text = "Empty"
		name_label.visible = true
		panel.add_theme_stylebox_override("panel", _slot_style(true, false))
	else:
		icon.texture = _item_icon(armor)
		icon.modulate = Color.WHITE
		name_label.text = armor.get("name", "")
		name_label.visible = true
		panel.add_theme_stylebox_override("panel", _slot_style(true, false, LootManager.get_rarity_color(armor.get("rarity", 0))))

func _refresh_locked_slot(key: String) -> void:
	var slot_ui: Dictionary = _slots.get(key, {})
	if slot_ui.is_empty():
		return
	var icon: TextureRect = slot_ui["icon"]
	var name_label: Label = slot_ui["name_label"]
	icon.texture = _placeholder_icon("lock", Color(0.3, 0.26, 0.22))
	icon.modulate = Color(0.65, 0.62, 0.58)
	name_label.text = "Soon"
	name_label.visible = true

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.04, 0.94)
	style.border_color = Color(0.28, 0.2, 0.14, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	return style

func _slot_style(active: bool, _info_only: bool, rarity_color: Color = Color(0.32, 0.26, 0.2)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.04, 0.03, 0.025, 0.98)
		style.border_color = rarity_color.lightened(0.15) if rarity_color != Color(0.32, 0.26, 0.2) else Color(0.38, 0.3, 0.22, 0.95)
	else:
		style.bg_color = Color(0.035, 0.03, 0.025, 0.85)
		style.border_color = Color(0.18, 0.14, 0.1, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style

func _weapon_slot_icon(slot: int) -> Texture2D:
	return _cached_icon("weapon_slot_%d" % slot, _draw_rifle_icon, WeaponLibrary.get_loadout_slot_color(slot))

func _item_icon(item: Dictionary) -> Texture2D:
	var item_type := str(item.get("type", ""))
	match item_type:
		"weapon":
			var slot := WeaponLibrary.get_loot_loadout_slot(item)
			return _cached_icon("rifle_%d_%s" % [slot, item.get("name", "")], _draw_rifle_icon, WeaponLibrary.get_loadout_slot_color(slot))
		"armor":
			var rarity_color := LootManager.get_rarity_color(item.get("rarity", 0))
			return _cached_icon("armor_%s" % rarity_color.to_html(false), _draw_armor_icon, rarity_color)
	return _placeholder_icon("gear", Color(0.6, 0.62, 0.66))

func _placeholder_icon(kind: String, color: Color) -> Texture2D:
	return _cached_icon("ph_%s_%s" % [kind, color.to_html(false)], func(img: Image, c: Color):
		match kind:
			"armor":
				_draw_armor_icon(img, c)
			_:
				_draw_lock_icon(img, c)
	, color)

func _cached_icon(cache_key: String, draw_fn: Callable, color: Color) -> Texture2D:
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]
	var img := Image.create(SLOT_ICON, SLOT_ICON, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	draw_fn.call(img, color)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[cache_key] = tex
	return tex

func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		if py < 0 or py >= SLOT_ICON:
			continue
		for px in range(x, x + w):
			if px < 0 or px >= SLOT_ICON:
				continue
			img.set_pixel(px, py, color)

func _draw_rifle_icon(img: Image, color: Color) -> void:
	_fill_rect(img, 4, 18, 22, 8, color)
	_fill_rect(img, 24, 20, 12, 4, color.lightened(0.08))
	_fill_rect(img, 4, 26, 8, 10, color.darkened(0.18))
	_fill_rect(img, 14, 26, 6, 8, color.darkened(0.12))

func _draw_armor_icon(img: Image, color: Color) -> void:
	_fill_rect(img, 12, 8, 20, 16, color)
	_fill_rect(img, 8, 12, 6, 10, color.lightened(0.06))
	_fill_rect(img, 28, 12, 6, 10, color.lightened(0.06))
	_fill_rect(img, 14, 24, 16, 8, color.darkened(0.15))
	_fill_rect(img, 18, 4, 8, 6, color.lightened(0.1))

func _draw_lock_icon(img: Image, color: Color) -> void:
	_fill_rect(img, 16, 22, 12, 10, color.darkened(0.1))
	_fill_rect(img, 18, 12, 8, 12, Color(0, 0, 0, 0))
	_fill_rect(img, 14, 12, 16, 4, color)
	_fill_rect(img, 14, 10, 4, 6, color)
	_fill_rect(img, 26, 10, 4, 6, color)
