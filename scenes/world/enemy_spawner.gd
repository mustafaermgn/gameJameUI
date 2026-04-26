extends Node

@export var spawn_rate_scale := 2.0
@export var base_spawn_interval := 10.0
@export var min_spawn_interval := 2.0
@export var max_enemies := 20
@export var spawn_distance_from_player := 30.0

var _green_pct := 0.0
var _timer := 0.0
var _player: CharacterBody3D = null
var _world_gen: Node = null
var _enemy_scene: PackedScene = null
var _grid_map: GridMap = null

func setup(player: CharacterBody3D, world_gen: Node, grid_map: GridMap, green_spread: Node) -> void:
	_player = player
	_world_gen = world_gen
	_grid_map = grid_map
	_enemy_scene = load("res://scenes/props/enemy.tscn") as PackedScene
	green_spread.spread_progress.connect(_on_spread_progress)

func _on_spread_progress(remaining: int, total: int) -> void:
	if total > 0:
		_green_pct = clampf(1.0 - float(remaining) / float(total), 0.0, 1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not _enemy_scene:
		return
	var enemy_count := get_tree().get_nodes_in_group("enemies").size()
	if enemy_count >= max_enemies:
		return
	var interval := maxf(min_spawn_interval, base_spawn_interval / (1.0 + _green_pct * spawn_rate_scale))
	_timer += delta
	if _timer < interval:
		return
	_timer = 0.0
	_spawn_enemy()

func _spawn_enemy() -> void:
	var spawn_pos := _pick_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return
	var enemy := _enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_pos
	enemy.setup(_player)

func _pick_spawn_position() -> Vector3:
	var attempts := 10
	var half_grid: float = _world_gen.GRID_SIZE / 2.0
	for _i in range(attempts):
		var angle := randf() * TAU
		var dist := spawn_distance_from_player + randf() * 20.0
		var pos := _player.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var gx := int(round(pos.x + half_grid))
		var gz := int(round(pos.z + half_grid))
		if gx < 0 or gx >= _world_gen.GRID_SIZE or gz < 0 or gz >= _world_gen.GRID_SIZE:
			continue
		var tile := _grid_map.get_cell_item(Vector3i(gx, 0, gz))
		var Tile := preload("res://scenes/world/mesh_library.gd").Tile
		if tile == Tile.GROUND or tile == Tile.GROUND_DESERT or tile == Tile.GROUND_FOREST:
			return pos + Vector3(0, 0.6, 0)
	return _player.global_position + Vector3(spawn_distance_from_player, 0.6, 0)
