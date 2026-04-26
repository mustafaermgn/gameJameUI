extends NavigationRegion3D

const GRID_SIZE := 200
const HALF_GRID := GRID_SIZE / 2.0
const OBSTACLE_COUNT := 200
const WATER_POOL_COUNT := 48

const Tile := preload("res://scenes/world/mesh_library.gd").Tile

enum Biome { FOREST, DESERT }

const FOREST_TREES := [
	"res://models/world/tree.glb",
	"res://models/world/tree_blocks.glb",
	"res://models/world/tree_detailed.glb",
	"res://models/world/tree_fat.glb",
	"res://models/world/tree_cone.glb",
]

const FOREST_BUSHES := [
	"res://models/world/plant_bush.glb",
	"res://models/world/plant_bushDetailed.glb",
	"res://models/world/plant_bushLarge.glb",
	"res://models/world/plant_bushSmall.glb",
	"res://models/world/plant_bushTriangle.glb",
]

const FOREST_GRASS := [
	"res://models/world/grass.glb",
	"res://models/world/grass_large.glb",
	"res://models/world/grass_leafs.glb",
	"res://models/world/grass_leafsLarge.glb",
	"res://models/world/plant_flatShort.glb",
	"res://models/world/plant_flatTall.glb",
]

const DESERT_TREES := [
	"res://models/world/tree_palmDetailedShort.glb",
	"res://models/world/tree_palmDetailedTall.glb",
]

const DESERT_DEAD_TREES := [
	"res://models/world/tree_blocks_fall.glb",
	"res://models/world/tree_detailed_fall.glb",
	"res://models/world/tree_fat_fall.glb",
	"res://models/world/tree_oak_fall.glb",
]

const DESERT_CACTI := [
	"res://models/world/cactus_short.glb",
	"res://models/world/cactus_tall.glb",
]

const DESERT_TREE_PATHS := [
	"res://models/world/tree_palmDetailedShort.glb",
	"res://models/world/tree_palmDetailedTall.glb",
	"res://models/world/tree_blocks_fall.glb",
	"res://models/world/tree_detailed_fall.glb",
	"res://models/world/tree_fat_fall.glb",
	"res://models/world/tree_oak_fall.glb",
]

const DESERT_CACTUS_PATHS := [
	"res://models/world/cactus_short.glb",
	"res://models/world/cactus_tall.glb",
]

const FOREST_OBSTACLES := [
	"res://models/world/rock.glb",
	"res://models/world/rock_largeA.glb",
	"res://models/world/rock_largeB.glb",
	"res://models/world/stone_largeA.glb",
	"res://models/world/stone_largeB.glb",
	"res://models/world/stone_largeC.glb",
	"res://models/world/stone_largeD.glb",
	"res://models/world/stone_largeE.glb",
	"res://models/world/stone_largeF.glb",
	"res://models/world/stone_smallA.glb",
	"res://models/world/bricks.glb",
]

const DESERT_OBSTACLES := [
	"res://models/world/rock.glb",
	"res://models/world/rock_largeA.glb",
	"res://models/world/rock_largeB.glb",
	"res://models/world/rock_crystals.glb",
	"res://models/world/rock_crystalsLargeA.glb",
	"res://models/world/rock_crystalsLargeB.glb",
	"res://models/world/craterLarge.glb",
	"res://models/world/crater.glb",
	"res://models/world/stone_largeA.glb",
	"res://models/world/stone_largeB.glb",
	"res://models/world/stone_largeC.glb",
	"res://models/world/stone_largeD.glb",
	"res://models/world/stone_largeE.glb",
	"res://models/world/stone_largeF.glb",
]

var occupied := {}
var obstacle_cells := {}
var container_positions := []
var _spawn_reserved := {}
var player_spawn := Vector3.ZERO
var water_data := {}
var pool_groups := []
var water_cell_to_pool := {}
var container_levels := {}

var biome_map := {}
var _biome_noise: FastNoiseLite
var _scene_cache := {}
var _scatter_instances := {}
var _scatter_paths := {}
var _rng: RandomNumberGenerator
var desert_tile_count := 0

@export var world_seed := 0

signal pool_depleted

@onready var grid_map: GridMap = $GridMap

