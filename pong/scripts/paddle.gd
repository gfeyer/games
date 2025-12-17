extends CharacterBody2D

@export var is_player: bool = false
@export var move_speed: float = 500.0
@export var ai_speed: float = 350.0
@export var ai_reaction_distance: float = 400.0

const PADDLE_HEIGHT: float = 100.0
const SCREEN_HEIGHT: float = 720.0
const MARGIN: float = 50.0

var target_y: float = 360.0

@onready var sprite: Polygon2D = $Sprite
@onready var glow: Polygon2D = $Glow

func _physics_process(delta: float) -> void:
	if is_player:
		handle_player_input(delta)
	else:
		handle_ai(delta)

	# Animate glow
	var pulse = 1.1 + sin(Time.get_ticks_msec() * 0.008 + position.x) * 0.05
	glow.scale = Vector2(1.4 * pulse, 1.1)

func handle_player_input(delta: float) -> void:
	var input_dir = 0.0

	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		input_dir = -1.0
	elif Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		input_dir = 1.0

	velocity.y = input_dir * move_speed
	move_and_slide()

	# Clamp position
	position.y = clamp(position.y, MARGIN + PADDLE_HEIGHT/2, SCREEN_HEIGHT - MARGIN - PADDLE_HEIGHT/2)

func handle_ai(delta: float) -> void:
	var ball = get_tree().get_first_node_in_group("ball")
	if ball and ball.active:
		# Only react when ball is coming towards AI and within reaction distance
		if ball.direction.x > 0 and ball.position.x > ai_reaction_distance:
			target_y = ball.position.y

		# Add some imperfection to AI
		var error = sin(Time.get_ticks_msec() * 0.002) * 30.0
		target_y += error
	else:
		# Return to center when ball is inactive
		target_y = 360.0

	# Move towards target
	var diff = target_y - position.y
	if abs(diff) > 5:
		velocity.y = sign(diff) * ai_speed
	else:
		velocity.y = 0

	move_and_slide()

	# Clamp position
	position.y = clamp(position.y, MARGIN + PADDLE_HEIGHT/2, SCREEN_HEIGHT - MARGIN - PADDLE_HEIGHT/2)
