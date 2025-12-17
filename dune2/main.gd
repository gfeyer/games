extends Node2D

# Scene references
const ConstructionYardScene = preload("res://buildings/construction_yard.tscn")
const RefineryScene = preload("res://buildings/refinery.tscn")
const BarracksScene = preload("res://buildings/barracks.tscn")
const LightFactoryScene = preload("res://buildings/light_factory.tscn")
const HarvesterScene = preload("res://units/harvester.tscn")
const InfantryScene = preload("res://units/infantry.tscn")
const TankScene = preload("res://units/tank.tscn")

@onready var terrain_manager: TerrainManager = $TerrainManager
@onready var fog_of_war: FogOfWar = $FogOfWar
@onready var map_generator: MapGenerator = $MapGenerator
@onready var game_camera: GameCamera = $GameCamera
@onready var buildings_container: Node2D = $Buildings
@onready var units_container: Node2D = $Units
@onready var hud: CanvasLayer = $HUD
@onready var ai_controller: AIController = $AIController

# Selection
var selection_start: Vector2 = Vector2.ZERO
var is_selecting: bool = false
var selection_rect: Rect2 = Rect2()

# Building placement
var placement_mode: bool = false
var placement_building: String = ""
var placement_ghost: Node2D = null

func _ready() -> void:
	# Generate map
	map_generator.generate_map(terrain_manager)

	# Setup HUD
	hud.setup(terrain_manager, fog_of_war)
	hud.build_requested.connect(_on_build_requested)
	hud.minimap_clicked.connect(_on_minimap_clicked)

	# Start game
	GameManager.start_game()

	# Spawn starting bases
	spawn_starting_base(Constants.Faction.ATREIDES, Vector2i(6, 6))
	spawn_starting_base(Constants.Faction.HARKONNEN, Vector2i(Constants.MAP_WIDTH - 10, Constants.MAP_HEIGHT - 10))

	# Setup AI
	ai_controller.setup(self, terrain_manager, Constants.Faction.HARKONNEN)

	# Center camera on player base
	game_camera.center_on(Constants.grid_to_world(Vector2i(8, 8)))

func _process(_delta: float) -> void:
	update_fog_of_war()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)

func handle_mouse_button(event: InputEventMouseButton) -> void:
	var world_pos = game_camera.get_world_mouse_position()
	var grid_pos = Constants.world_to_grid(world_pos)

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if placement_mode:
				try_place_building(grid_pos)
			else:
				start_selection(world_pos)
		else:
			if is_selecting:
				finish_selection(world_pos)

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if placement_mode:
				cancel_placement()
			else:
				issue_command(world_pos)

func handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	if is_selecting:
		var world_pos = game_camera.get_world_mouse_position()
		update_selection_rect(world_pos)

	if placement_mode and placement_ghost:
		var world_pos = game_camera.get_world_mouse_position()
		var grid_pos = Constants.world_to_grid(world_pos)
		update_placement_ghost(grid_pos)

func start_selection(pos: Vector2) -> void:
	selection_start = pos
	is_selecting = true
	selection_rect = Rect2(pos, Vector2.ZERO)

func update_selection_rect(pos: Vector2) -> void:
	var top_left = Vector2(min(selection_start.x, pos.x), min(selection_start.y, pos.y))
	var size = Vector2(abs(pos.x - selection_start.x), abs(pos.y - selection_start.y))
	selection_rect = Rect2(top_left, size)

func finish_selection(pos: Vector2) -> void:
	is_selecting = false
	update_selection_rect(pos)

	# Clear previous selection
	for unit in GameManager.selected_units:
		if is_instance_valid(unit):
			unit.deselect()

	GameManager.clear_selection()

	# Check if it's a click or drag selection
	if selection_rect.size.length() < 10:
		# Click selection
		select_at_point(pos)
	else:
		# Box selection
		select_in_rect(selection_rect)

	selection_rect = Rect2()

func select_at_point(pos: Vector2) -> void:
	# First check for units
	for unit in get_tree().get_nodes_in_group("player_units"):
		if unit.global_position.distance_to(pos) < 20:
			unit.select()
			GameManager.select_units([unit])
			return

	# Then check for buildings
	for building in get_tree().get_nodes_in_group("player_buildings"):
		var building_rect = get_building_rect(building)
		if building_rect.has_point(pos):
			building.select()
			GameManager.select_building(building)
			return

func select_in_rect(rect: Rect2) -> void:
	var selected = []
	for unit in get_tree().get_nodes_in_group("player_units"):
		if rect.has_point(unit.global_position):
			unit.select()
			selected.append(unit)

	if not selected.is_empty():
		GameManager.select_units(selected)

func get_building_rect(building: Building) -> Rect2:
	var size = Vector2(building.grid_size) * Constants.TILE_SIZE
	var pos = building.global_position - size / 2
	return Rect2(pos, size)

