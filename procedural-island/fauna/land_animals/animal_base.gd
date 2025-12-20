extends CharacterBody3D
class_name AnimalBase

## Base class for all land animals with AI and terrain following

signal died()
signal spotted_threat(threat: Node3D)
signal spotted_prey(prey: Node3D)

# Movement stats
@export var move_speed: float = 0.5
@export var run_speed: float = 1.2
@export var turn_speed: float = 3.0

# Detection
@export var detection_range: float = 5.0
@export var flee_range: float = 3.0

# Diet type
enum DietType { HERBIVORE, CARNIVORE, OMNIVORE }
@export var diet: DietType = DietType.HERBIVORE

# Activity pattern
@export var is_nocturnal: bool = false

# Stats
@export var max_health: float = 100.0
var health: float
var hunger: float = 0.0
var energy: float = 100.0
var is_active: bool = true

# Current state
var current_target: Node3D
var is_fleeing: bool = false
var is_dead: bool = false

# References
var terrain: TerrainGenerator
var state_machine: Node

# Physics
var gravity: float = 10.0

func _ready() -> void:
	health = max_health

	# Get terrain reference
	if EcosystemManager:
		terrain = EcosystemManager.terrain
		EcosystemManager.day_night_changed.connect(_on_day_night_changed)

	# Find state machine child
	for child in get_children():
		if child.has_method("change_state"):
			state_machine = child
			break

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# Stick to terrain
	if terrain:
		var target_y = terrain.get_height_at(global_position.x, global_position.z)
		if is_on_floor():
			global_position.y = target_y

	# Update stats
	update_stats(delta)

	# Move
	move_and_slide()

func update_stats(delta: float) -> void:
	# Increase hunger over time
	hunger = min(100.0, hunger + delta * 0.5)

	# Decrease energy when active
	if velocity.length() > 0.1:
		energy = max(0.0, energy - delta * 1.0)
	else:
		# Slowly recover energy when idle
		energy = min(100.0, energy + delta * 0.5)

func move_toward_position(target_pos: Vector3, speed: float, delta: float) -> void:
	var direction = (target_pos - global_position)
	direction.y = 0

	if direction.length() < 0.1:
		velocity.x = 0
		velocity.z = 0
		return

	direction = direction.normalized()

	# Smoothly rotate toward target
	var target_angle = atan2(direction.x, direction.z)
	var current_angle = rotation.y
	rotation.y = lerp_angle(current_angle, target_angle, turn_speed * delta)

	# Move forward
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func stop_movement() -> void:
	velocity.x = 0
	velocity.z = 0

func get_distance_to(target: Node3D) -> float:
	if not is_instance_valid(target):
		return INF
	return global_position.distance_to(target.global_position)

func is_player_nearby() -> bool:
	if not EcosystemManager or not EcosystemManager.player:
		return false
	var player = EcosystemManager.player
	return get_distance_to(player) < detection_range

func get_player_distance() -> float:
	if not EcosystemManager or not EcosystemManager.player:
		return INF
	return get_distance_to(EcosystemManager.player)

func should_flee() -> bool:
	return get_player_distance() < flee_range

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	died.emit()
	# Could add death animation or ragdoll here
	queue_free()

func _on_day_night_changed(is_day: bool) -> void:
	# Nocturnal animals are active at night, diurnal during day
	is_active = is_day != is_nocturnal

## Get a random position within a radius that's valid for this animal
func get_random_wander_position(radius: float) -> Vector3:
	if not terrain:
		return global_position

	var attempts = 10
	while attempts > 0:
		var angle = randf() * TAU
		var distance = randf_range(radius * 0.3, radius)
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var target_pos = global_position + offset

		# Check if position is valid (not in water, not too steep)
		var biome = terrain.get_biome_at(target_pos.x, target_pos.z)
		if biome != TerrainGenerator.Biome.WATER:
			var slope = terrain.get_slope_at(target_pos.x, target_pos.z)
			if slope < 0.5:
				target_pos.y = terrain.get_height_at(target_pos.x, target_pos.z)
				return target_pos

		attempts -= 1

	return global_position
