extends Control

const MAP_SIZE := 300
const GRID_SIZE := 200

const COL_WATER := Color(0.2, 0.4, 0.9)
const COL_CONTAINER := Color(0.8, 0.6, 0.1)
const COL_PIPE := Color(0.5, 0.5, 0.55)
const COL_PIPE_FLOWING := Color(0.2, 0.5, 1.0)
const COL_PUMP := Color(0.1, 0.7, 0.9)
const COL_PLAYER := Color.WHITE
const COL_TURRET := Color(0.9, 0.3, 0.2)
const COL_BG := Color(0.1, 0.1, 0.1, 0.85)

var _world_gen: Node = null
var _pipe_system: PipeSystem = null
var _player: CharacterBody3D = null
var _last_facing: Vector2 = Vector2(0.0, -1.0)
var _pool_centroids: Array = []

func setup(world_gen: Node, pipe_system: PipeSystem, player: CharacterBody3D) -> void:
	_world_gen = world_gen
	_pipe_system = pipe_system
	_player = player
	_compute_pool_centroids()
	_world_gen.pool_depleted.connect(_compute_pool_centroids)

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 10
	offset_top = 10
	offset_right = 10 + MAP_SIZE
	offset_bottom = 10 + MAP_SIZE
	clip_contents = true

func _compute_pool_centroids() -> void:
	_pool_centroids.clear()
	if not _world_gen:
		return
	var map_scale := float(MAP_SIZE) / float(GRID_SIZE)
	for group: Dictionary in _world_gen.pool_groups:
		var cells: Array = group["cells"]
		var sum := Vector2()
		var count := 0
		for cell: Vector2i in cells:
			if _world_gen.water_data.has(cell):
				sum += Vector2(cell.x, cell.y)
				count += 1
		if count > 0:
			var centroid := sum / float(count)
			_pool_centroids.append(Vector2(centroid.x * map_scale, centroid.y * map_scale))

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not _player or not _world_gen:
		return
	var dest_rect := Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE))
	draw_rect(dest_rect, COL_BG)
	if _pipe_system:
		_draw_pipes()
	_draw_water_pools()
	_draw_containers()
	_draw_turrets()
	_draw_player_arrow()
	draw_rect(dest_rect, Color.WHITE, false, 1.5)

func _draw_pipes() -> void:
	var map_scale := float(MAP_SIZE) / float(GRID_SIZE)
	var drawn_edges := {}
	for key in _pipe_system.pipes:
		var cell: Vector2i = key
		var node: Dictionary = _pipe_system.pipes[cell]
		var sx := cell.x * map_scale
		var sy := cell.y * map_scale
		var flowing: bool = node.get("flowing", false)
		var col := COL_PIPE_FLOWING if flowing else COL_PIPE
		var connections: Array = node.get("connections", [])
		for nb: Vector2i in connections:
			var edge_key := [min(cell.x, nb.x), min(cell.y, nb.y), max(cell.x, nb.x), max(cell.y, nb.y)]
			var ek_str := str(edge_key)
			if drawn_edges.has(ek_str):
				continue
			drawn_edges[ek_str] = true
			var nx := nb.x * map_scale
			var ny := nb.y * map_scale
			var nb_node: Dictionary = _pipe_system.pipes[nb]
			var nb_flowing: bool = nb_node.get("flowing", false)
			var line_col := COL_PIPE_FLOWING if (flowing or nb_flowing) else COL_PIPE
			draw_line(Vector2(sx, sy), Vector2(nx, ny), line_col, 1.5)
		if connections.is_empty():
			if node.get("is_pump", false):
				draw_rect(Rect2(sx - 2.0, sy - 2.0, 4.0, 4.0), COL_PUMP)
			else:
				draw_circle(Vector2(sx, sy), 1.5, col)
	_draw_pump_icons(map_scale)

func _draw_pump_icons(p_scale: float) -> void:
	for key in _pipe_system.pipes:
		var cell: Vector2i = key
		var node: Dictionary = _pipe_system.pipes[cell]
		if not node.get("is_pump", false):
			continue
		var sx := cell.x * p_scale
		var sy := cell.y * p_scale
		var s := 4.0
		var pts := PackedVector2Array([
			Vector2(sx, sy - s),
			Vector2(sx + s, sy),
			Vector2(sx, sy + s),
			Vector2(sx - s, sy),
		])
		draw_colored_polygon(pts, COL_PUMP)

func _draw_water_pools() -> void:
	for centroid: Vector2 in _pool_centroids:
		draw_circle(centroid, 5.0, COL_WATER)
		draw_circle(centroid, 5.0, Color(1, 1, 1, 0.3), false, 1.0)

func _draw_containers() -> void:
	var map_scale := float(MAP_SIZE) / float(GRID_SIZE)
	for cp: Vector2i in _world_gen.container_positions:
		var level: float = _world_gen.container_levels.get(cp, 0.0)
		var sx := cp.x * map_scale
		var sy := cp.y * map_scale
		var half_size := 2.0 + level / 100.0 * 3.0
		draw_rect(Rect2(sx - half_size, sy - half_size, half_size * 2, half_size * 2), COL_CONTAINER)
		draw_rect(Rect2(sx - half_size, sy - half_size, half_size * 2, half_size * 2), Color(1, 1, 1, 0.4), false, 1.0)

func _draw_turrets() -> void:
	if not _world_gen:
		return
	var grid_map: GridMap = _world_gen.grid_map
	var map_scale := float(MAP_SIZE) / float(GRID_SIZE)
	var turrets = get_tree().get_nodes_in_group("turrets")
	for turret in turrets:
		if not is_instance_valid(turret) or not turret is Node3D:
			continue
		var cell := grid_map.local_to_map(turret.global_position)
		var sx := cell.x * map_scale
		var sy := cell.z * map_scale
		# Draw a small crosshair icon for the turret
		var s := 4.0
		# Center dot
		draw_circle(Vector2(sx, sy), 2.0, COL_TURRET)
		# Crosshair lines
		draw_line(Vector2(sx - s, sy), Vector2(sx + s, sy), COL_TURRET, 1.5)
		draw_line(Vector2(sx, sy - s), Vector2(sx, sy + s), COL_TURRET, 1.5)
		# Outer ring
		draw_arc(Vector2(sx, sy), s + 1.0, 0, TAU, 16, COL_TURRET, 1.0)

func _draw_player_arrow() -> void:
	var vel := _player.velocity
	var flat_vel := Vector2(vel.x, vel.z)
	if flat_vel.length_squared() > 0.1:
		_last_facing = flat_vel.normalized()
	var grid_map: GridMap = _world_gen.grid_map
	var player_cell := grid_map.local_to_map(_player.global_position)
	var map_scale := float(MAP_SIZE) / float(GRID_SIZE)
	var cx := player_cell.x * map_scale
	var cy := player_cell.z * map_scale
	var angle := _last_facing.angle() + PI / 2.0
	var p_size := 7.0
	var tip := Vector2(cos(angle - PI / 2.0), sin(angle - PI / 2.0)) * p_size
	var bl := Vector2(cos(angle + PI * 5.0 / 6.0), sin(angle + PI * 5.0 / 6.0)) * p_size * 0.7
	var br := Vector2(cos(angle - PI * 5.0 / 6.0), sin(angle - PI * 5.0 / 6.0)) * p_size * 0.7
	var center := Vector2(cx, cy)
	var pts := PackedVector2Array([center + tip, center + bl, center + br])
	var cols := PackedColorArray([COL_PLAYER, COL_PLAYER, COL_PLAYER])
	draw_primitive(pts, cols, PackedVector2Array())
