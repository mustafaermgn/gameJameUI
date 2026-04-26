extends Node3D

const PLACE_RANGE := 20.0

var selected_item: int = 0
var pipe_rotation: int = 0

var _pipe_system: PipeSystem = null
var _world_gen: Node = null
var _grid_map: GridMap = null
var _radial_menu: Control = null

var _dragging: bool = false
var _drag_path: Array = []
var _last_drag_cell: Vector2i = Vector2i(-1, -1)
var _drag_axis: int = 0
var _drag_origin: Vector2i = Vector2i(-1, -1)
var _erasing: bool = false
var _last_erase_cell: Vector2i = Vector2i(-1, -1)

var _turret_scene = preload("res://scenes/props/turret_root.tscn")
var placing_market_item: Dictionary = {}

func _on_market_item_purchased(item_name: String, cost: int) -> void:
	placing_market_item = {"name": item_name, "cost": cost}
	_dragging = false
	_erasing = false

func setup(pipe_system: Node, world_gen: Node, grid_map: GridMap) -> void:
	_pipe_system = pipe_system
	_world_gen = world_gen
	_grid_map = grid_map
	_create_radial_menu()

func _create_radial_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var ctrl := Control.new()
	ctrl.set_script(preload("res://scenes/ui/radial_menu.gd"))
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ctrl)
	_radial_menu = ctrl
	_radial_menu.item_selected.connect(_on_radial_select)

func _on_radial_select(item: int) -> void:
	selected_item = item
	pipe_rotation = 0

func _process(_delta: float) -> void:
	if _erasing:
		_update_erase_drag()
		return
	if _dragging:
		_update_drag()
		return

func _start_drag(cell: Vector2i) -> void:
	if not _pipe_system.place_pipe(cell.x, cell.y, selected_item, pipe_rotation):
		return
	_dragging = true
	_drag_path = [cell]
	_last_drag_cell = cell
	_drag_origin = cell
	_drag_axis = 0

func _update_drag() -> void:
	var cell := _get_mouse_cell()
	if cell.x < 0:
		return
	if cell == _last_drag_cell:
		return
	if _drag_axis == 0:
		var dx: int = abs(cell.x - _drag_origin.x)
		var dy: int = abs(cell.y - _drag_origin.y)
		if dx > 0 or dy > 0:
			_drag_axis = 1 if dx >= dy else 2
	if _drag_axis == 1:
		cell = Vector2i(cell.x, _drag_origin.y)
	elif _drag_axis == 2:
		cell = Vector2i(_drag_origin.x, cell.y)
	if cell == _last_drag_cell:
		return
	var line := _line_cells(_last_drag_cell, cell)
	for i in range(1, line.size()):
		var c: Vector2i = line[i]
		if not _is_placement_valid(c.x, c.y):
			break
		if not _pipe_system.place_pipe(c.x, c.y, selected_item, 0):
			break
		_drag_path.append(c)
		_last_drag_cell = c
	_refresh_drag_rotations()

func _end_drag() -> void:
	_update_drag()
	if _drag_path.size() > 1:
		_refresh_drag_rotations()
	_dragging = false
	_drag_path.clear()
	_last_drag_cell = Vector2i(-1, -1)
	_drag_axis = 0
	_drag_origin = Vector2i(-1, -1)

func _refresh_drag_rotations() -> void:
	for i in range(_drag_path.size()):
		var cell: Vector2i = _drag_path[i]
		var needed_dirs := []
		if i > 0:
			var incoming: Vector2i = cell - _drag_path[i - 1]
			needed_dirs.append(-incoming)
		if i < _drag_path.size() - 1:
			var outgoing: Vector2i = _drag_path[i + 1] - cell
			needed_dirs.append(outgoing)
		if needed_dirs.is_empty():
			continue
		var best_rot := _find_best_rotation(selected_item, needed_dirs)
		_pipe_system.update_pipe_rotation(cell.x, cell.y, best_rot)

