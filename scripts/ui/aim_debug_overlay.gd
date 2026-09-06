extends Control

@onready var info_label: Label = $InfoPanel/InfoLabel
@onready var status_label: Label = $StatusLabel

var _flash_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AimDebug.overlay_changed.connect(_refresh)
	GrenadeDebug.overlay_changed.connect(_refresh)
	visible = false
	set_process(true)
	_refresh()

func _on_report_copied() -> void:
	_flash_timer = 2.0
	_refresh()

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		_refresh()

func _refresh() -> void:
	visible = AimDebug.enabled or GrenadeDebug.enabled
	if not visible:
		return
	queue_redraw()
	var lines: PackedStringArray = []
	if AimDebug.enabled:
		var last_aim := AimDebug.get_last_report()
		if last_aim.is_empty():
			lines.append("AIM DEBUG ON — fire to record (F3 off | F4 copy)")
		else:
			lines.append("AIM #%d (%s): %s (%.0fpx)" % [
				last_aim.get("id", 0),
				last_aim.get("camera_mode", "?"),
				AimDebug.describe_offset(last_aim),
				last_aim.get("distance_px", 0.0),
			])
	if GrenadeDebug.enabled:
		var last_g := GrenadeDebug.get_last_report()
		if last_g.is_empty():
			lines.append("GRENADE DEBUG ON — throw with Q (F6 off | F7 copy)")
		else:
			lines.append("GRENADE #%d (%s | %s)" % [
				last_g.get("id", 0),
				last_g.get("throw_mode", "?"),
				last_g.get("camera_mode", "?"),
			])
			lines.append("  Explosion vs reticle: %s (%.0fpx)" % [
				GrenadeDebug.describe_offset(last_g),
				last_g.get("distance_px", 0.0),
			])
			lines.append("  Arc peak vs reticle: %s (%.0fpx)" % [
				GrenadeDebug.describe_apex_offset(last_g),
				last_g.get("apex_distance_px", 0.0),
			])
			lines.append("  Arc vs target: %.0fpx | height delta: %+.1fm" % [
				last_g.get("apex_target_distance_px", 0.0),
				last_g.get("apex_height_delta_m", 0.0),
			])
			lines.append("  World miss: %.2fm | pitch: %.2f" % [
				last_g.get("world_miss_m", 0.0),
				last_g.get("aim_pitch", 0.0),
			])
			lines.append("  Target vs reticle: %.0fpx | range: %.1fm" % [
				last_g.get("target_distance_px", 0.0),
				last_g.get("effective_range", 0.0),
			])
	if lines.is_empty():
		info_label.text = "DEBUG OVERLAY\nF3 aim | F4 copy aim\nF6 grenade | F7 copy grenade"
	else:
		info_label.text = "\n".join(lines)
	if _flash_timer > 0.0:
		status_label.text = "Report copied to clipboard!"
		status_label.modulate = Color(0.4, 1.0, 0.5)
	else:
		status_label.text = "F3/F4 aim debug | F6/F7 grenade debug"
		status_label.modulate = Color(0.75, 0.85, 1.0)

func _draw() -> void:
	var center := size * 0.5
	if AimDebug.enabled:
		_draw_aim_debug(center)
	if GrenadeDebug.enabled:
		_draw_grenade_debug(center)

