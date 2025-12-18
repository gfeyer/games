extends Node

signal credits_changed(faction: int, amount: int)
signal building_placed(building: Node2D)
signal building_destroyed(building: Node2D)
signal unit_created(unit: Node2D)
signal unit_destroyed(unit: Node2D)
signal game_over(winner: int)
signal selection_changed(selected: Array)

# =============================================================================
# DEBUG SETTINGS - Set these to speed up testing
# =============================================================================
## Game speed multiplier (1.0 = normal, 2.0 = 2x speed, etc.)
@export var debug_game_speed: float = 2.0
## Production speed multiplier for buildings (1.0 = normal)
@export var debug_production_speed: float = 3.0
## Harvesting speed multiplier (1.0 = normal)
@export var debug_harvest_speed: float = 3.0
## Starting credits multiplier (1.0 = normal, 10.0 = 10x starting credits)
@export var debug_credits_multiplier: float = 1.0
## Give player extra credits at start
@export var debug_bonus_credits: int = 5000
# =============================================================================

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

var current_state: GameState = GameState.MENU

# Resources per faction
var credits: Dictionary = {
	Constants.Faction.ATREIDES: Constants.STARTING_CREDITS,
	Constants.Faction.HARKONNEN: Constants.STARTING_CREDITS
}

# Track all buildings and units
var buildings: Dictionary = {
	Constants.Faction.ATREIDES: [],
	Constants.Faction.HARKONNEN: []
}

var units: Dictionary = {
	Constants.Faction.ATREIDES: [],
	Constants.Faction.HARKONNEN: []
}

# Current selection (player only)
var selected_units: Array = []
var selected_building: Node2D = null

# Player faction
var player_faction: int = Constants.Faction.ATREIDES
var enemy_faction: int = Constants.Faction.HARKONNEN

func _ready() -> void:
	# Apply debug game speed
	if debug_game_speed != 1.0:
		Engine.time_scale = debug_game_speed

func start_game() -> void:
	current_state = GameState.PLAYING
	# Apply debug credits multiplier and bonus
	var starting = int(Constants.STARTING_CREDITS * debug_credits_multiplier) + debug_bonus_credits
	credits[Constants.Faction.ATREIDES] = starting
	credits[Constants.Faction.HARKONNEN] = int(Constants.STARTING_CREDITS * debug_credits_multiplier)

func get_credits(faction: int) -> int:
	return credits.get(faction, 0)

func add_credits(faction: int, amount: int) -> void:
	credits[faction] = credits.get(faction, 0) + amount
	credits_changed.emit(faction, credits[faction])

func spend_credits(faction: int, amount: int) -> bool:
	if credits.get(faction, 0) >= amount:
		credits[faction] -= amount
		credits_changed.emit(faction, credits[faction])
		return true
	return false

func can_afford(faction: int, amount: int) -> bool:
	return credits.get(faction, 0) >= amount

func register_building(building: Node2D, faction: int) -> void:
	if not buildings.has(faction):
		buildings[faction] = []
	buildings[faction].append(building)
	building_placed.emit(building)

func unregister_building(building: Node2D, faction: int) -> void:
	if buildings.has(faction):
		buildings[faction].erase(building)
	building_destroyed.emit(building)
	check_game_over(faction)

func register_unit(unit: Node2D, faction: int) -> void:
	if not units.has(faction):
		units[faction] = []
	units[faction].append(unit)
	unit_created.emit(unit)

func unregister_unit(unit: Node2D, faction: int) -> void:
	if units.has(faction):
		units[faction].erase(unit)
	selected_units.erase(unit)
	unit_destroyed.emit(unit)

func get_buildings(faction: int) -> Array:
	return buildings.get(faction, [])

func get_units(faction: int) -> Array:
	return units.get(faction, [])

func get_construction_yard(faction: int) -> Node2D:
	for building in buildings.get(faction, []):
		if building.building_type == "construction_yard":
			return building
	return null

func get_refineries(faction: int) -> Array:
	var refs = []
	for building in buildings.get(faction, []):
		if building.building_type == "refinery":
			refs.append(building)
	return refs

func select_units(new_selection: Array) -> void:
	selected_units = new_selection
	selected_building = null
	selection_changed.emit(selected_units)

func select_building(building: Node2D) -> void:
	selected_units = []
	selected_building = building
	selection_changed.emit([building] if building else [])

func clear_selection() -> void:
	selected_units = []
	selected_building = null
	selection_changed.emit([])

func check_game_over(faction: int) -> void:
	# Check if faction lost their construction yard
	var cy = get_construction_yard(faction)
	if cy == null and current_state == GameState.PLAYING:
		var winner = enemy_faction if faction == player_faction else player_faction
		current_state = GameState.GAME_OVER
		game_over.emit(winner)

func is_playing() -> bool:
	return current_state == GameState.PLAYING
