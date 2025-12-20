extends AnimalState
class_name WanderState

## Animal wanders to random nearby positions

var target_position: Vector3
var wander_radius: float = 3.0
var reached_target: bool = true
var stuck_timer: float = 0.0
var max_stuck_time: float = 5.0

func enter() -> void:
	reached_target = true
	stuck_timer = 0.0
	pick_new_target()

func update(delta: float) -> void:
	# Check for threats
	if animal.should_flee():
		state_machine.change_state("flee")
		return

	if reached_target:
		# Go to idle state between wandering
		state_machine.change_state("idle")
		return

	# Move toward target
	var distance = animal.global_position.distance_to(target_position)

	if distance < 0.3:
		reached_target = true
		animal.stop_movement()
		return

	# Check if stuck
	if animal.velocity.length() < 0.05:
		stuck_timer += delta
		if stuck_timer > max_stuck_time:
			# Pick a new target if stuck
			pick_new_target()
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0

	animal.move_toward_position(target_position, animal.move_speed, delta)

func pick_new_target() -> void:
	target_position = animal.get_random_wander_position(wander_radius)
	reached_target = false
	stuck_timer = 0.0

func exit() -> void:
	animal.stop_movement()
