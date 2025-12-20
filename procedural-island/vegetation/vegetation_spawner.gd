extends Node3D
class_name VegetationSpawner

## Spawns vegetation across the terrain using chunk-based loading

@export var chunk_size: float = 200.0
@export var load_distance: int = 3  # Chunks in each direction
@export var unload_distance: int = 5

# Density settings (items per chunk)
@export var trees_per_chunk: int = 15
@export var bushes_per_chunk: int = 25
@export var rocks_per_chunk: int = 10

# Scene references
var pine_tree_scene: PackedScene
var palm_tree_scene: PackedScene
var deciduous_tree_scene: PackedScene
var bush_scene: PackedScene
var rock_scene: PackedScene

# Loaded chunks: Vector2i -> Array of Node3D instances
var loaded_chunks: Dictionary = {}

# References
var terrain: TerrainGenerator
var player: Node3D

# Random number generator with seed for consistent spawning
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# Load vegetation scenes
	pine_tree_scene = preload("res://vegetation/trees/pine_tree.tscn")
	palm_tree_scene = preload("res://vegetation/trees/palm_tree.tscn")
	deciduous_tree_scene = preload("res://vegetation/trees/deciduous_tree.tscn")
	bush_scene = preload("res://vegetation/bushes/bush.tscn")
	rock_scene = preload("res://vegetation/rocks/rock.tscn")

func initialize(p_terrain: TerrainGenerator, p_player: Node3D) -> void:
	terrain = p_terrain
	player = p_player

func _process(_delta: float) -> void:
	if not player or not terrain:
		return

	var player_chunk = get_chunk_position(player.global_position)
	update_chunks(player_chunk)

func get_chunk_position(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / chunk_size),
		floori(world_pos.z / chunk_size)
	)

func update_chunks(center_chunk: Vector2i) -> void:
	# Load nearby chunks
	for x in range(-load_distance, load_distance + 1):
		for z in range(-load_distance, load_distance + 1):
			var chunk_pos = center_chunk + Vector2i(x, z)
			if not loaded_chunks.has(chunk_pos):
				load_chunk(chunk_pos)

	# Unload distant chunks
	var chunks_to_unload: Array[Vector2i] = []
	for chunk_pos in loaded_chunks.keys():
		var dist = absi(chunk_pos.x - center_chunk.x) + absi(chunk_pos.y - center_chunk.y)
		if dist > unload_distance:
			chunks_to_unload.append(chunk_pos)

	for chunk_pos in chunks_to_unload:
		unload_chunk(chunk_pos)

func load_chunk(chunk_pos: Vector2i) -> void:
	# Use chunk position as seed for consistent spawning
	rng.seed = hash(chunk_pos)

	var instances: Array[Node3D] = []
	var chunk_world_x = chunk_pos.x * chunk_size
	var chunk_world_z = chunk_pos.y * chunk_size

	# Spawn trees
	for i in range(trees_per_chunk):
		var local_x = rng.randf() * chunk_size
		var local_z = rng.randf() * chunk_size
		var world_x = chunk_world_x + local_x
		var world_z = chunk_world_z + local_z

		var tree = spawn_tree_at(world_x, world_z)
		if tree:
			instances.append(tree)

	# Spawn bushes
	for i in range(bushes_per_chunk):
		var local_x = rng.randf() * chunk_size
		var local_z = rng.randf() * chunk_size
		var world_x = chunk_world_x + local_x
		var world_z = chunk_world_z + local_z

		var bush = spawn_bush_at(world_x, world_z)
		if bush:
			instances.append(bush)

	# Spawn rocks
	for i in range(rocks_per_chunk):
		var local_x = rng.randf() * chunk_size
		var local_z = rng.randf() * chunk_size
		var world_x = chunk_world_x + local_x
		var world_z = chunk_world_z + local_z

		var rock = spawn_rock_at(world_x, world_z)
		if rock:
			instances.append(rock)

	loaded_chunks[chunk_pos] = instances

func unload_chunk(chunk_pos: Vector2i) -> void:
	if not loaded_chunks.has(chunk_pos):
		return

	var instances = loaded_chunks[chunk_pos]
	for instance in instances:
		if is_instance_valid(instance):
			instance.queue_free()

	loaded_chunks.erase(chunk_pos)

func spawn_tree_at(x: float, z: float) -> Node3D:
	if not terrain.is_valid_vegetation_spot(x, z, 0.4):
		return null

	var biome = terrain.get_biome_at(x, z)
	var tree_scene: PackedScene

	match biome:
		TerrainGenerator.Biome.BEACH:
			tree_scene = palm_tree_scene
		TerrainGenerator.Biome.GRASS:
			tree_scene = deciduous_tree_scene
		TerrainGenerator.Biome.ROCK, TerrainGenerator.Biome.SNOW:
			tree_scene = pine_tree_scene
		_:
			return null

	var height = terrain.get_height_at(x, z)
	var tree = tree_scene.instantiate()
	tree.position = Vector3(x, height, z)

	# Add random scale variation
	var scale_factor = rng.randf_range(0.7, 1.3)
	tree.scale *= scale_factor

	add_child(tree)
	return tree

func spawn_bush_at(x: float, z: float) -> Node3D:
	if not terrain.is_valid_vegetation_spot(x, z, 0.5):
		return null

	var biome = terrain.get_biome_at(x, z)

	# Bushes only in grass and rock biomes
	if biome != TerrainGenerator.Biome.GRASS and biome != TerrainGenerator.Biome.ROCK:
		return null

	var height = terrain.get_height_at(x, z)
	var bush = bush_scene.instantiate()
	bush.position = Vector3(x, height, z)

	# Random rotation and scale
	bush.rotation.y = rng.randf() * TAU
	var scale_factor = rng.randf_range(0.6, 1.4)
	bush.scale *= scale_factor

	add_child(bush)
	return bush

func spawn_rock_at(x: float, z: float) -> Node3D:
	if not terrain.is_valid_vegetation_spot(x, z, 0.8):
		return null

	var biome = terrain.get_biome_at(x, z)

	# Rocks in grass, rock, and snow biomes (more common in rock/snow)
	if biome == TerrainGenerator.Biome.WATER or biome == TerrainGenerator.Biome.BEACH:
		return null

	var height = terrain.get_height_at(x, z)
	var rock = rock_scene.instantiate()
	rock.position = Vector3(x, height, z)

	# Random rotation and scale
	rock.rotation.y = rng.randf() * TAU
	rock.rotation.x = rng.randf_range(-0.2, 0.2)
	var scale_factor = rng.randf_range(0.5, 2.0)
	rock.scale *= scale_factor

	add_child(rock)
	return rock

## Force reload all chunks (useful after terrain regeneration)
func reload_all_chunks() -> void:
	# Unload all existing chunks
	for chunk_pos in loaded_chunks.keys():
		unload_chunk(chunk_pos)
	loaded_chunks.clear()
