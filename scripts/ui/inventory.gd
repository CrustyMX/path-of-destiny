extends Control

signal closed

const ICON_SIZE := 20

const TAB_GEAR := 0
const TAB_RESOURCES := 1

const SORT_NEWEST := 0
const SORT_OLDEST := 1
const SORT_RARITY := 2
const SORT_NAME := 3
const SORT_SLOT := 4

const FILTER_ALL := -1
const FILTER_ARMOR := -2

var _stash_scroll: ScrollContainer
var _stash_list: VBoxContainer
var _stash_rows: Dictionary = {}
var _equip_button: Button
var _unequip_button: Button
var _scrap_button: Button
var _scrap_total_label: Label
var _selected_label: Label
var _loadout_doll: Control
var _gear_tab_btn: Button
var _resources_tab_btn: Button
var _tab_legend_label: Label
var _slot_filter_wrap: VBoxContainer
var _slot_filter_buttons: Array[Button] = []
var _sort_row: HBoxContainer
var _sort_button: OptionButton
var _selected_item: Dictionary = {}
var _compare_tooltip: PanelContainer
var _compare_tooltip_label: RichTextLabel
var _affix_tooltip: PanelContainer
var _affix_tooltip_label: Label
var _hover_meta: String = ""
var _inventory_tab: int = TAB_GEAR
var _slot_filter: int = FILTER_ALL
var _sort_mode: int = SORT_NEWEST
var _icon_cache: Dictionary = {}
var _hover_stash_id: String = ""
var _hover_loadout_slot: String = ""

