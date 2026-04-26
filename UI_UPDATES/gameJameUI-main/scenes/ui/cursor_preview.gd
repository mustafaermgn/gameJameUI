extends Control

var _placement: Node = null
var _radial_menu: Control = null

const BG_RADIUS := 18.0
const ARM_LEN := 13.0
const ARM_W := 5.0
const CENTER_SIZE := 6.0
const OFFSET_X := 24.0
const OFFSET_Y := 24.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(placement: Node, radial_menu: Control) -> void:
	_placement = placement
	_radial_menu = radial_menu

func _process(_delta: float) -> void:
	if not _placement:
		return
	queue_redraw()

func _draw() -> void:
	if not _placement:
		return
	if _radial_menu and _radial_menu.is_active():
		return
	if _placement._dragging or _placement._erasing:
		return
	var mouse := get_viewport().get_mouse_position()
	var cx := mouse.x + OFFSET_X
	var cy := mouse.y + OFFSET_Y
	var vp_size := get_viewport().get_visible_rect().size
	if cx + BG_RADIUS + 4 > vp_size.x:
		cx = mouse.x - OFFSET_X - BG_RADIUS
	if cy + BG_RADIUS + 4 > vp_size.y:
		cy = mouse.y - OFFSET_Y - BG_RADIUS
		
	if not _placement.placing_market_item.is_empty():
		draw_circle(Vector2(cx, cy), BG_RADIUS, Color(0.2, 0.8, 0.2, 0.5))
		var font := ThemeDB.fallback_font
		var label: String = _placement.placing_market_item["name"]
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(cx - tw * 0.5, cy - BG_RADIUS - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))
		return
		
	var item: int = _placement.selected_item
	var rot: int = _placement.pipe_rotation
	var is_omni := item == PipeSystem.BuildItem.PUMP or item == PipeSystem.BuildItem.CROSS
	var omni_color := Color(0.25, 0.65, 0.85) if item == PipeSystem.BuildItem.PUMP else Color(0.8, 0.35, 0.35)
	var openings: Array = PipeSystem.get_openings(item, rot) if not is_omni else [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	draw_circle(Vector2(cx, cy), BG_RADIUS, Color(0, 0, 0, 0.45))
	var hs := CENTER_SIZE * 0.5
	var center_color := omni_color if is_omni else Color(0.65, 0.65, 0.7)
	draw_rect(Rect2(cx - hs, cy - hs, CENTER_SIZE, CENTER_SIZE), center_color)
	for d: Vector2i in openings:
		var is_h: bool = abs(d.x) > 0
		var color := omni_color if is_omni else Color(0.5, 0.5, 0.55)
		if is_h:
			var sx := cx + signf(float(d.x)) * hs
			var rect := Rect2(
				sx if d.x > 0 else sx - ARM_LEN,
				cy - ARM_W * 0.5,
				ARM_LEN,
				ARM_W
			)
			draw_rect(rect, color)
		else:
			var sy := cy + signf(float(d.y)) * hs
			var rect := Rect2(
				cx - ARM_W * 0.5,
				sy if d.y > 0 else sy - ARM_LEN,
				ARM_W,
				ARM_LEN
			)
			draw_rect(rect, color)
	if not is_omni:
		var font := ThemeDB.fallback_font
		var font_size := 10
		var rot_label := "R" + str(rot)
		var tw := font.get_string_size(rot_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(cx - tw * 0.5, cy - BG_RADIUS - 2), rot_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.8))
