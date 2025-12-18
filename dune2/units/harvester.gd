extends Unit
class_name Harvester

signal spice_collected(amount: int)
signal returning_to_refinery
signal docked

enum HarvesterState { IDLE, MOVING_TO_SPICE, HARVESTING, RETURNING, WAITING_TO_DOCK, DOCKING, UNLOADING }

var state: HarvesterState = HarvesterState.IDLE
var spice_carried: int = 0
var max_capacity: int = 500
var harvest_rate: float = 50.0  # Spice per second
var target_spice_tile: Vector2i = Vector2i(-1, -1)
var target_refinery: Refinery = null

var harvest_timer: float = 0.0
var wait_retry_timer: float = 0.0
var terrain_manager: TerrainManager = null

func _ready() -> void:
	unit_type = "harvester"
	super._ready()
	max_capacity = unit_data.get("capacity", 500)

func _physics_process(delta: float) -> void:
	match state:
		HarvesterState.IDLE:
			pass
		HarvesterState.MOVING_TO_SPICE:
			super._physics_process(delta)
			if not is_moving:
				start_harvesting()
		HarvesterState.HARVESTING:
			process_harvesting(delta)
		HarvesterState.RETURNING:
			super._physics_process(delta)
			if not is_moving:
				start_docking()
		HarvesterState.WAITING_TO_DOCK:
			process_waiting_to_dock(delta)
		HarvesterState.DOCKING:
			process_docking(delta)
		HarvesterState.UNLOADING:
			process_unloading(delta)

	update_vision()

func process_waiting_to_dock(delta: float) -> void:
	# Check if refinery was destroyed while waiting
	if not target_refinery or not is_instance_valid(target_refinery):
		target_refinery = find_nearest_refinery()
		if target_refinery:
			state = HarvesterState.RETURNING
			move_to(target_refinery.get_dock_position())
		else:
			state = HarvesterState.IDLE
		return

	wait_retry_timer += delta
	if wait_retry_timer >= 0.5:  # Check every 0.5 seconds
		wait_retry_timer = 0.0
		if target_refinery.can_dock():
			start_docking()

func set_terrain_manager(tm: TerrainManager) -> void:
	terrain_manager = tm

# Override move_to to cancel docking operations when player issues move command
func move_to(pos: Vector2, player_order: bool = true) -> void:
	if player_order:
		cancel_docking()
	super.move_to(pos, player_order)

func cancel_docking() -> void:
	# If we're in any docking-related state, cancel it
	if state in [HarvesterState.RETURNING, HarvesterState.WAITING_TO_DOCK, HarvesterState.DOCKING, HarvesterState.UNLOADING]:
		# Undock from refinery if we were docked
		if target_refinery and is_instance_valid(target_refinery):
			target_refinery.undock_harvester()
		target_refinery = null
		state = HarvesterState.IDLE
		wait_retry_timer = 0.0

func harvest_at(grid_pos: Vector2i) -> void:
	cancel_docking()  # Cancel any docking operation first

	if not terrain_manager:
		return

	var terrain = terrain_manager.get_terrain(grid_pos)
	if terrain < Constants.Terrain.SPICE_LOW or terrain > Constants.Terrain.SPICE_HIGH:
		# Not a spice tile, find nearest spice
		grid_pos = find_nearest_spice(grid_pos)
		if grid_pos == Vector2i(-1, -1):
			return

	target_spice_tile = grid_pos
	state = HarvesterState.MOVING_TO_SPICE
	move_to(Constants.grid_to_world(grid_pos))

func find_nearest_spice(from_grid: Vector2i) -> Vector2i:
	if not terrain_manager:
		return Vector2i(-1, -1)

	var search_radius = 20
	var nearest = Vector2i(-1, -1)
	var nearest_dist = INF

	for dx in range(-search_radius, search_radius + 1):
		for dy in range(-search_radius, search_radius + 1):
			var check_pos = from_grid + Vector2i(dx, dy)
			if not Constants.is_valid_grid_pos(check_pos):
				continue

			var terrain = terrain_manager.get_terrain(check_pos)
			if terrain >= Constants.Terrain.SPICE_LOW and terrain <= Constants.Terrain.SPICE_HIGH:
				var dist = Vector2(dx, dy).length()
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = check_pos

	return nearest

