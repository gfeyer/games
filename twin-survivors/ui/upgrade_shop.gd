extends Control

signal shop_closed()

# Player panels
@onready var p1_panel: Control = $HBoxContainer/P1Panel
@onready var p2_panel: Control = $HBoxContainer/P2Panel
@onready var p1_credits_label: Label = $HBoxContainer/P1Panel/VBox/CreditsLabel
@onready var p2_credits_label: Label = $HBoxContainer/P2Panel/VBox/CreditsLabel
@onready var continue_button: Button = $ContinueButton

# Upgrade buttons for each player
var p1_buttons: Array[Button] = []
var p2_buttons: Array[Button] = []

# Selection tracking
var p1_selection: int = 0
var p2_selection: int = 0

const UPGRADE_NAMES: Array[String] = ["fire_rate", "damage", "aoe", "health_regen", "move_speed"]
const UPGRADE_LABELS: Array[String] = ["Fire Rate", "Damage", "AOE Blast", "Health Regen", "Move Speed"]


func _ready() -> void:
	# Get button references
	p1_buttons = [
		$HBoxContainer/P1Panel/VBox/UpgradeList/FireRateButton,
		$HBoxContainer/P1Panel/VBox/UpgradeList/DamageButton,
		$HBoxContainer/P1Panel/VBox/UpgradeList/AOEButton,
		$HBoxContainer/P1Panel/VBox/UpgradeList/RegenButton,
		$HBoxContainer/P1Panel/VBox/UpgradeList/SpeedButton
	]
	p2_buttons = [
		$HBoxContainer/P2Panel/VBox/UpgradeList/FireRateButton,
		$HBoxContainer/P2Panel/VBox/UpgradeList/DamageButton,
		$HBoxContainer/P2Panel/VBox/UpgradeList/AOEButton,
		$HBoxContainer/P2Panel/VBox/UpgradeList/RegenButton,
		$HBoxContainer/P2Panel/VBox/UpgradeList/SpeedButton
	]

	# Connect P1 button clicks
	for i in range(5):
		var upgrade_name = UPGRADE_NAMES[i]
		p1_buttons[i].pressed.connect(func(): purchase_for_player(1, upgrade_name))
		p2_buttons[i].pressed.connect(func(): purchase_for_player(2, upgrade_name))

	continue_button.pressed.connect(_on_continue_pressed)


func _process(_delta: float) -> void:
	if not visible:
		return

	# P1 controls: W/S to navigate, Enter to buy
	if Input.is_action_just_pressed("p1_up"):
		p1_selection = (p1_selection - 1 + 5) % 5
		update_selection_visuals()
	if Input.is_action_just_pressed("p1_down"):
		p1_selection = (p1_selection + 1) % 5
		update_selection_visuals()
	if Input.is_action_just_pressed("ui_accept"):
		purchase_for_player(1, UPGRADE_NAMES[p1_selection])

	# P2 controls: Arrow keys to navigate, Space to buy (using start_wave action)
	if Input.is_action_just_pressed("p2_up"):
		p2_selection = (p2_selection - 1 + 5) % 5
		update_selection_visuals()
	if Input.is_action_just_pressed("p2_down"):
		p2_selection = (p2_selection + 1) % 5
		update_selection_visuals()
	if Input.is_action_just_pressed("start_wave"):
		purchase_for_player(2, UPGRADE_NAMES[p2_selection])


func refresh_shop() -> void:
	p1_selection = 0
	p2_selection = 0
	update_credits_display()
	update_button_states()
	update_selection_visuals()


func update_credits_display() -> void:
	p1_credits_label.text = "P1 Budget: $%d" % GameManager.get_player_credits(1)
	p2_credits_label.text = "P2 Budget: $%d" % GameManager.get_player_credits(2)


func update_button_states() -> void:
	for i in range(5):
		var upgrade_name = UPGRADE_NAMES[i]
		var cost = GameManager.get_upgrade_cost(upgrade_name)
		var level = GameManager.upgrade_levels[upgrade_name]
		var label = "%s Lv.%d - $%d" % [UPGRADE_LABELS[i], level + 1, cost]

		# P1 buttons
		p1_buttons[i].text = label
		p1_buttons[i].disabled = not GameManager.can_player_afford_upgrade(1, upgrade_name)

		# P2 buttons
		p2_buttons[i].text = label
		p2_buttons[i].disabled = not GameManager.can_player_afford_upgrade(2, upgrade_name)


func update_selection_visuals() -> void:
	# Highlight selected button for each player
	for i in range(5):
		# P1 selection (cyan highlight)
		if i == p1_selection:
			p1_buttons[i].add_theme_color_override("font_color", Color(0, 1, 1))
			p1_buttons[i].add_theme_color_override("font_hover_color", Color(0, 1, 1))
		else:
			p1_buttons[i].remove_theme_color_override("font_color")
			p1_buttons[i].remove_theme_color_override("font_hover_color")

		# P2 selection (orange highlight)
		if i == p2_selection:
			p2_buttons[i].add_theme_color_override("font_color", Color(1, 0.5, 0))
			p2_buttons[i].add_theme_color_override("font_hover_color", Color(1, 0.5, 0))
		else:
			p2_buttons[i].remove_theme_color_override("font_color")
			p2_buttons[i].remove_theme_color_override("font_hover_color")


func purchase_for_player(player_id: int, upgrade_name: String) -> void:
	if GameManager.purchase_upgrade_for_player(player_id, upgrade_name):
		# Play purchase effect
		var buttons = p1_buttons if player_id == 1 else p2_buttons
		var idx = UPGRADE_NAMES.find(upgrade_name)
		if idx >= 0:
			var tween = create_tween()
			tween.tween_property(buttons[idx], "modulate", Color(0.5, 1.0, 0.5), 0.1)
			tween.tween_property(buttons[idx], "modulate", Color.WHITE, 0.2)

		update_credits_display()
		update_button_states()


func _on_continue_pressed() -> void:
	visible = false
	shop_closed.emit()
	GameManager.close_shop()
