extends Area2D

@export var speed: float = 800.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.UP
var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	
	# Auto-destroy after lifetime
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	wrap_screen()

func wrap_screen() -> void:
	if position.x < 0:
		position.x = screen_size.x
	elif position.x > screen_size.x:
		position.x = 0
	if position.y < 0:
		position.y = screen_size.y
	elif position.y > screen_size.y:
		position.y = 0

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = dir.angle() + PI / 2

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("asteroid"):
		body.hit()
		queue_free()
