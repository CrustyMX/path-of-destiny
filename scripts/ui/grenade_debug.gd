extends Node

signal overlay_changed

var enabled: bool = false
var _throw_counter: int = 0
var _pending: Dictionary = {}
var _impacts: Array[Dictionary] = []
const MAX_IMPACTS := 10

func toggle() -> void:
	enabled = not enabled
	if not enabled:
		_pending.clear()
	print("Grenade Debug: ", "ON" if enabled else "OFF")
	overlay_changed.emit()

func register_throw(data: Dictionary) -> int:
	if not enabled:
		return -1
	_throw_counter += 1
	var entry := data.duplicate()
	entry["id"] = _throw_counter
	entry["time"] = Time.get_ticks_msec()
	_pending[_throw_counter] = entry
	return _throw_counter

func register_impact(throw_id: int, world_pos: Vector3, camera: Camera3D, arc_peak: Vector3 = Vector3.ZERO) -> void:
	if not enabled or throw_id < 0 or not is_instance_valid(camera):
		return
	var throw_data: Dictionary = _pending.get(throw_id, {})
	_pending.erase(throw_id)
	var viewport := camera.get_viewport()
	var center := viewport.get_visible_rect().size * 0.5
	var impact_screen := camera.unproject_position(world_pos)
	var target_world: Vector3 = throw_data.get("target", world_pos)
	var target_screen := camera.unproject_position(target_world)
	var raw_aim_world: Vector3 = throw_data.get("raw_aim", target_world)
	var raw_aim_screen := camera.unproject_position(raw_aim_world)
	var predicted_apex: Vector3 = throw_data.get("predicted_apex", target_world)
	var has_arc_peak := arc_peak != Vector3.ZERO
	var apex_world := arc_peak if has_arc_peak else predicted_apex
	var apex_screen := camera.unproject_position(apex_world)
	var predicted_apex_screen := camera.unproject_position(predicted_apex)
	var offset := impact_screen - center
	var target_offset := target_screen - center
	var apex_offset := apex_screen - center
	var apex_target_offset := apex_screen - target_screen
	var world_miss := world_pos - target_world
	var world_apex_miss := apex_world - target_world
	var report := {
		"id": throw_id,
		"world_impact": world_pos,
		"world_target": target_world,
		"world_raw_aim": raw_aim_world,
		"world_origin": throw_data.get("origin", Vector3.ZERO),
		"world_apex": apex_world,
		"world_predicted_apex": predicted_apex,
		"initial_velocity": throw_data.get("velocity", Vector3.ZERO),
		"screen_reticle": center,
		"screen_impact": impact_screen,
		"screen_target": target_screen,
		"screen_raw_aim": raw_aim_screen,
		"screen_apex": apex_screen,
		"screen_predicted_apex": predicted_apex_screen,
		"offset_x": int(round(offset.x)),
		"offset_y": int(round(offset.y)),
		"distance_px": offset.length(),
		"target_offset_x": int(round(target_offset.x)),
		"target_offset_y": int(round(target_offset.y)),
		"target_distance_px": target_offset.length(),
		"apex_offset_x": int(round(apex_offset.x)),
		"apex_offset_y": int(round(apex_offset.y)),
		"apex_distance_px": apex_offset.length(),
		"apex_target_offset_x": int(round(apex_target_offset.x)),
		"apex_target_offset_y": int(round(apex_target_offset.y)),
		"apex_target_distance_px": apex_target_offset.length(),
		"world_miss_x": world_miss.x,
		"world_miss_y": world_miss.y,
		"world_miss_z": world_miss.z,
		"world_miss_m": world_miss.length(),
		"world_apex_miss_x": world_apex_miss.x,
		"world_apex_miss_y": world_apex_miss.y,
		"world_apex_miss_z": world_apex_miss.z,
		"world_apex_miss_m": world_apex_miss.length(),
		"apex_height_m": apex_world.y,
		"target_height_m": target_world.y,
		"apex_height_delta_m": apex_world.y - target_world.y,
		"camera_mode": throw_data.get("camera_mode", "?"),
		"aim_pitch": throw_data.get("aim_pitch", 0.0),
		"effective_range": throw_data.get("effective_range", 0.0),
		"throw_mode": throw_data.get("throw_mode", "?"),
		"throw_speed": throw_data.get("throw_speed", 0.0),
		"horizontal_dist": throw_data.get("horizontal_dist", 0.0),
		"total_dist": throw_data.get("total_dist", 0.0),
		"target_landing_horiz": throw_data.get("target_landing_horiz", 0.0),
		"actual_landing_horiz": Vector2(world_pos.x - throw_data.get("origin", world_pos).x, world_pos.z - throw_data.get("origin", world_pos).z).length(),
		"has_actual_apex": has_arc_peak,
	}
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

func describe_apex_offset(report: Dictionary) -> String:
	return _offset_label(report.get("apex_offset_x", 0), report.get("apex_offset_y", 0))

