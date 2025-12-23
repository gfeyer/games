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

# Game State
enum GameState { MENU, PLAYING, WAVE_COMPLETE, SHOP, GAME_OVER }
var current_state: GameState = GameState.MENU

# Wave System
var current_wave: int = 0
var zombies_alive: int = 0
var zombies_to_spawn: int = 0

# Economy
var credits: int = 0
var player_credits: Array[int] = [0, 0]  # Per-player credits during shop

# Upgrades (shared between players)
var upgrade_levels: Dictionary = {
	"fire_rate": 0,      # 10% faster per level
	"damage": 0,         # +1 damage per level
	"aoe": 0,            # Unlock at level 1, bigger radius per level
	"health_regen": 0,   # HP/sec regen
	"move_speed": 0      # 5% faster per level
}

# Upgrade costs (increases each level)
var upgrade_base_costs: Dictionary = {
	"fire_rate": 50,
	"damage": 75,
	"aoe": 100,
	"health_regen": 60,
	"move_speed": 40
}

# Player tracking
var players: Array[Node] = []
var players_alive: int = 2

# Base stats
const BASE_FIRE_RATE: float = 1.0  # seconds between shots
const BASE_DAMAGE: int = 1
const BASE_MOVE_SPEED: float = 200.0
const BASE_PLAYER_HEALTH: int = 100

# Wave scaling - MASSIVE WAVES
const BASE_ZOMBIES_PER_WAVE: int = 50
const ZOMBIES_PER_WAVE_INCREASE: int = 25
const ZOMBIE_SPEED_INCREASE: float = 0.08  # 8% faster per wave


func _ready() -> void:
	pass


func start_game() -> void:
	current_wave = 0
	credits = 0
	player_credits = [0, 0]
	zombies_alive = 0
	players_alive = 2

	# Reset upgrades
	for key in upgrade_levels.keys():
		upgrade_levels[key] = 0

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

	# Check wave complete
	if zombies_alive <= 0 and zombies_to_spawn <= 0:
		wave_complete()


func wave_complete() -> void:
	current_state = GameState.WAVE_COMPLETE
	wave_ended.emit(current_wave)

	# Small delay then open shop
	await get_tree().create_timer(1.5).timeout
	open_shop()


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


func get_upgrade_cost(upgrade_name: String) -> int:
	var base_cost = upgrade_base_costs.get(upgrade_name, 100)
	var level = upgrade_levels.get(upgrade_name, 0)
	return int(base_cost * pow(1.5, level))


func get_player_credits(player_id: int) -> int:
	return player_credits[player_id - 1]


func can_player_afford_upgrade(player_id: int, upgrade_name: String) -> bool:
	return player_credits[player_id - 1] >= get_upgrade_cost(upgrade_name)


func purchase_upgrade_for_player(player_id: int, upgrade_name: String) -> bool:
	var cost = get_upgrade_cost(upgrade_name)
	if player_credits[player_id - 1] < cost:
		return false

	player_credits[player_id - 1] -= cost
	upgrade_levels[upgrade_name] += 1
	return true


# Legacy function for backwards compatibility
func can_afford_upgrade(upgrade_name: String) -> bool:
	return credits >= get_upgrade_cost(upgrade_name)


func purchase_upgrade(upgrade_name: String) -> bool:
	if not can_afford_upgrade(upgrade_name):
		return false

	var cost = get_upgrade_cost(upgrade_name)
	credits -= cost
	upgrade_levels[upgrade_name] += 1
	credits_changed.emit(credits)
	return true


# Calculated stats based on upgrades
func get_fire_rate() -> float:
	var multiplier = pow(0.9, upgrade_levels["fire_rate"])  # 10% faster per level
	return BASE_FIRE_RATE * multiplier


func get_damage() -> int:
	return BASE_DAMAGE + upgrade_levels["damage"]


func get_aoe_radius() -> float:
	if upgrade_levels["aoe"] == 0:
		return 0.0
	return 30.0 + (upgrade_levels["aoe"] - 1) * 15.0  # 30, 45, 60, 75...


func get_move_speed() -> float:
	var multiplier = 1.0 + upgrade_levels["move_speed"] * 0.05  # 5% faster per level
	return BASE_MOVE_SPEED * multiplier


func get_health_regen() -> float:
	return upgrade_levels["health_regen"] * 2.0  # 2 HP/sec per level


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


func restart_game() -> void:
	get_tree().reload_current_scene()
