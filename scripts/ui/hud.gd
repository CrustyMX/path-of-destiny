extends CanvasLayer

@onready var health_bar: ProgressBar = $HUD/BottomCombatBar/BottomCenterVitals/HealthBar
@onready var shield_bar: ProgressBar = $HUD/BottomCombatBar/BottomCenterVitals/ShieldBar
@onready var stamina_bar: ProgressBar = $HUD/BottomCombatBar/BottomCenterVitals/StaminaBar
@onready var boss_health_bar: ProgressBar = $HUD/MarginContainer/VBox/BossHealthBar
@onready var boss_name_label: Label = $HUD/MarginContainer/VBox/BossNameLabel
@onready var zone_label: Label = $HUD/MarginContainer/VBox/TopBar/ZoneLabel
@onready var loot_label: Label = $HUD/MarginContainer/VBox/LootNotification
@onready var waypoint_label: Label = $HUD/MarginContainer/VBox/WaypointLabel
@onready var weapon_panels: Array = [
	$HUD/MarginContainer/VBox/AbilityBar/Ability1,
	$HUD/MarginContainer/VBox/AbilityBar/Ability2,
	$HUD/MarginContainer/VBox/AbilityBar/Ability3,
]
@onready var grenade_panel: PanelContainer = $HUD/MarginContainer/VBox/AbilityBar/Ability4
@onready var death_screen: Control = $DeathScreen
@onready var death_fade: ColorRect = $DeathScreen/ColorRect
@onready var death_cause_label: Label = $DeathScreen/VBox/DeathCauseLabel
@onready var death_detail_label: Label = $DeathScreen/VBox/DeathDetailLabel
@onready var pause_menu: Control = $PauseMenu
@onready var respawn_button: Button = $DeathScreen/VBox/RespawnButton
@onready var resume_button: Button = $PauseMenu/VBox/ResumeButton
@onready var quit_button: Button = $PauseMenu/VBox/QuitButton
@onready var loot_count_label: Label = $HUD/MarginContainer/VBox/TopBar/LootCount
@onready var bottom_left_ammo: HBoxContainer = $HUD/BottomCombatBar/BottomLeftAmmo
@onready var ammo_label: Label = $HUD/BottomCombatBar/BottomLeftAmmo/AmmoSlot/AmmoLabel
@onready var crosshair: Control = $HUD/Crosshair
@onready var camera_mode_label: Label = $HUD/MarginContainer/VBox/TopBar/CameraModeLabel
@onready var aim_debug_overlay: Control = $HUD/AimDebugOverlay

var _diag_panel: PanelContainer = null
var _inventory_panel: Control = null
var _test_weapons_panel: Control = null
var _keybind_hint: Label = null

var boss_ref: Node3D = null
var boss_waypoint: Vector3 = Vector3.ZERO
var loot_notification_timer: float = 0.0
var _state_before_pause: GameManager.GameState = GameManager.GameState.EXPLORING
var _state_before_loot: GameManager.GameState = GameManager.GameState.EXPLORING
var _weapon_controller: Node = null
var _grenade_throw_cd: float = 0.0
var _grenade_recharge_cd: float = 0.0
var _reload_panel: PanelContainer = null
var _reload_label: Label = null
var _reload_bar: ProgressBar = null
var _reload_time_label: Label = null
var _last_ammo_current: int = 0
var _last_ammo_maximum: int = 0
var _potion_panel: PanelContainer = null
var _potion_count_label: Label = null
var _potion_dots_label: Label = null
var _potion_cd_label: Label = null
var _potion_use_cd: float = 0.0

