extends Node3D

@export var rotation_speed: float = 10.0

func _process(delta):
	rotation_degrees.y += rotation_speed * delta
