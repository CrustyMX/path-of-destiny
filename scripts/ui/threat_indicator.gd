extends Control

const SEGMENT_COUNT := 8
const COMPASS_SIZE := 108.0
const SCAN_INTERVAL := 0.12
const MAX_HIT_ARROWS := 8

const INNER_RANGE := 6.0
const MID_RANGE := 24.0
const MAX_RANGE := 48.0

const COLOR_PRESENCE_HOT := Color(1.0, 0.88, 0.12, 0.98)
const COLOR_PRESENCE_MID := Color(0.92, 0.78, 0.14, 0.82)
const COLOR_PRESENCE_FAINT := Color(0.72, 0.62, 0.18, 0.55)
const COLOR_HIT := Color(1.0, 0.48, 0.06, 0.98)

var _blips: Array[Dictionary] = []
var _hit_arrows: Array[Dictionary] = []
var _scan_timer: float = 0.0

func _ready() -> void:
	add_to_group("threat_indicator")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(COMPASS_SIZE, COMPASS_SIZE)
	size = custom_minimum_size
	CombatFeedback.hit_threat.connect(_on_hit_threat)
	if StatManager.has_signal("stats_rebuilt"):
		StatManager.stats_rebuilt.connect(queue_redraw)

func _on_hit_threat(world_pos: Vector3, duration: float, strength: float) -> void:
	add_hit_threat(world_pos, duration, strength)

func add_hit_threat(world_pos: Vector3, duration: float = 1.15, strength: float = 1.0) -> void:
	var bearing := _world_to_bearing(world_pos)
	if bearing < -900.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_hit_arrows.append({
		"bearing": bearing,
		"until": now + maxf(duration, 0.35),
		"strength": clampf(strength, 0.5, 1.35),
	})
	while _hit_arrows.size() > MAX_HIT_ARROWS:
		_hit_arrows.pop_front()
	queue_redraw()

func _process(delta: float) -> void:
	var show := GameManager.current_state != GameManager.GameState.DEAD
	show = show and GameManager.current_state != GameManager.GameState.PAUSED
	if visible != show:
		visible = show
	_scan_timer -= delta
	var rescanned := false
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_INTERVAL
		_scan_nearby_enemies()
		rescanned = true
	var now := Time.get_ticks_msec() / 1000.0
	var changed := rescanned
	for i in range(_hit_arrows.size() - 1, -1, -1):
		if _hit_arrows[i]["until"] <= now:
			_hit_arrows.remove_at(i)
			changed = true
	if changed or not _blips.is_empty() or not _hit_arrows.is_empty():
		queue_redraw()

func _get_radar_range() -> float:
	return StatManager.get_stat("radar_range")

func _scan_nearby_enemies() -> void:
	_blips.clear()
	var player := GameManager.player
	if not player or not is_instance_valid(player):
		return
	var origin := player.global_position
	var radar_range := _get_radar_range()
	var tree := get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if _is_enemy_dead(node):
			continue
		if node.is_in_group("boss") and "is_active" in node and not node.is_active:
			continue
		var enemy_pos := (node as Node3D).global_position + Vector3(0.0, 1.0, 0.0)
		var dist := origin.distance_to(enemy_pos)
		if dist > radar_range:
			continue
		var bearing := _world_to_bearing(enemy_pos)
		if bearing < -900.0:
			continue
		var band := _distance_band(dist)
		var intensity := _band_intensity(dist, band, radar_range)
		_blips.append({
			"bearing": bearing,
			"dist": dist,
			"band": band,
			"intensity": intensity,
		})

func _distance_band(dist: float) -> int:
	if dist <= INNER_RANGE:
		return 0
	if dist <= MID_RANGE:
		return 1
	return 2

func _band_intensity(dist: float, band: int, radar_range: float) -> float:
	match band:
		0:
			return 0.75 + (1.0 - dist / INNER_RANGE) * 0.25
		1:
			var t := (dist - INNER_RANGE) / maxf(MID_RANGE - INNER_RANGE, 0.01)
			return 0.55 + (1.0 - t) * 0.35
		_:
			var span := maxf(radar_range - MID_RANGE, 0.01)
			var t := clampf((dist - MID_RANGE) / span, 0.0, 1.0)
			return 0.28 + (1.0 - t) * 0.32

func _is_enemy_dead(enemy: Node) -> bool:
	if "is_dead" in enemy and enemy.is_dead:
		return true
	if enemy.is_in_group("boss") and enemy.get("health") != null:
		return float(enemy.health) <= 0.0
	return false

