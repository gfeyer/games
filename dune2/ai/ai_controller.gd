extends Node
class_name AIController

var faction: int = Constants.Faction.HARKONNEN
var terrain_manager: TerrainManager
var fog_of_war: FogOfWar
var main_game: Node2D

# Timers
var think_timer: float = 0.0
var think_interval: float = 1.0  # Think every second
var building_timer: float = 0.0
var building_interval: float = 5.0  # Check building needs every 5 seconds
var attack_timer: float = 0.0
var attack_interval: float = 50.0  # Medium difficulty: 45-60 seconds

# AI States
enum AIState { STARTUP, ECONOMY, MILITARY, ATTACK }
var state: AIState = AIState.STARTUP

# Building priorities (type, min_count, priority)
var build_priorities: Array = [
	{"type": "refinery", "min_count": 1, "priority": 100},
	{"type": "barracks", "min_count": 1, "priority": 80},
	{"type": "light_factory", "min_count": 1, "priority": 70},
	{"type": "refinery", "min_count": 2, "priority": 50},
]

# Unit production ratios
var unit_ratios: Dictionary = {
	"infantry": 0.6,
	"tank": 0.4
}

# Attack settings (Medium difficulty)
var min_attack_force: int = 5
var attack_squad: Array = []

# Economy tracking
var desired_harvesters_per_refinery: int = 1

func _ready() -> void:
	# Randomize attack interval slightly
	attack_interval = randf_range(45.0, 60.0)

func setup(game: Node2D, tm: TerrainManager, ai_faction: int, fog: FogOfWar = null) -> void:
	main_game = game
	terrain_manager = tm
	faction = ai_faction
	fog_of_war = fog

func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return

	think_timer += delta
	building_timer += delta
	attack_timer += delta

	# Fast think cycle
	if think_timer >= think_interval:
		think_timer = 0.0
		think()

	# Slower building check
	if building_timer >= building_interval:
		building_timer = 0.0
		check_building_needs()

	# Attack timing
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		evaluate_attack()

func think() -> void:
	manage_harvesters()
	try_produce_units()
	check_threats()

func check_building_needs() -> void:
	var cy = GameManager.get_construction_yard(faction)
	if cy == null or cy.current_production != "":
		return

	# Count existing buildings
	var building_counts: Dictionary = {}
	var buildings = GameManager.get_buildings(faction)
	for building in buildings:
		if not is_instance_valid(building):
			continue
		var btype = building.building_type
		building_counts[btype] = building_counts.get(btype, 0) + 1

	# Find highest priority building we need
	var best_priority: int = -1
	var building_to_build: String = ""

	for priority_entry in build_priorities:
		var btype = priority_entry["type"]
		var min_count = priority_entry["min_count"]
		var priority = priority_entry["priority"]

		var current_count = building_counts.get(btype, 0)
		if current_count < min_count and priority > best_priority:
			var cost = Constants.BUILDINGS[btype]["cost"]
			if GameManager.can_afford(faction, cost):
				best_priority = priority
				building_to_build = btype

	if building_to_build != "":
		cy.queue_production(building_to_build, "building")
		# Connect to placement when complete
		if not cy.production_complete.is_connected(_on_building_ready):
			cy.production_complete.connect(_on_building_ready)

func _on_building_ready(building_type: String) -> void:
	# Find a valid placement location and place the building
	if building_type in Constants.BUILDINGS:
		var location = find_build_location(building_type)
		if location != Vector2i(-1, -1):
			place_ai_building(building_type, location)

func find_build_location(building_type: String) -> Vector2i:
	var cy = GameManager.get_construction_yard(faction)
	if cy == null:
		return Vector2i(-1, -1)

	var cy_pos = cy.grid_position
	var building_size = Constants.BUILDINGS[building_type].get("size", Vector2i(2, 2))

	# Search outward from CY in a spiral pattern
	var search_radius = 15
	var best_pos = Vector2i(-1, -1)
	var best_distance = 999999.0

	for radius in range(2, search_radius):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				# Only check positions at current radius ring
				if abs(dx) != radius and abs(dy) != radius:
					continue

				var check_pos = cy_pos + Vector2i(dx, dy)

				# Validate position
				if not is_valid_build_position(check_pos, building_size):
					continue

				# Prefer positions closer to existing buildings
				var distance = Vector2(check_pos - cy_pos).length()

				# Avoid blocking refinery dock areas
				if building_type != "refinery":
					var refineries = get_buildings_of_type("refinery")
					var blocks_dock = false
					for ref in refineries:
						var dock_area = Rect2i(ref.grid_position + Vector2i(-1, ref.grid_size.y), Vector2i(4, 2))
						var building_rect = Rect2i(check_pos, building_size)
						if dock_area.intersects(building_rect):
							blocks_dock = true
							break
					if blocks_dock:
						continue

				if distance < best_distance:
					best_distance = distance
					best_pos = check_pos

	return best_pos

func is_valid_build_position(pos: Vector2i, size: Vector2i) -> bool:
	# Check map bounds
	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x + size.x > Constants.MAP_WIDTH or pos.y + size.y > Constants.MAP_HEIGHT:
		return false

	# Check terrain
	if terrain_manager == null:
		return false

	for x in range(size.x):
		for y in range(size.y):
			var check_pos = pos + Vector2i(x, y)
			if not terrain_manager.can_place_building(check_pos, Vector2i(1, 1)):
				return false

	return true

