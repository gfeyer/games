extends AnimalState
class_name FleeState

## Animal runs away from threats

var flee_target: Vector3
var flee_duration: float = 0.0
var max_flee_time: float = 5.0

func enter() -> void:
	flee_duration = 0.0
	calculate_flee_direction()

func update(delta: float) -> void:
	flee_duration += delta

	# Check if still need to flee
	if not animal.should_flee() and flee_duration > 1.0:
		# Safe now, go back to idle
		state_machine.change_state("idle")
		return

	# Max flee time exceeded
	if flee_duration > max_flee_time:
		state_machine.change_state("idle")
		return

	# Recalculate flee direction periodically
	if fmod(flee_duration, 0.5) < delta:
		calculate_flee_direction()

	# Run away
	animal.move_toward_position(flee_target, animal.run_speed, delta)

func calculate_flee_direction() -> void:
	if not EcosystemManager or not EcosystemManager.player:
		return

	var player = EcosystemManager.player
	var away_direction = (animal.global_position - player.global_position).normalized()
	away_direction.y = 0

	# Add some randomness to not run in a straight line
	away_direction = away_direction.rotated(Vector3.UP, randf_range(-0.3, 0.3))

	# Calculate flee target position
	flee_target = animal.global_position + away_direction * 5.0

	# Make sure it's valid terrain
	if animal.terrain:
		var biome = animal.terrain.get_biome_at(flee_target.x, flee_target.z)
		if biome == TerrainGenerator.Biome.WATER:
			# Try opposite direction if heading to water
			flee_target = animal.global_position - away_direction * 3.0

		flee_target.y = animal.terrain.get_height_at(flee_target.x, flee_target.z)

func exit() -> void:
	animal.stop_movement()
	animal.is_fleeing = false
