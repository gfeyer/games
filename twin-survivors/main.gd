extends Node2D

# Preloaded scenes
var BulletScene: PackedScene = preload("res://projectile/bullet.tscn")
var ZombieScene: PackedScene = preload("res://zombie/zombie.tscn")
var CreditScene: PackedScene = preload("res://pickup/credit.tscn")
var BossScene: PackedScene = preload("res://boss/boss.tscn")

# Node references
@onready var players_container: Node2D = $Players
@onready var zombies_container: Node2D = $Zombies
@onready var projectiles_container: Node2D = $Projectiles
@onready var pickups_container: Node2D = $Pickups
@onready var hud: CanvasLayer = $HUD
@onready var upgrade_shop: Control = $HUD/UpgradeShop
@onready var camera: Camera2D = $Camera2D
@onready var ambient_particles: GPUParticles2D = $AmbientParticles
@onready var name_input_menu: Control = $HUD/NameInputMenu

# Spawning - FAST to get 30-40 on screen at once
var spawn_timer: float = 0.0
var spawn_delay: float = 0.1  # Very fast spawning
var viewport_size: Vector2

# Screen shake
var shake_amount: float = 0.0
var shake_decay: float = 5.0


func _ready() -> void:
	add_to_group("main")
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

	# Show name input menu instead of auto-starting
	name_input_menu.names_submitted.connect(_on_names_submitted)
	name_input_menu.show()


func _process(delta: float) -> void:
	handle_spawning(delta)
	handle_screen_shake(delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_performance"):
		GameManager.toggle_performance_mode()
		update_performance_mode()


func update_performance_mode() -> void:
	# Toggle ambient particles based on performance mode
	if ambient_particles:
		ambient_particles.emitting = not GameManager.performance_mode


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
		spawn_delay = max(0.05, spawn_delay * 0.98)  # Can go very fast


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


func spawn_boss(wave_number: int) -> void:
	var boss = BossScene.instantiate()
	boss.setup(wave_number)
	boss.global_position = get_spawn_position()
	boss.died.connect(_on_boss_died)
	boss.minion_spawn_requested.connect(_on_minion_spawn_requested)
	zombies_container.add_child(boss)
	GameManager.on_boss_spawned()


func _on_boss_died(pos: Vector2) -> void:
	# Spawn extra credits (5 credits worth 50 total)
	for i in range(5):
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		call_deferred("_spawn_credit", pos + offset)

	# Big screen shake
	add_screen_shake(15.0)


func _on_minion_spawn_requested(pos: Vector2) -> void:
	# Spawn a weaker zombie minion at the requested position
	var minion = ZombieScene.instantiate()
	minion.global_position = pos
	minion.died.connect(_on_zombie_died)
	# Make minions weaker (they're just regular zombies but spawned mid-wave)
	zombies_container.add_child(minion)
	GameManager.zombie_spawned()


func _on_player_shot(spawn_pos: Vector2, direction: Vector2, player_id: int) -> void:
	var bullet = BulletScene.instantiate()
	bullet.setup(spawn_pos, direction, player_id)
	projectiles_container.add_child(bullet)


func _on_zombie_died(pos: Vector2) -> void:
	# Spawn credit pickup (deferred to avoid physics query errors)
	call_deferred("_spawn_credit", pos)

	# Screen shake
	add_screen_shake(2.0)


func _spawn_credit(pos: Vector2) -> void:
	var credit = CreditScene.instantiate()
	credit.global_position = pos
	pickups_container.add_child(credit)


func _on_zombie_killed(_position: Vector2) -> void:
	pass  # Additional effects could go here


func _on_wave_started(wave_number: int) -> void:
	spawn_delay = 0.1  # Fast spawning - 30-40 on screen at once
	spawn_timer = 0.5  # Small delay before first spawn

	# Respawn all players at wave start
	respawn_all_players()

	# Spawn boss(es) on boss waves (every 3 waves starting at wave 3)
	# Double the number of bosses each boss wave: 1, 2, 4, 8...
	if GameManager.is_boss_wave(wave_number):
		var boss_wave_index = wave_number / 3  # 1, 2, 3, 4...
		var num_bosses = int(pow(2, boss_wave_index - 1))  # 1, 2, 4, 8...
		for i in range(num_bosses):
			call_deferred("spawn_boss", wave_number)


func _on_wave_ended(_wave_number: int) -> void:
	# Credits no longer auto-collected - players have 10 seconds to collect
	pass


func _on_game_over() -> void:
	# Game over handling
	pass


func _on_names_submitted(p1_name: String, p2_name: String) -> void:
	GameManager.set_player_name(1, p1_name)
	GameManager.set_player_name(2, p2_name)

	# Update player labels
	for player in players_container.get_children():
		if player is Player:
			player.update_name_label()

	# Start game after short delay
	await get_tree().create_timer(0.3).timeout
	GameManager.start_game()


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


func respawn_all_players() -> void:
	# Respawn all dead players at wave start
	GameManager.players_alive = 0
	for player in players_container.get_children():
		if player is Player:
			player.reset()
			# Reposition to starting positions (1920x1080 viewport)
			if player.player_id == 1:
				player.position = Vector2(480, 540)
			else:
				player.position = Vector2(1440, 540)
			GameManager.players_alive += 1


func restart_level() -> void:
	# Clear all entities (same as restart_game)
	for child in zombies_container.get_children():
		child.queue_free()
	for child in projectiles_container.get_children():
		child.queue_free()
	for child in pickups_container.get_children():
		child.queue_free()

	# Reset players (respawn, full health)
	for player in players_container.get_children():
		if player is Player:
			player.reset()

	# Restart current wave (keeps upgrades and credits)
	GameManager.restart_wave()


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
