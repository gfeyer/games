extends Building
class_name LightFactory

var rally_point: Vector2

func _ready() -> void:
	building_type = "light_factory"
	super._ready()
	production_complete.connect(_on_unit_produced)

func _on_unit_produced(unit_type: String) -> void:
	# Signal to main game to spawn the unit
	pass

func get_spawn_position() -> Vector2:
	# Spawn position is at the side of the factory (with random offset to prevent stacking)
	var random_offset = Vector2(randf_range(0, 16), randf_range(-16, 16))
	return global_position + Vector2(grid_size.x * Constants.TILE_SIZE / 2 + 32, 0) + random_offset

func set_rally_point(pos: Vector2) -> void:
	rally_point = pos

func get_rally_point() -> Vector2:
	if rally_point == Vector2.ZERO:
		return get_spawn_position() + Vector2(32, 0)
	return rally_point

func _draw() -> void:
	super._draw()

	if not is_placed:
		return

	var size = Vector2(grid_size) * Constants.TILE_SIZE
	var offset = -size / 2

	# Draw factory details - large door
	var door_width = size.x * 0.5
	var door_height = size.y * 0.6
	var door_rect = Rect2(offset.x + size.x - door_width - 4, -door_height / 2, door_width, door_height)
	draw_rect(door_rect, Constants.COLORS["ui_background"].darkened(0.3))
	draw_rect(door_rect, Color.WHITE, false, 1.0)

	# Factory stripes
	for i in range(3):
		var stripe_y = offset.y + 8 + i * 12
		draw_line(Vector2(offset.x + 4, stripe_y), Vector2(offset.x + size.x * 0.4, stripe_y), Constants.COLORS["ui_highlight"], 2.0)

	# Smoke stack
	var stack_rect = Rect2(offset.x + 8, offset.y - 8, 12, 16)
	draw_rect(stack_rect, Constants.COLORS["ui_background"])

	# Production indicator
	if current_production != "":
		var progress_width = size.x * 0.8
		var progress_height = 6
		var progress_pos = Vector2(-progress_width / 2, size.y / 2 - 12)

		draw_rect(Rect2(progress_pos, Vector2(progress_width, progress_height)), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(progress_pos, Vector2(progress_width * get_production_percent(), progress_height)), Constants.COLORS["ui_highlight"])