func _ready() -> void:
	name = "InventoryPanel"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_build_ui()
	set_process(true)
	LootManager.inventory_changed.connect(_refresh)
	LootManager.gear_equipped.connect(func(_item): _refresh())
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_inventory_toggle_key(event):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func _is_inventory_toggle_key(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if event.is_action("inventory"):
		return true
	var key_code: int = int(event.keycode)
	var physical_code: int = int(event.physical_keycode)
	return key_code == KEY_I or physical_code == KEY_I or int(event.unicode) == 105 or key_code == KEY_TAB or physical_code == KEY_TAB

func open() -> void:
	visible = true
	_refresh()
	if _selected_item.is_empty() and not _stash_rows.is_empty():
		_select_stash_item(str(_stash_rows.keys()[0]))

func close() -> void:
	if not visible:
		return
	visible = false
	_selected_item = {}
	_hide_compare_tooltip()
	_hide_affix_tooltip()
	closed.emit()

func is_open() -> bool:
	return visible

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.025, 0.82)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 600)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.045, 0.04, 0.97)
	panel_style.border_color = Color(0.32, 0.22, 0.14, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var title := Label.new()
	title.text = "CHARACTER"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.92, 0.72, 0.38))
	root.add_child(title)
	var hint := Label.new()
	hint.text = "Tab / I to close  |  Hover for stats  |  Double-click to equip/unequip"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.58, 0.52, 0.46))
	root.add_child(hint)
	_scrap_total_label = Label.new()
	_scrap_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scrap_total_label.add_theme_font_size_override("font_size", 12)
	_scrap_total_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.65))
	root.add_child(_scrap_total_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var list_column := VBoxContainer.new()
	list_column.custom_minimum_size = Vector2(340, 460)
	list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_column.add_theme_constant_override("separation", 6)
	body.add_child(list_column)
	var stash_title := Label.new()
	stash_title.text = "STASH"
	stash_title.add_theme_font_size_override("font_size", 14)
	stash_title.add_theme_color_override("font_color", Color(0.82, 0.72, 0.55))
	list_column.add_child(stash_title)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	list_column.add_child(tab_row)
	_gear_tab_btn = Button.new()
	_gear_tab_btn.text = "Gear"
	_gear_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_tab_btn.custom_minimum_size = Vector2(0, 32)
	_gear_tab_btn.pressed.connect(func(): _set_inventory_tab(TAB_GEAR))
	tab_row.add_child(_gear_tab_btn)
	_resources_tab_btn = Button.new()
	_resources_tab_btn.text = "Resources"
	_resources_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resources_tab_btn.custom_minimum_size = Vector2(0, 32)
	_resources_tab_btn.pressed.connect(func(): _set_inventory_tab(TAB_RESOURCES))
	tab_row.add_child(_resources_tab_btn)
	_tab_legend_label = Label.new()
	_tab_legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_legend_label.add_theme_font_size_override("font_size", 11)
	_tab_legend_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	list_column.add_child(_tab_legend_label)
	_slot_filter_wrap = VBoxContainer.new()
	_slot_filter_wrap.add_theme_constant_override("separation", 4)
	list_column.add_child(_slot_filter_wrap)
	_build_slot_filters()
	_sort_row = HBoxContainer.new()
	_sort_row.add_theme_constant_override("separation", 6)
	list_column.add_child(_sort_row)
	_build_sort_options()
	_stash_scroll = ScrollContainer.new()
	_stash_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stash_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(_stash_scroll)
	_stash_list = VBoxContainer.new()
	_stash_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stash_list.add_theme_constant_override("separation", 2)
	_stash_scroll.add_child(_stash_list)
	_stash_scroll.mouse_exited.connect(_on_stash_mouse_exited)
	var loadout_column := VBoxContainer.new()
	loadout_column.custom_minimum_size = Vector2(380, 460)
	loadout_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_column.add_theme_constant_override("separation", 4)
	body.add_child(loadout_column)
	var loadout_title := Label.new()
	loadout_title.text = "LOADOUT"
	loadout_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_title.add_theme_font_size_override("font_size", 14)
	loadout_title.add_theme_color_override("font_color", Color(0.82, 0.72, 0.55))
	loadout_column.add_child(loadout_title)
	_loadout_doll = load("res://scripts/ui/loadout_doll.gd").new()
	_loadout_doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_column.add_child(_loadout_doll)
	_loadout_doll.active_slot_pressed.connect(_on_loadout_slot_pressed)
	_loadout_doll.active_slot_double_pressed.connect(_on_loadout_slot_double_pressed)
	_loadout_doll.slot_hovered.connect(_on_loadout_slot_hovered)
	_loadout_doll.slot_unhovered.connect(_on_loadout_slot_unhovered)
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root.add_child(footer)
	_selected_label = Label.new()
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_label.add_theme_font_size_override("font_size", 13)
	_selected_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72))
	_selected_label.text = "Select an item from stash"
	footer.add_child(_selected_label)
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 10)
	footer.add_child(button_row)
	_equip_button = Button.new()
	_equip_button.text = "Equip"
	_equip_button.custom_minimum_size = Vector2(120, 36)
	_equip_button.pressed.connect(_on_equip_pressed)
	button_row.add_child(_equip_button)
	_unequip_button = Button.new()
	_unequip_button.text = "Unequip"
	_unequip_button.custom_minimum_size = Vector2(120, 36)
	_unequip_button.pressed.connect(_on_unequip_pressed)
	button_row.add_child(_unequip_button)
	_scrap_button = Button.new()
	_scrap_button.text = "Scrap"
	_scrap_button.custom_minimum_size = Vector2(120, 36)
	_scrap_button.pressed.connect(_on_scrap_pressed)
	button_row.add_child(_scrap_button)
	_build_compare_tooltip()
	_build_affix_tooltip()
	_update_tab_buttons()

func _build_slot_filters() -> void:
	_slot_filter_buttons.clear()
	for child in _slot_filter_wrap.get_children():
		child.queue_free()
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 4)
	_slot_filter_wrap.add_child(gear_row)
	_add_filter_button(gear_row, "All", FILTER_ALL)
	_add_filter_button(gear_row, "Armor", FILTER_ARMOR)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 4)
	_slot_filter_wrap.add_child(weapon_row)
	_add_filter_button(weapon_row, "Primary", 0)
	_add_filter_button(weapon_row, "Secondary", 1)
	_add_filter_button(weapon_row, "Heavy", 2)

func _add_filter_button(row: HBoxContainer, label: String, slot_value: int) -> void:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func(): _set_slot_filter(slot_value))
	row.add_child(btn)
	_slot_filter_buttons.append(btn)

func _build_sort_options() -> void:
	for child in _sort_row.get_children():
		child.queue_free()
	var sort_label := Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 11)
	sort_label.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
	_sort_row.add_child(sort_label)
	_sort_button = OptionButton.new()
	_sort_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort_button.add_item("Newest", SORT_NEWEST)
	_sort_button.add_item("Oldest", SORT_OLDEST)
	_sort_button.add_item("Rarity (high → low)", SORT_RARITY)
	_sort_button.add_item("Name (A → Z)", SORT_NAME)
	_sort_button.add_item("Weapon slot", SORT_SLOT)
	_sort_button.selected = _sort_mode
	_sort_button.item_selected.connect(_on_sort_selected)
	_sort_row.add_child(_sort_button)