func _find_best_rotation(item: int, needed_dirs: Array) -> int:
	var best_rot := 0
	var best_score := -1
	for rot in range(4):
		var openings: Array = PipeSystem.get_openings(item, rot)
		var score := 0
		for d: Vector2i in needed_dirs:
			if openings.has(d):
				score += 1
		if score > best_score:
			best_score = score
			best_rot = rot
	return best_rot

func _line_cells(a: Vector2i, b: Vector2i) -> Array:
	var cells := [a]
	var cx: int = a.x
	var cy: int = a.y
	while cx != b.x or cy != b.y:
		var dx: int = b.x - cx
		var dy: int = b.y - cy
		if abs(dx) >= abs(dy):
			cx += sign(dx)
		else:
			cy += sign(dy)
		cells.append(Vector2i(cx, cy))
	return cells

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_radial_menu.show_at(event.position)
		else:
			_radial_menu.hide_and_select()
		get_viewport().set_input_as_handled()
		return
	if _radial_menu and _radial_menu.is_active() and event is InputEventMouseMotion:
		_radial_menu.update_hover(event.position)
		return

func _unhandled_input(event: InputEvent) -> void:
	if _radial_menu and _radial_menu.is_active():
		return
	if event.is_action_pressed("rotate_pipe") and not _dragging:
		if selected_item != PipeSystem.BuildItem.PUMP:
			pipe_rotation = (pipe_rotation + 1) % 4
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("place_pipe"):
		var cell := _get_mouse_cell()
		if cell.x >= 0:
			if not placing_market_item.is_empty():
				if _pipe_system.score >= placing_market_item["cost"]:
					_pipe_system.score -= placing_market_item["cost"]
					_pipe_system.score_changed.emit(_pipe_system.score)
					var item_name: String = placing_market_item["name"]
					if item_name == "Turret" and _turret_scene:
						var t = _turret_scene.instantiate()
						get_tree().current_scene.add_child(t)
						t.global_position = _world_gen.grid_to_world(cell.x, cell.y)
					placing_market_item.clear()
			elif selected_item == PipeSystem.BuildItem.PUMP:
				_pipe_system.place_pump(cell.x, cell.y, pipe_rotation)
			elif _is_placement_valid(cell.x, cell.y):
				_start_drag(cell)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("place_pipe") and _dragging:
		_end_drag()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("remove_pipe"):
		if not placing_market_item.is_empty():
			placing_market_item.clear()
			get_viewport().set_input_as_handled()
			return
		var cell := _get_mouse_cell()
		if cell.x >= 0:
			_pipe_system.remove_pipe(cell.x, cell.y)
			_erasing = true
			_last_erase_cell = cell
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("remove_pipe") and _erasing:
		_erasing = false
		_last_erase_cell = Vector2i(-1, -1)
		get_viewport().set_input_as_handled()
		return

func _update_erase_drag() -> void:
	var cell := _get_mouse_cell()
	if cell.x < 0 or cell == _last_erase_cell:
		return
	var line := _line_cells(_last_erase_cell, cell)
	for i in range(1, line.size()):
		var c: Vector2i = line[i]
		_pipe_system.remove_pipe(c.x, c.y)
	_last_erase_cell = cell

func _get_mouse_cell() -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector2i(-1, -1)
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	var t := -from.y / dir.y
	if t < 0:
		return Vector2i(-1, -1)
	var hit := from + dir * t
	var map_pos := _grid_map.local_to_map(hit)
	return Vector2i(map_pos.x, map_pos.z)

func _is_placement_valid(gx: int, gz: int) -> bool:
	if _pipe_system.has_pipe(gx, gz):
		return false
	if selected_item == PipeSystem.BuildItem.PUMP:
		if not _world_gen.is_pump_valid(gx, gz):
			return false
	else:
		if not _world_gen.is_pipe_valid(gx, gz):
			return false
	var player_pos := (get_parent() as Node3D).global_position
	var pipe_world: Vector3 = _world_gen.grid_to_world(gx, gz)
	var dist := Vector2(player_pos.x - pipe_world.x, player_pos.z - pipe_world.z).length()
	return dist <= PLACE_RANGE
