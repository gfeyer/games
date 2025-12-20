extends AnimalBase
class_name Deer

## A gentle deer that grazes and flees from threats

func _ready() -> void:
	# Set deer-specific defaults
	move_speed = 0.8
	run_speed = 2.0
	detection_range = 8.0
	flee_range = 5.0
	diet = DietType.HERBIVORE
	is_nocturnal = false

	super._ready()