func _on_sort_selected(index: int) -> void:
	var new_mode: int = _sort_button.get_item_id(index)
	if _sort_mode == new_mode:
		return
	_sort_mode = new_mode
	_populate_stash_list()
	_update_action_bar()

func _set_slot_filter(slot: int) -> void:
	if _slot_filter == slot:
		return
	_slot_filter = slot
	_selected_item = {}
	_update_slot_filter_buttons()
	_populate_stash_list()
	_update_action_bar()

func _update_slot_filter_buttons() -> void:
	for btn in _slot_filter_buttons:
		var slot_value := FILTER_ALL
		match btn.text:
			"All":
				slot_value = FILTER_ALL
			"Armor":
				slot_value = FILTER_ARMOR
			"Primary":
				slot_value = 0
			"Secondary":
				slot_value = 1
			"Heavy":
				slot_value = 2
		btn.disabled = _inventory_tab != TAB_GEAR or _slot_filter == slot_value
	if _slot_filter_wrap:
		_slot_filter_wrap.visible = _inventory_tab == TAB_GEAR

func _set_inventory_tab(tab: int) -> void:
	if _inventory_tab == tab:
		return
	_inventory_tab = tab
	_selected_item = {}
	_update_tab_buttons()
	_update_slot_filter_buttons()
	_populate_stash_list()
	_update_action_bar()

func _update_tab_buttons() -> void:
	var gear_active := _inventory_tab == TAB_GEAR
	_gear_tab_btn.disabled = gear_active
	_resources_tab_btn.disabled = not gear_active
	_slot_filter_wrap.visible = gear_active
	if gear_active:
		_tab_legend_label.text = "Rifle icons: white primary, green secondary, purple heavy. Armor uses rarity color."
	else:
		_tab_legend_label.text = "Gear icons mark stackable materials and relics. Newest pickups appear first."
	_update_slot_filter_buttons()

func _item_matches_slot_filter(item: Dictionary) -> bool:
	if _slot_filter == FILTER_ALL:
		return true
	if _slot_filter == FILTER_ARMOR:
		return str(item.get("type", "")) == "armor"
	if str(item.get("type", "")) != "weapon":
		return false
	return WeaponLibrary.get_loot_loadout_slot(item) == _slot_filter

func _item_matches_tab(item: Dictionary) -> bool:
	var item_type := str(item.get("type", ""))
	if _inventory_tab == TAB_GEAR:
		return item_type == "weapon" or item_type == "armor"
	return LootManager.is_stackable_resource(item_type)

func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		if py < 0 or py >= ICON_SIZE:
			continue
		for px in range(x, x + w):
			if px < 0 or px >= ICON_SIZE:
				continue
			img.set_pixel(px, py, color)

func _draw_rifle_icon(img: Image, color: Color) -> void:
	_fill_rect(img, 2, 8, 11, 4, color)
	_fill_rect(img, 12, 9, 6, 2, color.lightened(0.08))
	_fill_rect(img, 2, 12, 4, 5, color.darkened(0.18))
	_fill_rect(img, 7, 12, 3, 4, color.darkened(0.12))

func _draw_armor_icon(img: Image, color: Color) -> void:
	_fill_rect(img, 5, 4, 10, 8, color)
	_fill_rect(img, 3, 6, 3, 5, color.lightened(0.06))
	_fill_rect(img, 14, 6, 3, 5, color.lightened(0.06))
	_fill_rect(img, 6, 12, 8, 4, color.darkened(0.15))
	_fill_rect(img, 8, 2, 4, 3, color.lightened(0.1))

func _draw_gear_icon(img: Image, color: Color) -> void:
	_fill_rect(img, 7, 7, 6, 6, color)
	for i in 8:
		var angle := (TAU / 8.0) * float(i)
		var cx := int(9.5 + cos(angle) * 7.5)
		var cy := int(9.5 + sin(angle) * 7.5)
		_fill_rect(img, cx - 1, cy - 2, 3, 4, color.lightened(0.05))
	_fill_rect(img, 8, 8, 4, 4, Color(0.04, 0.05, 0.08, 0.85))

