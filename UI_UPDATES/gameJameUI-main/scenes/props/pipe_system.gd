class_name PipeSystem
extends Node3D

const BASE_FLOW_RATE := 5.0
const DEPLETION_RATE := 2.0
const MAX_CONTAINER := 100.0
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const Tile := preload("res://scenes/world/mesh_library.gd").Tile

@export var model_scale := 1
@export var model_y_offset := 0
@export var corner_position_offset := Vector3.ZERO
@export var t_split_position_offset := Vector3.ZERO

enum BuildItem { STRAIGHT, CORNER, T_SPLIT, CROSS, PUMP }

const ITEM_NAMES := ["Straight", "Corner", "T-Split", "Cross", "Pump"]

const PIPE_SCENES := [
	preload("res://models/props/pipe_straight.glb"),
	preload("res://models/props/pipe_corner.glb"),
	preload("res://models/props/pipe_split.glb"),
	preload("res://models/props/pipe_cross.glb"),
	preload("res://models/props/machine_generatorLarge.glb"),
]

const PIPE_ROTATION_OFFSETS := [-90.0, -180.0, -180.0, -180.0, -180.0]

var pipes: Dictionary = {}
var score: float = 0.0

var _world_gen: Node = null
var _grid_map: GridMap = null
var _container_meshes: Dictionary = {}
var _container_set: Dictionary = {}
var _flow_accumulator: float = 0.0
const FLOW_INTERVAL := 0.1
var _prev_container_levels: Dictionary = {}
var _mat_flowing: StandardMaterial3D
var _mat_idle: StandardMaterial3D

signal score_changed(new_score: float)
signal container_level_changed(cell: Vector2i, level: float)

static func get_base_openings(item: int) -> Array:
	match item:
		BuildItem.STRAIGHT:
			return [Vector2i(1, 0), Vector2i(-1, 0)]
		BuildItem.CORNER:
			return [Vector2i(1, 0), Vector2i(0, 1)]
		BuildItem.T_SPLIT:
			return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		BuildItem.CROSS:
			return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		BuildItem.PUMP:
			return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	return []

static func rotate_dir(d: Vector2i, times: int) -> Vector2i:
	var result := d
	for i in range(times % 4):
		result = Vector2i(-result.y, result.x)
	return result

static func get_openings(item: int, p_rotation: int) -> Array:
	var base_op := get_base_openings(item)
	var result := []
	for d in base_op:
		result.append(rotate_dir(d, p_rotation))
	return result

func setup(world_gen: Node, grid_map: GridMap) -> void:
	_world_gen = world_gen
	_grid_map = grid_map
	_mat_flowing = StandardMaterial3D.new()
	_mat_flowing.albedo_color = Color(0.2, 0.5, 1.0)
	_mat_idle = StandardMaterial3D.new()
	_mat_idle.albedo_color = Color(0.6, 0.6, 0.65)
	_create_container_meshes()
	_build_container_set()

func _build_container_set() -> void:
	_container_set.clear()
	for cp in _world_gen.container_positions:
		_container_set[cp] = true

func _create_container_meshes() -> void:
	for cp in _world_gen.container_positions:
		var mesh_inst := MeshInstance3D.new()
		var pos := _grid_map.map_to_local(Vector3i(cp.x, 0, cp.y))
		mesh_inst.position = pos + Vector3(0, 0.55, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.6, 0.1)
		mesh_inst.mesh = BoxMesh.new()
		mesh_inst.mesh.size = Vector3(0.9, 0.9, 0.9)
		mesh_inst.mesh.material = mat
		add_child(mesh_inst)
		_container_meshes[cp] = mesh_inst

func place_pipe(gx: int, gz: int, item: int, p_rotation: int) -> bool:
	return _place_internal(gx, gz, item, p_rotation, false)

func place_pump(gx: int, gz: int, p_rotation: int) -> bool:
	return _place_internal(gx, gz, BuildItem.PUMP, p_rotation, true)