func _draw() -> void:
	var center := size * 0.5
	var outer_r := COMPASS_SIZE * 0.40
	var radar_range := _get_radar_range()
	var inner_ring_r := outer_r * 0.28
	var mid_ring_r := outer_r * 0.68
	var outer_ring_r := outer_r * 0.94
	draw_circle(center, outer_r + 4.0, Color(0.04, 0.04, 0.06, 0.78))
	draw_arc(center, outer_ring_r, 0.0, TAU, 48, Color(0.55, 0.48, 0.18, 0.45), 1.5, true)
	draw_arc(center, mid_ring_r, 0.0, TAU, 48, Color(0.45, 0.40, 0.16, 0.38), 1.2, true)
	draw_arc(center, inner_ring_r, 0.0, TAU, 48, Color(0.40, 0.36, 0.14, 0.42), 1.2, true)
	var seg_angle := TAU / float(SEGMENT_COUNT)
	for i in SEGMENT_COUNT:
		var angle := -PI * 0.5 + float(i) * seg_angle
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * inner_ring_r * 0.55, center + dir * outer_ring_r, Color(0.22, 0.20, 0.12, 0.22), 1.0)
	for blip in _blips:
		_draw_blip(center, outer_r, blip, radar_range)
	var now := Time.get_ticks_msec() / 1000.0
	var pulse := 1.0 + sin(now * 12.0) * 0.1
	for arrow in _hit_arrows:
		var remaining: float = float(arrow["until"]) - now
		var fade: float = clampf(remaining / 0.35, 0.0, 1.0)
		var strength: float = float(arrow["strength"]) * fade * pulse
		_draw_hit_arrow(center, outer_ring_r, float(arrow["bearing"]), strength)
	_draw_forward_marker(center, inner_ring_r * 0.42)

func _draw_blip(center: Vector2, outer_r: float, blip: Dictionary, radar_range: float) -> void:
	var bearing: float = blip["bearing"]
	var dist: float = blip["dist"]
	var band: int = blip["band"]
	var intensity: float = blip["intensity"]
	var dir := Vector2(cos(bearing), sin(bearing))
	var radius := _distance_to_radius(dist, outer_r, radar_range)
	var color := COLOR_PRESENCE_FAINT
	match band:
		0:
			color = COLOR_PRESENCE_HOT
		1:
			color = COLOR_PRESENCE_MID
	var fill := color
	fill.a *= intensity
	var blip_r := 4.5 if band == 0 else (3.8 if band == 1 else 3.0)
	var pos := center + dir * radius
	draw_circle(pos, blip_r + 1.5, Color(fill.r, fill.g, fill.b, fill.a * 0.35))
	draw_circle(pos, blip_r, fill)
	if band == 2:
		draw_arc(pos, blip_r + 0.5, 0.0, TAU, 12, Color(1.0, 0.92, 0.35, intensity * 0.4), 1.0, true)

func _distance_to_radius(dist: float, outer_r: float, radar_range: float) -> float:
	if dist <= INNER_RANGE:
		var t := dist / maxf(INNER_RANGE, 0.01)
		return lerpf(outer_r * 0.08, outer_r * 0.26, t)
	if dist <= MID_RANGE:
		var t := (dist - INNER_RANGE) / maxf(MID_RANGE - INNER_RANGE, 0.01)
		return lerpf(outer_r * 0.30, outer_r * 0.64, t)
	var span := maxf(radar_range - MID_RANGE, 0.01)
	var t := clampf((dist - MID_RANGE) / span, 0.0, 1.0)
	return lerpf(outer_r * 0.70, outer_r * 0.90, t)

func _draw_hit_arrow(center: Vector2, ring_r: float, bearing: float, strength: float) -> void:
	var dir := Vector2(cos(bearing), sin(bearing))
	var perp := Vector2(-dir.y, dir.x)
	var tip := center + dir * (ring_r + 2.0)
	var base := center + dir * (ring_r + 14.0 + strength * 3.0)
	var half_w := 4.5 + strength * 2.5
	var points := PackedVector2Array([
		tip,
		base + perp * half_w,
		base + dir * 3.0,
		base - perp * half_w,
	])
	var color := COLOR_HIT
	color.a = clampf(0.55 + strength * 0.45, 0.0, 1.0)
	draw_colored_polygon(points, color)
	var glow := Color(1.0, 0.62, 0.12, color.a * 0.45)
	draw_colored_polygon(PackedVector2Array([
		tip,
		base + perp * (half_w + 2.0),
		base + dir * 5.0,
		base - perp * (half_w + 2.0),
	]), glow)

func _draw_forward_marker(center: Vector2, marker_r: float) -> void:
	var tip := center + Vector2(0.0, -marker_r * 1.35)
	var left := center + Vector2(-marker_r * 0.55, marker_r * 0.35)
	var right := center + Vector2(marker_r * 0.55, marker_r * 0.35)
	var points := PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, Color(0.85, 0.78, 0.35, 0.85))
	points.append(tip)
	draw_polyline(points, Color(0.15, 0.12, 0.05, 0.9), 1.5, true)

func _world_to_bearing(world_pos: Vector3) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -999.0
	var origin := cam.global_position
	var player := GameManager.player
	if player and is_instance_valid(player):
		origin = player.global_position + Vector3(0.0, 1.0, 0.0)
	var to_threat := world_pos - origin
	to_threat.y = 0.0
	if to_threat.length_squared() < 0.01:
		return -999.0
	to_threat = to_threat.normalized()
	var cam_basis := cam.global_transform.basis
	var cam_fwd := -cam_basis.z
	cam_fwd.y = 0.0
	if cam_fwd.length_squared() < 0.0001:
		return -999.0
	cam_fwd = cam_fwd.normalized()
	var cam_right := cam_basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() < 0.0001:
		return -999.0
	cam_right = cam_right.normalized()
	var screen_x := to_threat.dot(cam_right)
	var screen_y := -to_threat.dot(cam_fwd)
	return atan2(screen_y, screen_x)
