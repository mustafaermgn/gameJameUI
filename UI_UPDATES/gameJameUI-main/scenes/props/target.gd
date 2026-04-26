extends CharacterBody3D

var health: int = 30

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