func build_copy_text() -> String:
	if _impacts.is_empty():
		return "No grenade debug throws recorded yet. Press F6 to enable, then throw (Q)."
	var lines: PackedStringArray = ["=== Path of Destiny — Grenade Debug Report ===", ""]
	for report in _impacts:
		lines.append(_format_report(report))
		lines.append("")
	var last := _impacts[-1]
	lines.append("--- Latest throw (quick read) ---")
	lines.append(_format_report_short(last))
	lines.append("")
	lines.append("Tuning hints:")
	lines.append("  apex_offset = arc peak vs reticle (screen px)")
	lines.append("  apex_target_offset = arc peak vs resolved target (screen px)")
	lines.append("  world_apex_miss_m = arc peak vs target (3D meters)")
	lines.append("  target_landing_horiz = desired min range from pitch (diminishing returns)")
	lines.append("  world_miss_m = explosion vs resolved target (3D meters)")
	lines.append("  target_offset = resolved target vs reticle (screen px)")
	lines.append("  offset = explosion vs reticle (screen px)")
	lines.append("")
	lines.append("Describe to dev: \"apex %s (%.0fpx) | explode %s | %.2fm world miss | mode: %s\"" % [
		_offset_plain_apex(last),
		last.get("apex_distance_px", 0.0),
		_offset_plain(last),
		last.get("world_miss_m", 0.0),
		last.get("throw_mode", "?"),
	])
	return "\n".join(lines)

func _format_report(report: Dictionary) -> String:
	return """Throw #%d | %s | pitch: %.2f | mode: %s | speed: %.1f m/s
Effective aim range: %.1fm | horiz: %.2fm | total: %.2fm
Reticle apex (screen): %s
Arc peak (screen):     %s
Predicted apex (screen): %s
Explosion (screen):    %s
Arc vs reticle:        %s (%.1fpx) [%s]
Peak vs reticle apex:  %s (%.1fpx)
Peak vs target height: %s
Explosion vs reticle:  %s (%.1fpx)
World reticle apex:    %s
World arc peak:        %s
World explosion:       %s
Arc miss (X,Y,Z):      %.2f, %.2f, %.2f (%.2fm)
Arc height delta:      %.2fm (peak %.2fm vs apex %.2fm)
Target landing horiz:  %.1fm | Actual: %.1fm
Explosion miss (X,Y,Z): %.2f, %.2f, %.2f (%.2fm)
Initial velocity:      %s""" % [
		report.get("id", 0),
		report.get("camera_mode", "?"),
		report.get("aim_pitch", 0.0),
		report.get("throw_mode", "?"),
		report.get("throw_speed", 0.0),
		report.get("effective_range", 0.0),
		report.get("horizontal_dist", 0.0),
		report.get("total_dist", 0.0),
		_vec2(report.get("screen_target", Vector2.ZERO)),
		_vec2(report.get("screen_apex", Vector2.ZERO)),
		_vec2(report.get("screen_predicted_apex", Vector2.ZERO)),
		_vec2(report.get("screen_impact", Vector2.ZERO)),
		_offset_label(report.get("apex_offset_x", 0), report.get("apex_offset_y", 0)),
		report.get("apex_distance_px", 0.0),
		_screen_pass_label(report.get("apex_offset_y", 0)),
		_offset_label(report.get("apex_target_offset_x", 0), report.get("apex_target_offset_y", 0)),
		report.get("apex_target_distance_px", 0.0),
		_height_vs_target_label(report.get("apex_height_delta_m", 0.0)),
		_offset_label(report.get("offset_x", 0), report.get("offset_y", 0)),
		report.get("distance_px", 0.0),
		_vec3(report.get("world_target", Vector3.ZERO)),
		_vec3(report.get("world_apex", Vector3.ZERO)),
		_vec3(report.get("world_impact", Vector3.ZERO)),
		report.get("world_apex_miss_x", 0.0),
		report.get("world_apex_miss_y", 0.0),
		report.get("world_apex_miss_z", 0.0),
		report.get("world_apex_miss_m", 0.0),
		report.get("apex_height_delta_m", 0.0),
		report.get("apex_height_m", 0.0),
		report.get("target_height_m", 0.0),
		report.get("target_landing_horiz", 0.0),
		report.get("actual_landing_horiz", 0.0),
		report.get("world_miss_x", 0.0),
		report.get("world_miss_y", 0.0),
		report.get("world_miss_z", 0.0),
		report.get("world_miss_m", 0.0),
		_vec3(report.get("initial_velocity", Vector3.ZERO)),
	]

func _format_report_short(report: Dictionary) -> String:
	return "Throw #%d: arc peak %s of reticle by %.0fpx (%.1fm height delta) | explosion %s by %.0fpx | world miss %.2fm [%s]" % [
		report.get("id", 0),
		_offset_plain_apex(report),
		report.get("apex_distance_px", 0.0),
		report.get("apex_height_delta_m", 0.0),
		_offset_plain(report),
		report.get("distance_px", 0.0),
		report.get("world_miss_m", 0.0),
		report.get("throw_mode", "?"),
	]

func _height_vs_target_label(delta_m: float) -> String:
	if delta_m >= -0.25:
		return "AT/ABOVE target (%.2fm)" % delta_m
	return "BELOW target by %.2fm" % absf(delta_m)

func _screen_pass_label(apex_offset_y: int) -> String:
	if apex_offset_y <= -8:
		return "projects ABOVE reticle on screen"
	if apex_offset_y >= 8:
		return "projects BELOW reticle on screen"
	return "projects near reticle on screen"

func _offset_plain(report: Dictionary) -> String:
	var ox: int = report.get("offset_x", 0)
	var oy: int = report.get("offset_y", 0)
	return _offset_plain_from_xy(ox, oy)

func _offset_plain_apex(report: Dictionary) -> String:
	var ox: int = report.get("apex_offset_x", 0)
	var oy: int = report.get("apex_offset_y", 0)
	return _offset_plain_from_xy(ox, oy)

func _offset_plain_from_xy(ox: int, oy: int) -> String:
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