func place_ai_building(building_type: String, grid_pos: Vector2i) -> void:
	if main_game == null or not main_game.has_method("place_building_at"):
		# Fallback: call main_game directly if method exists
		return

	main_game.place_building_at(building_type, grid_pos, faction)

func get_buildings_of_type(building_type: String) -> Array:
	var result: Array = []
	var buildings = GameManager.get_buildings(faction)
	for building in buildings:
		if is_instance_valid(building) and building.building_type == building_type:
			result.append(building)
	return result

func manage_harvesters() -> void:
	var units = GameManager.get_units(faction)
	var refineries = get_buildings_of_type("refinery")
	var harvester_count = 0

	for unit in units:
		if unit is Harvester:
			harvester_count += 1
			# Send idle harvesters to harvest
			if unit.state == Harvester.HarvesterState.IDLE:
				var grid_pos = unit.get_grid_position()
				unit.harvest_at(grid_pos)

	# Track desired harvester count for production
	var desired_harvesters = refineries.size() * desired_harvesters_per_refinery
	if desired_harvesters < 1:
		desired_harvesters = 1  # Always want at least 1 harvester

func try_produce_units() -> void:
	var buildings = GameManager.get_buildings(faction)
	var units = GameManager.get_units(faction)

	# Count current units
	var infantry_count = 0
	var tank_count = 0
	var harvester_count = 0

	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit is Harvester:
			harvester_count += 1
		elif unit.unit_type == "infantry":
			infantry_count += 1
		elif unit.unit_type == "tank":
			tank_count += 1

	# Check harvester needs
	var refineries = get_buildings_of_type("refinery")
	var desired_harvesters = max(1, refineries.size())

	for building in buildings:
		if not is_instance_valid(building):
			continue
		if building.current_production != "":
			continue

		if building is Barracks:
			# Produce infantry
			if GameManager.can_afford(faction, Constants.UNITS["infantry"]["cost"]):
				building.queue_production("infantry", "unit")

		elif building is LightFactory:
			# Priority: harvesters first, then combat units
			if harvester_count < desired_harvesters:
				if GameManager.can_afford(faction, Constants.UNITS["harvester"]["cost"]):
					building.queue_production("harvester", "unit")
			else:
				# Balance tanks and infantry based on ratios
				var total_combat = infantry_count + tank_count
				var current_tank_ratio = 0.0 if total_combat == 0 else float(tank_count) / total_combat

				if current_tank_ratio < unit_ratios["tank"]:
					# Need more tanks
					if GameManager.can_afford(faction, Constants.UNITS["tank"]["cost"]):
						building.queue_production("tank", "unit")
				else:
					# Build tank anyway if we can afford it
					if GameManager.can_afford(faction, Constants.UNITS["tank"]["cost"]):
						building.queue_production("tank", "unit")

func check_threats() -> void:
	# Check if any of our buildings are under attack
	var buildings = GameManager.get_buildings(faction)
	for building in buildings:
		if not is_instance_valid(building):
			continue
		# Check health - if damaged, something attacked us
		if building.current_health < building.max_health:
			defend_base()
			break

func defend_base() -> void:
	# Find enemy units near our base
	var cy = GameManager.get_construction_yard(faction)
	if cy == null:
		return

	var enemy_units = GameManager.get_units(GameManager.player_faction)
	var nearby_enemies: Array = []

	for enemy in enemy_units:
		if not is_instance_valid(enemy):
			continue
		var distance = cy.global_position.distance_to(enemy.global_position)
		if distance < 300:  # Within base defense range
			nearby_enemies.append(enemy)

	if nearby_enemies.is_empty():
		return

	# Send idle combat units to defend
	var our_units = GameManager.get_units(faction)
	for unit in our_units:
		if not is_instance_valid(unit):
			continue
		if unit is Harvester:
			continue
		if not unit.is_moving and unit.attack_target == null:
			# Attack nearest enemy
			var target = nearby_enemies[0]
			unit.attack(target)

func evaluate_attack() -> void:
	var units = GameManager.get_units(faction)
	attack_squad.clear()

	# Gather combat units
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit is Harvester:
			continue
		attack_squad.append(unit)

	# Check if we have enough force
	if attack_squad.size() < min_attack_force:
		return

	launch_attack()

func launch_attack() -> void:
	if attack_squad.is_empty():
		return

	# Find attack target
	var target = find_attack_target()
	if target == null:
		return

	# Send squad to attack
	for unit in attack_squad:
		if is_instance_valid(unit) and is_instance_valid(target):
			unit.attack(target)

	# Reset attack timer with some randomness
	attack_interval = randf_range(45.0, 60.0)

func find_attack_target() -> Node2D:
	var player_units = GameManager.get_units(GameManager.player_faction)
	var player_buildings = GameManager.get_buildings(GameManager.player_faction)

	# First, check for nearby enemy units (prioritize threats)
	var cy = GameManager.get_construction_yard(faction)
	if cy != null:
		for enemy in player_units:
			if not is_instance_valid(enemy):
				continue
			var distance = cy.global_position.distance_to(enemy.global_position)
			if distance < 400:
				return enemy

	# Target priority for buildings: refinery > barracks > CY
	var target_priority = ["refinery", "barracks", "construction_yard", "light_factory"]

	for target_type in target_priority:
		for building in player_buildings:
			if not is_instance_valid(building):
				continue
			if building.building_type == target_type:
				return building

	# Fallback: any building
	for building in player_buildings:
		if is_instance_valid(building):
			return building

	# Last resort: any unit
	for unit in player_units:
		if is_instance_valid(unit):
			return unit

	return null
