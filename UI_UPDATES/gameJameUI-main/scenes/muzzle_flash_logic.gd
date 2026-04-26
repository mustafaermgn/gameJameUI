extends Node3D

var _lifetime := 0.5
var _age := 0.0

func _ready() -> void:
	if has_node("@GPUParticles3D@5"):
		get_node("@GPUParticles3D@5").emitting = true

func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	# Fade out the light smoothly over the lifetime
	if has_node("@OmniLight3D@4"):
		var l = get_node("@OmniLight3D@4") as OmniLight3D
		var fade := 1.0 - (_age / _lifetime)
		l.light_energy = 8.0 * fade * fade
