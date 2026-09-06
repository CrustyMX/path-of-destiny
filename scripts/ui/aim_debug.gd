extends Node

signal overlay_changed

var enabled: bool = false
var _shot_counter: int = 0
var _pending_shots: Dictionary = {}
var _impacts: Array[Dictionary] = []
const MAX_IMPACTS := 12

func toggle() -> void:
	enabled = not enabled
	if not enabled:
		_pending_shots.clear()
	print("Aim Debug: ", "ON" if enabled else "OFF")
	overlay_changed.emit()

func register_shot(data: Dictionary) -> int:
	if not enabled:
		return -1
	_shot_counter += 1
	var entry := data.duplicate()
	entry["id"] = _shot_counter
	entry["time"] = Time.get_ticks_msec()
	_pending_shots[_shot_counter] = entry
	return _shot_counter

func patch_shot(shot_id: int, data: Dictionary) -> void:
	if shot_id < 0 or not _pending_shots.has(shot_id):
		return
	for key in data:
		_pending_shots[shot_id][key] = data[key]

func register_impact(shot_id: int, world_pos: Vector3, camera: Camera3D) -> void:
	if not enabled or shot_id < 0:
		return
	var shot: Dictionary = _pending_shots.get(shot_id, {})
	_pending_shots.erase(shot_id)
	var viewport := camera.get_viewport()
	var center := viewport.get_visible_rect().size * 0.5
	var impact_screen: Vector2 = camera.unproject_position(world_pos)
	var aim_screen: Vector2 = center
	if shot.has("aim_point"):
		var projected := camera.unproject_position(shot["aim_point"])
		if projected.x > -100000:
			aim_screen = projected
	var offset := impact_screen - center
	var aim_offset := impact_screen - aim_screen
	var report := {
		"id": shot_id,
		"world_impact": world_pos,
		"screen_impact": impact_screen,
		"screen_reticle": center,
		"screen_aim_point": aim_screen,
		"offset_px": offset,
		"offset_x": int(round(offset.x)),
		"offset_y": int(round(offset.y)),
		"distance_px": offset.length(),
		"spread_offset_x": int(round(aim_offset.x)),
		"spread_offset_y": int(round(aim_offset.y)),
		"spread_distance_px": aim_offset.length(),
		"camera_mode": shot.get("camera_mode", "?"),
		"ads": shot.get("ads", false),
		"spread_deg": shot.get("spread_deg", 0.0),
		"fire_dir": shot.get("fire_dir", Vector3.ZERO),
		"muzzle_screen": shot.get("muzzle_screen", Vector2.ZERO),
		"origin_screen": shot.get("origin_screen", center),
		"aim_point": shot.get("aim_point", Vector3.ZERO),
		"origin": shot.get("origin", Vector3.ZERO),
	}
	if shot.get("projectile_type", "") == "arc_explosive":
		report["lob_target"] = shot.get("lob_target", Vector3.ZERO)
		report["launch_velocity"] = shot.get("launch_velocity", Vector3.ZERO)
		report["aim_dir"] = shot.get("aim_dir", Vector3.ZERO)
	_impacts.append(report)
	while _impacts.size() > MAX_IMPACTS:
		_impacts.pop_front()
	overlay_changed.emit()

func get_impacts() -> Array[Dictionary]:
	return _impacts

func get_last_report() -> Dictionary:
	if _impacts.is_empty():
		return {}
	return _impacts[-1]

func describe_offset(report: Dictionary) -> String:
	return _offset_label(report.get("offset_x", 0), report.get("offset_y", 0))

func build_copy_text() -> String:
	if _impacts.is_empty():
		return "No aim debug shots recorded yet. Press F3 to enable, then fire."
	var lines: PackedStringArray = ["=== Path of Destiny — Aim Debug Report ===", ""]
	for report in _impacts:
		lines.append(_format_report(report))
		lines.append("")
	var last := _impacts[-1]
	lines.append("--- Latest shot (quick read) ---")
	lines.append(_format_report_short(last))
	lines.append("")
	lines.append("Describe offset to dev: \"%s\"" % _offset_plain(last))
	return "\n".join(lines)

func _format_report(report: Dictionary) -> String:
	var ox: int = report.get("offset_x", 0)
	var oy: int = report.get("offset_y", 0)
	var sx: int = report.get("spread_offset_x", 0)
	var sy: int = report.get("spread_offset_y", 0)
	var text := """Shot #%d | %s | ADS: %s | Spread: %.2f°
Reticle (screen center): %s
Aim point (screen):      %s
Impact (screen):         %s
Reticle offset:          %s  (%.1fpx)
Spread-only offset:      %s  (%.1fpx)
World aim point:         %s
World impact:            %s
Fire direction:          %s
Gameplay origin (screen): %s
Muzzle (screen):         %s""" % [
		report.get("id", 0),
		report.get("camera_mode", "?"),
		"Yes" if report.get("ads", false) else "No",
		report.get("spread_deg", 0.0),
		_vec2(report.get("screen_reticle", Vector2.ZERO)),
		_vec2(report.get("screen_aim_point", Vector2.ZERO)),
		_vec2(report.get("screen_impact", Vector2.ZERO)),
		_offset_label(ox, oy),
		report.get("distance_px", 0.0),
		_offset_label(sx, sy),
		report.get("spread_distance_px", 0.0),
		_vec3(report.get("aim_point", Vector3.ZERO)),
		_vec3(report.get("world_impact", Vector3.ZERO)),
		_vec3(report.get("fire_dir", Vector3.ZERO)),
		_vec2(report.get("origin_screen", Vector2.ZERO)),
		_vec2(report.get("muzzle_screen", Vector2.ZERO)),
	]
	if report.has("launch_velocity"):
		text += "\nLaunch velocity:       %s" % _vec3(report.get("launch_velocity", Vector3.ZERO))
		text += "\nLob aim dir:           %s" % _vec3(report.get("aim_dir", Vector3.ZERO))
	return text

func _format_report_short(report: Dictionary) -> String:
	return "Shot #%d: impact is %s of reticle by %dpx (%.0fpx total)" % [
		report.get("id", 0),
		_offset_plain(report),
		int(report.get("distance_px", 0.0)),
		report.get("distance_px", 0.0),
	]

func _offset_plain(report: Dictionary) -> String:
	var ox: int = report.get("offset_x", 0)
	var oy: int = report.get("offset_y", 0)
	var h := ""
	if absi(ox) >= 8:
		h = "RIGHT" if ox > 0 else "LEFT"
	var v := ""
	if absi(oy) >= 8:
		v = "BELOW" if oy > 0 else "ABOVE"
	if h.is_empty() and v.is_empty():
		return "ON TARGET (within 8px)"
	if h.is_empty():
		return v
	if v.is_empty():
		return h
	return "%s and %s" % [v, h]

func _offset_label(ox: int, oy: int) -> String:
	var parts: PackedStringArray = []
	if absi(ox) >= 1:
		parts.append("%s %dpx" % ["RIGHT" if ox > 0 else "LEFT", absi(ox)])
	if absi(oy) >= 1:
		parts.append("%s %dpx" % ["DOWN" if oy > 0 else "UP", absi(oy)])
	if parts.is_empty():
		return "ON TARGET"
	return ", ".join(parts)

func _vec2(v: Vector2) -> String:
	return "(%d, %d)" % [int(round(v.x)), int(round(v.y))]

func _vec3(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
