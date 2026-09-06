extends PanelContainer

const TAB_DEFS := [
	{"key": "stats", "title": "Stats"},
	{"key": "combat", "title": "Combat"},
	{"key": "player", "title": "Player"},
	{"key": "weapons", "title": "Weapons"},
	{"key": "loot", "title": "Loot"},
	{"key": "aim", "title": "Aim"},
	{"key": "grenade", "title": "Grenade"},
	{"key": "options", "title": "Options"},
]

const PANEL_BG_ALPHA := 0.38
const PANEL_BORDER_ALPHA := 0.55

var _tab_container: TabContainer
var _tab_labels: Dictionary = {}
var _options_label: Label
var _status_label: Label
var _flash_timer: float = 0.0
var _refresh_timer: float = 0.0

func _ready() -> void:
	name = "DiagPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -360.0
	offset_top = 72.0
	offset_right = -12.0
	offset_bottom = -96.0
	grow_horizontal = 0
	grow_vertical = 2
	_build_ui()
	_set_mouse_ignore_recursive(self)
	GameDiag.panel_changed.connect(_on_panel_changed)
	GameDiag.track_changed.connect(_refresh_all)
	GameDiag.snapshot_changed.connect(_refresh_all)
	set_process(true)

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.12:
		_refresh_timer = 0.0
		_refresh_all()
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		_update_status()

func _build_ui() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.08, PANEL_BG_ALPHA)
	panel_style.border_color = Color(0.35, 0.55, 0.85, PANEL_BORDER_ALPHA)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", panel_style)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var header := Label.new()
	header.text = "DIAG PANEL"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	root.add_child(header)
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	_status_label.text = "F10 close | F11 copy | [ ] switch tabs"
	root.add_child(_status_label)
	_tab_container = TabContainer.new()
	_tab_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT
	root.add_child(_tab_container)
	for tab_def in TAB_DEFS:
		var key: String = tab_def["key"]
		if key == "options":
			_build_options_tab(tab_def["title"])
		else:
			_build_text_tab(key, tab_def["title"])

func _build_text_tab(key: String, title: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	scroll.add_child(label)
	_tab_container.add_child(scroll)
	_tab_labels[key] = label

func _build_options_tab(title: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_options_label = Label.new()
	_options_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_options_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_label.add_theme_font_size_override("font_size", 12)
	_options_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	_options_label.add_theme_constant_override("shadow_offset_x", 1)
	_options_label.add_theme_constant_override("shadow_offset_y", 1)
	_options_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	scroll.add_child(_options_label)
	_tab_container.add_child(scroll)
	_tab_labels["options"] = _options_label

func _on_panel_changed() -> void:
	visible = GameDiag.panel_visible
	if visible:
		_refresh_all()
		_update_status()

func flash_copied() -> void:
	_flash_timer = 2.0
	_update_status()

func next_tab() -> void:
	if not visible or not _tab_container:
		return
	_tab_container.current_tab = (_tab_container.current_tab + 1) % _tab_container.get_tab_count()

func prev_tab() -> void:
	if not visible or not _tab_container:
		return
	var count := _tab_container.get_tab_count()
	_tab_container.current_tab = (_tab_container.current_tab - 1 + count) % count

func _refresh_all(_arg = null) -> void:
	if not visible:
		return
	for key in _tab_labels:
		if key == "options":
			_tab_labels[key].text = GameDiag.get_tab_text("options")
			continue
		var label: Label = _tab_labels[key]
		label.text = GameDiag.get_tab_text(key)

func _update_status() -> void:
	if _flash_timer > 0.0:
		_status_label.text = "Report copied to clipboard!"
		_status_label.modulate = Color(0.45, 1.0, 0.55)
	else:
		_status_label.text = "F10 close | F11 copy | [ ] tabs | play-through overlay"
		_status_label.modulate = Color(0.65, 0.75, 0.85)

func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
