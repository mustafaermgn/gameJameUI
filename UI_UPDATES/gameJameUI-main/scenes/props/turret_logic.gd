extends Node3D

@onready var detection_area: Area3D = $DetectionArea
@onready var muzzle: Marker3D = $Muzzle
@onready var fire_timer: Timer = $FireTimer

var BulletScene = preload("res://scenes/bullet.tscn")
var MuzzleFlashScene = preload("res://scenes/muzzle_flash.tscn")
var ExplosionScene = preload("res://scenes/turret_explosion.tscn")
var current_target: Node3D = null
var ammo: int = 120

# Burst settings
const BURST_COUNT := 2
const BURST_DELAY := 0.25  # seconds between shots in a burst
const INACCURACY_DEG := 3.0  # max spread in degrees per axis

# Predictive aim
const BULLET_SPEED := 150.0  # must match bullet_logic.gd speed
var _last_target_pos: Vector3 = Vector3.ZERO
var _target_velocity: Vector3 = Vector3.ZERO
var _velocity_sampled := false

func _ready() -> void:
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_to_group("turrets")
	_center_model()

func _center_model() -> void:
	var model = $Model
	if not model: return
	model.scale = Vector3(2.0, 2.0, 2.0)
	var total_aabb := Utils.collect_aabb(model, model.transform)
	if total_aabb.size != Vector3.ZERO:
		var center := total_aabb.get_center()
		model.position = Vector3(-center.x, -total_aabb.position.y, -center.z)

func _process(delta: float) -> void:
	_update_target()
	if current_target:
		# Track target velocity for intercept prediction
		if _velocity_sampled:
			_target_velocity = (current_target.global_position - _last_target_pos) / delta
		_last_target_pos = current_target.global_position
		_velocity_sampled = true
		
		# Aim at predicted intercept point
		var predicted = _predict_intercept(current_target.global_position, _target_velocity)
		var aim_pos = predicted
		aim_pos.y = global_position.y  # keep turret rotation on Y axis only
		if global_position.distance_to(aim_pos) > 0.1:
			var new_transform = transform.looking_at(aim_pos, Vector3.UP)
			transform = transform.interpolate_with(new_transform, 5.0 * delta)
	else:
		_velocity_sampled = false

func _predict_intercept(target_pos: Vector3, target_vel: Vector3) -> Vector3:
	# Iterative intercept: estimate time-of-flight, then refine the predicted point
	var to_target := target_pos - muzzle.global_position
	var dist := to_target.length()
	if dist < 0.001:
		return target_pos
	# Initial time estimate based on current distance
	var t := dist / BULLET_SPEED
	# Two refinement passes
	for _i in range(2):
		var future_pos := target_pos + target_vel * t
		t = (future_pos - muzzle.global_position).length() / BULLET_SPEED
	# Clamp lookahead so we don't wildly over-predict at long range
	t = clampf(t, 0.0, 1.5)
	return target_pos + target_vel * t

func _update_target() -> void:
	if is_instance_valid(current_target) and detection_area.overlaps_body(current_target):
		return
	
	current_target = null
	_velocity_sampled = false
	var bodies = detection_area.get_overlapping_bodies()
	if bodies.size() > 0:
		current_target = bodies[0]

func _on_fire_timer_timeout() -> void:
	if is_instance_valid(current_target):
		_fire_burst()

func _fire_burst() -> void:
	# Fire first shot immediately
	_fire_single()
	if ammo <= 0:
		return
	# Fire remaining burst shots with delays
	for i in range(1, BURST_COUNT):
		var delay_timer = get_tree().create_timer(BURST_DELAY * i)
		delay_timer.timeout.connect(_fire_single)

func _fire_single() -> void:
	if ammo <= 0:
		return
	ammo -= 1
	
	var flash = MuzzleFlashScene.instantiate()
	get_parent().add_child(flash)
	flash.global_position = muzzle.global_position
	
	var bullet = BulletScene.instantiate()
	get_parent().add_child(bullet)
	
	# Aim the bullet at the predicted intercept point
	if is_instance_valid(current_target):
		var predicted := _predict_intercept(current_target.global_position, _target_velocity)
		predicted.y += 1.0  # aim at center of mass
		var aim_dir := (predicted - muzzle.global_position)
		if aim_dir.length_squared() > 0.001:
			var up := Vector3.UP
			if abs(aim_dir.normalized().dot(up)) > 0.99:
				up = Vector3.RIGHT
			bullet.global_transform = muzzle.global_transform
			bullet.look_at(muzzle.global_position + aim_dir, up)
			bullet.global_transform.origin = muzzle.global_position
		else:
			bullet.global_transform = muzzle.global_transform
		# No homing — we predicted the position, fly straight
		bullet.turn_speed = 0.0
	else:
		bullet.global_transform = muzzle.global_transform
	
	# Apply random spread for inaccuracy
	var spread_x := deg_to_rad(randf_range(-INACCURACY_DEG, INACCURACY_DEG))
	bullet.rotate(bullet.global_transform.basis.x, spread_x)
	
	if ammo <= 0:
		_destroy_turret()

func _destroy_turret() -> void:
	# Stop firing
	fire_timer.stop()
	# Spawn explosion at turret center
	var explosion = ExplosionScene.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = global_position + Vector3(0, 1.0, 0)
	# Small delay so the last shot and explosion are visible
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)
