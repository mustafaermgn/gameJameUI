extends Node3D

var _lifetime := 1.0
var _age := 0.0
var _initial_light_energy := 12.0

func _ready() -> void:
	# Kick off particles
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true

func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	# Fade out the light smoothly
	var fade := 1.0 - (_age / _lifetime)
	for child in get_children():
		if child is OmniLight3D:
			child.light_energy = _initial_light_energy * fade * fade
