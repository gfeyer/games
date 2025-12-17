extends Node2D

const BulletScene = preload("res://bullet/bullet.tscn")
const AsteroidScene = preload("res://asteroid/asteroid.tscn")

@onready var ship: CharacterBody2D = $Ship
@onready var bullets_container: Node2D = $Bullets
@onready var asteroids_container: Node2D = $Asteroids
@onready var explosion_particles: GPUParticles2D = $ExplosionParticles
@onready var hud: CanvasLayer = $HUD
@onready var wave_label: Label = $HUD/MarginContainer/VBoxContainer/WaveLabel

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	ship.shoot_requested.connect(_on_ship_shoot)
	ship.ship_destroyed.connect(_on_ship_destroyed)
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_over.connect(_on_game_over)

	# Hide ship until game starts
	ship.visible = false
	ship.set_physics_process(false)

func _process(_delta: float) -> void:
	if GameManager.is_playing():
		check_wave_complete()

func _on_game_started() -> void:
	# Clear existing objects
	for bullet in bullets_container.get_children():
		bullet.queue_free()
	for asteroid in asteroids_container.get_children():
		asteroid.queue_free()

	# Reset ship
	ship.visible = true
	ship.set_physics_process(true)
	ship.respawn(screen_size / 2)

	# Spawn initial asteroids
	spawn_wave()
	update_wave_label()

func _on_game_over() -> void:
	ship.visible = false
	ship.set_physics_process(false)

func _on_ship_shoot(pos: Vector2, direction: Vector2) -> void:
	var bullet = BulletScene.instantiate()
	bullet.global_position = pos
	bullet.set_direction(direction)
	bullets_container.add_child(bullet)

func _on_ship_destroyed() -> void:
	spawn_explosion(ship.global_position, Color(0, 1, 1, 1))
	GameManager.lose_life()

	if GameManager.lives > 0:
		# Respawn after delay
		await get_tree().create_timer(1.5).timeout
		if GameManager.is_playing():
			ship.respawn(screen_size / 2)
			ship.visible = true

func spawn_wave() -> void:
	var asteroid_count = GameManager.get_asteroid_count_for_wave()

	for i in range(asteroid_count):
		spawn_asteroid(null, get_safe_spawn_position())

func spawn_asteroid(size, pos: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
	var asteroid = AsteroidScene.instantiate()
	asteroids_container.add_child(asteroid)

	if size == null:
		size = asteroid.Size.LARGE

	asteroid.setup(size, pos, vel)
	asteroid.asteroid_destroyed.connect(_on_asteroid_destroyed)

func get_safe_spawn_position() -> Vector2:
	var min_distance = 150.0
	var pos: Vector2
	var attempts = 0

	while attempts < 100:
		pos = Vector2(
			randf_range(50, screen_size.x - 50),
			randf_range(50, screen_size.y - 50)
		)

		if ship.global_position.distance_to(pos) > min_distance:
			return pos

		attempts += 1

	# Fallback to edge spawn
	var edge = randi() % 4
	match edge:
		0: pos = Vector2(randf_range(0, screen_size.x), 0)
		1: pos = Vector2(screen_size.x, randf_range(0, screen_size.y))
		2: pos = Vector2(randf_range(0, screen_size.x), screen_size.y)
		3: pos = Vector2(0, randf_range(0, screen_size.y))

	return pos

func _on_asteroid_destroyed(pos: Vector2, size: int, score: int) -> void:
	GameManager.add_score(score)
	spawn_explosion(pos, Color(1, 0.5, 0.2, 1))

	# Spawn smaller asteroids
	var asteroid_ref = AsteroidScene.instantiate()
	if size != asteroid_ref.Size.SMALL:
		var new_size = asteroid_ref.get_split_size() if size == asteroid_ref.Size.LARGE else asteroid_ref.Size.SMALL

		if size == asteroid_ref.Size.LARGE:
			new_size = asteroid_ref.Size.MEDIUM
		else:
			new_size = asteroid_ref.Size.SMALL

		for i in range(2):
			var angle = randf() * TAU
			var vel = Vector2.from_angle(angle) * randf_range(80, 150)
			spawn_asteroid(new_size, pos + Vector2.from_angle(angle) * 20, vel)

	asteroid_ref.queue_free()

func check_wave_complete() -> void:
	if asteroids_container.get_child_count() == 0:
		GameManager.next_wave()
		update_wave_label()
		await get_tree().create_timer(1.0).timeout
		if GameManager.is_playing():
			spawn_wave()

func update_wave_label() -> void:
	wave_label.text = "WAVE " + str(GameManager.current_wave)

func spawn_explosion(pos: Vector2, color: Color) -> void:
	explosion_particles.global_position = pos
	explosion_particles.modulate = color
	explosion_particles.restart()