func start_harvesting() -> void:
	if not terrain_manager:
		return

	var current_grid = Constants.world_to_grid(global_position)
	var terrain = terrain_manager.get_terrain(current_grid)

	if terrain < Constants.Terrain.SPICE_LOW or terrain > Constants.Terrain.SPICE_HIGH:
		# No spice here, find more
		var new_target = find_nearest_spice(current_grid)
		if new_target != Vector2i(-1, -1):
			harvest_at(new_target)
		else:
			state = HarvesterState.IDLE
		return

	state = HarvesterState.HARVESTING
	target_spice_tile = current_grid

func process_harvesting(delta: float) -> void:
	if not terrain_manager:
		return

	if spice_carried >= max_capacity:
		return_to_refinery()
		return

	var current_grid = Constants.world_to_grid(global_position)
	var spice_amount = terrain_manager.get_spice_amount(current_grid)

	if spice_amount <= 0:
		# Find more spice or return
		var new_target = find_nearest_spice(current_grid)
		if new_target != Vector2i(-1, -1) and spice_carried < max_capacity * 0.8:
			harvest_at(new_target)
		else:
			return_to_refinery()
		return

	harvest_timer += delta
	if harvest_timer >= 1.0:
		harvest_timer = 0.0
		var harvested = terrain_manager.harvest_spice(current_grid, 1)
		spice_carried += harvested
		spice_collected.emit(harvested)
		queue_redraw()

func return_to_refinery() -> void:
	target_refinery = find_nearest_refinery()
	if target_refinery == null:
		state = HarvesterState.IDLE
		return

	state = HarvesterState.RETURNING
	returning_to_refinery.emit()
	move_to(target_refinery.get_dock_position())

func force_return_to_refinery(refinery: Refinery) -> void:
	target_refinery = refinery
	state = HarvesterState.RETURNING
	returning_to_refinery.emit()
	move_to(target_refinery.get_dock_position())