func _ready() -> void:
	add_to_group("hud")
	boss_health_bar.visible = false
	boss_name_label.visible = false
	death_screen.visible = false
	death_screen.get_node("VBox").modulate.a = 0.0
	pause_menu.visible = false
	loot_label.visible = false
	waypoint_label.visible = true
	respawn_button.pressed.connect(_on_respawn)
	resume_button.pressed.connect(_on_resume)
	quit_button.pressed.connect(_on_quit)
	GameManager.player_died.connect(_on_player_died)
	GameManager.zone_entered.connect(_on_zone_entered)
	GameManager.zone_combat_started.connect(_on_zone_combat_started)
	GameManager.zone_cleared.connect(_on_zone_cleared_hud)
	GameManager.boss_fight_started.connect(_on_boss_fight_started)
	GameManager.boss_defeated.connect(_on_boss_defeated_hud)
	LootManager.loot_collected.connect(_on_loot_collected)
	LootManager.item_scrapped.connect(_on_item_scrapped)
	WeaponLibrary.weapon_changed.connect(_on_weapon_changed)
	WeaponLibrary.loadout_changed.connect(_on_loadout_changed)
	GrenadeManager.grenades_changed.connect(_on_grenades_changed)
	GrenadeManager.throw_cooldown_updated.connect(_on_grenade_cooldown)
	GrenadeManager.recharge_updated.connect(_on_grenade_recharge)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	_setup_weapon_bar()
	_setup_reload_banner()
	_setup_vitals_bars()
	_setup_threat_indicator()
	_setup_health_pots_ui()
	_on_grenades_changed(GrenadeManager.grenade_count, GrenadeManager.MAX_GRENADES)
	zone_label.text = GameManager.current_zone
	_update_crosshair()
	_setup_diag_panel()
	_setup_inventory_panel()
	_setup_test_weapons_panel()
	_setup_keybind_hint()
	ScreenshotCapture.capture_finished.connect(_on_screenshot_finished)

const KEYBIND_HINT_TEXT := """WASD Move  ·  Shift Sprint  ·  Space Jump
LMB Fire  ·  RMB Aim  ·  R Reload  ·  Q Grenade  ·  T Health Pot
1 / 2 / 3 Weapons  ·  Tab / I Inventory  ·  ` Test Weapons  ·  F12 Screenshot  ·  Esc Pause"""

func _setup_keybind_hint() -> void:
	var vbox: VBoxContainer = $HUD/MarginContainer/VBox
	_keybind_hint = Label.new()
	_keybind_hint.name = "KeybindHint"
	_keybind_hint.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_keybind_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_keybind_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keybind_hint.add_theme_font_size_override("font_size", 11)
	_keybind_hint.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9, 0.72))
	_keybind_hint.add_theme_constant_override("outline_size", 1)
	_keybind_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.65))
	_keybind_hint.text = KEYBIND_HINT_TEXT
	var insert_after: int = vbox.get_node("AbilityBar").get_index()
	vbox.add_child(_keybind_hint)
	vbox.move_child(_keybind_hint, insert_after + 1)
	_update_keybind_hint()

func _setup_reload_banner() -> void:
	_reload_panel = PanelContainer.new()
	_reload_panel.name = "ReloadBanner"
	_reload_panel.visible = false
	_reload_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload_panel.custom_minimum_size = Vector2(96, 0)
	_reload_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.1, 0.82)
	panel_style.border_color = Color(1.0, 0.72, 0.28, 0.85)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 6
	panel_style.content_margin_right = 6
	panel_style.content_margin_top = 3
	panel_style.content_margin_bottom = 3
	_reload_panel.add_theme_stylebox_override("panel", panel_style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_reload_panel.add_child(vbox)
	_reload_label = Label.new()
	_reload_label.text = "Reloading"
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reload_label.add_theme_font_size_override("font_size", 11)
	_reload_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	vbox.add_child(_reload_label)
	_reload_bar = ProgressBar.new()
	_reload_bar.custom_minimum_size = Vector2(84.0, 4.0)
	_reload_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	_reload_bar.value = 0.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.72, 0.28)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_right = 2
	fill.corner_radius_bottom_left = 2
	_reload_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	_reload_bar.add_theme_stylebox_override("background", bg)
	vbox.add_child(_reload_bar)
	_reload_time_label = Label.new()
	_reload_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reload_time_label.add_theme_font_size_override("font_size", 10)
	_reload_time_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	vbox.add_child(_reload_time_label)
	var indicator_stack := VBoxContainer.new()
	indicator_stack.name = "IndicatorStack"
	indicator_stack.add_theme_constant_override("separation", 3)
	indicator_stack.custom_minimum_size = Vector2(96, 0)
	indicator_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	indicator_stack.add_child(_reload_panel)
	var ammo_slot: CenterContainer = bottom_left_ammo.get_node("AmmoSlot")
	bottom_left_ammo.remove_child(ammo_slot)
	bottom_left_ammo.add_child(ammo_slot)
	bottom_left_ammo.add_child(indicator_stack)

