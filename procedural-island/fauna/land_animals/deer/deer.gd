extends AnimalBase
class_name Deer

## A gentle deer that grazes and flees from threats

func _ready() -> void:
	# Set deer-specific defaults
	move_speed = 0.4
	run_speed = 1.0
	detection_range = 4.0
	flee_range = 2.5
	diet = DietType.HERBIVORE
	is_nocturnal = false

	super._ready()
