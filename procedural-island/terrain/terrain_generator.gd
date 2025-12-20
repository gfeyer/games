extends Node3D
class_name TerrainGenerator

## Biome types for vegetation/fauna placement
enum Biome { WATER, BEACH, GRASS, ROCK, SNOW }

@export var island_size: float = 10000.0
@export var height_scale: float = 2000.0
@export var grid_resolution: int = 400
@export var noise_frequency: float = 0.0002
@export var noise_octaves: int = 4
@export var terrain_seed: int = 0  # 0 = random

var noise: FastNoiseLite
var mesh_instance: MeshInstance3D
var water_mesh: MeshInstance3D

# Height zone thresholds (normalized 0-1)
const DEEP_WATER_HEIGHT = 0.0
const SHALLOW_WATER_HEIGHT = 0.1
const BEACH_HEIGHT = 0.15
const GRASS_HEIGHT = 0.5
const ROCK_HEIGHT = 0.8

# Colors for each zone
var color_deep_water = Color(0.1, 0.2, 0.5)
var color_shallow_water = Color(0.2, 0.4, 0.7)
var color_beach = Color(0.9, 0.85, 0.6)
var color_grass = Color(0.3, 0.6, 0.2)
var color_rock = Color(0.5, 0.5, 0.5)
var color_snow = Color(0.95, 0.95, 1.0)

func _ready() -> void:
	generate_terrain()

func generate_terrain() -> void:
	# Initialize noise
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves

	if terrain_seed == 0:
		noise.seed = randi()
	else:
		noise.seed = terrain_seed

	# Generate the terrain mesh
	create_terrain_mesh()

	# Create water plane
	create_water_plane()

func create_terrain_mesh() -> void:
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_size = island_size / 2.0
	var step = island_size / grid_resolution

	# Store heights for later use
	var heights = []
	heights.resize((grid_resolution + 1) * (grid_resolution + 1))

	# Generate vertices
	for z in range(grid_resolution + 1):
		for x in range(grid_resolution + 1):
			var world_x = -half_size + x * step
			var world_z = -half_size + z * step

			# Get height from noise with island mask
			var height = get_height_at(world_x, world_z)
			heights[z * (grid_resolution + 1) + x] = height

	# Generate triangles with vertex colors
	for z in range(grid_resolution):
		for x in range(grid_resolution):
			var idx00 = z * (grid_resolution + 1) + x
			var idx10 = z * (grid_resolution + 1) + x + 1
			var idx01 = (z + 1) * (grid_resolution + 1) + x
			var idx11 = (z + 1) * (grid_resolution + 1) + x + 1

			var world_x0 = -half_size + x * step
			var world_x1 = -half_size + (x + 1) * step
			var world_z0 = -half_size + z * step
			var world_z1 = -half_size + (z + 1) * step

			var h00 = heights[idx00]
			var h10 = heights[idx10]
			var h01 = heights[idx01]
			var h11 = heights[idx11]

			var v00 = Vector3(world_x0, h00, world_z0)
			var v10 = Vector3(world_x1, h10, world_z0)
			var v01 = Vector3(world_x0, h01, world_z1)
			var v11 = Vector3(world_x1, h11, world_z1)

			# Triangle 1: v00, v10, v01
			add_vertex_with_color(surface_tool, v00, h00)
			add_vertex_with_color(surface_tool, v10, h10)
			add_vertex_with_color(surface_tool, v01, h01)

			# Triangle 2: v10, v11, v01
			add_vertex_with_color(surface_tool, v10, h10)
			add_vertex_with_color(surface_tool, v11, h11)
			add_vertex_with_color(surface_tool, v01, h01)

	# Generate normals
	surface_tool.generate_normals()

	# Create mesh
	var mesh = surface_tool.commit()

	# Create MeshInstance3D
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh

	# Create material that uses vertex colors
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	mesh_instance.material_override = material

	add_child(mesh_instance)

	# Create collision
	mesh_instance.create_trimesh_collision()

func add_vertex_with_color(surface_tool: SurfaceTool, vertex: Vector3, height: float) -> void:
	var color = get_color_for_height(height)
	surface_tool.set_color(color)
	surface_tool.set_uv(Vector2(vertex.x / island_size + 0.5, vertex.z / island_size + 0.5))
	surface_tool.add_vertex(vertex)