func _setup_threat_indicator() -> void:
	var combat_bar: HBoxContainer = $HUD/BottomCombatBar
	if combat_bar.get_node_or_null("ThreatCompass"):
		return
	var indicator: Control = load("res://scripts/ui/threat_indicator.gd").new()
	indicator.name = "ThreatCompass"
	indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	combat_bar.add_child(indicator)
	combat_bar.move_child(indicator, combat_bar.get_node("BottomCenterVitals").get_index() + 1)

func _setup_health_pots_ui() -> void:
	if _potion_panel != null:
		return
	var indicator_stack: VBoxContainer = bottom_left_ammo.get_node("IndicatorStack")
	_potion_panel = PanelContainer.new()
	_potion_panel.name = "PotionSlot"
	_potion_panel.custom_minimum_size = Vector2(96, 34)
	_potion_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.08, 0.82)
	panel_style.border_color = Color(0.58, 0.2, 0.18, 0.7)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	_potion_panel.add_theme_stylebox_override("panel", panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	_potion_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)
	var top_row := HBoxContainer.new()
	var title := Label.new()
	title.text = "Health Pot"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.92, 0.58, 0.52))
	var key_label := Label.new()
	key_label.text = "T"
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72))
	top_row.add_child(title)
	top_row.add_child(key_label)
	vbox.add_child(top_row)
	_potion_dots_label = Label.new()
	_potion_dots_label.add_theme_font_size_override("font_size", 12)
	_potion_dots_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.28))
	vbox.add_child(_potion_dots_label)
	_potion_count_label = Label.new()
	_potion_count_label.add_theme_font_size_override("font_size", 9)
	_potion_count_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	_potion_count_label.visible = false
	vbox.add_child(_potion_count_label)
	_potion_cd_label = Label.new()
	_potion_cd_label.add_theme_font_size_override("font_size", 9)
	_potion_cd_label.add_theme_color_override("font_color", Color(0.88, 0.72, 0.45))
	_potion_cd_label.visible = false
	vbox.add_child(_potion_cd_label)
	indicator_stack.add_child(_potion_panel)
	HealthPotionManager.potions_changed.connect(_on_potions_changed)
	HealthPotionManager.use_cooldown_updated.connect(_on_potion_cooldown)
	_on_potions_changed(HealthPotionManager.potion_count, HealthPotionManager.get_max_potions())

func _on_potions_changed(count: int, max_count: int) -> void:
	if _potion_dots_label == null:
		return
	_potion_dots_label.text = _format_potion_dots(count, max_count)
	_potion_count_label.text = "%d / %d" % [count, max_count]
	if count <= 0:
		_potion_panel.modulate = Color(0.55, 0.55, 0.55)
	else:
		_potion_panel.modulate = Color.WHITE

func _on_potion_cooldown(remaining: float, _total: float) -> void:
	_potion_use_cd = remaining
	_update_potion_cd_label()

func _update_potion_cd_label() -> void:
	if _potion_cd_label == null:
		return
	if _potion_use_cd > 0.0:
		_potion_cd_label.visible = true
		_potion_cd_label.text = "%.1fs" % _potion_use_cd
	else:
		_potion_cd_label.visible = false

func _format_potion_dots(count: int, max_count: int) -> String:
	var chars := PackedStringArray()
	for i in max_count:
		chars.append("●" if i < count else "○")
	return " ".join(chars)

func _setup_vitals_bars() -> void:
	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.35, 0.72, 1.0)
	shield_fill.corner_radius_top_left = 3
	shield_fill.corner_radius_top_right = 3
	shield_fill.corner_radius_bottom_right = 3
	shield_fill.corner_radius_bottom_left = 3
	shield_bar.add_theme_stylebox_override("fill", shield_fill)
	var shield_bg := StyleBoxFlat.new()
	shield_bg.bg_color = Color(0.08, 0.12, 0.18, 0.88)
	shield_bar.add_theme_stylebox_override("background", shield_bg)
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color(0.82, 0.18, 0.14)
	health_fill.corner_radius_top_left = 3
	health_fill.corner_radius_top_right = 3
	health_fill.corner_radius_bottom_right = 3
	health_fill.corner_radius_bottom_left = 3
	health_bar.add_theme_stylebox_override("fill", health_fill)
	var health_bg := StyleBoxFlat.new()
	health_bg.bg_color = Color(0.1, 0.08, 0.08, 0.88)
	health_bar.add_theme_stylebox_override("background", health_bg)
	var stamina_fill := StyleBoxFlat.new()
	stamina_fill.bg_color = Color(0.28, 0.78, 0.34)
	stamina_fill.corner_radius_top_left = 2
	stamina_fill.corner_radius_top_right = 2
	stamina_fill.corner_radius_bottom_right = 2
	stamina_fill.corner_radius_bottom_left = 2
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)
	var stamina_bg := StyleBoxFlat.new()
	stamina_bg.bg_color = Color(0.08, 0.1, 0.08, 0.75)
	stamina_bar.add_theme_stylebox_override("background", stamina_bg)