func issue_command(pos: Vector2) -> void:
	var grid_pos = Constants.world_to_grid(pos)

	# Check if clicking on enemy
	var target = get_enemy_at(pos)

	for unit in GameManager.selected_units:
		if not is_instance_valid(unit):
			continue

		if target:
			unit.attack(target)
		elif unit is Harvester:
			# Harvesters go harvest spice
			unit.harvest_at(grid_pos)
		else:
			unit.move_to(pos)

func get_enemy_at(pos: Vector2) -> Node2D:
	for unit in get_tree().get_nodes_in_group("enemy_units"):
		if unit.global_position.distance_to(pos) < 20:
			return unit

	for building in get_tree().get_nodes_in_group("enemy_buildings"):
		var building_rect = get_building_rect(building)
		if building_rect.has_point(pos):
			return building

	return null

# Building placement
func enter_placement_mode(building_type: String) -> void:
	placement_mode = true
	placement_building = building_type
	# Create ghost would go here

func cancel_placement() -> void:
	placement_mode = false
	placement_building = ""
	if placement_ghost:
		placement_ghost.queue_free()
		placement_ghost = null

func update_placement_ghost(grid_pos: Vector2i) -> void:
	if placement_ghost:
		placement_ghost.global_position = Constants.grid_to_world(grid_pos)

func try_place_building(grid_pos: Vector2i) -> void:
	if placement_building == "":
		return

	var building_data = Constants.BUILDINGS.get(placement_building, {})
	var size = building_data.get("size", Vector2i(1, 1))

	if terrain_manager.can_place_building(grid_pos, size):
		spawn_building(placement_building, grid_pos, GameManager.player_faction)
		cancel_placement()

# Spawning
func spawn_starting_base(faction: int, pos: Vector2i) -> void:
	# Spawn Construction Yard
	var cy = spawn_building("construction_yard", pos, faction)

	# Spawn a harvester nearby
	var harvester_pos = Constants.grid_to_world(pos + Vector2i(4, 4))
	spawn_unit("harvester", harvester_pos, faction)

func spawn_building(type: String, grid_pos: Vector2i, faction: int) -> Building:
	var scene: PackedScene
	match type:
		"construction_yard": scene = ConstructionYardScene
		"refinery": scene = RefineryScene
		"barracks": scene = BarracksScene
		"light_factory": scene = LightFactoryScene
		_: return null

	var building = scene.instantiate()
	buildings_container.add_child(building)
	building.setup(type, grid_pos, faction)
	building.place(terrain_manager, fog_of_war)

	# Connect signals
	building.production_complete.connect(_on_building_production_complete.bind(building))

	return building

func spawn_unit(type: String, pos: Vector2, faction: int) -> Unit:
	var scene: PackedScene
	match type:
		"harvester": scene = HarvesterScene
		"infantry": scene = InfantryScene
		"tank": scene = TankScene
		_: return null

	var unit = scene.instantiate()
	units_container.add_child(unit)
	unit.setup(type, pos, faction)

	if unit is Harvester:
		unit.set_terrain_manager(terrain_manager)

	return unit

func _on_building_production_complete(item_id: String, building: Building) -> void:
	# Check if it's a unit or building
	if item_id in Constants.UNITS:
		var spawn_pos = building.global_position + Vector2(0, 50)
		if building.has_method("get_spawn_position"):
			spawn_pos = building.get_spawn_position()
		spawn_unit(item_id, spawn_pos, building.faction)

		# If it's a refinery that spawned, give it a harvester
		if item_id == "refinery" and building is ConstructionYard:
			pass  # Refinery spawns its own harvester

func update_fog_of_war() -> void:
	# Update vision from all player units and buildings
	for unit in get_tree().get_nodes_in_group("player_units"):
		var grid_pos = Constants.world_to_grid(unit.global_position)
		fog_of_war.update_vision_source(unit.vision_id, grid_pos)

func _draw() -> void:
	# Draw selection rectangle
	if is_selecting and selection_rect.size.length() > 5:
		draw_rect(selection_rect, Color(0, 1, 0, 0.3))
		draw_rect(selection_rect, Color(0, 1, 0, 0.8), false, 2.0)

func _on_build_requested(building_type: String) -> void:
	# Check if player has a construction yard and it's ready
	var cy = GameManager.get_construction_yard(GameManager.player_faction)
	if cy == null:
		return

	if cy is ConstructionYard and cy.is_in_placement_mode():
		# Already have a building ready to place
		enter_placement_mode(cy.get_pending_building())
	else:
		# Queue the building for production
		cy.queue_production(building_type, "building")

func _on_minimap_clicked(world_position: Vector2) -> void:
	game_camera.center_on(world_position)
