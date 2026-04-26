extends Control

const MAP_SIZE := 300
const GRID_SIZE := 200

const COL_WATER := Color(0.0, 0.75, 1.0)      # Vibrant Electric Blue
const COL_CONTAINER := Color(1.0, 0.85, 0.2)  # Golden
const COL_PIPE := Color(0.4, 0.4, 0.5)
const COL_PIPE_FLOWING := Color(0.2, 0.9, 1.0)
const COL_PUMP := Color(0.0, 1.0, 0.85)
const COL_PLAYER := Color.WHITE
const COL_TURRET := Color(1.0, 0.25, 0.25)    # Vibrant Red
const COL_BG := Color(0.05, 0.06, 0.1, 0.5)   # Transparent Glass Deep Blue
const COL_GREEN := Color(0.4, 1.0, 0.4)       # Vibrant Neon Green
const COL_BORDER := Color(1.0, 1.0, 1.0, 1.0) # Thick White Border

var _world_gen: Node = null
var _pipe_system: PipeSystem = null
var _player: CharacterBody3D = null
var _last_facing: Vector2 = Vector2(0.0, -1.0)
var _pool_centroids: Array = []
var _green_spread: Node = null
var _green_image: Image = null
var _green_texture: ImageTexture = null
var _green_dirty := false
var _style_frame: StyleBoxFlat
var _time := 0.0

func setup(world_gen: Node, pipe_system: PipeSystem, player: CharacterBody3D) -> void:
	_world_gen = world_gen
	_pipe_system = pipe_system
	_player = player
	_compute_pool_centroids()
	_world_gen.pool_depleted.connect(_compute_pool_centroids)

func setup_green_spread(gs: Node) -> void:
	_green_spread = gs
	_green_image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	_green_image.fill(Color.TRANSPARENT)
	for cell in _green_spread.green_cells:
		var c: Vector2i = cell
		_green_image.set_pixel(c.x, c.y, COL_GREEN)
	_green_texture = ImageTexture.create_from_image(_green_image)
	_green_dirty = false
	_green_spread.tile_converted.connect(_on_tile_converted)

func _on_tile_converted(cell: Vector2i) -> void:
	if _green_image:
		_green_image.set_pixel(cell.x, cell.y, COL_GREEN)
		_green_dirty = true

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	# Position top-left but with a bit more margin for the thick border
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 25
	offset_top = 25
	offset_right = 25 + MAP_SIZE
	offset_bottom = 25 + MAP_SIZE
	clip_contents = false # Allow shadow to bleed out
	
	_style_frame = StyleBoxFlat.new()
	_style_frame.bg_color = COL_BG
	_style_frame.set_corner_radius_all(15)
	_style_frame.set_border_width_all(5)
	_style_frame.border_color = COL_BORDER
	_style_frame.set_shadow_size(10)
	_style_frame.shadow_color = Color(0, 0, 0, 0.4)
	_style_frame.shadow_offset = Vector2(4, 4)

func _compute_pool_centroids() -> void:
	_pool_centroids.clear()
	if not _world_gen:
		return
	var scale := float(MAP_SIZE) / float(GRID_SIZE)
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
			_pool_centroids.append(Vector2(centroid.x * scale, centroid.y * scale))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if not _player or not _world_gen:
		return
	
	var dest_rect := Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE))
	
	# 1. Draw Frame
	draw_style_box(_style_frame, dest_rect)
	
	# 2. Draw Subtle Grid
	_draw_grid()
	
	# 3. Draw Game Elements
	_draw_green_spread()
	if _pipe_system:
		_draw_pipes()
	_draw_water_pools()
	_draw_containers()
	_draw_turrets()
	_draw_player_arrow()

func _draw_grid() -> void:
	var grid_step := MAP_SIZE / 10.0
	for i in range(1, 10):
		var pos := i * grid_step
		draw_line(Vector2(pos, 0), Vector2(pos, MAP_SIZE), Color(1, 1, 1, 0.05), 1.0)
		draw_line(Vector2(0, pos), Vector2(MAP_SIZE, pos), Color(1, 1, 1, 0.05), 1.0)

func _draw_green_spread() -> void:
	if not _green_texture:
		return
	if _green_dirty:
		_green_texture.update(_green_image)
		_green_dirty = false
	draw_texture_rect(_green_texture, Rect2(Vector2.ZERO, Vector2(MAP_SIZE, MAP_SIZE)), false)

func _draw_pipes() -> void:
	var scale := float(MAP_SIZE) / float(GRID_SIZE)
	var drawn_edges := {}
	for key in _pipe_system.pipes:
		var cell: Vector2i = key
		var node: Dictionary = _pipe_system.pipes[cell]
		var sx := cell.x * scale
		var sy := cell.y * scale
		var flowing: bool = node.get("flowing", false)
		var col := COL_PIPE_FLOWING if flowing else COL_PIPE
		var connections: Array = node.get("connections", [])
		for nb: Vector2i in connections:
			var edge_key := [min(cell.x, nb.x), min(cell.y, nb.y), max(cell.x, nb.x), max(cell.y, nb.y)]
			var ek_str := str(edge_key)
			if drawn_edges.has(ek_str):
				continue
			drawn_edges[ek_str] = true
			var nx := nb.x * scale
			var ny := nb.y * scale
			var nb_node: Dictionary = _pipe_system.pipes[nb]
			var nb_flowing: bool = nb_node.get("flowing", false)
			var line_col := COL_PIPE_FLOWING if (flowing or nb_flowing) else COL_PIPE
			draw_line(Vector2(sx, sy), Vector2(nx, ny), line_col, 1.5)
		if connections.is_empty():
			if node.get("is_pump", false):
				draw_rect(Rect2(sx - 2.0, sy - 2.0, 4.0, 4.0), COL_PUMP)
			else:
				draw_circle(Vector2(sx, sy), 1.5, col)
	_draw_pump_icons(scale)

