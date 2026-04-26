extends Node

const SPREAD_THRESHOLD := 30.0
const CADENCE := 0.1
const MAX_PER_TICK := 5
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const Tile := preload("res://scenes/world/mesh_library.gd").Tile

signal game_won
signal tile_converted(cell: Vector2i)
signal spread_progress(remaining: int, total: int)

var green_cells := {}
var container_frontiers := {}
var desert_remaining := 0
var total_desert := 0
var _accumulator := 0.0
var _world_gen: Node = null
var _grid_map: GridMap = null
var _game_won_emitted := false

func setup(world_gen: Node, grid_map: GridMap) -> void:
	_world_gen = world_gen
	_grid_map = grid_map
	_init_frontiers()
	_count_desert()

func _init_frontiers() -> void:
	for cp in _world_gen.container_positions:
		var cell: Vector2i = cp
		green_cells[cell] = true
		container_frontiers[cell] = []
		for d in DIRS:
			var nb: Vector2i = cell + d
			if not green_cells.has(nb) and _is_valid_spread_target(nb):
				container_frontiers[cell].append(nb)
				green_cells[nb] = true

func _count_desert() -> void:
	desert_remaining = 0
	for gx in range(_world_gen.GRID_SIZE):
		for gz in range(_world_gen.GRID_SIZE):
			var tile := _grid_map.get_cell_item(Vector3i(gx, 0, gz))
			if tile == Tile.GROUND_DESERT:
				desert_remaining += 1
	total_desert = desert_remaining

func _is_valid_spread_target(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= _world_gen.GRID_SIZE or cell.y < 0 or cell.y >= _world_gen.GRID_SIZE:
		return false
	if _world_gen.container_positions.has(cell):
		return false
	return true

func tick(delta: float, container_levels: Dictionary) -> void:
	if _game_won_emitted:
		return
	_accumulator += delta
	if _accumulator < CADENCE:
		return
	_accumulator = 0.0
	var spread_count := 0
	for cp in _world_gen.container_positions:
		var level: float = container_levels.get(cp, 0.0)
		if level < SPREAD_THRESHOLD:
			continue
		var budget := mini(int(level / 20.0), MAX_PER_TICK)
		var converted := 0
		var my_frontier: Array = container_frontiers[cp]
		while converted < budget and not my_frontier.is_empty():
			var cell: Vector2i = my_frontier.pop_front()
			var ground_tile := _grid_map.get_cell_item(Vector3i(cell.x, 0, cell.y))
			if ground_tile == Tile.GROUND_FOREST:
				_enqueue_neighbors_for(cell, cp)
				continue
			if _world_gen.obstacle_cells.has(cell):
				var all_cells: Array = _world_gen.swap_obstacle_to_forest(cell)
				if all_cells.is_empty():
					_enqueue_neighbors_for(cell, cp)
					continue
				for c in all_cells:
					green_cells[c] = true
					desert_remaining -= 1
					tile_converted.emit(c)
					_enqueue_neighbors_for(c, cp)
				converted += 1
				spread_count += 1
				continue
			if _world_gen.water_data.has(cell):
				_grid_map.set_cell_item(Vector3i(cell.x, 0, cell.y), Tile.GROUND_FOREST)
				_world_gen.biome_map[cell] = _world_gen.Biome.FOREST
				converted += 1
				spread_count += 1
			else:
				var tile := _grid_map.get_cell_item(Vector3i(cell.x, 0, cell.y))
				if tile == Tile.GROUND_DESERT:
					_convert_ground(cell)
					_world_gen.swap_desert_scatter(cell)
					converted += 1
					spread_count += 1
			_enqueue_neighbors_for(cell, cp)
			tile_converted.emit(cell)
	if spread_count > 0:
		spread_progress.emit(desert_remaining, total_desert)
	if desert_remaining <= 0 and not _game_won_emitted:
		_game_won_emitted = true
		game_won.emit()

func _convert_ground(cell: Vector2i) -> void:
	_grid_map.set_cell_item(Vector3i(cell.x, 0, cell.y), Tile.GROUND_FOREST)
	_world_gen.biome_map[cell] = _world_gen.Biome.FOREST
	desert_remaining -= 1

func _enqueue_neighbors_for(cell: Vector2i, cp: Vector2i) -> void:
	for d in DIRS:
		var nb: Vector2i = cell + d
		if not green_cells.has(nb) and _is_valid_spread_target(nb):
			green_cells[nb] = true
			container_frontiers[cp].append(nb)
