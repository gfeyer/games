extends Building
class_name Barracks

var rally_point: Vector2

func _ready() -> void:
	building_type = "barracks"
	super._ready()
	production_complete.connect(_on_unit_produced)

func _on_unit_produced(unit_type: String) -> void:
	# Signal to main game to spawn the unit
	pass

func get_spawn_position() -> Vector2:
	# Spawn position is at the front of the barracks
	return global_position + Vector2(0, grid_size.y * Constants.TILE_SIZE / 2 + 16)

func set_rally_point(pos: Vector2) -> void:
	rally_point = pos

func get_rally_point() -> Vector2:
	if rally_point == Vector2.ZERO:
		return get_spawn_position() + Vector2(0, 32)
	return rally_point

func _draw() -> void:
	super._draw()

	if not is_placed:
		return

	var size = Vector2(grid_size) * Constants.TILE_SIZE
	var offset = -size / 2

	# Draw barracks details - door/entrance
	var door_width = size.x * 0.4
	var door_height = size.y * 0.3
	var door_rect = Rect2(-door_width / 2, offset.y + size.y - door_height - 2, door_width, door_height)
	draw_rect(door_rect, Constants.COLORS["ui_background"])
	draw_rect(door_rect, Color.WHITE, false, 1.0)

	# Windows
	var window_size = 8
	draw_rect(Rect2(offset.x + 6, offset.y + 6, window_size, window_size), Constants.COLORS["ui_background"])
	draw_rect(Rect2(offset.x + size.x - window_size - 6, offset.y + 6, window_size, window_size), Constants.COLORS["ui_background"])

	# Production indicator
	if current_production != "":
		var progress_width = size.x * 0.8
		var progress_height = 6
		var progress_pos = Vector2(-progress_width / 2, size.y / 2 - 12)

		draw_rect(Rect2(progress_pos, Vector2(progress_width, progress_height)), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(progress_pos, Vector2(progress_width * get_production_percent(), progress_height)), Constants.COLORS["ui_highlight"])