func _setup_inventory_panel() -> void:
	_inventory_panel = load("res://scenes/ui/inventory.tscn").instantiate()
	$HUD.add_child(_inventory_panel)
	$HUD.move_child(_inventory_panel, $HUD.get_child_count() - 1)
	_inventory_panel.closed.connect(_on_inventory_closed)
	LootManager.inventory_full.connect(_on_inventory_full)

func _setup_test_weapons_panel() -> void:
	_test_weapons_panel = load("res://scripts/ui/test_weapons_panel.gd").new()
	$HUD.add_child(_test_weapons_panel)
	$HUD.move_child(_test_weapons_panel, $HUD.get_child_count() - 1)
	_test_weapons_panel.closed.connect(_on_test_weapons_closed)

func _on_camera_mode_changed(mode: int) -> void:
	if mode == 0:
		camera_mode_label.text = "3rd Person"
	else:
		camera_mode_label.text = "1st Person"
	_update_crosshair()

func _on_ads_changed(is_ads: bool) -> void:
	if crosshair.has_method("set_scoped"):
		crosshair.set_scoped(is_ads)

func _on_game_state_changed(_state: GameManager.GameState) -> void:
	_update_crosshair()

func _update_keybind_hint() -> void:
	if _keybind_hint == null:
		return
	var show := GameManager.current_state != GameManager.GameState.DEAD
	show = show and not pause_menu.visible and not death_screen.visible
	show = show and (_inventory_panel == null or not _inventory_panel.is_open())
	show = show and (_test_weapons_panel == null or not _test_weapons_panel.is_open())
	_keybind_hint.visible = show

func show_notice(text: String, duration: float = 2.0) -> void:
	loot_label.text = text
	loot_label.modulate = Color(1.0, 0.75, 0.35)
	loot_label.visible = true
	loot_notification_timer = duration

func _on_screenshot_finished(path: String, clipboard_ok: bool) -> void:
	if path.is_empty() and not clipboard_ok:
		show_notice("Screenshot failed", 2.0)
		return
	var msg := "Screenshot saved"
	if clipboard_ok:
		msg += " · copied to clipboard"
	show_notice(msg, 2.5)

func _setup_diag_panel() -> void:
	_diag_panel = load("res://scripts/ui/diag_panel.gd").new()
	$HUD.add_child(_diag_panel)