func _draw_aim_debug(center: Vector2) -> void:
	draw_circle(center, 6.0, Color(0.2, 1.0, 0.45, 0.35))
	draw_arc(center, 10.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.45, 0.9), 2.0, true)
	var last := AimDebug.get_last_report()
	if not last.is_empty() and last.has("screen_aim_point"):
		var aim_screen: Vector2 = last.get("screen_aim_point", center)
		if aim_screen.distance_to(center) > 4.0:
			draw_circle(aim_screen, 5.0, Color(0.3, 0.7, 1.0, 0.5))
			draw_line(center, aim_screen, Color(0.3, 0.7, 1.0, 0.35), 1.0)
	for i in range(AimDebug.get_impacts().size()):
		var report: Dictionary = AimDebug.get_impacts()[i]
		var impact: Vector2 = report.get("screen_impact", center)
		var alpha := 0.35 + 0.65 * float(i + 1) / float(AimDebug.get_impacts().size())
		var color := Color(1.0, 0.25, 0.15, alpha)
		draw_line(center, impact, Color(1.0, 0.35, 0.15, alpha * 0.45), 1.5)
		draw_arc(impact, 8.0, 0.0, TAU, 24, color, 2.0, true)
	if not last.is_empty():
		var impact := last.get("screen_impact", center) as Vector2
		var ox: int = last.get("offset_x", 0)
		var oy: int = last.get("offset_y", 0)
		draw_string(ThemeDB.fallback_font, impact + Vector2(12, -8), "A %+d,%+d" % [ox, oy], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.3))

func _draw_grenade_debug(center: Vector2) -> void:
	var last := GrenadeDebug.get_last_report()
	for i in range(GrenadeDebug.get_impacts().size()):
		var report: Dictionary = GrenadeDebug.get_impacts()[i]
		var target_screen: Vector2 = report.get("screen_target", center)
		var apex_screen: Vector2 = report.get("screen_apex", target_screen)
		var impact: Vector2 = report.get("screen_impact", center)
		var raw_screen: Vector2 = report.get("screen_raw_aim", target_screen)
		var alpha := 0.4 + 0.6 * float(i + 1) / float(GrenadeDebug.get_impacts().size())
		draw_line(center, raw_screen, Color(0.35, 0.75, 1.0, alpha * 0.4), 1.0)
		draw_line(center, target_screen, Color(0.2, 0.95, 0.85, alpha * 0.55), 1.5)
		draw_line(center, apex_screen, Color(0.95, 0.45, 1.0, alpha * 0.5), 1.5)
		_draw_diamond(raw_screen, 7.0, Color(0.35, 0.75, 1.0, alpha * 0.85))
		_draw_diamond(target_screen, 9.0, Color(0.2, 0.95, 0.85, alpha))
		_draw_apex_marker(apex_screen, 8.0, Color(0.95, 0.45, 1.0, alpha))
		draw_line(apex_screen, impact, Color(1.0, 0.55, 0.1, alpha * 0.65), 1.5)
		draw_arc(impact, 10.0, 0.0, TAU, 28, Color(1.0, 0.45, 0.05, alpha), 2.5, true)
		draw_circle(impact, 5.0, Color(1.0, 0.35, 0.05, alpha * 0.35))
	if not last.is_empty():
		var impact := last.get("screen_impact", center) as Vector2
		var apex := last.get("screen_apex", center) as Vector2
		var ox: int = last.get("offset_x", 0)
		var oy: int = last.get("offset_y", 0)
		var aox: int = last.get("apex_offset_x", 0)
		var aoy: int = last.get("apex_offset_y", 0)
		var miss_m: float = last.get("world_miss_m", 0.0)
		var apex_delta: float = last.get("apex_height_delta_m", 0.0)
		draw_string(ThemeDB.fallback_font, apex + Vector2(12, -8), "A %+d,%+d | %+.1fm" % [aox, aoy, apex_delta], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.55, 1.0))
		draw_string(ThemeDB.fallback_font, impact + Vector2(12, 14), "G %+d,%+d | %.1fm" % [ox, oy, miss_m], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.65, 0.25))

func _draw_apex_marker(pos: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(5):
		var outer_angle := -PI * 0.5 + float(i) * TAU / 5.0
		var inner_angle := outer_angle + PI / 5.0
		pts.append(pos + Vector2(cos(outer_angle), sin(outer_angle)) * radius)
		pts.append(pos + Vector2(cos(inner_angle), sin(inner_angle)) * radius * 0.45)
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color.lightened(0.15), 1.5, true)

func _draw_diamond(pos: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = [
		pos + Vector2(0, -radius),
		pos + Vector2(radius, 0),
		pos + Vector2(0, radius),
		pos + Vector2(-radius, 0),
	]
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color.lightened(0.2), 1.5)
