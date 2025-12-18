extends Building
class_name Refinery

signal harvester_docked(harvester: Node2D)
signal spice_deposited(amount: int)

var spice_storage: int = 0
var max_storage: int = 1000
var docked_harvester: Node2D = null
var dock_timeout: float = 0.0

func _ready() -> void:
	building_type = "refinery"
	super._ready()
	max_storage = building_data.get("storage", 1000)

func _process(delta: float) -> void:
	super._process(delta)

	# Safety check: validate docked harvester is actually unloading
	if docked_harvester != null:
		if not is_instance_valid(docked_harvester):
			# Harvester was destroyed, clear reference
			docked_harvester = null
			dock_timeout = 0.0
		elif docked_harvester is Harvester:
			var h = docked_harvester as Harvester
			# Check if harvester is actually in UNLOADING state (only state that blocks dock)
			if h.state != Harvester.HarvesterState.UNLOADING:
				# Harvester claimed dock but isn't actually unloading - clear it
				dock_timeout += delta
				if dock_timeout > 2.0:  # 2 second timeout
					docked_harvester = null
					dock_timeout = 0.0
			else:
				dock_timeout = 0.0

func get_dock_position() -> Vector2:
	# Dock position is at the front of the refinery
	return global_position + Vector2(0, grid_size.y * Constants.TILE_SIZE / 2 + 16)

func can_dock() -> bool:
	# Clear stale reference if harvester was destroyed
	if docked_harvester != null and not is_instance_valid(docked_harvester):
		docked_harvester = null
	return docked_harvester == null

func dock_harvester(harvester: Node2D) -> bool:
	# Atomic check - reject if already occupied
	if docked_harvester != null:
		return false
	docked_harvester = harvester
	harvester_docked.emit(harvester)
	return true

func undock_harvester() -> void:
	docked_harvester = null

func deposit_spice(amount: int) -> int:
	# Convert spice directly to credits (no storage limit)
	# spice_storage is just for visual display, doesn't block deposits
	spice_storage = mini(spice_storage + amount, max_storage)

	GameManager.add_credits(faction, amount)
	spice_deposited.emit(amount)

	return amount

func _draw() -> void:
	super._draw()

	if not is_placed:
		return

	var size = Vector2(grid_size) * Constants.TILE_SIZE
	var offset = -size / 2

	# Draw refinery details - silos
	var silo_width = size.x * 0.25
	var silo_height = size.y * 0.6

	# Left silo
	var left_silo = Rect2(offset.x + 4, offset.y + 4, silo_width, silo_height)
	draw_rect(left_silo, Constants.COLORS["ui_background"])
	draw_rect(left_silo, Constants.COLORS["spice_medium"], false, 1.0)

	# Right silo
	var right_silo = Rect2(offset.x + size.x - silo_width - 4, offset.y + 4, silo_width, silo_height)
	draw_rect(right_silo, Constants.COLORS["ui_background"])
	draw_rect(right_silo, Constants.COLORS["spice_medium"], false, 1.0)

	# Dock indicator
	var dock_rect = Rect2(offset.x + size.x * 0.3, offset.y + size.y - 12, size.x * 0.4, 8)
	var dock_color = Color.GREEN if can_dock() else Color.RED
	draw_rect(dock_rect, dock_color.darkened(0.5))
