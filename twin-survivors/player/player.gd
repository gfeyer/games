extends CharacterBody2D
class_name Player

signal health_changed(current: int, max_health: int)
signal died()
signal shot_fired(position: Vector2, direction: Vector2)

# Player ID (1 or 2)
@export var player_id: int = 1

# Input action names (set based on player_id)
var input_up: String
var input_down: String
var input_left: String
var input_right: String

# Stats
var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true

# Shooting
var shoot_timer: float = 0.0
var current_target: Node2D = null

# Visual references
@onready var body_sprite: Sprite2D = $BodySprite
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var aim_indicator: Sprite2D = $AimIndicator
@onready var muzzle_flash: GPUParticles2D = $MuzzleFlash
@onready var damage_flash: AnimationPlayer = $AnimationPlayer
@onready var trail_particles: GPUParticles2D = $TrailParticles

# Colors
const PLAYER_COLORS: Dictionary = {
	1: Color(0.0, 1.0, 1.0),   # Cyan
	2: Color(1.0, 0.53, 0.0)   # Orange
}


func _ready() -> void:
	setup_input_actions()
	setup_visuals()
	GameManager.register_player(self)
	add_to_group("players")


func setup_input_actions() -> void:
	input_up = "p%d_up" % player_id
	input_down = "p%d_down" % player_id
	input_left = "p%d_left" % player_id
	input_right = "p%d_right" % player_id


func setup_visuals() -> void:
	var color = PLAYER_COLORS.get(player_id, Color.WHITE)
	if body_sprite:
		body_sprite.modulate = color
	if glow_sprite:
		glow_sprite.modulate = color
		glow_sprite.modulate.a = 0.5
	if aim_indicator:
		aim_indicator.modulate = color


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	handle_movement(delta)
	handle_targeting()
	handle_shooting(delta)
	update_visuals()


func handle_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO

	if Input.is_action_pressed(input_up):
		input_dir.y -= 1
	if Input.is_action_pressed(input_down):
		input_dir.y += 1
	if Input.is_action_pressed(input_left):
		input_dir.x -= 1
	if Input.is_action_pressed(input_right):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	var speed = GameManager.get_move_speed()
	velocity = input_dir * speed

	# Enable trail when moving
	if trail_particles:
		trail_particles.emitting = velocity.length() > 10

	move_and_slide()

	# Wraparound - exit one edge, appear on opposite
	var viewport_rect = get_viewport_rect()
	if position.x < 0:
		position.x = viewport_rect.size.x
	elif position.x > viewport_rect.size.x:
		position.x = 0
	if position.y < 0:
		position.y = viewport_rect.size.y
	elif position.y > viewport_rect.size.y:
		position.y = 0


func handle_targeting() -> void:
	current_target = find_nearest_zombie()

	# Update aim indicator
	if aim_indicator:
		if current_target:
			aim_indicator.visible = true
			var dir = (current_target.global_position - global_position).normalized()
			aim_indicator.rotation = dir.angle()
			aim_indicator.position = dir * 25
		else:
			aim_indicator.visible = false


func find_nearest_zombie() -> Node2D:
	var zombies = get_tree().get_nodes_in_group("zombies")
	var nearest: Node2D = null
	var nearest_dist: float = INF

	for zombie in zombies:
		if not is_instance_valid(zombie):
			continue
		var dist = global_position.distance_to(zombie.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = zombie

	return nearest


func handle_shooting(delta: float) -> void:
	shoot_timer -= delta

	if shoot_timer <= 0 and current_target:
		shoot_at_target()
		shoot_timer = GameManager.get_fire_rate()


func shoot_at_target() -> void:
	if not current_target:
		return

	var direction = (current_target.global_position - global_position).normalized()
	var spawn_pos = global_position + direction * 20

	# Emit muzzle flash
	if muzzle_flash:
		muzzle_flash.position = direction * 20
		muzzle_flash.rotation = direction.angle()
		muzzle_flash.restart()

	shot_fired.emit(spawn_pos, direction)


func take_damage(amount: int) -> void:
	if not is_alive:
		return

	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)

	# Flash effect
	if damage_flash:
		damage_flash.play("damage_flash")

	if current_health <= 0:
		die()


func heal(amount: int) -> void:
	if not is_alive:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func die() -> void:
	is_alive = false
	died.emit()
	GameManager.on_player_died(player_id)

	# Death effect - could add explosion particles here
	visible = false
	set_physics_process(false)


func update_visuals() -> void:
	# Pulsing glow effect
	if glow_sprite:
		var pulse = 0.4 + sin(Time.get_ticks_msec() * 0.005) * 0.1
		glow_sprite.modulate.a = pulse


func _process(delta: float) -> void:
	# Health regen
	if is_alive and current_health < max_health:
		var regen = GameManager.get_health_regen()
		if regen > 0:
			heal(int(regen * delta))


func reset() -> void:
	current_health = max_health
	is_alive = true
	visible = true
	set_physics_process(true)
	health_changed.emit(current_health, max_health)