func _make_icon(draw_fn: Callable, color: Color) -> Texture2D:
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	draw_fn.call(img, color)
	return ImageTexture.create_from_image(img)

func _cached_icon(cache_key: String, draw_fn: Callable, color: Color) -> Texture2D:
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key]
	var tex := _make_icon(draw_fn, color)
	_icon_cache[cache_key] = tex
	return tex

func _item_icon(item: Dictionary) -> Texture2D:
	var item_type := str(item.get("type", ""))
	match item_type:
		"weapon":
			var slot := WeaponLibrary.get_loot_loadout_slot(item)
			var color := WeaponLibrary.get_loadout_slot_color(slot)
			return _cached_icon("rifle_%d" % slot, _draw_rifle_icon, color)
		"armor":
			var rarity_color := LootManager.get_rarity_color(item.get("rarity", 0))
			return _cached_icon("armor_%s" % rarity_color.to_html(false), _draw_armor_icon, rarity_color)
		"material", "relic":
			var resource_color := LootManager.get_rarity_color(item.get("rarity", 0)).lerp(Color(0.78, 0.82, 0.88), 0.25)
			return _cached_icon("gear_%s" % resource_color.to_html(false), _draw_gear_icon, resource_color)
	return _cached_icon("gear_default", _draw_gear_icon, Color(0.75, 0.78, 0.82))

func _item_list_text_color(item: Dictionary) -> Color:
	match str(item.get("type", "")):
		"weapon":
			return Color(0.92, 0.94, 0.98)
		"armor", "material", "relic":
			return LootManager.get_rarity_color(item.get("rarity", 0))
	return Color(0.88, 0.9, 0.94)

func _item_list_label(item: Dictionary) -> String:
	var prefix := "[E] " if LootManager.is_equipped(item) else ""
	var label := "%s%s" % [prefix, item.get("name", "Item")]
	var item_type := str(item.get("type", ""))
	if item_type == "weapon":
		var slot_label := WeaponLibrary.get_loadout_slot_label(WeaponLibrary.get_loot_loadout_slot(item))
		label += " (%s)" % slot_label
	else:
		label += " [%s]" % LootManager.get_rarity_name(item.get("rarity", 0))
	var qty := int(item.get("quantity", 1))
	if LootManager.is_stackable_resource(item_type) or qty > 1:
		label += " x%d" % maxi(1, qty)
	return label

