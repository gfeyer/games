extends Node

# Signals
signal wave_started(wave_number: int)
signal wave_ended(wave_number: int)
signal credits_changed(amount: int)
signal game_over()
signal game_started()
signal zombie_killed(position: Vector2)
signal player_died(player_id: int)
signal shop_opened()
signal collection_phase_started(time_remaining: float)
signal collection_phase_tick(time_remaining: float)
signal boss_spawned()
signal boss_died()

# Game State
enum GameState { MENU, PLAYING, WAVE_COMPLETE, COLLECTION_PHASE, SHOP, GAME_OVER }
var current_state: GameState = GameState.MENU

# Wave System
var current_wave: int = 0
var zombies_alive: int = 0
var zombies_to_spawn: int = 0

# Boss tracking
var bosses_alive: int = 0

# Collection Phase
var collection_time_remaining: float = 0.0
const COLLECTION_PHASE_DURATION: float = 10.0

# Economy
var credits: int = 0
var player_credits: Array[int] = [0, 0]  # Per-player credits during shop

# Per-player upgrades
var player_upgrade_levels: Array[Dictionary] = [
	{ "fire_rate": 0, "damage": 0, "aoe": 0, "health_regen": 0, "move_speed": 0, "bomb": 0 },
	{ "fire_rate": 0, "damage": 0, "aoe": 0, "health_regen": 0, "move_speed": 0, "bomb": 0 }
]

# Upgrade costs (increases each level)
var upgrade_base_costs: Dictionary = {
	"fire_rate": 50,
	"damage": 75,
	"aoe": 100,
	"health_regen": 60,
	"move_speed": 40,
	"bomb": 150
}

# Player tracking
var players: Array[Node] = []
var players_alive: int = 2

# Player names
var player_names: Array[String] = ["Seba", "Sofia"]


func set_player_name(player_id: int, player_name: String) -> void:
	player_names[player_id - 1] = player_name


func get_player_name(player_id: int) -> String:
	return player_names[player_id - 1]

# Base stats
const BASE_FIRE_RATE: float = 1.0  # seconds between shots
const BASE_DAMAGE: int = 1
const BASE_MOVE_SPEED: float = 280.0
const BASE_PLAYER_HEALTH: int = 100

# Wave scaling - MASSIVE WAVES
const BASE_ZOMBIES_PER_WAVE: int = 50
const ZOMBIES_PER_WAVE_INCREASE: int = 25
const ZOMBIE_SPEED_INCREASE: float = 0.08  # 8% faster per wave


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# Handle collection phase countdown
	if current_state == GameState.COLLECTION_PHASE:
		collection_time_remaining -= delta
		collection_phase_tick.emit(collection_time_remaining)
		if collection_time_remaining <= 0:
			open_shop()


func start_game() -> void:
	current_wave = 0
	credits = 0
	player_credits = [0, 0]
	zombies_alive = 0
	zombies_to_spawn = 0
	bosses_alive = 0
	collection_time_remaining = 0.0
	players_alive = 2

	# Reset per-player upgrades
	player_upgrade_levels = [
		{ "fire_rate": 0, "damage": 0, "aoe": 0, "health_regen": 0, "move_speed": 0, "bomb": 0 },
		{ "fire_rate": 0, "damage": 0, "aoe": 0, "health_regen": 0, "move_speed": 0, "bomb": 0 }
	]

	current_state = GameState.PLAYING
	game_started.emit()
	start_next_wave()


func start_next_wave() -> void:
	current_wave += 1
	zombies_to_spawn = get_zombies_for_wave(current_wave)
	zombies_alive = 0
	current_state = GameState.PLAYING
	wave_started.emit(current_wave)


func get_zombies_for_wave(wave: int) -> int:
	return BASE_ZOMBIES_PER_WAVE + (wave - 1) * ZOMBIES_PER_WAVE_INCREASE


func get_zombie_speed_multiplier() -> float:
	return 1.0 + (current_wave - 1) * ZOMBIE_SPEED_INCREASE


func zombie_spawned() -> void:
	zombies_alive += 1


