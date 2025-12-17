extends CharacterBody2D

signal shoot_requested(position: Vector2, direction: Vector2)
signal ship_destroyed

@export var rotation_speed: float = 5.0
@export var thrust_power: float = 400.0
@export var max_speed: float = 500.0
@export var friction: float = 0.5

@onready var ship_polygon: Polygon2D = $ShipPolygon
@onready var thrust_particles: GPUParticles2D = $ThrustParticles
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var can_shoot: bool = true
var is_invincible: bool = false
var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	thrust_particles.emitting = false

func _physics_process(delta: float) -> void:
	handle_rotation(delta)
	handle_thrust(delta)
	handle_shooting()
	wrap_screen()
	move_and_slide()

func handle_rotation(delta: float) -> void:
	var rotation_input = Input.get_axis("rotate_left", "rotate_right")
	rotation += rotation_input * rotation_speed * delta

func handle_thrust(delta: float) -> void:
	if Input.is_action_pressed("thrust"):
		var direction = Vector2.UP.rotated(rotation)
		velocity += direction * thrust_power * delta
		velocity = velocity.limit_length(max_speed)
		thrust_particles.emitting = true
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		thrust_particles.emitting = false

func handle_shooting() -> void:
	if Input.is_action_just_pressed("shoot") and can_shoot:
		var direction = Vector2.UP.rotated(rotation)
		var spawn_pos = global_position + direction * 25
		shoot_requested.emit(spawn_pos, direction)
		can_shoot = false
		shoot_cooldown.start()

func wrap_screen() -> void:
	var pos = global_position
	if pos.x < 0:
		pos.x = screen_size.x
	elif pos.x > screen_size.x:
		pos.x = 0
	if pos.y < 0:
		pos.y = screen_size.y
	elif pos.y > screen_size.y:
		pos.y = 0
	global_position = pos

func hit() -> void:
	if is_invincible:
		return
	ship_destroyed.emit()

func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	rotation = -PI / 2
	start_invincibility()

func start_invincibility() -> void:
	is_invincible = true
	collision_shape.set_deferred("disabled", true)
	invincibility_timer.start()
	
	# Blink effect
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(ship_polygon, "modulate:a", 0.3, 0.15)
	tween.tween_property(ship_polygon, "modulate:a", 1.0, 0.15)

func _on_shoot_cooldown_timeout() -> void:
	can_shoot = true

func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	collision_shape.set_deferred("disabled", false)
	ship_polygon.modulate.a = 1.0