func _build_compare_tooltip() -> void:
	_compare_tooltip = PanelContainer.new()
	_compare_tooltip.name = "CompareTooltip"
	_compare_tooltip.visible = false
	_compare_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compare_tooltip.z_index = 200
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.035, 0.97)
	style.border_color = Color(0.42, 0.32, 0.2, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	_compare_tooltip.add_theme_stylebox_override("panel", style)
	add_child(_compare_tooltip)
	_compare_tooltip_label = RichTextLabel.new()
	_compare_tooltip_label.bbcode_enabled = true
	_compare_tooltip_label.fit_content = true
	_compare_tooltip_label.scroll_active = false
	_compare_tooltip_label.custom_minimum_size = Vector2(300, 0)
	_compare_tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	_compare_tooltip_label.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	_compare_tooltip_label.meta_underlined = false
	_compare_tooltip_label.meta_hover_started.connect(_on_compare_meta_hover_started)
	_compare_tooltip_label.meta_hover_ended.connect(_on_compare_meta_hover_ended)
	_compare_tooltip.add_child(_compare_tooltip_label)

func _build_affix_tooltip() -> void:
	_affix_tooltip = PanelContainer.new()
	_affix_tooltip.name = "AffixTooltip"
	_affix_tooltip.visible = false
	_affix_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_affix_tooltip.z_index = 200
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	style.border_color = Color(0.45, 0.65, 0.95, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_affix_tooltip.add_theme_stylebox_override("panel", style)
	add_child(_affix_tooltip)
	_affix_tooltip_label = Label.new()
	_affix_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_affix_tooltip_label.custom_minimum_size = Vector2(240, 0)
	_affix_tooltip_label.add_theme_font_size_override("font_size", 12)
	_affix_tooltip_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_affix_tooltip.add_child(_affix_tooltip_label)

func _process(_delta: float) -> void:
	if _compare_tooltip and _compare_tooltip.visible:
		_update_compare_tooltip_position()
	if _affix_tooltip and _affix_tooltip.visible:
		_update_affix_tooltip_position()

func _show_compare_tooltip(item: Dictionary) -> void:
	if item.is_empty() or not _compare_tooltip:
		return
	_compare_tooltip_label.text = LootManager.get_item_compare_bbcode(item)
	_compare_tooltip.visible = true
	_update_compare_tooltip_position()

func _hide_compare_tooltip() -> void:
	_hover_stash_id = ""
	_hover_loadout_slot = ""
	if _compare_tooltip:
		_compare_tooltip.visible = false

func _update_compare_tooltip_position() -> void:
	if not _compare_tooltip:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var tooltip_size := _compare_tooltip.get_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var pos := mouse_pos + Vector2(20, 16)
	if pos.x + tooltip_size.x > viewport_size.x - 8:
		pos.x = mouse_pos.x - tooltip_size.x - 20
	if pos.y + tooltip_size.y > viewport_size.y - 8:
		pos.y = mouse_pos.y - tooltip_size.y - 16
	_compare_tooltip.global_position = pos

func _on_compare_meta_hover_started(meta: Variant) -> void:
	_hover_meta = str(meta)
	var text := AffixLibrary.get_meta_description(_hover_meta)
	if text.is_empty():
		_hide_affix_tooltip()
		return
	_affix_tooltip_label.text = text
	_affix_tooltip.visible = true
	_update_affix_tooltip_position()

func _on_compare_meta_hover_ended(meta: Variant) -> void:
	if str(meta) == _hover_meta:
		_hide_affix_tooltip()

func _on_detail_meta_hover_started(meta: Variant) -> void:
	_on_compare_meta_hover_started(meta)

func _on_detail_meta_hover_ended(meta: Variant) -> void:
	_on_compare_meta_hover_ended(meta)

func _hide_affix_tooltip() -> void:
	_hover_meta = ""
	if _affix_tooltip:
		_affix_tooltip.visible = false

func _update_affix_tooltip_position() -> void:
	if not _affix_tooltip:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var tooltip_size := _affix_tooltip.get_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var pos := mouse_pos + Vector2(18, 14)
	if pos.x + tooltip_size.x > viewport_size.x - 8:
		pos.x = mouse_pos.x - tooltip_size.x - 18
	if pos.y + tooltip_size.y > viewport_size.y - 8:
		pos.y = mouse_pos.y - tooltip_size.y - 14
	_affix_tooltip.global_position = pos

func _refresh(_arg = null) -> void:
	_hide_affix_tooltip()
	_hide_compare_tooltip()
	_update_scrap_total_label()
	if _loadout_doll and _loadout_doll.has_method("refresh"):
		_loadout_doll.refresh()
	_populate_stash_list()
	_update_action_bar()

func _on_loadout_slot_hovered(slot_key: String) -> void:
	_hover_loadout_slot = slot_key
	if slot_key == "body" and LootManager.equipped_armor.is_empty():
		_show_empty_body_tooltip()
		return
	var item := _item_for_loadout_slot(slot_key)
	if not item.is_empty():
		_show_compare_tooltip(item)
	elif _is_locked_loadout_slot(slot_key):
		_show_locked_slot_tooltip(slot_key)

func _on_loadout_slot_unhovered() -> void:
	_hover_loadout_slot = ""
	if _hover_stash_id.is_empty():
		_hide_compare_tooltip()

func _item_for_loadout_slot(slot_key: String) -> Dictionary:
	match slot_key:
		"primary", "secondary", "heavy":
			var slot_index := _weapon_slot_index(slot_key)
			var loot_weapon: Dictionary = LootManager.get_equipped_weapon_for_slot(slot_index)
			if not loot_weapon.is_empty():
				return loot_weapon
			return LootManager.get_baseline_weapon_for_slot(slot_index)
		"body":
			return LootManager.equipped_armor
	return {}

func _is_locked_loadout_slot(slot_key: String) -> bool:
	return slot_key in ["helmet", "belt", "charm_1", "charm_2", "charm_3", "amulet", "ring_1", "ring_2", "gloves", "boots"]

func _show_locked_slot_tooltip(slot_key: String) -> void:
	if not _compare_tooltip:
		return
	var label := slot_key.replace("_", " ").to_upper()
	_compare_tooltip_label.text = "[color=#888888]%s[/color]\n\nComing in a future update." % label
	_compare_tooltip.visible = true
	_update_compare_tooltip_position()

func _show_empty_body_tooltip() -> void:
	if not _compare_tooltip:
		return
	_compare_tooltip_label.text = "[color=#888888]BODY ARMOUR[/color]\n\nEmpty slot.\nSelect armor from stash to equip."
	_compare_tooltip.visible = true
	_update_compare_tooltip_position()

func _on_loadout_slot_pressed(slot_key: String) -> void:
	match slot_key:
		"primary", "secondary", "heavy":
			var slot_index := _weapon_slot_index(slot_key)
			_slot_filter = slot_index
			_update_slot_filter_buttons()
			var loot_weapon: Dictionary = LootManager.get_equipped_weapon_for_slot(slot_index)
			if not loot_weapon.is_empty():
				_selected_item = loot_weapon
				_select_stash_item_by_id(str(loot_weapon.get("id", "")))
			else:
				_selected_item = {}
			_update_action_bar()
		"body":
			if LootManager.equipped_armor.is_empty():
				_selected_item = {}
			else:
				_selected_item = LootManager.equipped_armor
				_select_stash_item_by_id(str(LootManager.equipped_armor.get("id", "")))
			_update_action_bar()

func _on_loadout_slot_double_pressed(slot_key: String) -> void:
	match slot_key:
		"primary", "secondary", "heavy":
			LootManager.unequip_weapon(_weapon_slot_index(slot_key))
		"body":
			LootManager.unequip_armor()
	_refresh()

func _weapon_slot_index(slot_key: String) -> int:
	match slot_key:
		"secondary":
			return 1
		"heavy":
			return 2
	return 0

func _select_stash_item_by_id(item_id: String) -> void:
	if item_id.is_empty() or not _stash_rows.has(item_id):
		return
	_select_stash_item(item_id)

func _update_action_bar() -> void:
	if _selected_item.is_empty() or not _item_matches_tab(_selected_item):
		if not _stash_rows.is_empty() and _selected_item.is_empty():
			_select_stash_item(str(_stash_rows.keys()[0]))
			return
		_selected_label.text = "Select an item from stash"
		_equip_button.disabled = true
		_unequip_button.disabled = true
		_scrap_button.disabled = true
		return
	var rarity_name := LootManager.get_rarity_name(_selected_item.get("rarity", 0))
	var item_type := str(_selected_item.get("type", "")).capitalize()
	_selected_label.text = "%s  ·  %s  ·  %s" % [_selected_item.get("name", "Item"), rarity_name, item_type]
	if LootManager.is_equipped(_selected_item):
		_selected_label.text += "  ·  Equipped"
	var can_equip := LootManager.can_equip(_selected_item)
	var is_equipped := LootManager.is_equipped(_selected_item)
	var scrap_yield := LootManager.get_scrap_yield(_selected_item)
	_equip_button.disabled = not can_equip or is_equipped
	_equip_button.text = "Equip" if can_equip else "Cannot equip"
	_unequip_button.disabled = not is_equipped
	_scrap_button.disabled = scrap_yield <= 0
	_scrap_button.text = "Scrap (+%d)" % scrap_yield if scrap_yield > 0 else "Scrap"

func _update_scrap_total_label() -> void:
	var cap: Dictionary = LootManager.get_gear_capacity()
	var total := LootManager.get_scrap_total()
	_scrap_total_label.text = "Gear stash: %d / %d  |  Scrap Alloy: %d" % [cap["used"], cap["max"], total]
	if cap.get("full", false):
		_scrap_total_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	else:
		_scrap_total_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.65))