func zombie_died(position: Vector2) -> void:
	zombies_alive -= 1
	zombie_killed.emit(position)
	check_wave_complete()


func check_wave_complete() -> void:
	# Wave is complete when all zombies and bosses are dead
	if zombies_alive <= 0 and zombies_to_spawn <= 0 and bosses_alive <= 0:
		wave_complete()


func wave_complete() -> void:
	current_state = GameState.COLLECTION_PHASE
	collection_time_remaining = COLLECTION_PHASE_DURATION
	wave_ended.emit(current_wave)
	collection_phase_started.emit(collection_time_remaining)


func open_shop() -> void:
	current_state = GameState.SHOP
	# Split credits evenly between players
	var half = credits / 2
	player_credits[0] = half
	player_credits[1] = credits - half  # Give remainder to P2
	shop_opened.emit()


func close_shop() -> void:
	# Combine remaining credits back into pool
	credits = player_credits[0] + player_credits[1]
	start_next_wave()


func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)


func get_upgrade_cost(player_id: int, upgrade_name: String) -> int:
	var base_cost = upgrade_base_costs.get(upgrade_name, 100)
	var level = player_upgrade_levels[player_id - 1].get(upgrade_name, 0)
	return int(base_cost * pow(1.5, level))


func get_player_credits(player_id: int) -> int:
	return player_credits[player_id - 1]


func can_player_afford_upgrade(player_id: int, upgrade_name: String) -> bool:
	return player_credits[player_id - 1] >= get_upgrade_cost(player_id, upgrade_name)


func purchase_upgrade_for_player(player_id: int, upgrade_name: String) -> bool:
	var cost = get_upgrade_cost(player_id, upgrade_name)
	if player_credits[player_id - 1] < cost:
		return false

	player_credits[player_id - 1] -= cost
	player_upgrade_levels[player_id - 1][upgrade_name] += 1
	return true


func get_player_upgrade_level(player_id: int, upgrade_name: String) -> int:
	return player_upgrade_levels[player_id - 1].get(upgrade_name, 0)


# Calculated stats based on per-player upgrades
func get_fire_rate(player_id: int) -> float:
	var level = player_upgrade_levels[player_id - 1]["fire_rate"]
	var multiplier = pow(0.9, level)  # 10% faster per level
	return BASE_FIRE_RATE * multiplier


func get_damage(player_id: int) -> int:
	var level = player_upgrade_levels[player_id - 1]["damage"]
	return BASE_DAMAGE + level


func get_aoe_radius(player_id: int) -> float:
	var level = player_upgrade_levels[player_id - 1]["aoe"]
	if level == 0:
		return 0.0
	return 30.0 + (level - 1) * 15.0  # 30, 45, 60, 75...


func get_move_speed(player_id: int) -> float:
	var level = player_upgrade_levels[player_id - 1]["move_speed"]
	var multiplier = 1.0 + level * 0.05  # 5% faster per level
	return BASE_MOVE_SPEED * multiplier


func get_health_regen(player_id: int) -> float:
	var level = player_upgrade_levels[player_id - 1]["health_regen"]
	return level * 15.0  # 15 HP/sec per level


func has_bomb(player_id: int) -> bool:
	return player_upgrade_levels[player_id - 1]["bomb"] > 0


func get_bomb_level(player_id: int) -> int:
	return player_upgrade_levels[player_id - 1]["bomb"]


func register_player(player: Node) -> void:
	if player not in players:
		players.append(player)


func unregister_player(player: Node) -> void:
	players.erase(player)


func on_player_died(id: int) -> void:
	players_alive -= 1
	player_died.emit(id)

	if players_alive <= 0:
		trigger_game_over()


func trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	game_over.emit()


# Boss functions
func is_boss_wave(wave: int) -> bool:
	return wave >= 3 and wave % 3 == 0


func on_boss_spawned() -> void:
	bosses_alive += 1
	boss_spawned.emit()


func on_boss_died() -> void:
	bosses_alive -= 1
	boss_died.emit()
	check_wave_complete()


func restart_game() -> void:
	get_tree().reload_current_scene()
