extends RigidBody2D

signal asteroid_destroyed(position: Vector2, size: int, score: int)

enum Size { LARGE, MEDIUM, SMALL }

@export var size: Size = Size.LARGE

@onready var polygon: Polygon2D = $AsteroidPolygon
@onready var outline: Line2D = $AsteroidOutline
@onready var glow: Line2D = $AsteroidGlow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var screen_size: Vector2
var base_speed: float = 100.0

const SIZE_SCALES = {
	Size.LARGE: 1.0,
	Size.MEDIUM: 0.5,
	Size.SMALL: 0.25
}

const SIZE_SCORES = {
	Size.LARGE: 20,
	Size.MEDIUM: 50,
	Size.SMALL: 100
}

func _ready() -> void:
	screen_size = get_viewport_rect().size
	apply_size()

	# Random rotation
	angular_velocity = randf_range(-2.0, 2.0)

func _physics_process(_delta: float) -> void:
	wrap_screen()

func wrap_screen() -> void:
	var pos = global_position
	if pos.x < -50:
		pos.x = screen_size.x + 50
	elif pos.x > screen_size.x + 50:
		pos.x = -50
	if pos.y < -50:
		pos.y = screen_size.y + 50
	elif pos.y > screen_size.y + 50:
		pos.y = -50
	global_position = pos

func apply_size() -> void:
	var scale_factor = SIZE_SCALES[size]
	polygon.scale = Vector2.ONE * scale_factor
	outline.scale = Vector2.ONE * scale_factor
	glow.scale = Vector2.ONE * scale_factor
	collision_shape.scale = Vector2.ONE * scale_factor

func setup(asteroid_size: Size, pos: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	size = asteroid_size
	global_position = pos

	if vel == Vector2.ZERO:
		var angle = randf() * TAU
		var speed = base_speed * (1.0 + (2 - size) * 0.5)
		vel = Vector2.from_angle(angle) * speed

	linear_velocity = vel

func hit() -> void:
	asteroid_destroyed.emit(global_position, size, SIZE_SCORES[size])
	queue_free()

func get_split_size() -> Size:
	match size:
		Size.LARGE:
			return Size.MEDIUM
		Size.MEDIUM:
			return Size.SMALL
		_:
			return size

func can_split() -> bool:
	return size != Size.SMALL
