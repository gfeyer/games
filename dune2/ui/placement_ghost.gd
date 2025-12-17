extends Node2D

var building_type: String = ""
var grid_size: Vector2i = Vector2i(1, 1)
var is_valid: bool = false

func setup(type: String) -> void:
	building_type = type
	var data = Constants.BUILDINGS.get(type, {})
	grid_size = data.get("size", Vector2i(1, 1))

func set_valid(valid: bool) -> void:
	is_valid = valid
	queue_redraw()

func _draw() -> void:
	var size = Vector2(grid_size) * Constants.TILE_SIZE
	var offset = -Vector2(Constants.TILE_SIZE / 2, Constants.TILE_SIZE / 2)

	# Adjust offset for multi-tile buildings
	offset += Vector2((grid_size.x - 1) * Constants.TILE_SIZE / 2, (grid_size.y - 1) * Constants.TILE_SIZE / 2)

	var color = Color(0, 1, 0, 0.4) if is_valid else Color(1, 0, 0, 0.4)
	var border_color = Color(0, 1, 0, 0.8) if is_valid else Color(1, 0, 0, 0.8)

	draw_rect(Rect2(-size / 2, size), color)
	draw_rect(Rect2(-size / 2, size), border_color, false, 2.0)

	# Draw grid lines for multi-tile buildings
	if grid_size.x > 1 or grid_size.y > 1:
		for x in range(1, grid_size.x):
			var x_pos = -size.x / 2 + x * Constants.TILE_SIZE
			draw_line(Vector2(x_pos, -size.y / 2), Vector2(x_pos, size.y / 2), border_color, 1.0)
		for y in range(1, grid_size.y):
			var y_pos = -size.y / 2 + y * Constants.TILE_SIZE
			draw_line(Vector2(-size.x / 2, y_pos), Vector2(size.x / 2, y_pos), border_color, 1.0)
