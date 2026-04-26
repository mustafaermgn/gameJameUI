extends Area3D

var speed: float = 150.0
var max_range: float = 30.0
var _spawn_position: Vector3
var _has_spawn := false

# Fade-out state
var _dissolving := false
var _dissolve_duration := 0.15
var _dissolve_elapsed := 0.0
var _original_scale: Vector3
var _material: StandardMaterial3D

var target: Node3D = null
var turn_speed: float = 0.0

var lifetime: float = 1.2
var _life_elapsed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _dissolving:
		return
	if body.has_method("take_damage"):
		body.take_damage(25)
	_start_dissolve()

func _physics_process(delta: float) -> void:
	if not _has_spawn:
		_spawn_position = global_position
		_has_spawn = true
		_original_scale = scale

	if _dissolving:
		_dissolve_elapsed += delta
		var t := clampf(_dissolve_elapsed / _dissolve_duration, 0.0, 1.0)
		# Shrink down
		scale = _original_scale * lerpf(1.0, 0.0, t)
		# Fade opacity & emission
		if _material:
			_material.albedo_color.a = lerpf(1.0, 0.0, t)
			_material.emission_energy_multiplier = lerpf(10.0, 0.0, t)
		if t >= 1.0:
			queue_free()
		return

	_life_elapsed += delta
	if _life_elapsed >= lifetime:
		_start_dissolve()
		return

	if is_instance_valid(target):
		var target_pos = target.global_position
		target_pos.y += 1.0 # aim roughly at center of mass
		var current_dir = -global_transform.basis.z
		var target_dir = (target_pos - global_position).normalized()
		var new_dir = current_dir.slerp(target_dir, turn_speed * delta)
		
		var up = Vector3.UP
		if abs(new_dir.dot(up)) > 0.99:
			up = Vector3.RIGHT
		look_at(global_position + new_dir, up)

	global_transform.origin -= global_transform.basis.z * speed * delta
	if global_position.distance_to(_spawn_position) >= max_range:
		_start_dissolve()

func _start_dissolve() -> void:
	_dissolving = true
	_dissolve_elapsed = 0.0
	# Disable collision so it doesn't hit anything while fading
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	# Grab the mesh material and enable transparency
	for child in get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
				# Get or duplicate the material so we can modify it
				var mat = mesh_inst.mesh.surface_get_material(0)
				if mat is StandardMaterial3D:
					_material = mat.duplicate() as StandardMaterial3D
					_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mesh_inst.material_override = _material
			break
