extends Node3D
class_name FaunaSpawner

## Spawns and manages animals across the terrain

@export var spawn_radius: float = 80.0  # Radius around player to maintain animals
@export var max_deer: int = 25
@export var spawn_interval: float = 1.0  # Seconds between spawn attempts

# Scene references
var deer_scene: PackedScene

# Active animals
var deer_list: Array[Node3D] = []

# References
var terrain: TerrainGenerator
var player: Node3D

# Spawn timer
var spawn_timer: float = 0.0

# Random number generator
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	deer_scene = preload("res://fauna/land_animals/deer/deer.tscn")

func initialize(p_terrain: TerrainGenerator, p_player: Node3D) -> void:
	terrain = p_terrain
	player = p_player

	# Defer initial spawn to ensure everything is ready
	call_deferred("_initial_spawn")

func _initial_spawn() -> void:
	# Initial spawn of some animals
	for i in range(10):
		spawn_deer()

func _process(delta: float) -> void:
	if not player or not terrain:
		return

	spawn_timer += delta

	# Periodic spawn attempts
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		maintain_animal_population()

	# Clean up dead or distant animals
	cleanup_animals()

func maintain_animal_population() -> void:
	# Spawn deer if below max
	if deer_list.size() < max_deer:
		spawn_deer()

func spawn_deer() -> void:
	var spawn_pos = get_valid_spawn_position(TerrainGenerator.Biome.GRASS)
	if spawn_pos == Vector3.ZERO:
		return

	var deer = deer_scene.instantiate()
	add_child(deer)
	deer.global_position = spawn_pos
	deer.rotation.y = rng.randf() * TAU
	deer_list.append(deer)

func get_valid_spawn_position(preferred_biome: TerrainGenerator.Biome) -> Vector3:
	if not player or not terrain:
		return Vector3.ZERO

	var attempts = 20

	while attempts > 0:
		attempts -= 1

		# Random position around player but not too close
		var angle = rng.randf() * TAU
		var distance = rng.randf_range(spawn_radius * 0.2, spawn_radius * 0.7)
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var pos = player.global_position + offset

		# Check biome
		var biome = terrain.get_biome_at(pos.x, pos.z)
		if biome == TerrainGenerator.Biome.WATER:
			continue

		# Prefer specific biome but accept adjacent ones
		if preferred_biome == TerrainGenerator.Biome.GRASS:
			if biome != TerrainGenerator.Biome.GRASS and biome != TerrainGenerator.Biome.BEACH:
				if rng.randf() > 0.3:  # 30% chance to spawn in other biomes
					continue

		# Check slope
		var slope = terrain.get_slope_at(pos.x, pos.z)
		if slope > 0.4:
			continue

		# Valid position found
		pos.y = terrain.get_height_at(pos.x, pos.z)
		return pos

	return Vector3.ZERO

func cleanup_animals() -> void:
	if not player:
		return

	# Remove dead or too distant animals
	var to_remove: Array[Node3D] = []

	for deer in deer_list:
		if not is_instance_valid(deer):
			to_remove.append(deer)
			continue

		# Remove if too far from player
		var distance = deer.global_position.distance_to(player.global_position)
		if distance > spawn_radius * 1.5:
			to_remove.append(deer)
			deer.queue_free()

	for deer in to_remove:
		deer_list.erase(deer)

## Get count of active animals
func get_animal_count() -> int:
	return deer_list.size()
