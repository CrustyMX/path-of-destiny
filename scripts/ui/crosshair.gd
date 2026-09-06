extends Control

@export var crosshair_color := Color(1, 0.95, 0.9, 0.95)
@export var scope_color := Color(1, 0.95, 0.9, 0.85)
@export var hit_color := Color(1, 0.35, 0.15, 1.0)
@export var line_length := 10.0
@export var gap := 7.0
@export var thickness := 2.0
@export var dot_radius := 1.0

var is_scoped: bool = false
var is_melee_mode: bool = false
var _hit_timer: float = 0.0
var _shot_timer: float = 0.0
var _shot_color: Color = Color(1.0, 0.92, 0.75, 0.85)
var _hit_tween: Tween = null

func _ready() -> void:
	add_to_group("crosshair")

func set_scoped(scoped: bool) -> void:
	if is_scoped == scoped:
		return
	is_scoped = scoped
	queue_redraw()

func set_melee_mode(melee: bool) -> void:
	if is_melee_mode == melee:
		return
	is_melee_mode = melee
	queue_redraw()

func show_hit_confirm() -> void:
	_hit_timer = 0.14
	queue_redraw()
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_method(_set_hit_timer, 0.14, 0.0, 0.14)
	_hit_tween.tween_callback(queue_redraw)

func show_shot_pulse(color: Color = crosshair_color) -> void:
	_shot_timer = 0.045
	_shot_color = Color(color.r, color.g, color.b, 0.9)
	queue_redraw()

func _set_hit_timer(value: float) -> void:
	_hit_timer = value
	queue_redraw()

func _process(delta: float) -> void:
	var dirty := false
	if _hit_timer > 0.0 and not _hit_tween:
		_hit_timer = maxf(0.0, _hit_timer - delta)
		dirty = true
	if _shot_timer > 0.0:
		_shot_timer = maxf(0.0, _shot_timer - delta)
		dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	if is_scoped:
		_draw_scope()
	else:
		_draw_crosshair()
	if _shot_timer > 0.0:
		_draw_shot_pulse()
	if _hit_timer > 0.0:
		_draw_hit_marker()

func _crosshair_center() -> Vector2:
	return size * 0.5

func _draw_crosshair() -> void:
	var center := _crosshair_center()
	var color := crosshair_color
	if is_melee_mode:
		draw_circle(center, 3.0, color)
		return
	var half_t := thickness * 0.5
	draw_rect(Rect2(center.x - half_t, center.y - gap - line_length, thickness, line_length), color)
	draw_rect(Rect2(center.x - half_t, center.y + gap, thickness, line_length), color)
	draw_rect(Rect2(center.x - gap - line_length, center.y - half_t, line_length, thickness), color)
	draw_rect(Rect2(center.x + gap, center.y - half_t, line_length, thickness), color)
	draw_circle(center, dot_radius, color)

func _draw_shot_pulse() -> void:
	var center := _crosshair_center()
	var alpha := clampf(_shot_timer / 0.045, 0.0, 1.0)
	var col := Color(_shot_color.r, _shot_color.g, _shot_color.b, _shot_color.a * alpha)
	var extend := lerpf(4.0, 16.0, alpha)
	var half_t := 1.5
	draw_rect(Rect2(center.x - half_t, center.y - gap - extend, half_t * 2.0, extend), col)
	draw_rect(Rect2(center.x - half_t, center.y + gap, half_t * 2.0, extend), col)
	draw_rect(Rect2(center.x - gap - extend, center.y - half_t, extend, half_t * 2.0), col)
	draw_rect(Rect2(center.x + gap, center.y - half_t, extend, half_t * 2.0), col)
	draw_circle(center, dot_radius + 1.5 * alpha, col)

func _draw_scope() -> void:
	var center := _crosshair_center()
	var radius := 14.0
	draw_arc(center, radius, 0.0, TAU, 48, scope_color, 1.5, true)
	draw_circle(center, 1.2, scope_color)
	var tick := 5.0
	draw_line(center + Vector2(-tick, 0), center + Vector2(tick, 0), scope_color, 1.0)
	draw_line(center + Vector2(0, -tick), center + Vector2(0, tick), scope_color, 1.0)

func _draw_hit_marker() -> void:
	var center := _crosshair_center()
	var alpha := clampf(_hit_timer / 0.14, 0.0, 1.0)
	var color := Color(hit_color.r, hit_color.g, hit_color.b, alpha)
	var arm := 5.0 + (1.0 - alpha) * 3.0
	var inset := 4.0
	draw_line(center + Vector2(inset, inset), center + Vector2(inset + arm, inset + arm), color, 2.0)
	draw_line(center + Vector2(-inset, inset), center + Vector2(-inset - arm, inset + arm), color, 2.0)
	draw_line(center + Vector2(inset, -inset), center + Vector2(inset + arm, -inset - arm), color, 2.0)
	draw_line(center + Vector2(-inset, -inset), center + Vector2(-inset - arm, -inset - arm), color, 2.0)
