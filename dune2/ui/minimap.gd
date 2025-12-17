extends Control
class_name Minimap

signal clicked(world_position: Vector2)

@export var minimap_size: Vector2 = Vector2(180, 180)

var terrain_manager: TerrainManager
var fog_of_war: FogOfWar
var game_camera: GameCamera
var scale_factor: Vector2

func _ready() -> void:
	custom_minimum_size = minimap_size
	calculate_scale()

func setup(tm: TerrainManager, fog: FogOfWar, camera: GameCamera = null) -> void:
	terrain_manager = tm
	fog_of_war = fog
	game_camera = camera
	calculate_scale()

func calculate_scale() -> void:
	var map_pixel_size = Vector2(Constants.MAP_WIDTH, Constants.MAP_HEIGHT)
	scale_factor = minimap_size / map_pixel_size

func _process(_delta: float) -> void:
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = get_local_mouse_position()
			var grid_pos = Vector2i(local_pos / scale_factor)
			var world_pos = Constants.grid_to_world(grid_pos)
			clicked.emit(world_pos)

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, minimap_size), Constants.COLORS["fog_unexplored"])

	if not terrain_manager:
		return

	# Draw terrain
	for x in range(Constants.MAP_WIDTH):
		for y in range(Constants.MAP_HEIGHT):
			var pos = Vector2(x, y) * scale_factor
			var rect_size = scale_factor + Vector2(1, 1)  # Slight overlap to avoid gaps

			# Check fog
			var fog_state = Constants.FogState.VISIBLE
			if fog_of_war:
				fog_state = fog_of_war.get_visibility(Vector2i(x, y))

			if fog_state == Constants.FogState.UNEXPLORED:
				continue  # Leave as black

			var terrain = terrain_manager.get_terrain(Vector2i(x, y))
			var color = terrain_manager.get_terrain_color(terrain)

			if fog_state == Constants.FogState.EXPLORED:
				color = color.darkened(0.5)

			draw_rect(Rect2(pos, rect_size), color)

	# Draw buildings
	for building in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(building):
			continue

		var grid_pos = building.grid_position
		var grid_size = building.grid_size

		# Check if visible
		if fog_of_war and not fog_of_war.is_explored(grid_pos):
			continue

		var pos = Vector2(grid_pos) * scale_factor
		var rect_size = Vector2(grid_size) * scale_factor

		var color = Constants.COLORS["atreides"] if building.faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen"]
		draw_rect(Rect2(pos, rect_size), color)

	# Draw units
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue

		var grid_pos = unit.get_grid_position()

		# Check if visible
		if fog_of_war and not fog_of_war.is_tile_visible(grid_pos):
			continue

		var pos = Vector2(grid_pos) * scale_factor
		var color = Constants.COLORS["atreides_light"] if unit.faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen_light"]

		draw_circle(pos + scale_factor / 2, 2, color)

	# Draw camera viewport rectangle
	if game_camera:
		var view_rect = game_camera.get_view_rect()
		# Convert world coordinates to grid coordinates, then to minimap coordinates
		var view_grid_pos = view_rect.position / Constants.TILE_SIZE
		var view_grid_size = view_rect.size / Constants.TILE_SIZE
		var minimap_rect_pos = view_grid_pos * scale_factor
		var minimap_rect_size = view_grid_size * scale_factor
		# Clamp to minimap bounds
		minimap_rect_pos = minimap_rect_pos.clamp(Vector2.ZERO, minimap_size)
		var max_size = minimap_size - minimap_rect_pos
		minimap_rect_size = minimap_rect_size.clamp(Vector2.ZERO, max_size)
		draw_rect(Rect2(minimap_rect_pos, minimap_rect_size), Color.WHITE, false, 2.0)

	# Draw border
	draw_rect(Rect2(Vector2.ZERO, minimap_size), Constants.COLORS["ui_border"], false, 2.0)
