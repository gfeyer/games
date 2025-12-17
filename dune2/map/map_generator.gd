extends Node
class_name MapGenerator

@export var rock_coverage: float = 0.25
@export var spice_field_count: int = 8
@export var spice_field_size: int = 6

var terrain_manager: TerrainManager
var noise: FastNoiseLite

func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05

func generate_map(tm: TerrainManager) -> void:
	terrain_manager = tm
	terrain_manager.initialize_grid()

	# Generate rock formations using noise
	generate_rock_formations()

	# Generate spice fields
	generate_spice_fields()

	# Clear starting areas for players
	clear_starting_area(Vector2i(5, 5), 8)  # Player (top-left area)
	clear_starting_area(Vector2i(Constants.MAP_WIDTH - 13, Constants.MAP_HEIGHT - 13), 8)  # Enemy (bottom-right)

	terrain_manager.queue_redraw()

func generate_rock_formations() -> void:
	for x in range(Constants.MAP_WIDTH):
		for y in range(Constants.MAP_HEIGHT):
			var noise_val = noise.get_noise_2d(x, y)
			if noise_val > (1.0 - rock_coverage * 2):
				terrain_manager.set_terrain(Vector2i(x, y), Constants.Terrain.ROCK)

func generate_spice_fields() -> void:
	var placed_fields = 0
	var attempts = 0
	var max_attempts = 100

	while placed_fields < spice_field_count and attempts < max_attempts:
		var center = Vector2i(
			randi_range(spice_field_size, Constants.MAP_WIDTH - spice_field_size),
			randi_range(spice_field_size, Constants.MAP_HEIGHT - spice_field_size)
		)

		# Check if area is mostly sand (not near starting positions)
		if is_valid_spice_location(center):
			create_spice_field(center)
			placed_fields += 1

		attempts += 1

func is_valid_spice_location(center: Vector2i) -> bool:
	# Don't place spice too close to corners (starting positions)
	var margin = 15
	if center.x < margin and center.y < margin:
		return false
	if center.x > Constants.MAP_WIDTH - margin and center.y > Constants.MAP_HEIGHT - margin:
		return false

	# Check terrain is suitable
	var sand_count = 0
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var pos = center + Vector2i(dx, dy)
			if Constants.is_valid_grid_pos(pos):
				var terrain = terrain_manager.get_terrain(pos)
				if terrain == Constants.Terrain.SAND:
					sand_count += 1

	return sand_count > 30  # At least 30 sand tiles in 7x7 area

func create_spice_field(center: Vector2i) -> void:
	# Create organic-looking spice field
	for dx in range(-spice_field_size, spice_field_size + 1):
		for dy in range(-spice_field_size, spice_field_size + 1):
			var pos = center + Vector2i(dx, dy)
			if not Constants.is_valid_grid_pos(pos):
				continue

			var dist = Vector2(dx, dy).length()
			if dist > spice_field_size:
				continue

			# Only place on sand
			if terrain_manager.get_terrain(pos) != Constants.Terrain.SAND:
				continue

			# Density based on distance from center
			var density_chance = 1.0 - (dist / spice_field_size)
			if randf() < density_chance:
				var spice_level = 3 if dist < spice_field_size * 0.3 else (2 if dist < spice_field_size * 0.6 else 1)
				terrain_manager.set_spice(pos, spice_level)

func clear_starting_area(top_left: Vector2i, size: int) -> void:
	# Clear area for starting base - make it rock (buildable)
	for x in range(size):
		for y in range(size):
			var pos = top_left + Vector2i(x, y)
			if Constants.is_valid_grid_pos(pos):
				terrain_manager.set_terrain(pos, Constants.Terrain.ROCK)

	# Add some concrete in the center for immediate building
	var center_offset = size / 2 - 2
	for x in range(4):
		for y in range(4):
			var pos = top_left + Vector2i(center_offset + x, center_offset + y)
			if Constants.is_valid_grid_pos(pos):
				terrain_manager.set_terrain(pos, Constants.Terrain.ROCK)
