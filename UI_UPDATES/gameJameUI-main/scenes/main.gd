extends Node3D

func _ready() -> void:
	_setup_lighting()
	var player := $Player as CharacterBody3D
	var world_gen := $WorldGenerator
	player.global_position = world_gen.player_spawn + Vector3(0, 0.6, 0)
	var pipe_system := $PipeSystem
	pipe_system.setup(world_gen, world_gen.grid_map)
	var placement := $Player/PipePlacement
	placement.setup(pipe_system, world_gen, world_gen.grid_map)
	var hud := $HUD
	hud.setup(pipe_system, world_gen, placement, player)
	
	_spawn_enemies(player, world_gen)

func _spawn_enemies(player: CharacterBody3D, world_gen: Node) -> void:
	var enemy_scene := load("res://scenes/props/enemy.tscn") as PackedScene
	if not enemy_scene:
		return
	var spawn_points: Array = world_gen.container_positions
	var count := mini(3, spawn_points.size())
	for i in count:
		var cp: Vector2i = spawn_points[i]
		var world_pos: Vector3 = world_gen.grid_to_world(cp.x, cp.y)
		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		enemy.global_position = world_pos + Vector3(3, 0, 3)
		enemy.setup(player)

func _setup_lighting() -> void:
	var env := Environment.new()
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.8
	env.ambient_light_sky_contribution = 0.3
	$WorldEnvironment.environment = env
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.9)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)
