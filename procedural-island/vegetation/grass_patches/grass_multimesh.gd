extends MultiMeshInstance3D
class_name GrassMultiMesh

## Efficient grass rendering using MultiMesh for a single chunk

const MAX_INSTANCES_PER_CHUNK = 2000
const GRASS_BLADE_HEIGHT = 0.08
const GRASS_BLADE_WIDTH = 0.015

var chunk_position: Vector2i
var active_instance_count: int = 0

func _ready() -> void:
	# Create the grass mesh and multimesh
	setup_multimesh()

func setup_multimesh() -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = create_grass_blade_mesh()
	mm.instance_count = MAX_INSTANCES_PER_CHUNK

	# Start with all instances hidden (scale 0)
	for i in range(MAX_INSTANCES_PER_CHUNK):
		mm.set_instance_transform(i, Transform3D().scaled(Vector3.ZERO))

	multimesh = mm

func create_grass_blade_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Simple triangle blade
	var half_width = GRASS_BLADE_WIDTH / 2.0

	# Bottom left
	st.set_color(Color(0.2, 0.5, 0.15))
	st.set_uv(Vector2(0, 1))
	st.add_vertex(Vector3(-half_width, 0, 0))

	# Bottom right
	st.set_color(Color(0.2, 0.5, 0.15))
	st.set_uv(Vector2(1, 1))
	st.add_vertex(Vector3(half_width, 0, 0))

	# Top (tip)
	st.set_color(Color(0.3, 0.6, 0.2))
	st.set_uv(Vector2(0.5, 0))
	st.add_vertex(Vector3(0, GRASS_BLADE_HEIGHT, 0))

	# Back face (for visibility from both sides)
	st.set_color(Color(0.2, 0.5, 0.15))
	st.add_vertex(Vector3(half_width, 0, 0))
	st.set_color(Color(0.2, 0.5, 0.15))
	st.add_vertex(Vector3(-half_width, 0, 0))
	st.set_color(Color(0.3, 0.6, 0.2))
	st.add_vertex(Vector3(0, GRASS_BLADE_HEIGHT, 0))

	st.generate_normals()

	var mesh = st.commit()

	# Apply material
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mesh.surface_set_material(0, material)

	return mesh

func populate_chunk(chunk_pos: Vector2i, chunk_size: float, terrain: TerrainGenerator, rng: RandomNumberGenerator) -> void:
	chunk_position = chunk_pos
	active_instance_count = 0

	var chunk_world_x = chunk_pos.x * chunk_size
	var chunk_world_z = chunk_pos.y * chunk_size

	var instance_idx = 0
	var attempts = 0
	var max_attempts = MAX_INSTANCES_PER_CHUNK * 2

	while instance_idx < MAX_INSTANCES_PER_CHUNK and attempts < max_attempts:
		attempts += 1

		var local_x = rng.randf() * chunk_size
		var local_z = rng.randf() * chunk_size
		var world_x = chunk_world_x + local_x
		var world_z = chunk_world_z + local_z

		# Only place grass in grass biome
		var biome = terrain.get_biome_at(world_x, world_z)
		if biome != TerrainGenerator.Biome.GRASS:
			continue

		# Check slope
		var slope = terrain.get_slope_at(world_x, world_z)
		if slope > 0.3:
			continue

		var height = terrain.get_height_at(world_x, world_z)

		# Create transform for this grass blade
		var transform = Transform3D()

		# Random rotation around Y axis
		var rot_y = rng.randf() * TAU
		transform = transform.rotated(Vector3.UP, rot_y)

		# Small random tilt
		var tilt = rng.randf_range(-0.1, 0.1)
		transform = transform.rotated(Vector3.RIGHT, tilt)

		# Random scale variation
		var scale_factor = rng.randf_range(0.6, 1.4)
		transform = transform.scaled(Vector3(scale_factor, scale_factor, scale_factor))

		# Position
		transform.origin = Vector3(world_x, height, world_z)

		multimesh.set_instance_transform(instance_idx, transform)

		# Slight color variation
		var color_var = rng.randf_range(0.85, 1.15)
		var grass_color = Color(0.25 * color_var, 0.5 * color_var, 0.18 * color_var)
		multimesh.set_instance_color(instance_idx, grass_color)

		instance_idx += 1

	active_instance_count = instance_idx

	# Hide unused instances
	for i in range(instance_idx, MAX_INSTANCES_PER_CHUNK):
		multimesh.set_instance_transform(i, Transform3D().scaled(Vector3.ZERO))

func clear_chunk() -> void:
	if multimesh:
		for i in range(MAX_INSTANCES_PER_CHUNK):
			multimesh.set_instance_transform(i, Transform3D().scaled(Vector3.ZERO))
	active_instance_count = 0
