extends Node

## Central manager for the island ecosystem
## Note: Do not use class_name as this is an autoload singleton
## Handles day/night cycle, time signals, and global references

signal time_changed(hour: float)
signal day_night_changed(is_day: bool)

# Time system
@export var day_length_seconds: float = 600.0  # 10 minute full day cycle
@export var time_scale: float = 1.0  # Multiplier for time speed

var current_hour: float = 8.0  # Start at 8 AM
var is_day: bool = true

const DAWN_HOUR = 6.0
const DUSK_HOUR = 18.0

# Global references (set by main.gd)
var terrain: TerrainGenerator
var player: Node3D

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	update_time(delta)

func update_time(delta: float) -> void:
	var hours_per_second = 24.0 / day_length_seconds
	current_hour += delta * hours_per_second * time_scale

	if current_hour >= 24.0:
		current_hour -= 24.0

	var was_day = is_day
	is_day = current_hour >= DAWN_HOUR and current_hour < DUSK_HOUR

	if was_day != is_day:
		day_night_changed.emit(is_day)

	time_changed.emit(current_hour)
	update_sun_position()

func update_sun_position() -> void:
	var sun = get_tree().get_first_node_in_group("sun")
	if sun and sun is DirectionalLight3D:
		# Rotate sun based on time (full rotation over 24 hours)
		var sun_angle = ((current_hour - 6.0) / 24.0) * TAU
		sun.rotation.x = -sun_angle

		# Adjust light based on day/night
		if is_day:
			var day_progress = (current_hour - DAWN_HOUR) / (DUSK_HOUR - DAWN_HOUR)
			# Peak brightness at noon
			var brightness = sin(day_progress * PI)
			sun.light_energy = 0.5 + brightness * 0.7
			sun.light_color = Color(1.0, 0.95, 0.85)
		else:
			sun.light_energy = 0.05
			sun.light_color = Color(0.4, 0.4, 0.6)

## Get normalized time of day (0.0 = midnight, 0.5 = noon, 1.0 = midnight)
func get_normalized_time() -> float:
	return current_hour / 24.0

## Check if it's currently night time
func is_night() -> bool:
	return not is_day
