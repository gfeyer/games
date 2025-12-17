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
@onready var selection_box: Node2D = $SelectionBox

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
	hud.setup(terrain_manager, fog_of_war, game_camera)
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
	update_enemy_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			handle_escape()

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
	selection_box.set_selection(selection_rect, is_selecting)

func finish_selection(pos: Vector2) -> void:
	is_selecting = false
	update_selection_rect(pos)

	# Clear previous selection
	for unit in GameManager.selected_units:
		if is_instance_valid(unit):
			unit.deselect()

	# Also deselect building
	if GameManager.selected_building and is_instance_valid(GameManager.selected_building):
		GameManager.selected_building.deselect()

	GameManager.clear_selection()

	# Check if it's a click or drag selection
	if selection_rect.size.length() < 10:
		# Click selection
		select_at_point(pos)
	else:
		# Box selection
		select_in_rect(selection_rect)

	selection_rect = Rect2()
	selection_start = Vector2.ZERO
	selection_box.set_selection(selection_rect, false)

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

	# Check if clicking on friendly refinery (for harvesters)
	var refinery = get_friendly_refinery_at(pos)

	for unit in GameManager.selected_units:
		if not is_instance_valid(unit):
			continue

		if target:
			unit.attack(target)
		elif unit is Harvester:
			if refinery:
				# Send harvester to specific refinery
				unit.force_return_to_refinery(refinery)
			else:
				# Harvesters go harvest spice
				unit.harvest_at(grid_pos)
		else:
			unit.move_to(pos)

func get_friendly_refinery_at(pos: Vector2) -> Refinery:
	for building in get_tree().get_nodes_in_group("player_buildings"):
		if building is Refinery:
			var building_rect = get_building_rect(building)
			if building_rect.has_point(pos):
				return building
	return null

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

	# Create placement ghost
	if placement_ghost:
		placement_ghost.queue_free()

	placement_ghost = Node2D.new()
	placement_ghost.set_script(preload("res://ui/placement_ghost.gd"))
	placement_ghost.setup(building_type)
	add_child(placement_ghost)

func handle_escape() -> void:
	if placement_mode:
		cancel_placement()
	else:
		# Deselect all units and buildings
		for unit in GameManager.selected_units:
			if is_instance_valid(unit):
				unit.deselect()
		if GameManager.selected_building and is_instance_valid(GameManager.selected_building):
			GameManager.selected_building.deselect()
		GameManager.clear_selection()

func cancel_placement() -> void:
	placement_mode = false
	placement_building = ""
	if placement_ghost:
		placement_ghost.queue_free()
		placement_ghost = null

	# Clear CY pending building
	var cy = GameManager.get_construction_yard(GameManager.player_faction)
	if cy and cy is ConstructionYard:
		cy.clear_pending_building()

func update_placement_ghost(grid_pos: Vector2i) -> void:
	if placement_ghost:
		placement_ghost.global_position = Constants.grid_to_world(grid_pos)
		# Use correct validation for concrete vs buildings
		if placement_building == "concrete":
			placement_ghost.set_valid(terrain_manager.can_place_concrete(grid_pos))
		else:
			placement_ghost.set_valid(terrain_manager.can_place_building(grid_pos, placement_ghost.grid_size))

func try_place_building(grid_pos: Vector2i) -> void:
	if placement_building == "":
		return

	# Handle concrete specially - just modify terrain
	if placement_building == "concrete":
		if not terrain_manager.can_place_concrete(grid_pos):
			return
		terrain_manager.place_concrete(grid_pos)
		# Clear CY pending
		var cy = GameManager.get_construction_yard(GameManager.player_faction)
		if cy and cy is ConstructionYard:
			cy.clear_pending_building()
		cancel_placement()
		return

	var building_data = Constants.BUILDINGS.get(placement_building, {})
	var size = building_data.get("size", Vector2i(1, 1))

	if not terrain_manager.can_place_building(grid_pos, size):
		return

	# Spawn the building
	var building = spawn_building(placement_building, grid_pos, GameManager.player_faction)
	if building:
		# Clear CY pending
		var cy = GameManager.get_construction_yard(GameManager.player_faction)
		if cy and cy is ConstructionYard:
			cy.clear_pending_building()
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

	# Register player units as vision sources for fog of war
	if faction == Constants.Faction.ATREIDES:
		var grid_pos = Constants.world_to_grid(pos)
		fog_of_war.add_vision_source(unit.vision_id, grid_pos, unit.sight_range)
		unit.destroyed.connect(_on_unit_destroyed.bind(unit))

	return unit

func _on_building_production_complete(item_id: String, building: Building) -> void:
	# Check if it's a unit or building
	if item_id in Constants.UNITS:
		var spawn_pos = building.global_position + Vector2(0, 50)
		if building.has_method("get_spawn_position"):
			spawn_pos = building.get_spawn_position()
		spawn_unit(item_id, spawn_pos, building.faction)
	elif item_id in Constants.BUILDINGS:
		# Building completed - automatically enter placement mode for player
		if building.faction == GameManager.player_faction and building is ConstructionYard:
			enter_placement_mode(item_id)
		# AI buildings are handled by ai_controller via place_building_at

func place_building_at(building_type: String, grid_pos: Vector2i, faction: int) -> Building:
	# Used by AI to place buildings directly
	var building_data = Constants.BUILDINGS.get(building_type, {})
	var size = building_data.get("size", Vector2i(1, 1))

	if not terrain_manager.can_place_building(grid_pos, size):
		return null

	return spawn_building(building_type, grid_pos, faction)

func update_fog_of_war() -> void:
	# Update vision from all player units and buildings
	for unit in get_tree().get_nodes_in_group("player_units"):
		var grid_pos = Constants.world_to_grid(unit.global_position)
		fog_of_war.update_vision_source(unit.vision_id, grid_pos)

func update_enemy_visibility() -> void:
	# Hide enemy units/buildings that are not in VISIBLE tiles
	for unit in get_tree().get_nodes_in_group("enemy_units"):
		var grid_pos = Constants.world_to_grid(unit.global_position)
		unit.visible = fog_of_war.is_tile_visible(grid_pos)

	for building in get_tree().get_nodes_in_group("enemy_buildings"):
		var grid_pos = building.grid_position
		# Building is visible if any of its tiles are visible
		var is_visible = false
		for x in range(building.grid_size.x):
			for y in range(building.grid_size.y):
				if fog_of_war.is_tile_visible(grid_pos + Vector2i(x, y)):
					is_visible = true
					break
			if is_visible:
				break
		building.visible = is_visible

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

func _on_unit_destroyed(unit: Unit) -> void:
	# Remove vision source when player unit dies
	if unit.faction == Constants.Faction.ATREIDES:
		fog_of_war.remove_vision_source(unit.vision_id)