func _place_internal(gx: int, gz: int, item: int, p_rotation: int, is_pump: bool) -> bool:
	if is_pump:
		if not _world_gen.is_pump_valid(gx, gz):
			return false
	else:
		if not _world_gen.is_pipe_valid(gx, gz):
			return false
	var key := Vector2i(gx, gz)
	if pipes.has(key):
		return false
	var node := _create_pipe_node(gx, gz, item, p_rotation)
	if is_pump:
		node["is_pump"] = true
	pipes[key] = node
	_update_connections(key)
	for d: Vector2i in DIRS:
		var nb: Vector2i = key + d
		if pipes.has(nb):
			_update_connections(nb)
	_refresh_visual(key)
	for d: Vector2i in DIRS:
		var nb: Vector2i = key + d
		if pipes.has(nb):
			_refresh_visual(nb)
	return true

func remove_pipe(gx: int, gz: int) -> bool:
	var key := Vector2i(gx, gz)
	if not pipes.has(key):
		return false
	var node: Dictionary = pipes[key]
	var was_pump: bool = node.get("is_pump", false)
	node["visual"].queue_free()
	var old_connections: Array = node["connections"].duplicate()
	pipes.erase(key)
	for nb_key in old_connections:
		var nbk: Vector2i = nb_key
		if pipes.has(nbk):
			_update_connections(nbk)
			_refresh_visual(nbk)
	return true

func has_pipe(gx: int, gz: int) -> bool:
	return pipes.has(Vector2i(gx, gz))

func update_pipe_rotation(gx: int, gz: int, p_new_rotation: int) -> void:
	var key := Vector2i(gx, gz)
	if not pipes.has(key):
		return
	var node: Dictionary = pipes[key]
	node["rotation"] = p_new_rotation
	_update_connections(key)
	for d: Vector2i in DIRS:
		var nb: Vector2i = key + d
		if pipes.has(nb):
			_update_connections(nb)
	_refresh_visual(key)
	for d: Vector2i in DIRS:
		var nb: Vector2i = key + d
		if pipes.has(nb):
			_refresh_visual(nb)

