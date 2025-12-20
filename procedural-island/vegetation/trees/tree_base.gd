extends Node3D
class_name TreeBase

## Base class for all tree types with gentle sway animation

@export var sway_amount: float = 0.01
@export var sway_speed: float = 0.8

var time_offset: float

func _ready() -> void:
	# Random offset so trees don't all sway in sync
	time_offset = randf() * TAU

	# Randomize scale slightly for variety
	var scale_var = randf_range(0.8, 1.2)
	scale *= scale_var

	# Random Y rotation for variety
	rotation.y = randf() * TAU

func _process(delta: float) -> void:
	# Gentle sway animation
	var sway = sin(Time.get_ticks_msec() * 0.001 * sway_speed + time_offset) * sway_amount
	rotation.x = sway
	rotation.z = sway * 0.5
