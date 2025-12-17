extends Node

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal game_over
signal game_started

enum GameState { MENU, PLAYING, GAME_OVER }

var score: int = 0:
	set(value):
		score = value
		score_changed.emit(score)

var lives: int = 3:
	set(value):
		lives = value
		lives_changed.emit(lives)
		if lives <= 0:
			end_game()

var high_score: int = 0
var current_state: GameState = GameState.MENU
var current_wave: int = 1

func _ready() -> void:
	pass

func start_game() -> void:
	score = 0
	lives = 3
	current_wave = 1
	current_state = GameState.PLAYING
	game_started.emit()

func end_game() -> void:
	current_state = GameState.GAME_OVER
	if score > high_score:
		high_score = score
	game_over.emit()

func add_score(points: int) -> void:
	score += points

func lose_life() -> void:
	lives -= 1

func next_wave() -> void:
	current_wave += 1

func get_asteroid_count_for_wave() -> int:
	return min(3 + current_wave, 12)

func is_playing() -> bool:
	return current_state == GameState.PLAYING
