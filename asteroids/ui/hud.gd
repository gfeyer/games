extends CanvasLayer

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var lives_container: HBoxContainer = $MarginContainer/VBoxContainer/LivesContainer
@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var high_score_label: Label = $GameOverPanel/VBoxContainer/HighScoreLabel
@onready var start_panel: PanelContainer = $StartPanel

var life_icon_scene: PackedScene

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_started.connect(_on_game_started)

	game_over_panel.visible = false
	start_panel.visible = true
	update_score(0)
	update_lives(3)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		if GameManager.current_state == GameManager.GameState.MENU:
			GameManager.start_game()
		elif GameManager.current_state == GameManager.GameState.GAME_OVER:
			GameManager.start_game()

func _on_score_changed(new_score: int) -> void:
	update_score(new_score)

func _on_lives_changed(new_lives: int) -> void:
	update_lives(new_lives)

func _on_game_over() -> void:
	game_over_panel.visible = true
	final_score_label.text = "SCORE: " + str(GameManager.score)
	high_score_label.text = "HIGH SCORE: " + str(GameManager.high_score)

func _on_game_started() -> void:
	game_over_panel.visible = false
	start_panel.visible = false

func update_score(value: int) -> void:
	score_label.text = "SCORE: " + str(value)

func update_lives(count: int) -> void:
	# Clear existing life icons
	for child in lives_container.get_children():
		child.queue_free()

	# Add life icons
	for i in range(count):
		var icon = create_life_icon()
		lives_container.add_child(icon)

func create_life_icon() -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(20, 20)

	var polygon = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(10, 2),
		Vector2(18, 18),
		Vector2(10, 14),
		Vector2(2, 18)
	])
	polygon.color = Color(0, 0.9, 1, 1)
	container.add_child(polygon)

	return container
