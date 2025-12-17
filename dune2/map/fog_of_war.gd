extends Node2D
class_name FogOfWar

signal fog_state_changed(grid_pos: Vector2i, state: int)

# Visibility grid: stores FogState for each tile
var visibility_grid: Array = []

# Track what each unit/building can see
var vision_sources: Array = []  # Array of {position: Vector2i, range: int, active: bool}

func _ready() -> void:
	initialize_grid()

func initialize_grid() -> void:
	visibility_grid.clear()
	for x in range(Constants.MAP_WIDTH):
		var column = []
		for y in range(Constants.MAP_HEIGHT):
			column.append(Constants.FogState.UNEXPLORED)
		visibility_grid.append(column)

func get_visibility(grid_pos: Vector2i) -> int:
	if not Constants.is_valid_grid_pos(grid_pos):
		return Constants.FogState.UNEXPLORED
	return visibility_grid[grid_pos.x][grid_pos.y]

func is_tile_visible(grid_pos: Vector2i) -> bool:
	return get_visibility(grid_pos) == Constants.FogState.VISIBLE

func is_explored(grid_pos: Vector2i) -> bool:
	var state = get_visibility(grid_pos)
	return state == Constants.FogState.VISIBLE or state == Constants.FogState.EXPLORED

func add_vision_source(source_id: int, grid_pos: Vector2i, sight_range: int) -> void:
	vision_sources.append({
		"id": source_id,
		"position": grid_pos,
		"range": sight_range,
		"active": true
	})
	update_visibility()

func update_vision_source(source_id: int, grid_pos: Vector2i) -> void:
	for source in vision_sources:
		if source["id"] == source_id:
			source["position"] = grid_pos
			break
	update_visibility()

func remove_vision_source(source_id: int) -> void:
	for i in range(vision_sources.size() - 1, -1, -1):
		if vision_sources[i]["id"] == source_id:
			vision_sources.remove_at(i)
			break
	update_visibility()

func update_visibility() -> void:
	# First, set all VISIBLE tiles to EXPLORED
	for x in range(Constants.MAP_WIDTH):
		for y in range(Constants.MAP_HEIGHT):
			if visibility_grid[x][y] == Constants.FogState.VISIBLE:
				visibility_grid[x][y] = Constants.FogState.EXPLORED

	# Then reveal tiles from all vision sources
	for source in vision_sources:
		if not source["active"]:
			continue
		reveal_around(source["position"], source["range"])

	queue_redraw()

func reveal_around(center: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var pos = center + Vector2i(dx, dy)
			if not Constants.is_valid_grid_pos(pos):
				continue

			# Circular reveal
			if Vector2(dx, dy).length() <= radius:
				visibility_grid[pos.x][pos.y] = Constants.FogState.VISIBLE

func reveal_area(top_left: Vector2i, size: Vector2i) -> void:
	for x in range(size.x):
		for y in range(size.y):
			var pos = top_left + Vector2i(x, y)
			if Constants.is_valid_grid_pos(pos):
				visibility_grid[pos.x][pos.y] = Constants.FogState.VISIBLE
	queue_redraw()

func _draw() -> void:
	for x in range(Constants.MAP_WIDTH):
		for y in range(Constants.MAP_HEIGHT):
			var state = visibility_grid[x][y]
			var rect = Rect2(
				x * Constants.TILE_SIZE,
				y * Constants.TILE_SIZE,
				Constants.TILE_SIZE,
				Constants.TILE_SIZE
			)

			match state:
				Constants.FogState.UNEXPLORED:
					draw_rect(rect, Constants.COLORS["fog_unexplored"])
				Constants.FogState.EXPLORED:
					draw_rect(rect, Constants.COLORS["fog_explored"])
				# VISIBLE: draw nothing (fully visible)
