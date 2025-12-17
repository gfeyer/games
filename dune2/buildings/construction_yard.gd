extends Building
class_name ConstructionYard

signal building_ready(building_type: String)

var pending_building: String = ""
var placement_mode: bool = false

func _ready() -> void:
	building_type = "construction_yard"
	super._ready()
	production_complete.connect(_on_production_complete)

func _on_production_complete(what: String) -> void:
	pending_building = what
	building_ready.emit(what)
	placement_mode = true

func get_pending_building() -> String:
	return pending_building

func clear_pending_building() -> void:
	pending_building = ""
	placement_mode = false

func is_in_placement_mode() -> bool:
	return placement_mode and pending_building != ""

func _draw() -> void:
	super._draw()

	if not is_placed:
		return

	var size = Vector2(grid_size) * Constants.TILE_SIZE
	var offset = -size / 2

	# Draw CY specific details - radar dish / dome
	var center = Vector2.ZERO
	var dome_radius = min(size.x, size.y) * 0.3

	# Main dome
	draw_circle(center, dome_radius, Constants.COLORS["atreides_light"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen_light"])
	draw_circle(center, dome_radius * 0.6, Constants.COLORS["ui_background"])

	# Production indicator
	if current_production != "":
		var progress_width = size.x * 0.8
		var progress_height = 6
		var progress_pos = Vector2(-progress_width / 2, size.y / 2 - 12)

		draw_rect(Rect2(progress_pos, Vector2(progress_width, progress_height)), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(progress_pos, Vector2(progress_width * get_production_percent(), progress_height)), Constants.COLORS["ui_highlight"])

	# Ready indicator
	if pending_building != "":
		var ready_text_pos = Vector2(0, size.y / 2 + 10)
		# Can't draw text directly, but we show it's ready via the production bar being full
		draw_circle(center + Vector2(0, dome_radius + 8), 4, Constants.COLORS["ui_highlight"])
