extends Control

signal item_selected(item: int)

const RADIUS := 80.0
const INNER_RADIUS := 25.0
const SEGMENTS := 5
const LABELS := ["Straight", "Corner", "T-Split", "Cross", "Pump"]
const COLORS := [
	Color(0.35, 0.75, 0.35),
	Color(0.35, 0.45, 0.8),
	Color(0.8, 0.75, 0.3),
	Color(0.8, 0.35, 0.35),
	Color(0.25, 0.65, 0.85),
]

var _center := Vector2.ZERO
var _hovered := -1
var _active := false

func _ready() -> void:
	visible = false
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_at(pos: Vector2) -> void:
	_center = pos
	_active = true
	visible = true
	_hovered = -1
	queue_redraw()

func hide_and_select() -> void:
	var selected := _hovered
	_active = false
	visible = false
	if selected >= 0:
		item_selected.emit(selected)

func is_active() -> bool:
	return _active

func update_hover(pos: Vector2) -> void:
	if not _active:
		return
	var rel := pos - _center
	var dist := rel.length()
	if dist < INNER_RADIUS or dist > RADIUS:
		if _hovered != -1:
			_hovered = -1
			queue_redraw()
		return
	var angle := fposmod(atan2(rel.y, rel.x) + PI / 2.0, TAU)
	var seg := int(angle / (TAU / SEGMENTS)) % SEGMENTS
	if seg != _hovered:
		_hovered = seg
		queue_redraw()

func _draw() -> void:
	if not _active:
		return
	var seg_angle := TAU / SEGMENTS
	for i in SEGMENTS:
		var start_a := i * seg_angle - PI / 2.0 - seg_angle / 2.0
		var end_a := start_a + seg_angle
		var color: Color = COLORS[i]
		if i == _hovered:
			color = color.lightened(0.3)
		else:
			color.a = 0.7
		var points := PackedVector2Array()
		var steps := 20
		for j in range(steps + 1):
			var a := start_a + (end_a - start_a) * float(j) / float(steps)
			points.append(_center + Vector2(cos(a), sin(a)) * RADIUS)
		for j in range(steps, -1, -1):
			var a := start_a + (end_a - start_a) * float(j) / float(steps)
			points.append(_center + Vector2(cos(a), sin(a)) * INNER_RADIUS)
		draw_colored_polygon(points, color)
		var mid_a := (start_a + end_a) / 2.0
		var label_r := (INNER_RADIUS + RADIUS) / 2.0
		var lp := _center + Vector2(cos(mid_a), sin(mid_a)) * label_r
		var font := ThemeDB.fallback_font
		var font_size := 13
		var text: String = LABELS[i]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		draw_string(font, lp - Vector2(tw / 2.0, -font_size / 3.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