func _draw_pump_icons(scale: float) -> void:
	for key in _pipe_system.pipes:
		var cell: Vector2i = key
		var node: Dictionary = _pipe_system.pipes[cell]
		if not node.get("is_pump", false):
			continue
		var sx := cell.x * scale
		var sy := cell.y * scale
		var s := 4.0
		var pts := PackedVector2Array([
			Vector2(sx, sy - s),
			Vector2(sx + s, sy),
			Vector2(sx, sy + s),
			Vector2(sx - s, sy),
		])
		draw_colored_polygon(pts, COL_PUMP)

func _draw_water_pools() -> void:
	var pulse := (sin(_time * 3.0) * 0.5 + 0.5) * 2.0
	for centroid: Vector2 in _pool_centroids:
		# Inner glow
		draw_circle(centroid, 6.0 + pulse, Color(COL_WATER.r, COL_WATER.g, COL_WATER.b, 0.3))
		# Main circle
		draw_circle(centroid, 5.0, COL_WATER)
		# Shine
		draw_circle(centroid, 5.0, Color(1, 1, 1, 0.3), false, 1.5)

func _draw_containers() -> void:
	var scale := float(MAP_SIZE) / float(GRID_SIZE)
	for cp: Vector2i in _world_gen.container_positions:
		var level: float = _world_gen.container_levels.get(cp, 0.0)
		var sx := cp.x * scale
		var sy := cp.y * scale
		var half_size := 3.0 + level / 100.0 * 4.0
		
		# Shadow/Glow
		draw_rect(Rect2(sx - half_size - 1, sy - half_size - 1, half_size * 2 + 2, half_size * 2 + 2), Color(0, 0, 0, 0.3))
		# Body
		draw_rect(Rect2(sx - half_size, sy - half_size, half_size * 2, half_size * 2), COL_CONTAINER)
		# Shine
		draw_rect(Rect2(sx - half_size, sy - half_size, half_size * 2, half_size * 2), Color(1, 1, 1, 0.5), false, 1.5)

func _draw_turrets() -> void:
	if not _world_gen:
		return
	var grid_map: GridMap = _world_gen.grid_map
	var scale := float(MAP_SIZE) / float(GRID_SIZE)
	var turrets = get_tree().get_nodes_in_group("turrets")
	for turret in turrets:
		if not is_instance_valid(turret) or not turret is Node3D:
			continue
		var cell := grid_map.local_to_map(turret.global_position)
		var sx := cell.x * scale
		var sy := cell.z * scale
		# Draw a small crosshair icon for the turret
		var s := 4.0
		# Center dot with white outline
		draw_circle(Vector2(sx, sy), 2.5, Color.WHITE)
		draw_circle(Vector2(sx, sy), 1.8, COL_TURRET)
		# Crosshair lines with white backing
		draw_line(Vector2(sx - s, sy), Vector2(sx + s, sy), Color.WHITE, 2.5)
		draw_line(Vector2(sx, sy - s), Vector2(sx, sy + s), Color.WHITE, 2.5)
		draw_line(Vector2(sx - s, sy), Vector2(sx + s, sy), COL_TURRET, 1.5)
		draw_line(Vector2(sx, sy - s), Vector2(sx, sy + s), COL_TURRET, 1.5)
		# Outer ring
		draw_arc(Vector2(sx, sy), s + 1.0, 0, TAU, 16, Color.WHITE, 2.0)
		draw_arc(Vector2(sx, sy), s + 1.0, 0, TAU, 16, COL_TURRET, 1.0)

func _draw_player_arrow() -> void:
	var vel := _player.velocity
	var flat_vel := Vector2(vel.x, vel.z)
	if flat_vel.length_squared() > 0.1:
		_last_facing = flat_vel.normalized()
	var grid_map: GridMap = _world_gen.grid_map
	var player_cell := grid_map.local_to_map(_player.global_position)
	var scale := float(MAP_SIZE) / float(GRID_SIZE)
	var cx := player_cell.x * scale
	var cy := player_cell.z * scale
	var angle := _last_facing.angle() + PI / 2.0
	var size := 7.0
	var tip := Vector2(cos(angle - PI / 2.0), sin(angle - PI / 2.0)) * size
	var bl := Vector2(cos(angle + PI * 5.0 / 6.0), sin(angle + PI * 5.0 / 6.0)) * size * 0.7
	var br := Vector2(cos(angle - PI * 5.0 / 6.0), sin(angle - PI * 5.0 / 6.0)) * size * 0.7
	var center := Vector2(cx, cy)
	
	# Shadow
	var shadow_pts := PackedVector2Array([center + tip + Vector2(2,2), center + bl + Vector2(2,2), center + br + Vector2(2,2)])
	draw_primitive(shadow_pts, PackedColorArray([Color(0,0,0,0.4), Color(0,0,0,0.4), Color(0,0,0,0.4)]), PackedVector2Array())
	
	# Body
	var pts := PackedVector2Array([center + tip, center + bl, center + br])
	var cols := PackedColorArray([COL_PLAYER, COL_PLAYER, COL_PLAYER])
	draw_primitive(pts, cols, PackedVector2Array())
	
	# Outline
	draw_line(center + tip, center + bl, Color.BLACK, 1.0)
	draw_line(center + bl, center + br, Color.BLACK, 1.0)
	draw_line(center + br, center + tip, Color.BLACK, 1.0)
