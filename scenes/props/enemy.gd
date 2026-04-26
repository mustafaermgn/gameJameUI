extends CharacterBody3D

signal died

const DETECTION_RADIUS := 1000.0
const ATTACK_RADIUS := 2.0
const PATROL_RADIUS := 12.0
const PATROL_SPEED := 3.0
const CHASE_SPEED := 4.0
const ATTACK_DAMAGE := 10
const ATTACK_COOLDOWN := 1.0
const MAX_HEALTH := 100
const MODEL_HEIGHT := 1.2

@onready var model: Node3D = $Model
@onready var detection_area: Area3D = $DetectionArea

var health: int = MAX_HEALTH
var _player: CharacterBody3D = null
var _state := "patrol"
var _patrol_target := Vector3.ZERO
var _attack_timer := 0.0

# Hit-stun slow
const HIT_SLOW_MULTIPLIER := 0.1   # fraction of normal speed at full stun
const HIT_SLOW_DURATION  := 0.35   # seconds the stun lasts
var _hit_slow_timer := 0.0         # counts down while stunned

var _anim_player: AnimationPlayer
var _skeleton: Skeleton3D
var _current_anim := ""
func _ready() -> void:
	_center_model()
	_setup_animation()
	add_to_group("enemies")
	_pick_patrol_target()

func _setup_animation() -> void:
	_skeleton = _find_skeleton(model)
	_anim_player = _find_anim_player(model)
	if not _anim_player:
		return
	
	var new_lib := AnimationLibrary.new()
	if _anim_player.has_animation_library(""):
		var default_lib = _anim_player.get_animation_library("")
		if default_lib.has_animation("Walking"):
			new_lib.add_animation("Walk", default_lib.get_animation("Walking"))
		if default_lib.has_animation("Running"):
			new_lib.add_animation("Run", default_lib.get_animation("Running"))
		if default_lib.has_animation("Triple_Combo_Attack"):
			new_lib.add_animation("Attack", default_lib.get_animation("Triple_Combo_Attack"))
		if default_lib.has_animation("Dead"):
			new_lib.add_animation("Dead", default_lib.get_animation("Dead"))
	
	if _anim_player.has_animation_library("custom"):
		_anim_player.remove_animation_library("custom")
	_anim_player.add_animation_library("custom", new_lib)
	
	if _anim_player.has_animation("custom/Walk"):
		_anim_player.get_animation("custom/Walk").set_loop_mode(Animation.LOOP_LINEAR)
	if _anim_player.has_animation("custom/Run"):
		_anim_player.get_animation("custom/Run").set_loop_mode(Animation.LOOP_LINEAR)
	if _anim_player.has_animation("custom/Attack"):
		_anim_player.get_animation("custom/Attack").set_loop_mode(Animation.LOOP_LINEAR)
	if _anim_player.has_animation("custom/Dead"):
		_anim_player.get_animation("custom/Dead").set_loop_mode(Animation.LOOP_NONE)

	_anim_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "custom/Dead":
		queue_free()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

func _play_anim(anim_name: String) -> void:
	if not _anim_player or not _anim_player.has_animation("custom/" + anim_name):
		return
	_anim_player.speed_scale = 2.0 if anim_name == "Attack" else 1.0
	if _current_anim != anim_name:
		_anim_player.play("custom/" + anim_name, 0.2)
		_current_anim = anim_name

func setup(player: CharacterBody3D) -> void:
	_player = player

func _center_model() -> void:
	var scale_factor := MODEL_HEIGHT / 1.7
	model.scale = Vector3.ONE * scale_factor
	model.position = Vector3(0, -0.7, 0)

func _physics_process(delta: float) -> void:
	# Tick hit-slow timer
	if _hit_slow_timer > 0.0:
		_hit_slow_timer -= delta
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	if _state == "dead":
		velocity.x = move_toward(velocity.x, 0, PATROL_SPEED)
		velocity.z = move_toward(velocity.z, 0, PATROL_SPEED)
		move_and_slide()
		return
		
	if not is_instance_valid(_player):
		velocity.x = move_toward(velocity.x, 0, PATROL_SPEED)
		velocity.z = move_toward(velocity.z, 0, PATROL_SPEED)
		move_and_slide()
		if Vector2(velocity.x, velocity.z).length() < 0.1:
			_play_anim("Walk")
		else:
			_play_anim("Walk")
		return

	var dist := global_position.distance_to(_player.global_position)

	match _state:
		"patrol":
			_process_patrol(delta)
			if dist < DETECTION_RADIUS:
				_state = "chase"
		"chase":
			_process_chase(delta)
			if dist > DETECTION_RADIUS * 1.5:
				_state = "patrol"
				_pick_patrol_target()
			elif dist < ATTACK_RADIUS:
				_state = "attack"
		"attack":
			_process_attack(delta)
			if dist > ATTACK_RADIUS * 1.5:
				_state = "chase"

	move_and_slide()
	_face_velocity()

func _process_patrol(_delta: float) -> void:
	_play_anim("Walk")
	if global_position.distance_to(_patrol_target) < 1.5:
		_pick_patrol_target()
		return
	
	var direction := (_patrol_target - global_position)
	direction.y = 0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
	else:
		direction = Vector3.FORWARD
			
	var speed_scale := lerpf(HIT_SLOW_MULTIPLIER, 1.0, 1.0 - clampf(_hit_slow_timer / HIT_SLOW_DURATION, 0.0, 1.0))
	velocity.x = direction.x * PATROL_SPEED * speed_scale
	velocity.z = direction.z * PATROL_SPEED * speed_scale

func _process_chase(_delta: float) -> void:
	_play_anim("Run")
	var direction := (_player.global_position - global_position)
	direction.y = 0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
	else:
		direction = Vector3.FORWARD
			
	var speed_scale := lerpf(HIT_SLOW_MULTIPLIER, 1.0, 1.0 - clampf(_hit_slow_timer / HIT_SLOW_DURATION, 0.0, 1.0))
	velocity.x = direction.x * CHASE_SPEED * speed_scale
	velocity.z = direction.z * CHASE_SPEED * speed_scale

func _process_attack(delta: float) -> void:
	_play_anim("Attack")
	velocity.x = 0
	velocity.z = 0
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = ATTACK_COOLDOWN
		_player.take_damage(ATTACK_DAMAGE)

func _face_velocity() -> void:
	var h_vel := Vector2(velocity.x, velocity.z)
	if h_vel.length() < 0.5 and _state != "attack":
		return
	
	var forward := Vector3.FORWARD
	if h_vel.length() >= 0.5:
		forward = Vector3(velocity.x, 0, velocity.z).normalized()
	elif is_instance_valid(_player):
		forward = (_player.global_position - global_position)
		forward.y = 0
		if forward.length() > 0.001:
			forward = forward.normalized()
		else:
			forward = Vector3.FORWARD
		
	var target_pos := Vector3.ZERO + forward
	var target_transform := Transform3D()
	target_transform = target_transform.looking_at(target_pos, Vector3.UP)
	target_transform.basis = target_transform.basis.rotated(Vector3.UP, PI)
	target_transform.origin = model.transform.origin
	model.transform.basis = model.transform.basis.slerp(target_transform.basis, 0.15)

func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var dist := randf() * PATROL_RADIUS
	_patrol_target = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

func take_damage(amount: int) -> void:
	if _state == "dead":
		return
	health -= amount
	# Trigger hit-stun slow
	_hit_slow_timer = HIT_SLOW_DURATION
	if health <= 0:
		_state = "dead"
		_play_anim("Dead")
		collision_layer = 0
		collision_mask = 0
		died.emit()