func _populate_stash_list() -> void:
	var selected_id := str(_selected_item.get("id", ""))
	for child in _stash_list.get_children():
		child.queue_free()
	_stash_rows.clear()
	var sorted_items: Array[Dictionary] = []
	for item in LootManager.inventory:
		if _item_matches_tab(item) and _item_matches_slot_filter(item):
			sorted_items.append(item)
	_sort_items(sorted_items)
	for item in sorted_items:
		var row := _make_stash_row(item)
		_stash_list.add_child(row)
	if not selected_id.is_empty() and _stash_rows.has(selected_id):
		_update_stash_selection_highlight()
	elif not sorted_items.is_empty():
		_select_stash_item(str(sorted_items[0].get("id", "")))
	elif not _selected_item.is_empty() and not _item_matches_tab(_selected_item):
		_selected_item = {}

func _make_stash_row(item: Dictionary) -> PanelContainer:
	var item_id := str(item.get("id", ""))
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _stash_row_style(false))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.texture = _item_icon(item)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon)
	var label := Label.new()
	label.text = _item_list_label(item)
	label.add_theme_color_override("font_color", _item_list_text_color(item))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hbox.add_child(label)
	row.gui_input.connect(func(event: InputEvent): _on_stash_row_gui_input(event, item_id))
	row.mouse_entered.connect(func(): _on_stash_row_hover(item_id))
	row.mouse_exited.connect(_on_stash_row_unhover)
	_stash_rows[item_id] = row
	return row