func _create_pipe_node(gx: int, gz: int, item: int, p_rotation: int) -> Dictionary:
	var visual := Node3D.new()
	var pos := _grid_map.map_to_local(Vector3i(gx, 0, gz))
	visual.position = pos + Vector3(0, model_y_offset, 0)
	var model: Node = PIPE_SCENES[item].instantiate()
	model.scale = Vector3.ONE * model_scale
	visual.add_child(model)
	var aabb := Utils.compute_visual_aabb(model)
	if aabb.size != Vector3.ZERO:
		model.position = Vector3(
			-(aabb.position.x + aabb.size.x * 0.5),
			-aabb.position.y,
			-(aabb.position.z + aabb.size.z * 0.5)
		)
	model.position += _get_position_offset(item)
	_set_shadow_recursive(model, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	add_child(visual)
	return {
		"visual": visual,
		"connections": [],
		"flowing": false,
		"prev_flowing": false,
		"item": item,
		"rotation": p_rotation,
		"is_pump": false,
	}

func _update_connections(key: Vector2i) -> void:
	var node: Dictionary = pipes[key]
	node["connections"].clear()
	var openings: Array = get_openings(node["item"], node["rotation"])
	for d: Vector2i in openings:
		var nb: Vector2i = key + d
		if pipes.has(nb):
			var nb_node: Dictionary = pipes[nb]
			var nb_openings: Array = get_openings(nb_node["item"], nb_node["rotation"])
			if nb_openings.has(-d):
				node["connections"].append(nb)

func _refresh_visual(key: Vector2i) -> void:
	if not pipes.has(key):
		return
	var node: Dictionary = pipes[key]
	var visual: Node3D = node["visual"]
	var p_rotation: int = node["rotation"]
	var flowing: bool = node["flowing"]
	var is_pump: bool = node.get("is_pump", false)
	visual.rotation_degrees.y = -(p_rotation * 90.0 + PIPE_ROTATION_OFFSETS[node["item"]])
	if not is_pump:
		var mat := _mat_flowing if flowing else _mat_idle
		_apply_material_recursive(visual, mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _get_position_offset(item: int) -> Vector3:
	match item:
		BuildItem.CORNER:
			return corner_position_offset
		BuildItem.T_SPLIT:
			return t_split_position_offset
	return Vector3.ZERO

func _set_shadow_recursive(node: Node, mode: int) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = mode
	for child in node.get_children():
		_set_shadow_recursive(child, mode)

func _process(delta: float) -> void:
	if not _world_gen:
		return
	_world_gen.deplete_containers(delta, DEPLETION_RATE)
	_flow_accumulator += delta
	if _flow_accumulator >= FLOW_INTERVAL:
		_simulate_flow(_flow_accumulator)
		_flow_accumulator = 0.0
	_update_container_visuals()

func _simulate_flow(delta: float) -> void:
	for key in pipes:
		pipes[key]["flowing"] = false
	var visited: Dictionary = {}
	for key in pipes:
		if visited.has(key):
			continue
		var start_key: Vector2i = key
		var network: Array = []
		var queue: Array = [start_key]
		visited[start_key] = true
		while queue.size() > 0:
			var current: Vector2i = queue.pop_front()
			network.append(current)
			var node: Dictionary = pipes[current]
			for nb in node["connections"]:
				var nbv: Vector2i = nb
				if not visited.has(nbv):
					visited[nbv] = true
					queue.append(nbv)
		var sources: Array = []
		var sinks: Array = []
		for pipe_key in network:
			var pk: Vector2i = pipe_key
			var pnode: Dictionary = pipes[pk]
			if pnode.get("is_pump", false) and _world_gen.water_data.has(pk):
				sources.append(pipe_key)
			var openings: Array = get_openings(pnode["item"], pnode["rotation"])
			for d: Vector2i in openings:
				var adj: Vector2i = pk + d
				if _container_set.has(adj) and not sinks.has(pipe_key):
					sinks.append(pipe_key)
		if sources.is_empty() or sinks.is_empty():
			continue
		var flow_rate := BASE_FLOW_RATE * float(sources.size())
		var per_source := flow_rate * delta / float(sources.size())
		for src in sources:
			var src_key: Vector2i = src
			_world_gen.deplete_pool(src_key, per_source)
		var per_sink := flow_rate * delta / float(sinks.size())
		for sink in sinks:
			var sink_key: Vector2i = sink
			var snode: Dictionary = pipes[sink_key]
			var sink_openings: Array = get_openings(snode["item"], snode["rotation"])
			for d: Vector2i in sink_openings:
				var adj: Vector2i = sink_key + d
				if _container_set.has(adj):
					var old_level: float = _world_gen.container_levels[adj]
					_world_gen.container_levels[adj] = minf(old_level + per_sink, MAX_CONTAINER)
					container_level_changed.emit(adj, _world_gen.container_levels[adj])
		score += flow_rate * delta
		score_changed.emit(score)
		for pipe_key in network:
			pipes[pipe_key]["flowing"] = true
	for pipe_key in pipes:
		var pk2: Vector2i = pipe_key
		var node: Dictionary = pipes[pk2]
		if node["flowing"] != node["prev_flowing"]:
			node["prev_flowing"] = node["flowing"]
			_refresh_visual(pk2)

func _update_container_visuals() -> void:
	for cp in _world_gen.container_positions:
		var level: float = _world_gen.container_levels.get(cp, 0.0)
		var prev: float = _prev_container_levels.get(cp, -1.0)
		if absf(level - prev) < 0.5:
			continue
		_prev_container_levels[cp] = level
		var t := level / MAX_CONTAINER
		var empty_color := Color(0.8, 0.6, 0.1)
		var full_color := Color(0.2, 0.6, 1.0)
		var color := empty_color.lerp(full_color, t)
		if _container_meshes.has(cp):
			var mesh_inst: MeshInstance3D = _container_meshes[cp]
			var mat := mesh_inst.mesh.surface_get_material(0) as StandardMaterial3D
			mat.albedo_color = color