func find_nearest_refinery() -> Refinery:
	var refineries = GameManager.get_refineries(faction)
	if refineries.is_empty():
		return null

	var nearest: Refinery = null
	var nearest_dist = INF

	for ref in refineries:
		if ref.can_dock():
			var dist = global_position.distance_to(ref.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = ref

	# If no free refineries, just pick the closest
	if nearest == null and not refineries.is_empty():
		for ref in refineries:
			var dist = global_position.distance_to(ref.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = ref

	return nearest

func start_docking() -> void:
	if not target_refinery or not is_instance_valid(target_refinery):
		# Refinery was destroyed, find another
		target_refinery = find_nearest_refinery()
		if target_refinery:
			state = HarvesterState.RETURNING
			move_to(target_refinery.get_dock_position())
		else:
			state = HarvesterState.IDLE
		return

	if target_refinery.can_dock():
		# Try to dock - may fail if another harvester docked in same frame
		if target_refinery.dock_harvester(self):
			state = HarvesterState.DOCKING
			docked.emit()
		else:
			# Lost race to dock, wait and retry
			state = HarvesterState.WAITING_TO_DOCK
	else:
		# Refinery is busy - wait nearby and retry
		state = HarvesterState.WAITING_TO_DOCK

func process_docking(_delta: float) -> void:
	# Check if refinery still exists
	if not target_refinery or not is_instance_valid(target_refinery):
		# Refinery destroyed while docking, find another
		target_refinery = find_nearest_refinery()
		if target_refinery:
			state = HarvesterState.RETURNING
			move_to(target_refinery.get_dock_position())
		else:
			state = HarvesterState.IDLE
		return

	# Move to dock position
	var dock_pos = target_refinery.get_dock_position()
	if global_position.distance_to(dock_pos) > 5:
		global_position = global_position.move_toward(dock_pos, move_speed * _delta * 0.5)
	else:
		state = HarvesterState.UNLOADING

func process_unloading(delta: float) -> void:
	if spice_carried <= 0:
		finish_unloading()
		return

	# Check if refinery still exists
	if not target_refinery or not is_instance_valid(target_refinery):
		# Refinery destroyed while unloading, find another
		target_refinery = find_nearest_refinery()
		if target_refinery:
			state = HarvesterState.RETURNING
			move_to(target_refinery.get_dock_position())
		else:
			state = HarvesterState.IDLE
		return

	# Unload spice over time
	var unload_amount = int(harvest_rate * 2 * delta)
	unload_amount = mini(unload_amount, spice_carried)

	var deposited = target_refinery.deposit_spice(unload_amount)
	spice_carried -= deposited
	queue_redraw()

func finish_unloading() -> void:
	if target_refinery and is_instance_valid(target_refinery):
		target_refinery.undock_harvester()

	target_refinery = null
	state = HarvesterState.IDLE

	# Auto-harvest: find more spice
	var current_grid = Constants.world_to_grid(global_position)
	var new_target = find_nearest_spice(current_grid)
	if new_target != Vector2i(-1, -1):
		harvest_at(new_target)

# Override die to undock from refinery first
func die() -> void:
	# Undock from refinery if we were docked
	if target_refinery and is_instance_valid(target_refinery):
		target_refinery.undock_harvester()
	super.die()

func get_cargo_percent() -> float:
	return float(spice_carried) / float(max_capacity)

func _draw() -> void:
	# Harvester is larger and box-shaped
	var size = Vector2(20, 28)
	var base_color = Constants.COLORS["atreides"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen"]

	# Body
	draw_rect(Rect2(-size / 2, size), base_color)

	# Border
	var border_color = Constants.COLORS["atreides_light"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen_light"]
	draw_rect(Rect2(-size / 2, size), border_color, false, 2.0)

	# Harvester scoop at front
	draw_rect(Rect2(-8, -size.y / 2 - 4, 16, 6), Constants.COLORS["ui_background"])

	# Cargo indicator
	var cargo_width = size.x - 4
	var cargo_height = size.y * 0.4
	var cargo_pos = Vector2(-cargo_width / 2, 0)
	draw_rect(Rect2(cargo_pos, Vector2(cargo_width, cargo_height)), Constants.COLORS["ui_background"])

	var cargo_fill = cargo_width * get_cargo_percent()
	if cargo_fill > 0:
		draw_rect(Rect2(cargo_pos, Vector2(cargo_fill, cargo_height)), Constants.COLORS["spice_medium"])

	# Selection indicator (rotates with unit)
	if is_selected:
		draw_rect(Rect2(-size / 2 - Vector2(4, 4), size + Vector2(8, 8)), Color.WHITE, false, 2.0)

	# Health bar - draw in screen space (counter-rotate)
	var health_bar_width = size.x
	var health_bar_height = 4.0
	var health_bar_y = -size.y / 2 - 10

	# Calculate screen-aligned position
	var health_bar_pos = Vector2(-health_bar_width / 2, health_bar_y).rotated(-rotation)

	draw_set_transform(health_bar_pos, -rotation)

	draw_rect(Rect2(Vector2.ZERO, Vector2(health_bar_width, health_bar_height)), Color(0.2, 0.2, 0.2))

	var health_percent = get_health_percent()
	var health_color = Constants.COLORS["health_green"]
	if health_percent < 0.3:
		health_color = Constants.COLORS["health_red"]
	elif health_percent < 0.6:
		health_color = Constants.COLORS["health_yellow"]

	draw_rect(Rect2(Vector2.ZERO, Vector2(health_bar_width * health_percent, health_bar_height)), health_color)

	# State indicator
	var state_color = Color.GRAY
	match state:
		HarvesterState.HARVESTING:
			state_color = Constants.COLORS["spice_high"]
		HarvesterState.RETURNING, HarvesterState.DOCKING, HarvesterState.UNLOADING:
			state_color = Color.GREEN
		HarvesterState.WAITING_TO_DOCK:
			state_color = Color.YELLOW

	draw_circle(Vector2(size.x / 2 + 4, -size.y / 2), 3, state_color)
