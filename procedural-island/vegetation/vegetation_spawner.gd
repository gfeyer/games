extends Node3D
class_name VegetationSpawner

## Spawns vegetation across the terrain using chunk-based loading

@export var chunk_size: float = 200.0
@export var load_distance: int = 3  # Chunks in each direction
@export var unload_distance: int = 5

# Density settings (items per chunk)
@export var trees_per_chunk: int = 40
@export var bushes_per_chunk: int = 50
@export var rocks_per_chunk: int = 20
@export var flowers_per_chunk: int = 80
@export var enable_grass: bool = true

# Scene references
var pine_tree_scene: PackedScene
var palm_tree_scene: PackedScene
var deciduous_tree_scene: PackedScene
var bush_scenes: Array[PackedScene] = []
var rock_scenes: Array[PackedScene] = []
var flower_scene: PackedScene

# Grass MultiMesh script
var grass_multimesh_script: GDScript

# Loaded chunks: Vector2i -> Dictionary with instances and grass
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

	# Load bush variants
	bush_scenes.append(preload("res://vegetation/bushes/bush.tscn"))
	bush_scenes.append(preload("res://vegetation/bushes/bush_berry.tscn"))

	# Load rock variants
	rock_scenes.append(preload("res://vegetation/rocks/rock.tscn"))
	rock_scenes.append(preload("res://vegetation/rocks/rock_large.tscn"))
	rock_scenes.append(preload("res://vegetation/rocks/rock_mossy.tscn"))

	flower_scene = preload("res://vegetation/grass_patches/flower.tscn")
	grass_multimesh_script = preload("res://vegetation/grass_patches/grass_multimesh.gd")

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

	var chunk_data = {
		"instances": [] as Array[Node3D],
		"grass": null
	}
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
			chunk_data["instances"].append(tree)

	# Spawn bushes
	for i in range(bushes_per_chunk):
		var local_x = rng.randf() * chunk_size
		var local_z = rng.randf() * chunk_size
		var world_x = chunk_world_x + local_x
		var world_z = chunk_world_z + local_z

		var bush = spawn_bush_at(world_x, world_z)
		if bush:
			chunk_data["instances"].append(bush)

	# Spawn rocks
	for i in range(rocks_per_chunk):
		var local_x = rng.randf() * chunk_size
		var local_z = rng.randf() * chunk_size
		var world_x = chunk_world_x + local_x
		var world_z = chunk_world_z + local_z

		var rock = spawn_rock_at(world_x, world_z)
		if rock:
			chunk_data["instances"].append(rock)

	# Spawn flowers
	for i in range(flowers_per_chunk):
		var local_x = rng.randf() * chunk_size
		var local_z = rng.randf() * chunk_size
		var world_x = chunk_world_x + local_x
		var world_z = chunk_world_z + local_z

		var flower = spawn_flower_at(world_x, world_z)
		if flower:
			chunk_data["instances"].append(flower)

	# Spawn grass using MultiMesh
	if enable_grass:
		var grass = spawn_grass_chunk(chunk_pos)
		if grass:
			chunk_data["grass"] = grass

	loaded_chunks[chunk_pos] = chunk_data

func unload_chunk(chunk_pos: Vector2i) -> void:
	if not loaded_chunks.has(chunk_pos):
		return

	var chunk_data = loaded_chunks[chunk_pos]

	# Free vegetation instances
	var instances = chunk_data.get("instances", [])
	for instance in instances:
		if is_instance_valid(instance):
			instance.queue_free()

	# Free grass multimesh
	var grass = chunk_data.get("grass")
	if grass and is_instance_valid(grass):
		grass.queue_free()

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

	# Pick random bush variant
	var bush_scene = bush_scenes[rng.randi() % bush_scenes.size()]

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

	# Pick random rock variant (mossy rocks more common in grass biome)
	var rock_scene: PackedScene
	if biome == TerrainGenerator.Biome.GRASS and rng.randf() < 0.4:
		rock_scene = rock_scenes[2]  # Mossy rock
	else:
		rock_scene = rock_scenes[rng.randi() % rock_scenes.size()]

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

func spawn_flower_at(x: float, z: float) -> Node3D:
	if not terrain.is_valid_vegetation_spot(x, z, 0.3):
		return null

	var biome = terrain.get_biome_at(x, z)

	# Flowers only in grass biome
	if biome != TerrainGenerator.Biome.GRASS:
		return null

	var height = terrain.get_height_at(x, z)
	var flower = flower_scene.instantiate()
	flower.position = Vector3(x, height, z)

	# Random rotation and scale
	flower.rotation.y = rng.randf() * TAU
	var scale_factor = rng.randf_range(0.5, 1.2)
	flower.scale *= scale_factor

	add_child(flower)
	return flower

func spawn_grass_chunk(chunk_pos: Vector2i) -> GrassMultiMesh:
	var grass = MultiMeshInstance3D.new()
	grass.set_script(grass_multimesh_script)
	add_child(grass)

	# Reset RNG seed for grass consistency
	rng.seed = hash(chunk_pos) + 12345

	# Populate the grass
	grass.populate_chunk(chunk_pos, chunk_size, terrain, rng)

	return grass

## Force reload all chunks (useful after terrain regeneration)
func reload_all_chunks() -> void:
	# Unload all existing chunks
	for chunk_pos in loaded_chunks.keys():
		unload_chunk(chunk_pos)
	loaded_chunks.clear()