func get_height_at(x: float, z: float) -> float:
	# Get base noise value
	var noise_val = noise.get_noise_2d(x, z)

	# Normalize from [-1, 1] to [0, 1]
	noise_val = (noise_val + 1.0) / 2.0

	# Apply island mask (circular falloff)
	var half_size = island_size / 2.0
	var dist_from_center = Vector2(x, z).length()
	var max_dist = half_size * 0.9  # Island radius

	# Smooth falloff at edges
	var falloff = 1.0 - smoothstep(max_dist * 0.5, max_dist, dist_from_center)

	# Combine noise with falloff
	var masked_height = noise_val * falloff

	# Scale to world height (subtract to create water level)
	var final_height = (masked_height - 0.3) * height_scale

	return final_height

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func get_color_for_height(height: float) -> Color:
	# Normalize height to 0-1 range for color selection
	var normalized = (height / height_scale) + 0.3
	normalized = clamp(normalized, 0.0, 1.0)

	if normalized < DEEP_WATER_HEIGHT:
		return color_deep_water
	elif normalized < SHALLOW_WATER_HEIGHT:
		return color_shallow_water
	elif normalized < BEACH_HEIGHT:
		return color_beach
	elif normalized < GRASS_HEIGHT:
		# Gradient between beach and grass
		var t = (normalized - BEACH_HEIGHT) / (GRASS_HEIGHT - BEACH_HEIGHT)
		return color_beach.lerp(color_grass, t)
	elif normalized < ROCK_HEIGHT:
		# Gradient between grass and rock
		var t = (normalized - GRASS_HEIGHT) / (ROCK_HEIGHT - GRASS_HEIGHT)
		return color_grass.lerp(color_rock, t)
	else:
		# Gradient between rock and snow
		var t = (normalized - ROCK_HEIGHT) / (1.0 - ROCK_HEIGHT)
		return color_rock.lerp(color_snow, t)

func create_water_plane() -> void:
	# Create a simple water plane at y=0
	var water_size = island_size * 1.5

	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(water_size, water_size)

	water_mesh = MeshInstance3D.new()
	water_mesh.mesh = plane_mesh
	water_mesh.position.y = -0.5  # Slightly below water level

	# Water material
	var water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.1, 0.3, 0.6, 0.8)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.1
	water_material.metallic = 0.3
	water_mesh.material_override = water_material

	add_child(water_mesh)

func get_spawn_position() -> Vector3:
	# Find a good spawn point on the island (near center, above water)
	var best_pos = Vector3(0, 0, 0)
	var best_height = -INF

	# Search in a grid near center
	for x in range(-5, 6):
		for z in range(-5, 6):
			var world_x = x * 200.0
			var world_z = z * 200.0
			var h = get_height_at(world_x, world_z)
			if h > best_height and h > 100.0:  # Above water level
				best_height = h
				best_pos = Vector3(world_x, h + 0.5, world_z)

	# Fallback to center if no good spot found
	if best_height < 0:
		best_pos = Vector3(0, get_height_at(0, 0) + 2.0, 0)

	return best_pos

## Get the biome type at a world position
func get_biome_at(x: float, z: float) -> Biome:
	var height = get_height_at(x, z)
	var normalized = (height / height_scale) + 0.3
	normalized = clamp(normalized, 0.0, 1.0)

	if normalized < SHALLOW_WATER_HEIGHT:
		return Biome.WATER
	elif normalized < BEACH_HEIGHT:
		return Biome.BEACH
	elif normalized < GRASS_HEIGHT:
		return Biome.GRASS
	elif normalized < ROCK_HEIGHT:
		return Biome.ROCK
	else:
		return Biome.SNOW

## Get the terrain slope at a position (for placement validation)
func get_slope_at(x: float, z: float, sample_dist: float = 5.0) -> float:
	var h_center = get_height_at(x, z)
	var h_px = get_height_at(x + sample_dist, z)
	var h_nx = get_height_at(x - sample_dist, z)
	var h_pz = get_height_at(x, z + sample_dist)
	var h_nz = get_height_at(x, z - sample_dist)

	var slope_x = abs(h_px - h_nx) / (2.0 * sample_dist)
	var slope_z = abs(h_pz - h_nz) / (2.0 * sample_dist)

	return max(slope_x, slope_z)

## Get normalized height (0-1) at a position
func get_normalized_height_at(x: float, z: float) -> float:
	var height = get_height_at(x, z)
	var normalized = (height / height_scale) + 0.3
	return clamp(normalized, 0.0, 1.0)

## Check if a position is valid for vegetation (above water, not too steep)
func is_valid_vegetation_spot(x: float, z: float, max_slope: float = 0.5) -> bool:
	var biome = get_biome_at(x, z)
	if biome == Biome.WATER:
		return false
	var slope = get_slope_at(x, z)
	return slope <= max_slope
