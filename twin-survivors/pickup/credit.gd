extends Area2D
class_name CreditPickup

@export var value: int = 10

var collected: bool = false
var spawn_velocity: Vector2 = Vector2.ZERO
var friction: float = 5.0

# Visual references
@onready var sprite: Sprite2D = $Sprite
@onready var glow: Sprite2D = $Glow
@onready var sparkle_particles: GPUParticles2D = $SparkleParticles
@onready var collect_particles: GPUParticles2D = $CollectParticles

var pulse_offset: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	pulse_offset = randf() * TAU

	# Random spawn velocity
	spawn_velocity = Vector2(randf_range(-50, 50), randf_range(-80, -40))


func _physics_process(delta: float) -> void:
	if collected:
		return

	# Apply spawn velocity with friction
	if spawn_velocity.length() > 1:
		position += spawn_velocity * delta
		spawn_velocity = spawn_velocity.lerp(Vector2.ZERO, friction * delta)

	# Pulsing effect
	pulse_offset += delta * 4
	var pulse_scale = 1.0 + sin(pulse_offset) * 0.1
	if sprite:
		sprite.scale = Vector2(0.12, 0.12) * pulse_scale
	if glow:
		glow.modulate.a = 0.4 + sin(pulse_offset) * 0.2


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return

	if body is Player and body.is_alive:
		collect()


func collect() -> void:
	collected = true
	GameManager.add_credits(value)

	# Play collection effect
	if collect_particles:
		collect_particles.emitting = true

	# Hide sprite
	if sprite:
		sprite.visible = false
	if glow:
		glow.visible = false
	if sparkle_particles:
		sparkle_particles.emitting = false

	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)

	# Clean up after particles
	await get_tree().create_timer(0.4).timeout
	queue_free()
