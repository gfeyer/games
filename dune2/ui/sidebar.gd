extends Control
class_name Sidebar

signal build_requested(building_type: String)
signal unit_requested(unit_type: String)

@onready var credits_label: Label = $VBoxContainer/CreditsLabel
@onready var build_buttons: VBoxContainer = $VBoxContainer/BuildButtons
@onready var unit_buttons: VBoxContainer = $VBoxContainer/UnitButtons
@onready var info_panel: PanelContainer = $VBoxContainer/InfoPanel
@onready var info_label: Label = $VBoxContainer/InfoPanel/InfoLabel

var selected_building: Building = null
var build_button_refs: Dictionary = {}  # building_id -> BuildButton
var unit_button_refs: Dictionary = {}   # unit_id -> BuildButton
var production_building: Building = null  # Building that produces units

func _ready() -> void:
	GameManager.credits_changed.connect(_on_credits_changed)
	GameManager.selection_changed.connect(_on_selection_changed)
	update_credits(GameManager.get_credits(GameManager.player_faction))
	update_build_buttons()

func _process(_delta: float) -> void:
	update_button_states()
	update_unit_button_states()

func update_button_states() -> void:
	var cy = GameManager.get_construction_yard(GameManager.player_faction)
	if cy == null:
		return

	for building_id in build_button_refs:
		var btn: BuildButton = build_button_refs[building_id]
		if not is_instance_valid(btn):
			continue

		var is_producing = (cy.current_production == building_id)
		var is_ready = false
		var progress = 0.0

		if cy is ConstructionYard:
			is_ready = (cy.pending_building == building_id)

		if is_producing:
			progress = cy.get_production_percent()

		btn.set_production_state(is_producing, progress, is_ready)

func update_unit_button_states() -> void:
	if production_building == null or not is_instance_valid(production_building):
		return

	for unit_id in unit_button_refs:
		var btn: BuildButton = unit_button_refs[unit_id]
		if not is_instance_valid(btn):
			continue

		var is_producing = (production_building.current_production == unit_id)
		var progress = 0.0
		var queued = get_queue_count(production_building, unit_id)

		if is_producing:
			progress = production_building.get_production_percent()

		btn.set_production_state(is_producing, progress, false, queued)

func get_queue_count(building: Building, item_id: String) -> int:
	var count = 0
	for item in building.production_queue:
		if item["id"] == item_id:
			count += 1
	return count

func _on_credits_changed(faction: int, amount: int) -> void:
	if faction == GameManager.player_faction:
		update_credits(amount)

func _on_selection_changed(selection: Array) -> void:
	if selection.is_empty():
		selected_building = null
		production_building = null
		clear_info()
		hide_production_buttons()
	elif selection[0] is Building:
		selected_building = selection[0]
		show_building_info(selected_building)
		show_production_buttons(selected_building)
	else:
		selected_building = null
		production_building = null
		show_unit_info(selection)
		hide_production_buttons()

func update_credits(amount: int) -> void:
	credits_label.text = "Credits: " + str(amount)

func update_build_buttons() -> void:
	# Clear existing buttons
	for child in build_buttons.get_children():
		child.queue_free()
	build_button_refs.clear()

	# Add building buttons (from Construction Yard)
	for building_id in Constants.BUILDINGS:
		if building_id == "construction_yard":
			continue

		var data = Constants.BUILDINGS[building_id]
		var btn = BuildButton.new()
		btn.setup(building_id, data)
		btn.pressed.connect(_on_build_pressed)
		build_buttons.add_child(btn)
		build_button_refs[building_id] = btn

func show_production_buttons(building: Building) -> void:
	# Clear existing unit buttons
	for child in unit_buttons.get_children():
		child.queue_free()
	unit_button_refs.clear()
	production_building = null

	if not building.can_produce():
		return

	# Only track unit-producing buildings (not Construction Yard)
	if not building is ConstructionYard:
		production_building = building

	var items = building.get_produceable_items()
	for item in items:
		var btn = BuildButton.new()
		btn.setup(item["id"], item["data"])

		if item["type"] == "unit":
			btn.pressed.connect(_on_unit_pressed.bind(building))
			unit_button_refs[item["id"]] = btn
		else:
			btn.pressed.connect(_on_build_pressed)

		unit_buttons.add_child(btn)

func hide_production_buttons() -> void:
	for child in unit_buttons.get_children():
		child.queue_free()
	unit_button_refs.clear()
	production_building = null

func show_building_info(building: Building) -> void:
	var text = building.building_data.get("name", "Building") + "\n"
	text += "HP: " + str(building.current_health) + "/" + str(building.max_health)

	info_label.text = text
	info_panel.visible = true

func show_unit_info(units: Array) -> void:
	if units.is_empty():
		return

	var text = ""
	if units.size() == 1:
		var unit = units[0]
		text = unit.unit_data.get("name", "Unit") + "\n"
		text += "HP: " + str(unit.current_health) + "/" + str(unit.max_health)
		if unit is Harvester:
			text += "\nCargo: " + str(unit.spice_carried) + "/" + str(unit.max_capacity)
	else:
		text = str(units.size()) + " units selected"

	info_label.text = text
	info_panel.visible = true

func clear_info() -> void:
	info_label.text = ""
	info_panel.visible = false

func _on_build_pressed(building_type: String) -> void:
	build_requested.emit(building_type)

func _on_unit_pressed(unit_type: String, building: Building) -> void:
	if building and is_instance_valid(building):
		building.queue_production(unit_type, "unit")
