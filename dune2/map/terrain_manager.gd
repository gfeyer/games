extends Node2D
class_name TerrainManager

signal terrain_changed(grid_pos: Vector2i, terrain_type: int)

# Terrain data stored in a 2D array
var terrain_grid: Array = []
var spice_amounts: Dictionary = {}  # Vector2i -> int (0-3)

@onready var terrain_layer: Node2D = $TerrainLayer

func _ready() -> void:
	initialize_grid()

func initialize_grid() -> void:
	terrain_grid.clear()
	for x in range(Constants.MAP_WIDTH):
		var column = []
		for y in range(Constants.MAP_HEIGHT):
			column.append(Constants.Terrain.SAND)
		terrain_grid.append(column)

func get_terrain(grid_pos: Vector2i) -> int:
	if not Constants.is_valid_grid_pos(grid_pos):
		return -1
	return terrain_grid[grid_pos.x][grid_pos.y]

func set_terrain(grid_pos: Vector2i, terrain_type: int) -> void:
	if not Constants.is_valid_grid_pos(grid_pos):
		return
	terrain_grid[grid_pos.x][grid_pos.y] = terrain_type
	terrain_changed.emit(grid_pos, terrain_type)
	queue_redraw()

func set_spice(grid_pos: Vector2i, amount: int) -> void:
	if amount <= 0:
		spice_amounts.erase(grid_pos)
		set_terrain(grid_pos, Constants.Terrain.SAND)
	else:
		spice_amounts[grid_pos] = clampi(amount, 1, 3)
		match amount:
			1: set_terrain(grid_pos, Constants.Terrain.SPICE_LOW)
			2: set_terrain(grid_pos, Constants.Terrain.SPICE_MEDIUM)
			_: set_terrain(grid_pos, Constants.Terrain.SPICE_HIGH)

func get_spice_amount(grid_pos: Vector2i) -> int:
	return spice_amounts.get(grid_pos, 0)

func harvest_spice(grid_pos: Vector2i, amount: int) -> int:
	var current = get_spice_amount(grid_pos)
	if current <= 0:
		return 0
	var harvested = mini(current, amount)
	set_spice(grid_pos, current - harvested)
	return harvested * Constants.SPICE_HARVEST_RATE

func is_buildable(grid_pos: Vector2i) -> bool:
	var terrain = get_terrain(grid_pos)
	return terrain == Constants.Terrain.ROCK or terrain == Constants.Terrain.CONCRETE

func is_passable(grid_pos: Vector2i) -> bool:
	var terrain = get_terrain(grid_pos)
	return terrain != Constants.Terrain.BUILDING and terrain != -1

func can_place_building(top_left: Vector2i, size: Vector2i, require_concrete: bool = true) -> bool:
	for x in range(size.x):
		for y in range(size.y):
			var check_pos = top_left + Vector2i(x, y)
			if not Constants.is_valid_grid_pos(check_pos):
				return false
			var terrain = get_terrain(check_pos)
			if terrain == Constants.Terrain.BUILDING:
				return false
			if require_concrete and terrain != Constants.Terrain.ROCK and terrain != Constants.Terrain.CONCRETE:
				return false
	return true

func place_building(top_left: Vector2i, size: Vector2i) -> void:
	for x in range(size.x):
		for y in range(size.y):
			var pos = top_left + Vector2i(x, y)
			set_terrain(pos, Constants.Terrain.BUILDING)

func remove_building(top_left: Vector2i, size: Vector2i) -> void:
	for x in range(size.x):
		for y in range(size.y):
			var pos = top_left + Vector2i(x, y)
			set_terrain(pos, Constants.Terrain.CONCRETE)

func place_concrete(grid_pos: Vector2i) -> void:
	if not Constants.is_valid_grid_pos(grid_pos):
		return
	var terrain = get_terrain(grid_pos)
	# Can place concrete on sand, rock, or spice (not on existing buildings)
	if terrain != Constants.Terrain.BUILDING and terrain != Constants.Terrain.CONCRETE:
		set_terrain(grid_pos, Constants.Terrain.CONCRETE)

func can_place_concrete(grid_pos: Vector2i) -> bool:
	if not Constants.is_valid_grid_pos(grid_pos):
		return false
	var terrain = get_terrain(grid_pos)
	return terrain != Constants.Terrain.BUILDING and terrain != Constants.Terrain.CONCRETE

func _draw() -> void:
	for x in range(Constants.MAP_WIDTH):
		for y in range(Constants.MAP_HEIGHT):
			var terrain = terrain_grid[x][y]
			var color = get_terrain_color(terrain)
			var rect = Rect2(
				x * Constants.TILE_SIZE,
				y * Constants.TILE_SIZE,
				Constants.TILE_SIZE,
				Constants.TILE_SIZE
			)
			draw_rect(rect, color)

			# Draw grid lines (subtle)
			draw_rect(rect, Color(0, 0, 0, 0.1), false, 1.0)

func get_terrain_color(terrain: int) -> Color:
	match terrain:
		Constants.Terrain.SAND:
			return Constants.COLORS["sand"]
		Constants.Terrain.ROCK:
			return Constants.COLORS["rock"]
		Constants.Terrain.SPICE_LOW:
			return Constants.COLORS["spice_low"]
		Constants.Terrain.SPICE_MEDIUM:
			return Constants.COLORS["spice_medium"]
		Constants.Terrain.SPICE_HIGH:
			return Constants.COLORS["spice_high"]
		Constants.Terrain.CONCRETE:
			return Constants.COLORS["concrete"]
		Constants.Terrain.BUILDING:
			return Constants.COLORS["concrete"].darkened(0.2)
		_:
			return Color.MAGENTA  # Debug color for unknown terrain