func _stash_row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.18, 0.16, 0.14, 0.95)
		style.border_color = Color(0.45, 0.38, 0.28, 0.9)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(3)
	return style

func _select_stash_item(item_id: String) -> void:
	_selected_item = LootManager.find_item(item_id)
	_update_stash_selection_highlight()
	_update_action_bar()

func _update_stash_selection_highlight() -> void:
	var selected_id := str(_selected_item.get("id", ""))
	for id in _stash_rows:
		var row: PanelContainer = _stash_rows[id]
		row.add_theme_stylebox_override("panel", _stash_row_style(str(id) == selected_id))

func _on_stash_row_hover(item_id: String) -> void:
	_hover_stash_id = item_id
	var item := LootManager.find_item(item_id)
	_show_compare_tooltip(item)

func _on_stash_row_unhover() -> void:
	if _hover_stash_id == "":
		return
	_hover_stash_id = ""
	if _hover_loadout_slot.is_empty():
		_hide_compare_tooltip()

func _on_stash_mouse_exited() -> void:
	_hover_stash_id = ""
	if _hover_loadout_slot.is_empty():
		_hide_compare_tooltip()

func _on_stash_row_gui_input(event: InputEvent, item_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if mouse_event.double_click:
		_select_stash_item(item_id)
		_activate_selected_item()
	else:
		_select_stash_item(item_id)
	get_viewport().set_input_as_handled()

func _activate_selected_item() -> void:
	if _selected_item.is_empty():
		return
	if LootManager.is_equipped(_selected_item):
		match _selected_item.get("type", ""):
			"weapon":
				LootManager.unequip_weapon(WeaponLibrary.get_loot_loadout_slot(_selected_item))
			"armor":
				LootManager.unequip_armor()
	elif LootManager.can_equip(_selected_item):
		LootManager.equip_item(_selected_item)
	_refresh()

func _sort_items(items: Array[Dictionary]) -> void:
	match _sort_mode:
		SORT_OLDEST:
			items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("collected_at", 0)) < int(b.get("collected_at", 0))
			)
		SORT_RARITY:
			items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var rarity_a: int = int(a.get("rarity", 0))
				var rarity_b: int = int(b.get("rarity", 0))
				if rarity_a == rarity_b:
					return str(a.get("name", "")) < str(b.get("name", ""))
				return rarity_a > rarity_b
			)
		SORT_NAME:
			items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
			)
		SORT_SLOT:
			items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var slot_a: int = _item_sort_slot(a)
				var slot_b: int = _item_sort_slot(b)
				if slot_a == slot_b:
					return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
				return slot_a < slot_b
			)
		_:
			items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("collected_at", 0)) > int(b.get("collected_at", 0))
			)

func _item_sort_slot(item: Dictionary) -> int:
	match str(item.get("type", "")):
		"weapon":
			return WeaponLibrary.get_loot_loadout_slot(item)
		"armor":
			return 10
		_:
			return 99

func _on_scrap_pressed() -> void:
	if _selected_item.is_empty():
		return
	if LootManager.scrap_item(_selected_item):
		_selected_item = {}
		_refresh()
		if not _stash_rows.is_empty():
			_select_stash_item(str(_stash_rows.keys()[0]))
		else:
			_update_action_bar()

func _on_equip_pressed() -> void:
	if _selected_item.is_empty():
		return
	if LootManager.equip_item(_selected_item):
		_refresh()

func _on_unequip_pressed() -> void:
	if _selected_item.is_empty():
		return
	match _selected_item.get("type", ""):
		"weapon":
			LootManager.unequip_weapon(WeaponLibrary.get_loot_loadout_slot(_selected_item))
		"armor":
			LootManager.unequip_armor()
	_refresh()
