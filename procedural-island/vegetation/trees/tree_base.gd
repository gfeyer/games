extends Node3D
class_name TreeBase

## Base class for all tree types (sway disabled for performance)

func _ready() -> void:
	# Randomize scale slightly for variety
	var scale_var = randf_range(0.8, 1.2)
	scale *= scale_var

	# Random Y rotation for variety
	rotation.y = randf() * TAU