func _ready() -> void:
	grid_map.mesh_library = preload("res://scenes/world/mesh_library.gd").build()
	grid_map.cell_size = Vector3(1, 1, 1)
	_rng = RandomNumberGenerator.new()
	if world_seed == 0:
		_rng.seed = hash(Time.get_ticks_usec())
	else:
		_rng.seed = world_seed
	_init_biome_noise(_rng.seed)
	_generate_biome_map()
	_create_ground()
	_reserve_spawn_area()
	_generate_obstacles(_rng)
	_generate_water_pools(_rng)
	_generate_containers(_rng)
	_generate_biome_scatter(_rng)
	_ensure_connectivity()
	
	if has_method("bake_navigation_mesh"):
		bake_navigation_mesh(false)

func _init_biome_noise(seed_val: int) -> void:
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = seed_val
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.015
	_biome_noise.fractal_octaves = 3

func _generate_biome_map() -> void:
	var center_f := float(int(HALF_GRID))
	for gx in range(GRID_SIZE):
		for gz in range(GRID_SIZE):
			var noise_val := _biome_noise.get_noise_2d(float(gx), float(gz))
			var dx := float(gx) - center_f
			var dz := float(gz) - center_f
			var dist := sqrt(dx * dx + dz * dz)
			var radial := clampf(dist / (HALF_GRID * 0.5), 0.0, 1.0)
			var biome_val := radial * 0.6 + (noise_val * 0.5 + 0.5) * 0.4
			if biome_val < 0.42:
				biome_map[Vector2i(gx, gz)] = Biome.FOREST
			else:
				biome_map[Vector2i(gx, gz)] = Biome.DESERT

func _get_forest_weight(gx: int, gz: int) -> float:
	var noise_val := _biome_noise.get_noise_2d(float(gx), float(gz))
	var center_f := float(int(HALF_GRID))
	var dx := float(gx) - center_f
	var dz := float(gz) - center_f
	var dist := sqrt(dx * dx + dz * dz)
	var radial := clampf(dist / (HALF_GRID * 0.5), 0.0, 1.0)
	var biome_val := radial * 0.6 + (noise_val * 0.5 + 0.5) * 0.4
	var threshold := 0.42
	var blend := 0.08
	if biome_val < threshold - blend:
		return 1.0
	elif biome_val > threshold + blend:
		return 0.0
	return 1.0 - (biome_val - (threshold - blend)) / (blend * 2.0)

func grid_to_world(gx: float, gz: float) -> Vector3:
	return grid_map.map_to_local(Vector3i(int(gx), 0, int(gz)))

func is_occupied(gx: int, gz: int) -> bool:
	return occupied.has(Vector2i(gx, gz))

func mark_occupied(gx: int, gz: int, w: int = 1, h: int = -1) -> void:
	var hh := h if h >= 0 else w
	for dx in range(w):
		for dz in range(hh):
			occupied[Vector2i(gx + dx, gz + dz)] = true

func is_area_free(gx: int, gz: int, w: int = 1, h: int = -1) -> bool:
	var hh := h if h >= 0 else w
	for dx in range(w):
		for dz in range(hh):
			var key := Vector2i(gx + dx, gz + dz)
			if key.x < 0 or key.x >= GRID_SIZE or key.y < 0 or key.y >= GRID_SIZE:
				return false
			if occupied.has(key):
				return false
	return true

func _create_ground() -> void:
	for gx in range(GRID_SIZE):
		for gz in range(GRID_SIZE):
			var cell := Vector2i(gx, gz)
			var biome: int = biome_map.get(cell, Biome.DESERT)
			if biome == Biome.FOREST:
				grid_map.set_cell_item(Vector3i(gx, 0, gz), Tile.GROUND_FOREST)
			else:
				grid_map.set_cell_item(Vector3i(gx, 0, gz), Tile.GROUND_DESERT)
				desert_tile_count += 1

func _reserve_spawn_area() -> void:
	var center := int(HALF_GRID)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var key := Vector2i(center + dx, center + dz)
			occupied[key] = true
			_spawn_reserved[key] = true
	player_spawn = grid_to_world(center, center)

