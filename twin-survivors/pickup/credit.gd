extends Area2D
class_name CreditPickup

@export var value: int = 10

var collected: bool = false
var spawn_velocity: Vector2 = Vector2.ZERO
var friction: float = 5.0

# Magnet effect
const MAGNET_RANGE: float = 100.0  # Distance to start attracting
const MAGNET_SPEED: float = 300.0  # Speed when moving toward player

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

	# Disable sparkle particles in performance mode
	if sparkle_particles and GameManager.performance_mode:
		sparkle_particles.emitting = false


func _physics_process(delta: float) -> void:
	if collected:
		return

	# Apply spawn velocity with friction
	if spawn_velocity.length() > 1:
		position += spawn_velocity * delta
		spawn_velocity = spawn_velocity.lerp(Vector2.ZERO, friction * delta)

	# Magnet effect - move toward nearest player if close
	var nearest_player = find_nearest_player()
	if nearest_player:
		var dist = global_position.distance_to(nearest_player.global_position)
		if dist < MAGNET_RANGE:
			var direction = (nearest_player.global_position - global_position).normalized()
			# Move faster as we get closer
			var speed_mult = 1.0 + (1.0 - dist / MAGNET_RANGE)
			position += direction * MAGNET_SPEED * speed_mult * delta
			spawn_velocity = Vector2.ZERO  # Cancel spawn velocity when magnetized

	# Pulsing effect (skip in performance mode)
	if not GameManager.performance_mode:
		pulse_offset += delta * 4
		var pulse_scale = 1.0 + sin(pulse_offset) * 0.1
		if sprite:
			sprite.scale = Vector2(0.12, 0.12) * pulse_scale
		if glow:
			glow.modulate.a = 0.4 + sin(pulse_offset) * 0.2


func find_nearest_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var nearest_dist: float = INF

	for player in players:
		if not is_instance_valid(player):
			continue
		if not player.is_alive:
			continue
		var dist = global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player

	return nearest


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return

	if body is Player and body.is_alive:
		collect()


func collect() -> void:
	collected = true
	GameManager.add_credits(value)

	# Play collection effect (skip in performance mode)
	if collect_particles and not GameManager.performance_mode:
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