func _update_crosshair() -> void:
	var show := GameManager.current_state != GameManager.GameState.DEAD
	show = show and not pause_menu.visible and not death_screen.visible
	show = show and (_inventory_panel == null or not _inventory_panel.is_open())
	show = show and (_test_weapons_panel == null or not _test_weapons_panel.is_open())
	crosshair.visible = show
	if _reload_panel:
		if not show:
			_reload_panel.visible = false
	if crosshair.has_method("set_melee_mode"):
		crosshair.set_melee_mode(not WeaponLibrary.is_ranged())
	if not show and crosshair.has_method("set_scoped"):
		crosshair.set_scoped(false)
	_update_keybind_hint()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("aim_debug_toggle"):
		AimDebug.toggle()
		if aim_debug_overlay.has_method("_refresh"):
			aim_debug_overlay._refresh()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("aim_debug_copy"):
		var text := AimDebug.build_copy_text()
		DisplayServer.clipboard_set(text)
		print(text)
		if aim_debug_overlay.has_method("_on_report_copied"):
			aim_debug_overlay._on_report_copied()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("grenade_debug_toggle"):
		GrenadeDebug.toggle()
		if aim_debug_overlay.has_method("_refresh"):
			aim_debug_overlay._refresh()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("grenade_debug_copy"):
		var text := GrenadeDebug.build_copy_text()
		DisplayServer.clipboard_set(text)
		print(text)
		if aim_debug_overlay.has_method("_on_report_copied"):
			aim_debug_overlay._on_report_copied()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("diag_panel_toggle"):
		GameDiag.toggle_panel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("diag_copy"):
		var text := GameDiag.build_copy_text()
		DisplayServer.clipboard_set(text)
		print(text)
		if _diag_panel and _diag_panel.has_method("flash_copied"):
			_diag_panel.flash_copied()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("screenshot"):
		ScreenshotCapture.capture_viewport(get_viewport())
		get_viewport().set_input_as_handled()
		return
	if GameDiag.panel_visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BRACKETRIGHT and _diag_panel and _diag_panel.has_method("next_tab"):
			_diag_panel.next_tab()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_BRACKETLEFT and _diag_panel and _diag_panel.has_method("prev_tab"):
			_diag_panel.prev_tab()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("toggle_enemy_spawning"):
		GameManager.toggle_enemy_spawning()
		_show_enemy_spawn_notice()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("test_weapons"):
		if death_screen.visible or GameManager.current_state == GameManager.GameState.DEAD:
			return
		_toggle_test_weapons()
		get_viewport().set_input_as_handled()
		return
	if _is_inventory_toggle_key(event):
		if death_screen.visible or GameManager.current_state == GameManager.GameState.DEAD:
			return
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if death_screen.visible:
			return
		if _test_weapons_panel and _test_weapons_panel.is_open():
			_close_test_weapons()
			get_viewport().set_input_as_handled()
			return
		if _inventory_panel and _inventory_panel.is_open():
			_close_inventory()
			get_viewport().set_input_as_handled()
			return
		_toggle_pause()

func _toggle_inventory() -> void:
	if _inventory_panel.is_open():
		_close_inventory()
	else:
		_open_inventory()

