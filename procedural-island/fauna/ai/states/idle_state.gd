extends AnimalState
class_name IdleState

## Animal stands still and looks around

var idle_time: float = 0.0
var idle_duration: float = 0.0
var look_timer: float = 0.0
var look_interval: float = 2.0

func enter() -> void:
	animal.stop_movement()
	idle_time = 0.0
	idle_duration = randf_range(2.0, 5.0)
	look_timer = 0.0

func update(delta: float) -> void:
	idle_time += delta
	look_timer += delta

	# Check for threats (player nearby)
	if animal.should_flee():
		state_machine.change_state("flee")
		return

	# Occasionally look around (rotate slightly)
	if look_timer >= look_interval:
		look_timer = 0.0
		look_interval = randf_range(1.5, 3.0)
		# Small random rotation
		animal.rotation.y += randf_range(-0.3, 0.3)

	# After idle duration, start wandering
	if idle_time >= idle_duration:
		state_machine.change_state("wander")

func exit() -> void:
	pass
