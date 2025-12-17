extends Area2D
class_name Building

signal selected
signal deselected
signal destroyed
signal production_complete(what: String)

@export var building_type: String = "building"
@export var faction: int = Constants.Faction.ATREIDES

var building_data: Dictionary = {}
var grid_position: Vector2i
var grid_size: Vector2i
var max_health: int = 100
var current_health: int = 100
var is_selected: bool = false
var is_placed: bool = false
var vision_id: int = 0

# Production queue
var production_queue: Array = []
var current_production: String = ""
var production_progress: float = 0.0
var production_time: float = 0.0

static var _next_vision_id: int = 1000

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("selectable")
	if faction == Constants.Faction.ATREIDES:
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_buildings")

	vision_id = _next_vision_id
	_next_vision_id += 1

	if building_type in Constants.BUILDINGS:
		building_data = Constants.BUILDINGS[building_type]
		max_health = building_data.get("health", 100)
		current_health = max_health
		grid_size = building_data.get("size", Vector2i(1, 1))

func _process(delta: float) -> void:
	if current_production != "" and is_placed:
		process_production(delta)

func setup(type: String, pos: Vector2i, owner_faction: int) -> void:
	building_type = type
	grid_position = pos
	faction = owner_faction

	if type in Constants.BUILDINGS:
		building_data = Constants.BUILDINGS[type]
		max_health = building_data.get("health", 100)
		current_health = max_health
		grid_size = building_data.get("size", Vector2i(1, 1))

	# Position at center of building footprint
	var world_pos = Constants.grid_to_world(pos)
	world_pos += Vector2((grid_size.x - 1) * Constants.TILE_SIZE / 2, (grid_size.y - 1) * Constants.TILE_SIZE / 2)
	global_position = world_pos

	queue_redraw()

func place(terrain_manager: TerrainManager, fog: FogOfWar) -> void:
	is_placed = true
	terrain_manager.place_building(grid_position, grid_size)

	# Add vision
	var sight_range = building_data.get("sight_range", 3)
	var center = grid_position + grid_size / 2
	fog.add_vision_source(vision_id, center, sight_range)

	GameManager.register_building(self, faction)

func take_damage(damage: int) -> void:
	current_health -= damage
	queue_redraw()
	if current_health <= 0:
		die()

func die() -> void:
	destroyed.emit()
	GameManager.unregister_building(self, faction)
	queue_free()

func select() -> void:
	is_selected = true
	selected.emit()
	queue_redraw()

func deselect() -> void:
	is_selected = false
	deselected.emit()
	queue_redraw()

func get_health_percent() -> float:
	return float(current_health) / float(max_health)

# Production methods
func can_produce() -> bool:
	return building_data.get("produces", null) != null

func get_produceable_items() -> Array:
	var produces = building_data.get("produces", null)
	if produces == null:
		return []

	var items = []
	match produces:
		"buildings":
			for key in Constants.BUILDINGS:
				if key != "construction_yard":  # Can't build another CY
					items.append({"type": "building", "id": key, "data": Constants.BUILDINGS[key]})
		"infantry":
			items.append({"type": "unit", "id": "infantry", "data": Constants.UNITS["infantry"]})
		"vehicles":
			items.append({"type": "unit", "id": "harvester", "data": Constants.UNITS["harvester"]})
			items.append({"type": "unit", "id": "tank", "data": Constants.UNITS["tank"]})
	return items

func queue_production(item_id: String, item_type: String) -> bool:
	var cost = 0
	var time = 0.0

	if item_type == "building" and item_id in Constants.BUILDINGS:
		cost = Constants.BUILDINGS[item_id]["cost"]
		time = Constants.BUILDINGS[item_id]["build_time"]
	elif item_type == "unit" and item_id in Constants.UNITS:
		cost = Constants.UNITS[item_id]["cost"]
		time = Constants.UNITS[item_id]["build_time"]
	else:
		return false

	if not GameManager.can_afford(faction, cost):
		return false

	GameManager.spend_credits(faction, cost)
	production_queue.append({"id": item_id, "type": item_type, "time": time})

	if current_production == "":
		start_next_production()

	return true

func start_next_production() -> void:
	if production_queue.is_empty():
		current_production = ""
		production_progress = 0.0
		return

	var next_item = production_queue[0]
	current_production = next_item["id"]
	production_time = next_item["time"]
	production_progress = 0.0

func process_production(delta: float) -> void:
	if current_production == "":
		return

	production_progress += delta
	if production_progress >= production_time:
		complete_production()

func complete_production() -> void:
	var completed_item = production_queue.pop_front()
	production_complete.emit(completed_item["id"])
	current_production = ""
	production_progress = 0.0

	# Start next item in queue
	start_next_production()

func get_production_percent() -> float:
	if production_time <= 0:
		return 0.0
	return production_progress / production_time

func _draw() -> void:
	if not is_placed:
		return

	var size = Vector2(grid_size) * Constants.TILE_SIZE
	var offset = -size / 2

	# Building base color (faction colored)
	var base_color = Constants.COLORS["atreides"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen"]
	draw_rect(Rect2(offset, size), base_color)

	# Building border
	var border_color = Constants.COLORS["atreides_light"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen_light"]
	draw_rect(Rect2(offset, size), border_color, false, 2.0)

	# Selection indicator
	if is_selected:
		draw_rect(Rect2(offset - Vector2(2, 2), size + Vector2(4, 4)), Color.WHITE, false, 2.0)

	# Health bar
	var health_bar_width = size.x - 4
	var health_bar_height = 4
	var health_bar_pos = Vector2(offset.x + 2, offset.y - 8)

	# Background
	draw_rect(Rect2(health_bar_pos, Vector2(health_bar_width, health_bar_height)), Color(0.2, 0.2, 0.2))

	# Health fill
	var health_percent = get_health_percent()
	var health_color = Constants.COLORS["health_green"]
	if health_percent < 0.3:
		health_color = Constants.COLORS["health_red"]
	elif health_percent < 0.6:
		health_color = Constants.COLORS["health_yellow"]

	draw_rect(Rect2(health_bar_pos, Vector2(health_bar_width * health_percent, health_bar_height)), health_color)
