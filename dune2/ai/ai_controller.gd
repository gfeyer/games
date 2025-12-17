extends Node
class_name AIController

var faction: int = Constants.Faction.HARKONNEN
var terrain_manager: TerrainManager
var main_game: Node2D

var think_timer: float = 0.0
var think_interval: float = 2.0

var attack_timer: float = 0.0
var attack_interval: float = 60.0  # Attack every 60 seconds

enum AIState { BUILDING, HARVESTING, ATTACKING }
var state: AIState = AIState.BUILDING

var build_order: Array = ["refinery", "barracks", "light_factory"]
var build_index: int = 0

func _ready() -> void:
	pass

func setup(game: Node2D, tm: TerrainManager, ai_faction: int) -> void:
	main_game = game
	terrain_manager = tm
	faction = ai_faction

func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return

	think_timer += delta
	attack_timer += delta

	if think_timer >= think_interval:
		think_timer = 0.0
		think()

	if attack_timer >= attack_interval:
		attack_timer = 0.0
		launch_attack()

func think() -> void:
	match state:
		AIState.BUILDING:
			try_build()
		AIState.HARVESTING:
			manage_harvesters()
		AIState.ATTACKING:
			manage_combat()

	# Always try to produce units if we have credits
	try_produce_units()

func try_build() -> void:
	var cy = GameManager.get_construction_yard(faction)
	if cy == null or cy.current_production != "":
		return

	if build_index >= build_order.size():
		state = AIState.HARVESTING
		return

	var building_to_build = build_order[build_index]
	var cost = Constants.BUILDINGS[building_to_build]["cost"]

	if GameManager.can_afford(faction, cost):
		# Queue the building
		cy.queue_production(building_to_build, "building")
		build_index += 1

func try_produce_units() -> void:
	var buildings = GameManager.get_buildings(faction)

	for building in buildings:
		if not is_instance_valid(building):
			continue

		if building.current_production != "":
			continue

		if building is Barracks:
			if GameManager.can_afford(faction, Constants.UNITS["infantry"]["cost"]):
				building.queue_production("infantry", "unit")

		elif building is LightFactory:
			var units = GameManager.get_units(faction)
			var harvester_count = 0
			for unit in units:
				if unit is Harvester:
					harvester_count += 1

			# Keep at least 2 harvesters
			if harvester_count < 2 and GameManager.can_afford(faction, Constants.UNITS["harvester"]["cost"]):
				building.queue_production("harvester", "unit")
			elif GameManager.can_afford(faction, Constants.UNITS["tank"]["cost"]):
				building.queue_production("tank", "unit")

func manage_harvesters() -> void:
	var units = GameManager.get_units(faction)
	for unit in units:
		if unit is Harvester:
			if unit.state == Harvester.HarvesterState.IDLE:
				var grid_pos = unit.get_grid_position()
				unit.harvest_at(grid_pos)

func manage_combat() -> void:
	pass

func launch_attack() -> void:
	var units = GameManager.get_units(faction)
	var attack_force: Array = []

	for unit in units:
		if unit is Harvester:
			continue
		attack_force.append(unit)

	if attack_force.size() < 3:
		return  # Don't attack with too few units

	# Find player construction yard
	var player_cy = GameManager.get_construction_yard(GameManager.player_faction)
	if player_cy == null:
		# Player has no CY, find any player building
		var player_buildings = GameManager.get_buildings(GameManager.player_faction)
		if player_buildings.is_empty():
			return
		player_cy = player_buildings[0]

	# Send units to attack
	for unit in attack_force:
		if is_instance_valid(unit) and is_instance_valid(player_cy):
			unit.attack(player_cy)
