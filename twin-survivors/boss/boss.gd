extends CharacterBody2D
class_name Boss

signal died(position: Vector2)
signal minion_spawn_requested(position: Vector2)

# States
enum State { CHASING, CHARGE_WINDUP, CHARGING, COOLDOWN }
var current_state: State = State.CHASING

# Stats (scaled by wave in setup())
@export var base_health: int = 50
@export var health_per_wave: int = 10
@export var speed: float = 100.0
@export var charge_speed: float = 400.0
@export var damage: int = 25
@export var credit_value: int = 50

var current_health: int
var is_alive: bool = true
var target: Node2D = null
var wave_number: int = 1

# Charge attack
var charge_timer: float = 5.0
var charge_duration: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
const CHARGE_INTERVAL: float = 5.0
const CHARGE_WINDUP_TIME: float = 0.5
const CHARGE_DURATION: float = 1.0
const CHARGE_COOLDOWN: float = 1.0
var cooldown_timer: float = 0.0

# Minion spawning
var spawn_timer: float = 8.0
const SPAWN_INTERVAL: float = 8.0
const MINIONS_PER_SPAWN: int = 3

# Wobble animation
var wobble_offset: float = 0.0
var wobble_speed: float = 6.0

# Visual references
@onready var body_sprite: Sprite2D = $BodySprite
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var eyes: Node2D = $Eyes
@onready var death_particles: GPUParticles2D = $DeathParticles
@onready var charge_indicator: Sprite2D = $ChargeIndicator
@onready var charge_particles: GPUParticles2D = $ChargeParticles

# Damage cooldown
var damage_cooldown: float = 0.0
const DAMAGE_COOLDOWN_TIME: float = 0.5


func _ready() -> void:
	add_to_group("bosses")
	wobble_offset = randf() * TAU


func setup(wave: int) -> void:
	wave_number = wave
	current_health = base_health + (wave * health_per_wave)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	damage_cooldown -= delta
	find_target()

	# Update timers
	charge_timer -= delta
	spawn_timer -= delta

	# Handle state machine
	match current_state:
		State.CHASING:
			handle_chasing(delta)
		State.CHARGE_WINDUP:
			handle_charge_windup(delta)
		State.CHARGING:
			handle_charging(delta)
		State.COOLDOWN:
			handle_cooldown(delta)

	# Check for minion spawning (can happen in any state except charging)
	if spawn_timer <= 0 and current_state != State.CHARGING:
		spawn_minions()
		spawn_timer = SPAWN_INTERVAL

	update_visuals(delta)


func find_target() -> void:
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

	target = nearest


func handle_chasing(delta: float) -> void:
	# Check if should start charge
	if charge_timer <= 0 and target:
		start_charge_windup()
		return

	# Move toward target
	if target:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	check_player_collision()


func start_charge_windup() -> void:
	current_state = State.CHARGE_WINDUP
	charge_duration = CHARGE_WINDUP_TIME

	# Show charge indicator
	if charge_indicator:
		charge_indicator.visible = true
		var tween = create_tween()
		tween.tween_property(charge_indicator, "scale", Vector2(2.0, 2.0), CHARGE_WINDUP_TIME)

	# Lock direction toward target
	if target:
		charge_direction = (target.global_position - global_position).normalized()

	velocity = Vector2.ZERO


func handle_charge_windup(delta: float) -> void:
	charge_duration -= delta

	# Flash effect during windup
	if body_sprite:
		var flash = sin(Time.get_ticks_msec() * 0.02) * 0.3 + 0.7
		body_sprite.modulate = Color(1.0, flash, flash)

	if charge_duration <= 0:
		start_charging()


func start_charging() -> void:
	current_state = State.CHARGING
	charge_duration = CHARGE_DURATION

	# Start charge particles
	if charge_particles:
		charge_particles.emitting = true

	# Hide indicator
	if charge_indicator:
		charge_indicator.visible = false


func handle_charging(delta: float) -> void:
	charge_duration -= delta

	# Move fast in charge direction
	velocity = charge_direction * charge_speed
	move_and_slide()
	check_player_collision()

	# Check if hit screen edge
	var viewport = get_viewport_rect()
	var hit_edge = false
	if global_position.x < 50 or global_position.x > viewport.size.x - 50:
		hit_edge = true
	if global_position.y < 50 or global_position.y > viewport.size.y - 50:
		hit_edge = true

	if charge_duration <= 0 or hit_edge:
		end_charge()


func end_charge() -> void:
	current_state = State.COOLDOWN
	cooldown_timer = CHARGE_COOLDOWN
	charge_timer = CHARGE_INTERVAL

	# Stop particles
	if charge_particles:
		charge_particles.emitting = false

	# Reset color
	if body_sprite:
		body_sprite.modulate = Color(0.8, 0.2, 0.8, 1)


func handle_cooldown(delta: float) -> void:
	cooldown_timer -= delta
	velocity = Vector2.ZERO

	if cooldown_timer <= 0:
		current_state = State.CHASING


func check_player_collision() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is Player and damage_cooldown <= 0:
			deal_damage_to_player(collider)


func deal_damage_to_player(player: Player) -> void:
	player.take_damage(damage)
	damage_cooldown = DAMAGE_COOLDOWN_TIME


func spawn_minions() -> void:
	# Emit signal for main to spawn minions at our position
	for i in range(MINIONS_PER_SPAWN):
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		minion_spawn_requested.emit(global_position + offset)


func take_damage(amount: int) -> void:
	if not is_alive:
		return

	current_health -= amount

	# Flash effect
	if body_sprite:
		var tween = create_tween()
		tween.tween_property(body_sprite, "modulate", Color.WHITE, 0.05)
		tween.tween_property(body_sprite, "modulate", Color(0.8, 0.2, 0.8), 0.1)

	if current_health <= 0:
		die()


func die() -> void:
	is_alive = false
	died.emit(global_position)
	GameManager.on_boss_died()

	# Play death effect
	if death_particles:
		death_particles.emitting = true

	# Hide body
	if body_sprite:
		body_sprite.visible = false
	if glow_sprite:
		glow_sprite.visible = false
	if eyes:
		eyes.visible = false
	if charge_indicator:
		charge_indicator.visible = false

	# Disable collision
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)

	# Clean up after particles
	await get_tree().create_timer(0.8).timeout
	queue_free()


func update_visuals(delta: float) -> void:
	# Wobble animation (slower, heavier feel)
	wobble_offset += wobble_speed * delta
	if body_sprite and current_state != State.CHARGING:
		body_sprite.rotation = sin(wobble_offset) * 0.1

	# Eyes track target
	if eyes and target:
		var dir = (target.global_position - global_position).normalized()
		eyes.rotation = dir.angle()

	# Pulsing glow (faster when charging)
	if glow_sprite:
		var pulse_speed = 0.003 if current_state != State.CHARGING else 0.01
		var pulse = 0.4 + sin(Time.get_ticks_msec() * pulse_speed + wobble_offset) * 0.2
		glow_sprite.modulate.a = pulse

	# Scale effect when charging
	if current_state == State.CHARGING:
		scale = Vector2(1.1, 1.1)
	else:
		scale = Vector2(1.0, 1.0)
