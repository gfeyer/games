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

func _ready() -> void:
	GameManager.credits_changed.connect(_on_credits_changed)
	GameManager.selection_changed.connect(_on_selection_changed)
	update_credits(GameManager.get_credits(GameManager.player_faction))
	update_build_buttons()

func _on_credits_changed(faction: int, amount: int) -> void:
	if faction == GameManager.player_faction:
		update_credits(amount)

func _on_selection_changed(selection: Array) -> void:
	if selection.is_empty():
		selected_building = null
		clear_info()
		hide_production_buttons()
	elif selection[0] is Building:
		selected_building = selection[0]
		show_building_info(selected_building)
		show_production_buttons(selected_building)
	else:
		selected_building = null
		show_unit_info(selection)
		hide_production_buttons()

func update_credits(amount: int) -> void:
	credits_label.text = "Credits: " + str(amount)

func update_build_buttons() -> void:
	# Clear existing buttons
	for child in build_buttons.get_children():
		child.queue_free()

	# Add building buttons (from Construction Yard)
	for building_id in Constants.BUILDINGS:
		if building_id == "construction_yard":
			continue

		var data = Constants.BUILDINGS[building_id]
		var btn = Button.new()
		btn.text = data["name"] + " ($" + str(data["cost"]) + ")"
		btn.pressed.connect(_on_build_pressed.bind(building_id))
		build_buttons.add_child(btn)

func show_production_buttons(building: Building) -> void:
	# Clear existing unit buttons
	for child in unit_buttons.get_children():
		child.queue_free()

	if not building.can_produce():
		return

	var items = building.get_produceable_items()
	for item in items:
		var btn = Button.new()
		btn.text = item["data"]["name"] + " ($" + str(item["data"]["cost"]) + ")"
		if item["type"] == "unit":
			btn.pressed.connect(_on_unit_pressed.bind(item["id"], building))
		else:
			btn.pressed.connect(_on_build_pressed.bind(item["id"]))
		unit_buttons.add_child(btn)

func hide_production_buttons() -> void:
	for child in unit_buttons.get_children():
		child.queue_free()

func show_building_info(building: Building) -> void:
	var text = building.building_data.get("name", "Building") + "\n"
	text += "HP: " + str(building.current_health) + "/" + str(building.max_health) + "\n"

	if building.current_production != "":
		text += "Building: " + building.current_production + "\n"
		text += "Progress: " + str(int(building.get_production_percent() * 100)) + "%"

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
