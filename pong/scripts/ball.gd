extends CharacterBody2D

signal scored(scorer: String)

const INITIAL_SPEED: float = 400.0
const MAX_SPEED: float = 800.0
const SPEED_INCREMENT: float = 20.0

var speed: float = INITIAL_SPEED
var direction: Vector2 = Vector2.ZERO
var active: bool = false

@onready var sprite: Polygon2D = $Sprite
@onready var glow: Polygon2D = $Glow

func _physics_process(delta: float) -> void:
	if not active:
		return

	# Animate glow pulsing
	var pulse = 1.3 + sin(Time.get_ticks_msec() * 0.01) * 0.2
	glow.scale = Vector2(pulse, pulse)

	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)

	if collision:
		var collider = collision.get_collider()

		if collider.is_in_group("wall"):
			# Bounce off walls
			direction = direction.bounce(collision.get_normal())
		elif collider.is_in_group("paddle"):
			# Bounce off paddle with angle based on hit position
			var paddle = collider as CharacterBody2D
			var hit_pos = (position.y - paddle.position.y) / 50.0
			hit_pos = clamp(hit_pos, -1.0, 1.0)

			# Calculate new direction based on which side the paddle is on
			if paddle.position.x < 512:
				direction = Vector2(1, hit_pos).normalized()
			else:
				direction = Vector2(-1, hit_pos).normalized()

			# Increase speed
			speed = min(speed + SPEED_INCREMENT, MAX_SPEED)

			# Visual feedback
			create_hit_effect()

	# Check for scoring
	if position.x < 0:
		scored.emit("ai")
		active = false
	elif position.x > 1024:
		scored.emit("player")
		active = false

func launch() -> void:
	active = true
	speed = INITIAL_SPEED
	# Random direction, slightly favoring horizontal
	var angle = randf_range(-PI/4, PI/4)
	if randi() % 2 == 0:
		angle += PI
	direction = Vector2.from_angle(angle)

func reset_position() -> void:
	active = false
	position = Vector2(512, 360)
	direction = Vector2.ZERO
	speed = INITIAL_SPEED

func create_hit_effect() -> void:
	# Flash the ball brighter on hit
	var tween = create_tween()
	sprite.color = Color(1, 1, 1, 1)
	glow.modulate = Color(1, 1, 0.5, 0.6)
	tween.tween_property(sprite, "color", Color(1, 0.9, 0.3, 1), 0.15)
	tween.parallel().tween_property(glow, "modulate", Color(1, 0.9, 0.3, 0.3), 0.15)
