extends CharacterBody2D
class_name Zombie

signal died(position: Vector2)

# Stats
@export var base_speed: float = 150.0  # Fast - players must run!
@export var damage: int = 10
@export var health: int = 1
@export var credit_value: int = 10

var current_health: int
var is_alive: bool = true
var target: Node2D = null


# Wobble animation
var wobble_offset: float = 0.0
var wobble_speed: float = 8.0

# Visual references
@onready var body_sprite: Sprite2D = $BodySprite
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var eyes: Node2D = $Eyes
@onready var death_particles: GPUParticles2D = $DeathParticles

# Damage cooldown (to prevent rapid hits)
var damage_cooldown: float = 0.0
const DAMAGE_COOLDOWN_TIME: float = 0.5


func _ready() -> void:
	current_health = health
	add_to_group("zombies")
	wobble_offset = randf() * TAU  # Random start phase


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	damage_cooldown -= delta
	find_target()
	move_toward_target(delta)
	update_visuals(delta)


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


func find_target() -> void:
	target = find_nearest_player()


func move_toward_target(delta: float) -> void:
	if not target:
		velocity = Vector2.ZERO
		return

	var direction = (target.global_position - global_position).normalized()
	var speed = base_speed * GameManager.get_zombie_speed_multiplier()
	velocity = direction * speed

	move_and_slide()

	# Check for collision with players
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is Player and damage_cooldown <= 0:
			deal_damage_to_player(collider)


func deal_damage_to_player(player: Player) -> void:
	player.take_damage(damage)
	damage_cooldown = DAMAGE_COOLDOWN_TIME


func take_damage(amount: int) -> void:
	if not is_alive:
		return

	current_health -= amount

	# Flash effect
	if body_sprite:
		var tween = create_tween()
		tween.tween_property(body_sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(body_sprite, "modulate", Color(0.9, 0.2, 0.2), 0.1)

	if current_health <= 0:
		die()


func die() -> void:
	is_alive = false
	died.emit(global_position)
	GameManager.zombie_died(global_position)

	# Play death effect
	if death_particles:
		death_particles.emitting = true

	# Hide body immediately
	if body_sprite:
		body_sprite.visible = false
	if glow_sprite:
		glow_sprite.visible = false
	if eyes:
		eyes.visible = false

	# Disable collision
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)

	# Clean up after particles finish
	await get_tree().create_timer(0.5).timeout
	queue_free()


func update_visuals(delta: float) -> void:
	# Wobble animation (shambling effect)
	wobble_offset += wobble_speed * delta
	if body_sprite:
		body_sprite.rotation = sin(wobble_offset) * 0.15

	# Eyes track target
	if eyes and target:
		var dir = (target.global_position - global_position).normalized()
		eyes.rotation = dir.angle()

	# Pulsing glow
	if glow_sprite:
		var pulse = 0.3 + sin(Time.get_ticks_msec() * 0.003 + wobble_offset) * 0.1
		glow_sprite.modulate.a = pulse
