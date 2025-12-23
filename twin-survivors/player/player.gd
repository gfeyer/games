extends CharacterBody2D
class_name Player

signal health_changed(current: int, max_health: int)
signal died()
signal shot_fired(position: Vector2, direction: Vector2, player_id: int)

# Player ID (1 or 2)
@export var player_id: int = 1

# Input action names (set based on player_id)
var input_up: String
var input_down: String
var input_left: String
var input_right: String
var input_bomb: String

# Stats
var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true
var regen_accumulator: float = 0.0  # Accumulate fractional HP

# Shooting
var shoot_timer: float = 0.0
var current_target: Node2D = null

# Bomb ability
var bomb_cooldown: float = 0.0
const BOMB_COOLDOWN_TIME: float = 10.0
const BOMB_RADIUS: float = 350.0  # Large radius
const BOMB_DAMAGE: int = 5
const AUTO_BOMB_THRESHOLD: int = 5  # Auto-trigger when this many enemies are close

# Bomb visual
@onready var bomb_radius_indicator: Node2D = $BombRadiusIndicator

# Visual references
@onready var body_sprite: Sprite2D = $BodySprite
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var aim_indicator: Sprite2D = $AimIndicator
@onready var muzzle_flash: GPUParticles2D = $MuzzleFlash
@onready var damage_flash: AnimationPlayer = $AnimationPlayer
@onready var trail_particles: GPUParticles2D = $TrailParticles
@onready var bomb_particles: GPUParticles2D = $BombParticles

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
	input_bomb = "p%d_bomb" % player_id


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
	handle_bomb(delta)
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

	var speed = GameManager.get_move_speed(player_id)
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
		shoot_timer = GameManager.get_fire_rate(player_id)


func handle_bomb(delta: float) -> void:
	if bomb_cooldown > 0:
		bomb_cooldown -= delta

	if not GameManager.has_bomb(player_id):
		return

	# Manual trigger
	if Input.is_action_just_pressed(input_bomb) and bomb_cooldown <= 0:
		trigger_bomb()
		bomb_cooldown = BOMB_COOLDOWN_TIME
		return

	# Auto-trigger when surrounded by enemies
	if bomb_cooldown <= 0:
		var enemies_in_range = count_enemies_in_radius(BOMB_RADIUS)
		if enemies_in_range >= AUTO_BOMB_THRESHOLD:
			trigger_bomb()
			bomb_cooldown = BOMB_COOLDOWN_TIME


func count_enemies_in_radius(radius: float) -> int:
	var count = 0
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if is_instance_valid(zombie):
			if global_position.distance_to(zombie.global_position) <= radius:
				count += 1
	return count


func trigger_bomb() -> void:
	# Show radius indicator
	if bomb_radius_indicator:
		bomb_radius_indicator.visible = true
		var tween = create_tween()
		tween.tween_property(bomb_radius_indicator, "modulate:a", 0.0, 0.4).from(0.6)
		tween.tween_callback(func(): bomb_radius_indicator.visible = false)

	# Damage all zombies in radius
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if is_instance_valid(zombie):
			var dist = global_position.distance_to(zombie.global_position)
			if dist <= BOMB_RADIUS:
				zombie.take_damage(BOMB_DAMAGE)

	# Visual explosion effect
	if bomb_particles:
		bomb_particles.restart()

	# Screen shake via main scene
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("add_screen_shake"):
		main.add_screen_shake(12.0)


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

	shot_fired.emit(spawn_pos, direction, player_id)


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
	# Health regen (accumulate fractional HP)
	if is_alive and current_health < max_health:
		var regen = GameManager.get_health_regen(player_id)
		if regen > 0:
			regen_accumulator += regen * delta
			if regen_accumulator >= 1.0:
				var heal_amount = int(regen_accumulator)
				heal(heal_amount)
				regen_accumulator -= heal_amount


func reset() -> void:
	current_health = max_health
	is_alive = true
	visible = true
	set_physics_process(true)
	bomb_cooldown = 0.0
	regen_accumulator = 0.0
	health_changed.emit(current_health, max_health)


func get_bomb_cooldown() -> float:
	return bomb_cooldown