func _is_inventory_toggle_key(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if event.is_action("inventory"):
		return true
	var key_code: int = int(event.keycode)
	var physical_code: int = int(event.physical_keycode)
	return key_code == KEY_I or physical_code == KEY_I or int(event.unicode) == 105 or key_code == KEY_TAB or physical_code == KEY_TAB

func _open_inventory() -> void:
	if _test_weapons_panel and _test_weapons_panel.is_open():
		_close_test_weapons()
	if pause_menu.visible:
		pause_menu.visible = false
	_state_before_loot = GameManager.current_state
	if _state_before_loot in [GameManager.GameState.PAUSED, GameManager.GameState.LOOTING, GameManager.GameState.DEAD]:
		_state_before_loot = GameManager.GameState.EXPLORING
	_inventory_panel.open()
	GameManager.set_state(GameManager.GameState.LOOTING)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_crosshair()

func _close_inventory() -> void:
	if _inventory_panel == null or not _inventory_panel.is_open():
		return
	_inventory_panel.close()

func _on_inventory_closed() -> void:
	if GameManager.current_state == GameManager.GameState.LOOTING:
		GameManager.set_state(_state_before_loot)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_crosshair()

func _toggle_test_weapons() -> void:
	if _test_weapons_panel.is_open():
		_close_test_weapons()
	else:
		_open_test_weapons()

func _open_test_weapons() -> void:
	if _inventory_panel and _inventory_panel.is_open():
		_close_inventory()
	if pause_menu.visible:
		pause_menu.visible = false
	_state_before_loot = GameManager.current_state
	if _state_before_loot in [GameManager.GameState.PAUSED, GameManager.GameState.LOOTING, GameManager.GameState.DEAD]:
		_state_before_loot = GameManager.GameState.EXPLORING
	_test_weapons_panel.open()
	GameManager.set_state(GameManager.GameState.LOOTING)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_crosshair()

func _close_test_weapons() -> void:
	if _test_weapons_panel == null or not _test_weapons_panel.is_open():
		return
	_test_weapons_panel.close()

func _on_test_weapons_closed() -> void:
	if GameManager.current_state == GameManager.GameState.LOOTING:
		GameManager.set_state(_state_before_loot)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_crosshair()

func _show_enemy_spawn_notice() -> void:
	var enabled := GameManager.enemy_spawning_enabled
	loot_label.text = "Enemy Spawning: %s" % ("ON" if enabled else "OFF")
	loot_label.modulate = Color(0.55, 1.0, 0.65) if enabled else Color(1.0, 0.55, 0.35)
	loot_label.visible = true
	loot_notification_timer = 2.5

func _toggle_pause() -> void:
	if _inventory_panel and _inventory_panel.is_open():
		return
	if _test_weapons_panel and _test_weapons_panel.is_open():
		return
	if GameManager.current_state == GameManager.GameState.PAUSED:
		pause_menu.visible = false
		GameManager.set_state(_state_before_pause)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_state_before_pause = GameManager.current_state
		pause_menu.visible = true
		GameManager.set_state(GameManager.GameState.PAUSED)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_crosshair()

func _on_resume() -> void:
	_toggle_pause()

func _on_quit() -> void:
	get_tree().quit()

func _process(delta: float) -> void:
	if loot_notification_timer > 0:
		loot_notification_timer -= delta
		if loot_notification_timer <= 0:
			loot_label.visible = false
	loot_count_label.text = "Loot: %d" % LootManager.total_loot_collected
	_update_waypoint()

func _update_waypoint() -> void:
	if GameManager.boss_fight_active or boss_waypoint == Vector3.ZERO:
		waypoint_label.visible = false
		return
	var player := GameManager.player
	if not player:
		return
	var to_arena := boss_waypoint - player.global_position
	to_arena.y = 0
	var dist := to_arena.length()
	if dist < 18.0:
		waypoint_label.text = "⚠ BOSS ARENA — Enter the ring!"
		waypoint_label.modulate = Color(1, 0.3, 0.1)
	elif dist < 1.0:
		waypoint_label.visible = false
	else:
		var dir_name := _direction_name(to_arena.normalized())
		waypoint_label.text = "Boss Arena → %dm %s" % [int(dist), dir_name]
		waypoint_label.modulate = Color(1, 0.55, 0.2)
	waypoint_label.visible = true

func _direction_name(dir: Vector3) -> String:
	if abs(dir.x) > abs(dir.z):
		return "East" if dir.x > 0 else "West"
	return "South" if dir.z > 0 else "North"

func _on_weapon_changed(_weapon_id: String) -> void:
	_update_crosshair()
	_refresh_weapon_bar()

func _on_loadout_changed(_slot: int, _weapon_id: String) -> void:
	_refresh_weapon_bar()

func _format_ammo_text(current: int, maximum: int) -> String:
	if maximum <= 0:
		return ""
	return "%d / %d" % [current, maximum]

func _on_ammo_changed(current: int, maximum: int, is_reloading: bool) -> void:
	_last_ammo_current = current
	_last_ammo_maximum = maximum
	if maximum <= 0:
		ammo_label.text = "--"
		_update_reload_banner(0.0, 0.0, false)
		return
	if is_reloading:
		ammo_label.text = _format_ammo_text(current, maximum)
		ammo_label.modulate = Color(0.72, 0.72, 0.72)
	elif current <= 0:
		ammo_label.text = "0 / %d" % maximum
		ammo_label.modulate = Color(1.0, 0.45, 0.25)
		_show_empty_mag_banner()
	else:
		ammo_label.text = _format_ammo_text(current, maximum)
		if current <= int(maximum * 0.25):
			ammo_label.modulate = Color(1.0, 0.55, 0.35)
		else:
			ammo_label.modulate = Color(0.92, 0.94, 1.0)
	if not is_reloading and current > 0:
		_update_reload_banner(0.0, 0.0, false)

func _on_reload_progress(remaining: float, total: float, is_reloading: bool) -> void:
	_update_reload_banner(remaining, total, is_reloading)

func _update_reload_banner(remaining: float, total: float, is_reloading: bool) -> void:
	if _reload_panel == null:
		return
	if not is_reloading or total <= 0.0:
		if _last_ammo_maximum > 0 and _last_ammo_current <= 0 and WeaponLibrary.is_ranged():
			return
		_reload_panel.visible = false
		return
	_reload_panel.visible = true
	_reload_label.text = "Reloading"
	_reload_label.visible = true
	_reload_bar.visible = true
	_reload_time_label.visible = true
	_reload_bar.value = 1.0 - clampf(remaining / total, 0.0, 1.0)
	_reload_time_label.text = "%.1fs" % remaining

func _show_empty_mag_banner() -> void:
	if _reload_panel == null or not WeaponLibrary.is_ranged():
		return
	if _weapon_controller and _weapon_controller.has_method("is_reloading") and _weapon_controller.is_reloading():
		return
	_reload_panel.visible = true
	_reload_label.text = "Press R"
	_reload_label.visible = true
	_reload_bar.visible = false
	_reload_time_label.visible = false

func connect_player(player: Node3D) -> void:
	player.health_changed.connect(_on_health_changed)
	player.shield_changed.connect(_on_shield_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	if player.has_signal("attack_landed"):
		player.attack_landed.connect(_on_attack_landed)
	if player.has_signal("camera_mode_changed"):
		player.camera_mode_changed.connect(_on_camera_mode_changed)
		_on_camera_mode_changed(player.get_camera_mode() if player.has_method("get_camera_mode") else 0)
	if player.has_signal("ads_changed"):
		player.ads_changed.connect(_on_ads_changed)
	if player.has_node("WeaponController"):
		_weapon_controller = player.get_node("WeaponController")
		if _weapon_controller.has_signal("ammo_changed"):
			_weapon_controller.ammo_changed.connect(_on_ammo_changed)
		if _weapon_controller.has_signal("reload_progress_changed"):
			_weapon_controller.reload_progress_changed.connect(_on_reload_progress)
			if _weapon_controller.has_method("get_reload_progress"):
				var progress: Dictionary = _weapon_controller.get_reload_progress()
				_on_reload_progress(progress.get("remaining", 0.0), progress.get("total", 0.0), progress.get("is_reloading", false))
		if _weapon_controller.has_method("_emit_ammo_state"):
			_weapon_controller._emit_ammo_state()
	GameDiag.link_player(player)

func set_boss_waypoint(pos: Vector3) -> void:
	boss_waypoint = pos

func register_boss(boss: Node3D) -> void:
	boss_ref = boss
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.boss_died.connect(_on_boss_died)
	boss_name_label.text = boss.BOSS_NAME

func _on_boss_fight_started(_boss: Node3D) -> void:
	boss_health_bar.max_value = boss_ref.MAX_HEALTH if boss_ref else 800
	boss_health_bar.value = boss_ref.health if boss_ref else 800
	boss_health_bar.visible = true
	boss_name_label.visible = true
	waypoint_label.visible = false

func _on_boss_defeated_hud(_boss_name: String) -> void:
	waypoint_label.text = "Boss Defeated!"
	waypoint_label.modulate = Color(0.3, 1, 0.4)
	waypoint_label.visible = true

func _setup_weapon_bar() -> void:
	_refresh_weapon_bar()
	var g_label: Label = grenade_panel.get_node("Label")
	var g_key: Label = grenade_panel.get_node("KeyLabel")
	g_label.text = "Frag Grenade"
	g_key.text = "Q"
	grenade_panel.get_node("CDLabel").visible = false

func _refresh_weapon_bar() -> void:
	for i in range(weapon_panels.size()):
		var panel: PanelContainer = weapon_panels[i]
		var w: Dictionary = WeaponLibrary.get_loadout_weapon(i)
		var label: Label = panel.get_node("Label")
		var key_label: Label = panel.get_node("KeyLabel")
		var slot_label := WeaponLibrary.get_loadout_slot_label(i)
		var weapon_name: String = w.get("name", "Empty")
		label.text = weapon_name if weapon_name != "Empty" else slot_label
		key_label.text = str(i + 1)
		panel.get_node("CDLabel").visible = false
		if i == WeaponLibrary.active_slot:
			panel.modulate = Color(1.0, 0.88, 0.58)
		else:
			panel.modulate = Color(0.72, 0.72, 0.72)

func _refresh_weapon_highlights() -> void:
	_refresh_weapon_bar()

func _on_grenades_changed(count: int, max_count: int) -> void:
	var label: Label = grenade_panel.get_node("Label")
	label.text = "Frag Grenade (%d/%d)" % [count, max_count]
	if count <= 0:
		grenade_panel.modulate = Color(0.5, 0.5, 0.5)
	else:
		grenade_panel.modulate = Color.WHITE

func _on_grenade_cooldown(remaining: float, _total: float) -> void:
	_grenade_throw_cd = remaining
	_update_grenade_cd_label()

func _on_grenade_recharge(remaining: float, _total: float) -> void:
	_grenade_recharge_cd = remaining
	_update_grenade_cd_label()

func _update_grenade_cd_label() -> void:
	var cd_label: Label = grenade_panel.get_node("CDLabel")
	if _grenade_throw_cd > 0.0:
		cd_label.text = "%.1f" % _grenade_throw_cd
		cd_label.visible = true
	elif _grenade_recharge_cd > 0.0 and GrenadeManager.grenade_count < GrenadeManager.MAX_GRENADES:
		cd_label.text = "+%.0fs" % ceilf(_grenade_recharge_cd)
		cd_label.visible = true
	else:
		cd_label.visible = false

func _on_attack_landed(_damage: float) -> void:
	if crosshair.has_method("show_hit_confirm"):
		crosshair.show_hit_confirm()

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_shield_changed(current: float, maximum: float) -> void:
	shield_bar.max_value = maximum
	shield_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current

func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_health_bar.max_value = maximum
	boss_health_bar.value = current

func _on_boss_phase_changed(phase: int) -> void:
	boss_name_label.text = "%s — Phase %d" % [boss_ref.BOSS_NAME if boss_ref else "Boss", phase]

func _on_boss_died() -> void:
	boss_health_bar.visible = false
	boss_name_label.visible = false
	boss_ref = null

func _on_player_died() -> void:
	if _inventory_panel and _inventory_panel.is_open():
		_inventory_panel.visible = false
	if pause_menu.visible:
		pause_menu.visible = false
	var info: Dictionary = GameManager.last_death_info
	death_cause_label.text = info.get("source_name", "Unknown assailant")
	death_detail_label.text = info.get("detail", "Your journey ends here.")
	death_fade.color = Color(0.05, 0, 0, 0)
	death_screen.visible = true
	death_screen.modulate.a = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_crosshair()
	var tween := create_tween()
	tween.tween_property(death_fade, "color:a", 0.88, 0.55)
	tween.parallel().tween_property(death_screen.get_node("VBox"), "modulate:a", 1.0, 0.45).from(0.0)
	await tween.finished
	respawn_button.grab_focus()

func _on_respawn() -> void:
	var tween := create_tween()
	tween.tween_property(death_fade, "color:a", 0.0, 0.35)
	tween.parallel().tween_property(death_screen.get_node("VBox"), "modulate:a", 0.0, 0.3)
	await tween.finished
	death_screen.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.respawn_player()
	_update_crosshair()

func _on_zone_entered(zone_name: String) -> void:
	zone_label.text = zone_name

func _on_zone_combat_started(_zone_id: String, zone_name: String) -> void:
	zone_label.text = zone_name
	show_notice("Zone Engaged — %s" % zone_name, 2.5)
	waypoint_label.visible = false

func _on_zone_cleared_hud(zone_id: String) -> void:
	show_notice("Zone Cleared!", 3.0)
	waypoint_label.visible = not GameManager.boss_fight_active
	if GameManager.is_zone_cleared(zone_id):
		waypoint_label.text = ""

func _on_item_scrapped(item: Dictionary, scrap_gain: int) -> void:
	show_notice("Scrapped %s → +%d Scrap Alloy" % [item.get("name", "Item"), scrap_gain], 2.5)

func _on_inventory_full(item: Dictionary) -> void:
	show_notice("Inventory full — cannot pick up %s" % item.get("name", "gear"), 3.0)

func _on_loot_collected(item: Dictionary) -> void:
	var rarity: int = item.get("rarity", 0)
	var color := LootManager.get_rarity_color(rarity)
	var affix_text := AffixLibrary.format_affix_lines(item.get("affixes", []))
	if affix_text.is_empty():
		loot_label.text = "+%s [%s] — inventory" % [item.get("name", ""), LootManager.get_rarity_name(rarity)]
	else:
		loot_label.text = "+%s [%s] — inventory\n%s" % [item.get("name", ""), LootManager.get_rarity_name(rarity), affix_text]
	loot_label.modulate = color
	loot_label.visible = true
	loot_notification_timer = 4.0 if not affix_text.is_empty() else 3.0
