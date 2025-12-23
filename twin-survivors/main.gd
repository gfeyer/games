extends Node2D

# Preloaded scenes
var BulletScene: PackedScene = preload("res://projectile/bullet.tscn")
var ZombieScene: PackedScene = preload("res://zombie/zombie.tscn")
var CreditScene: PackedScene = preload("res://pickup/credit.tscn")

# Node references
@onready var players_container: Node2D = $Players
@onready var zombies_container: Node2D = $Zombies
@onready var projectiles_container: Node2D = $Projectiles
@onready var pickups_container: Node2D = $Pickups
@onready var hud: CanvasLayer = $HUD
@onready var upgrade_shop: Control = $HUD/UpgradeShop
@onready var camera: Camera2D = $Camera2D
@onready var ambient_particles: GPUParticles2D = $AmbientParticles

# Spawning
var spawn_timer: float = 0.0
var spawn_delay: float = 1.5  # Seconds between spawns
var viewport_size: Vector2

# Screen shake
var shake_amount: float = 0.0
var shake_decay: float = 5.0


func _ready() -> void:
	viewport_size = get_viewport_rect().size

	# Connect signals
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.zombie_killed.connect(_on_zombie_killed)
	GameManager.game_over.connect(_on_game_over)

	# Connect player shoot signals
	for player in players_container.get_children():
		if player is Player:
			player.shot_fired.connect(_on_player_shot)

	# Start game
	await get_tree().create_timer(0.5).timeout
	GameManager.start_game()


func _process(delta: float) -> void:
	handle_spawning(delta)
	handle_screen_shake(delta)


func handle_spawning(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if GameManager.zombies_to_spawn <= 0:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_zombie()
		spawn_timer = spawn_delay
		# Decrease spawn delay as wave progresses
		spawn_delay = max(0.3, spawn_delay * 0.98)


func spawn_zombie() -> void:
	if GameManager.zombies_to_spawn <= 0:
		return

	var zombie = ZombieScene.instantiate()
	zombie.global_position = get_spawn_position()
	zombie.died.connect(_on_zombie_died)
	zombies_container.add_child(zombie)

	GameManager.zombies_to_spawn -= 1
	GameManager.zombie_spawned()


func get_spawn_position() -> Vector2:
	var margin: float = 50.0
	var side = randi() % 4

	match side:
		0:  # Top
			return Vector2(randf_range(margin, viewport_size.x - margin), -margin)
		1:  # Bottom
			return Vector2(randf_range(margin, viewport_size.x - margin), viewport_size.y + margin)
		2:  # Left
			return Vector2(-margin, randf_range(margin, viewport_size.y - margin))
		3:  # Right
			return Vector2(viewport_size.x + margin, randf_range(margin, viewport_size.y - margin))

	return Vector2.ZERO


func _on_player_shot(spawn_pos: Vector2, direction: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.setup(spawn_pos, direction)
	projectiles_container.add_child(bullet)


func _on_zombie_died(position: Vector2) -> void:
	# Spawn credit pickup
	var credit = CreditScene.instantiate()
	credit.global_position = position
	pickups_container.add_child(credit)

	# Screen shake
	add_screen_shake(2.0)


func _on_zombie_killed(_position: Vector2) -> void:
	pass  # Additional effects could go here


func _on_wave_started(wave_number: int) -> void:
	spawn_delay = 1.5  # Reset spawn delay
	spawn_timer = 0.5  # Small delay before first spawn


func _on_wave_ended(wave_number: int) -> void:
	# Show shop after delay (handled in GameManager)
	pass


func _on_game_over() -> void:
	# Game over handling
	pass


func handle_screen_shake(delta: float) -> void:
	if shake_amount > 0:
		shake_amount = max(0, shake_amount - shake_decay * delta)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
	elif camera:
		camera.offset = Vector2.ZERO


func add_screen_shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)


func restart_game() -> void:
	# Clear all entities
	for child in zombies_container.get_children():
		child.queue_free()
	for child in projectiles_container.get_children():
		child.queue_free()
	for child in pickups_container.get_children():
		child.queue_free()

	# Reset players
	for player in players_container.get_children():
		if player is Player:
			player.reset()

	# Restart game manager
	GameManager.start_game()
