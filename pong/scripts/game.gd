extends Node2D

var player_score: int = 0
var ai_score: int = 0
var game_started: bool = false

@onready var ball: CharacterBody2D = $Ball
@onready var player_paddle: CharacterBody2D = $PlayerPaddle
@onready var ai_paddle: CharacterBody2D = $AIPaddle
@onready var score_label: Label = $UI/ScoreLabel
@onready var title_label: Label = $UI/TitleLabel
@onready var start_label: Label = $UI/StartLabel

func _ready() -> void:
	ball.scored.connect(_on_ball_scored)
	reset_game()

func _process(_delta: float) -> void:
	if not game_started and Input.is_action_just_pressed("ui_accept"):
		start_game()

func start_game() -> void:
	game_started = true
	title_label.visible = false
	start_label.visible = false
	ball.launch()

func reset_game() -> void:
	game_started = false
	player_score = 0
	ai_score = 0
	update_score_display()
	ball.reset_position()
	player_paddle.position = Vector2(50, 360)
	ai_paddle.position = Vector2(974, 360)
	title_label.visible = true
	start_label.visible = true

func _on_ball_scored(scorer: String) -> void:
	if scorer == "player":
		player_score += 1
	else:
		ai_score += 1

	update_score_display()

	if player_score >= 10 or ai_score >= 10:
		show_winner()
	else:
		await get_tree().create_timer(0.5).timeout
		ball.reset_position()
		ball.launch()

func update_score_display() -> void:
	score_label.text = "%d - %d" % [player_score, ai_score]

func show_winner() -> void:
	game_started = false
	if player_score >= 10:
		title_label.text = "YOU WIN!"
	else:
		title_label.text = "AI WINS!"
	title_label.visible = true
	start_label.text = "Press SPACE to play again"
	start_label.visible = true

	await get_tree().create_timer(2.0).timeout
	title_label.text = "PONG"
	start_label.text = "Press SPACE to start"
	reset_game()
