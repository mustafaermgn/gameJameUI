extends CharacterBody3D

signal player_hurt(hp_remaining: int)
signal player_died

const MODEL_HEIGHT := 1.2

var speed: float = 8.0

const MAX_HP := 3
var hp := MAX_HP
var _invuln_timer := 0.0
const INVULN_DURATION := 1.0

var _dead := false

@onready var model: Node3D = $Model
@onready var camera: Camera3D = $Camera3D

var _anim_player: AnimationPlayer
var _skeleton: Skeleton3D
var _is_moving := false
var _move_dir := Vector3.FORWARD

func _ready() -> void:
	add_to_group("player")
	camera.position = Vector3(0, 18, 12)
	camera.look_at(global_position, Vector3.UP)
	_center_model()
	_setup_animation()

func _center_model() -> void:
	# The imported Meshy character model is visually ~1.7 units tall.
	# Scale it down to match our MODEL_HEIGHT (1.2)
	var scale_factor := MODEL_HEIGHT / 1.7
	model.scale = Vector3.ONE * scale_factor
	# The capsule goes from -0.6 to 0.6. The model's origin is at its feet.
	model.position = Vector3(0, -0.6, 0)

func _setup_animation() -> void:
	_skeleton = _find_skeleton(model)
	_anim_player = _find_anim_player(model)
	if not _anim_player:
		return
	
	var new_lib := AnimationLibrary.new()
	var run_scene := load("res://models/player/meshy/Meshy_AI_biped_Animation_Running_withSkin.glb") as PackedScene
	if run_scene:
		var run_inst := run_scene.instantiate()
		var run_ap := _find_anim_player(run_inst)
		if run_ap:
			var anim_lib := run_ap.get_animation_library("")
			if anim_lib:
				var anim := anim_lib.get_animation("Armature|running|baselayer")
				if anim:
					new_lib.add_animation("Run", anim)
		run_inst.queue_free()
	
	if _anim_player.has_animation_library("custom"):
		_anim_player.remove_animation_library("custom")
	_anim_player.add_animation_library("custom", new_lib)
	if _anim_player.has_animation("custom/Run"):
		_anim_player.get_animation("custom/Run").set_loop_mode(Animation.LOOP_LINEAR)

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

func _physics_process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		model.visible = fmod(_invuln_timer, 0.15) > 0.075
	elif not model.visible:
		model.visible = true
	
	if _dead:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		move_and_slide()
		return
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_move_dir = direction.normalized()
		if not _is_moving:
			_is_moving = true
			_start_run()
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		if _is_moving:
			_is_moving = false
			_stop_run()
	velocity.y = 0
	move_and_slide()
	_face_direction()

func _start_run() -> void:
	if _anim_player and _anim_player.has_animation("custom/Run"):
		_anim_player.play("custom/Run", 0.1)

func _stop_run() -> void:
	if _anim_player:
		_anim_player.stop(0.1)

func _face_direction() -> void:
	if not _is_moving:
		return
	var target_pos := Vector3.ZERO + _move_dir
	var target_transform := Transform3D()
	target_transform = target_transform.looking_at(target_pos, Vector3.UP)
	# The Meshy_AI_biped faces +Z by default, so we rotate the basis by 180 degrees (PI) around Y.
	target_transform.basis = target_transform.basis.rotated(Vector3.UP, PI)
	target_transform.origin = model.transform.origin
	model.transform.basis = model.transform.basis.slerp(target_transform.basis, 0.15)

func stop_water() -> void:
	pass

func repair_pipe(_method: String) -> void:
	pass

func take_damage(_amount: int) -> void:
	if _dead or _invuln_timer > 0.0:
		return
	hp -= 1
	_invuln_timer = INVULN_DURATION
	player_hurt.emit(hp)
	if hp <= 0:
		_dead = true
		_is_moving = false
		_stop_run()
		player_died.emit()