func _has_nearby_obstacle(gx: int, gz: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if obstacle_cells.has(Vector2i(gx + d.x, gz + d.y)):
			return true
	return false

func _create_blocking_body(world_pos: Vector3, half_extents: Vector3, col_offset: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = world_pos
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = half_extents * 2.0
	col_shape.shape = box
	col_shape.position = col_offset
	body.add_child(col_shape)
	add_child(body)
	return body

func _place_obstacle_instance(rng: RandomNumberGenerator, gx: int, gz: int, footprint: int) -> void:
	var cell := Vector2i(gx, gz)
	var biome: int = biome_map.get(cell, Biome.DESERT)
	var paths := FOREST_OBSTACLES if biome == Biome.FOREST else DESERT_OBSTACLES
	var path: String = paths[rng.randi_range(0, paths.size() - 1)]
	var scene: PackedScene = _get_scene(path)
	if not scene:
		return
	var inst: Node3D = scene.instantiate()
	var half_fp := float(footprint - 1) * 0.5
	var world_pos := grid_to_world(gx + half_fp, gz + half_fp)
	inst.position = Vector3.ZERO
	inst.rotate_y(rng.randf() * TAU)
	var sx := rng.randf_range(2.0, 3.5)
	var sz := rng.randf_range(2.0, 3.5)
	var sy := rng.randf_range(1.5, 2.5)
	inst.scale = Vector3(sx, sy, sz)
	var body := _create_blocking_body(world_pos, Vector3.ONE * 0.5)
	body.add_child(inst)
	var local_aabb := Utils.compute_visual_aabb(inst)
	local_aabb = inst.transform * local_aabb
	var center := local_aabb.position + local_aabb.size * 0.5
	var half := local_aabb.size * 0.5
	var max_half := float(footprint) * 0.5 - 0.05
	half.x = minf(half.x, max_half)
	half.z = minf(half.z, max_half)
	half.y = maxf(half.y, 0.7)
	var col_shape := body.get_child(0) as CollisionShape3D
	(col_shape.shape as BoxShape3D).size = half * 2.0
	col_shape.position = center
	for dx in range(footprint):
		for dz in range(footprint):
			var c := Vector2i(gx + dx, gz + dz)
			occupied[c] = true
			obstacle_cells[c] = true
			_scatter_instances[c] = body
			_scatter_paths[c] = path


func _generate_obstacles(rng: RandomNumberGenerator) -> void:
	var center := int(HALF_GRID)
	var spawn_cell := Vector2i(center, center)
	for i in range(OBSTACLE_COUNT):
		var footprint := rng.randi_range(2, 3)
		for _attempt in range(50):
			var gx := rng.randi_range(1, GRID_SIZE - footprint - 1)
			var gz := rng.randi_range(1, GRID_SIZE - footprint - 1)
			var cell := Vector2i(gx, gz)
			var dist_to_spawn := cell.distance_to(Vector2(spawn_cell))
			if dist_to_spawn < 15.0:
				continue
			var density_mult := 0.7
			if dist_to_spawn > 40.0:
				density_mult = 0.95
			if rng.randf() > density_mult:
				continue
			if is_area_free(gx, gz, footprint):
				_place_obstacle_instance(rng, gx, gz, footprint)
				break

func _generate_water_pools(rng: RandomNumberGenerator) -> void:
	for i in range(WATER_POOL_COUNT):
		var target_area := rng.randi_range(6, 36)
		for _attempt in range(50):
			var gx := rng.randi_range(1, GRID_SIZE - 2)
			var gz := rng.randi_range(1, GRID_SIZE - 2)
			if occupied.has(Vector2i(gx, gz)):
				continue
			var pool_cells := [Vector2i(gx, gz)]
			var pool_set: Dictionary = {Vector2i(gx, gz): true}
			var frontier := _get_free_neighbors(gx, gz, pool_set)
			while pool_cells.size() < target_area and not frontier.is_empty():
				var idx := rng.randi_range(0, frontier.size() - 1)
				var pick: Vector2i = frontier[idx]
				frontier.remove_at(idx)
				if pool_set.has(pick):
					continue
				if pick.x < 1 or pick.x >= GRID_SIZE - 1 or pick.y < 1 or pick.y >= GRID_SIZE - 1:
					continue
				if occupied.has(pick):
					continue
				pool_cells.append(pick)
				pool_set[pick] = true
				frontier.append_array(_get_free_neighbors(pick.x, pick.y, pool_set))
			for cell in pool_cells:
				occupied[cell] = true
				grid_map.set_cell_item(Vector3i(cell.x, 1, cell.y), Tile.WATER)
				water_data[cell] = 10.0
			var pool_idx := pool_groups.size()
			pool_groups.append({"cells": pool_cells, "total": float(pool_cells.size()) * 10.0})
			for cell in pool_cells:
				water_cell_to_pool[cell] = pool_idx
			break


func _get_free_neighbors(gx: int, gz: int, exclude: Dictionary) -> Array:
	var result := []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := Vector2i(gx + d.x, gz + d.y)
		if not exclude.has(n):
			result.append(n)
	return result

func _generate_containers(rng: RandomNumberGenerator) -> void:
	_place_container(rng, 3, 5, false)
	_place_container(rng, 85, 95, true)

func _is_near_container(gx: int, gz: int, radius: int) -> bool:
	for cp in container_positions:
		if abs(cp.x - gx) <= radius and abs(cp.y - gz) <= radius:
			return true
	return false

func _place_container(rng: RandomNumberGenerator, min_dist: int, max_dist: int, dense_obstacles: bool) -> void:
	var center := int(HALF_GRID)
	for _attempt in range(200):
		var angle := rng.randf() * TAU
		var dist := rng.randi_range(min_dist, max_dist)
		var gx := center + int(round(cos(angle) * dist))
		var gz := center + int(round(sin(angle) * dist))
		if gx < 2 or gx >= GRID_SIZE - 2 or gz < 2 or gz >= GRID_SIZE - 2:
			continue
		if not is_area_free(gx - 1, gz - 1, 3, 3):
			continue
		mark_occupied(gx, gz)
		if dense_obstacles:
			_place_dense_obstacles_around(rng, gx, gz)
		grid_map.set_cell_item(Vector3i(gx, 1, gz), Tile.CONTAINER)
		container_positions.append(Vector2i(gx, gz))
		container_levels[Vector2i(gx, gz)] = 0.0
		return

func _place_dense_obstacles_around(rng: RandomNumberGenerator, cx: int, cz: int) -> void:
	for dx in range(-5, 6):
		for dz in range(-5, 6):
			if abs(dx) <= 1 and abs(dz) <= 1:
				continue
			var gx := cx + dx
			var gz := cz + dz
			if gx < 0 or gx >= GRID_SIZE - 1 or gz < 0 or gz >= GRID_SIZE - 1:
				continue
			if is_occupied(gx, gz):
				continue
			if rng.randf() < 0.25:
				if is_area_free(gx, gz, 2):
					_place_obstacle_instance(rng, gx, gz, 2)

func _generate_biome_scatter(rng: RandomNumberGenerator) -> void:
	var center := int(HALF_GRID)
	var spawn_cell := Vector2i(center, center)
	for gx in range(GRID_SIZE):
		for gz in range(GRID_SIZE):
			var cell := Vector2i(gx, gz)
			if occupied.has(cell):
				continue
			var dist_to_spawn := cell.distance_to(Vector2(spawn_cell))
			if dist_to_spawn < 15.0:
				continue
			var fw := _get_forest_weight(gx, gz)
			var dw := 1.0 - fw
			var roll := rng.randf()
			var cumul := 0.0
			cumul += 0.06 * fw
			if roll < cumul:
				if not _has_nearby_obstacle(gx, gz):
					_place_scatter(rng, gx, gz, FOREST_TREES, true)
				continue
			cumul += 0.08 * fw
			if roll < cumul:
				_place_scatter(rng, gx, gz, FOREST_BUSHES, false)
				continue
			cumul += 0.15 * fw
			if roll < cumul:
				_place_scatter(rng, gx, gz, FOREST_GRASS, false)
				continue
			cumul += 0.01 * dw
			if roll < cumul:
				if not _has_nearby_obstacle(gx, gz):
					_place_scatter(rng, gx, gz, DESERT_TREES, true)
				continue
			cumul += 0.005 * dw
			if roll < cumul:
				if not _has_nearby_obstacle(gx, gz):
					_place_scatter(rng, gx, gz, DESERT_DEAD_TREES, true)
				continue
			cumul += 0.02 * dw
			if roll < cumul:
				if not _has_nearby_obstacle(gx, gz):
					_place_scatter(rng, gx, gz, DESERT_CACTI, true)
				continue

func _place_scatter(rng: RandomNumberGenerator, gx: int, gz: int, paths: Array, blocking: bool) -> void:
	var path: String = paths[rng.randi_range(0, paths.size() - 1)]
	var scene: PackedScene = _get_scene(path)
	if not scene:
		return
	var inst: Node3D = scene.instantiate()
	var world_pos := grid_to_world(gx, gz)
	inst.position = Vector3.ZERO
	inst.rotate_y(rng.randf() * TAU)
	var sx := rng.randf_range(1.5, 2.5)
	var sz := rng.randf_range(1.5, 2.5)
	var sy := rng.randf_range(1.2, 2.0)
	inst.scale = Vector3(sx, sy, sz)
	var cell := Vector2i(gx, gz)
	if blocking:
		var body := _create_blocking_body(world_pos, Vector3.ONE * 0.5)
		body.add_child(inst)
		var local_aabb := Utils.compute_visual_aabb(inst)
		local_aabb = inst.transform * local_aabb
		var center := local_aabb.position + local_aabb.size * 0.5
		var half := local_aabb.size * 0.5
		half.x = minf(half.x, 0.45)
		half.z = minf(half.z, 0.45)
		half.y = maxf(half.y, 0.7)
		var col_shape := body.get_child(0) as CollisionShape3D
		(col_shape.shape as BoxShape3D).size = half * 2.0
		col_shape.position = center
		_scatter_instances[cell] = body
		_scatter_paths[cell] = path
		occupied[cell] = true
		obstacle_cells[cell] = true
	else:
		inst.position = world_pos
		add_child(inst)
		_scatter_instances[cell] = inst
		_scatter_paths[cell] = path

func _get_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

func deplete_containers(delta: float, rate: float) -> void:
	for cp in container_positions:
		var key := cp as Vector2i
		container_levels[key] = maxf(container_levels[key] - rate * delta, 0.0)

func deplete_pool(cell: Vector2i, amount: float) -> void:
	if not water_cell_to_pool.has(cell):
		return
	var pool_idx: int = water_cell_to_pool[cell]
	var group: Dictionary = pool_groups[pool_idx]
	group["total"] -= amount
	if group["total"] <= 0.0:
		for c in group["cells"]:
			var pc: Vector2i = c
			water_data.erase(pc)
			occupied.erase(pc)
			water_cell_to_pool.erase(pc)
			grid_map.set_cell_item(Vector3i(pc.x, 1, pc.y), GridMap.INVALID_CELL_ITEM)
		pool_depleted.emit()

func is_pipe_valid(gx: int, gz: int) -> bool:
	if gx < 0 or gx >= GRID_SIZE or gz < 0 or gz >= GRID_SIZE:
		return false
	var key := Vector2i(gx, gz)
	if water_data.has(key):
		return false
	var ground := grid_map.get_cell_item(Vector3i(gx, 0, gz))
	return ground != Tile.WATER and ground != -1

func is_pump_valid(gx: int, gz: int) -> bool:
	if gx < 0 or gx >= GRID_SIZE or gz < 0 or gz >= GRID_SIZE:
		return false
	return water_data.has(Vector2i(gx, gz))

func _bfs_reachable(start: Vector2i) -> Dictionary:
	var reachable := {}
	var queue := [start]
	reachable[start] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while queue.size() > 0:
		var current := queue.pop_front() as Vector2i
		for d in dirs:
			var next: Vector2i = current + d
			if next.x < 0 or next.x >= GRID_SIZE or next.y < 0 or next.y >= GRID_SIZE:
				continue
			if reachable.has(next):
				continue
			if occupied.has(next) and not _spawn_reserved.has(next):
				continue
			reachable[next] = true
			queue.append(next)
	return reachable

func _find_nearest_free(start: Vector2i) -> Vector2i:
	var visited := {}
	var queue := [start]
	visited[start] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while queue.size() > 0:
		var current := queue.pop_front() as Vector2i
		if not occupied.has(current):
			return current
		for d in dirs:
			var next: Vector2i = current + d
			if next.x < 0 or next.x >= GRID_SIZE or next.y < 0 or next.y >= GRID_SIZE:
				continue
			if visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	return start

func _astar_path(start: Vector2i, goal: Vector2i) -> Array:
	var open_set := []
	var came_from := {}
	var g_score := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	var start_key := start
	g_score[start_key] = 0.0
	open_set.append({"pos": start, "f": _heuristic(start, goal)})

	while open_set.size() > 0:
		open_set.sort_custom(func(a, b): return a["f"] < b["f"])
		var current_data := open_set.pop_front() as Dictionary
		var current: Vector2i = current_data["pos"]

		if current == goal:
			return _reconstruct_path(came_from, current)

		for d in dirs:
			var next: Vector2i = current + d
			if next.x < 0 or next.x >= GRID_SIZE or next.y < 0 or next.y >= GRID_SIZE:
				continue
			var cost := 2.0 if (occupied.has(next) and not _spawn_reserved.has(next)) else 1.0
			var tentative_g: float = g_score[current] + cost
			if not g_score.has(next) or tentative_g < g_score[next]:
				g_score[next] = tentative_g
				came_from[next] = current
				var f := tentative_g + _heuristic(next, goal)
				var in_open := false
				for item in open_set:
					if item["pos"] == next:
						item["f"] = f
						in_open = true
						break
				if not in_open:
					open_set.append({"pos": next, "f": f})

	return []

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path := [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path

func _clear_cell(cell: Vector2i) -> void:
	var cell_3d := Vector3i(cell.x, 0, cell.y)
	var max_y := 10
	for y in range(1, max_y):
		if grid_map.get_cell_item(Vector3i(cell.x, y, cell.y)) != GridMap.INVALID_CELL_ITEM:
			grid_map.set_cell_item(Vector3i(cell.x, y, cell.y), GridMap.INVALID_CELL_ITEM)
		else:
			break
	obstacle_cells.erase(cell)
	occupied.erase(cell)
	_scatter_paths.erase(cell)
	if _scatter_instances.has(cell):
		var inst: Node3D = _scatter_instances[cell]
		var keys_to_remove := []
		for key in _scatter_instances:
			if _scatter_instances[key] == inst:
				keys_to_remove.append(key)
		for key in keys_to_remove:
			_scatter_instances.erase(key)
			_scatter_paths.erase(key)
			obstacle_cells.erase(key)
			occupied.erase(key)
		inst.queue_free()

func _ensure_connectivity() -> void:
	var spawn_cell := Vector2i(int(HALF_GRID), int(HALF_GRID))
	var reachable := _bfs_reachable(spawn_cell)
	for cp in container_positions:
		if _is_area_reachable(cp, reachable):
			continue
		var nearest_free := _find_nearest_free(cp)
		var path := _astar_path(spawn_cell, nearest_free)
		if path.is_empty():
			_carve_straight_line(spawn_cell, cp)
		else:
			for cell in path:
				if occupied.has(cell):
					_clear_cell(cell)
		_carve_straight_line(nearest_free, cp)
		reachable = _bfs_reachable(spawn_cell)

func _is_area_reachable(center: Vector2i, reachable: Dictionary) -> bool:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := center + Vector2i(dx, dz)
			if reachable.has(cell):
				return true
	return false

func _carve_straight_line(from: Vector2i, to: Vector2i) -> void:
	var x := from.x
	var z := from.y
	var dx := 1 if to.x > from.x else (-1 if to.x < from.x else 0)
	var dz := 1 if to.y > from.y else (-1 if to.y < from.y else 0)
	while x != to.x or z != to.y:
		if x != to.x:
			x += dx
		if z != to.y:
			z += dz
		if occupied.has(Vector2i(x, z)):
			_clear_cell(Vector2i(x, z))

func swap_desert_scatter(cell: Vector2i) -> void:
	var old_path: String = _scatter_paths.get(cell, "")
	var was_cactus := _is_cactus_path(old_path)
	if _scatter_instances.has(cell):
		var inst: Node3D = _scatter_instances[cell]
		var keys_to_remove := []
		for key in _scatter_instances:
			if _scatter_instances[key] == inst:
				keys_to_remove.append(key)
		for key in keys_to_remove:
			_scatter_instances.erase(key)
			_scatter_paths.erase(key)
		inst.queue_free()
	if not occupied.has(cell):
		_place_grass_undergrowth(cell)
		return
	if was_cactus:
		var roll := _rng.randf()
		if roll < 0.5:
			_place_scatter(_rng, cell.x, cell.y, FOREST_GRASS, false)
		else:
			_place_scatter(_rng, cell.x, cell.y, FOREST_BUSHES, false)
		_place_grass_undergrowth(cell)
		return
	var roll := _rng.randf()
	if roll < 0.06:
		if not _has_nearby_obstacle(cell.x, cell.y):
			_place_scatter(_rng, cell.x, cell.y, FOREST_TREES, true)
		else:
			_place_scatter(_rng, cell.x, cell.y, FOREST_BUSHES, false)
	elif roll < 0.14:
		_place_scatter(_rng, cell.x, cell.y, FOREST_BUSHES, false)
	elif roll < 0.20:
		_place_scatter(_rng, cell.x, cell.y, FOREST_GRASS, false)
	_place_grass_undergrowth(cell)

func _is_desert_only_path(path: String) -> bool:
	for dp in DESERT_TREE_PATHS:
		if path == dp:
			return true
	for dp in DESERT_CACTUS_PATHS:
		if path == dp:
			return true
	return false

func _is_cactus_path(path: String) -> bool:
	for dp in DESERT_CACTUS_PATHS:
		if path == dp:
			return true
	return false

func _get_all_cells_of_instance(cell: Vector2i) -> Array:
	if not _scatter_instances.has(cell):
		return [cell]
	var inst: Node3D = _scatter_instances[cell]
	var cells := []
	for key in _scatter_instances:
		if _scatter_instances[key] == inst:
			cells.append(key)
	return cells

func swap_obstacle_to_forest(cell: Vector2i) -> Array:
	var all_cells := _get_all_cells_of_instance(cell)
	var model_path: String = _scatter_paths.get(cell, "")
	var is_tree := _is_desert_only_path(model_path) and not _is_cactus_path(model_path)
	var is_cactus := _is_cactus_path(model_path)
	var needs_swap := is_tree or is_cactus
	var old_inst: Node3D = null
	if needs_swap and _scatter_instances.has(cell):
		old_inst = _scatter_instances[cell] as Node3D
	var converted_cells := []
	for c in all_cells:
		var c2: Vector2i = c
		var ground := grid_map.get_cell_item(Vector3i(c2.x, 0, c2.y))
		if ground == Tile.GROUND_FOREST:
			continue
		grid_map.set_cell_item(Vector3i(c2.x, 0, c2.y), Tile.GROUND_FOREST)
		biome_map[c2] = Biome.FOREST
		converted_cells.append(c2)
		if needs_swap:
			_scatter_instances.erase(c2)
			_scatter_paths.erase(c2)
			obstacle_cells.erase(c2)
			occupied.erase(c2)
	if needs_swap and old_inst:
		old_inst.queue_free()
	if is_tree:
		var ref_cell: Vector2i = all_cells[0]
		var min_x := ref_cell.x
		var min_z := ref_cell.y
		for c in all_cells:
			var c2: Vector2i = c
			min_x = mini(min_x, c2.x)
			min_z = mini(min_z, c2.y)
		_place_scatter(_rng, min_x, min_z, FOREST_TREES, true)
	elif is_cactus:
		var ref_cell: Vector2i = all_cells[0]
		_place_scatter(_rng, ref_cell.x, ref_cell.y, FOREST_BUSHES, false)
	if not converted_cells.is_empty():
		_place_grass_undergrowth(cell)
	return converted_cells

func _place_grass_undergrowth(center_cell: Vector2i) -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	for d in dirs:
		var nb: Vector2i = center_cell + d
		if nb.x < 0 or nb.x >= GRID_SIZE or nb.y < 0 or nb.y >= GRID_SIZE:
			continue
		if occupied.has(nb):
			continue
		if _scatter_instances.has(nb):
			continue
		if _rng.randf() < 0.12:
			var roll := _rng.randf()
			if roll < 0.5:
				_place_scatter(_rng, nb.x, nb.y, FOREST_GRASS, false)
			else:
				_place_scatter(_rng, nb.x, nb.y, FOREST_BUSHES, false)
