extends Node

# Grid settings
const TILE_SIZE: int = 32
const MAP_WIDTH: int = 64
const MAP_HEIGHT: int = 64

# Terrain types
enum Terrain {
	SAND,
	ROCK,
	SPICE_LOW,
	SPICE_MEDIUM,
	SPICE_HIGH,
	CONCRETE,
	BUILDING
}

# Fog of war states
enum FogState {
	UNEXPLORED,
	EXPLORED,
	VISIBLE
}

# Factions
enum Faction {
	ATREIDES,
	HARKONNEN,
	NEUTRAL
}

# Dune 2 Color Palette
const COLORS = {
	# Terrain
	"sand": Color("#C4A458"),
	"rock": Color("#785830"),
	"spice_low": Color("#B85820"),
	"spice_medium": Color("#D06018"),
	"spice_high": Color("#E87010"),
	"concrete": Color("#606060"),

	# Fog
	"fog_unexplored": Color("#000000"),
	"fog_explored": Color(0, 0, 0, 0.6),

	# Factions
	"atreides": Color("#2060A0"),
	"atreides_light": Color("#4080C0"),
	"harkonnen": Color("#A02020"),
	"harkonnen_light": Color("#C04040"),

	# UI
	"ui_background": Color("#182838"),
	"ui_border": Color("#304050"),
	"ui_text": Color("#C0C0C0"),
	"ui_highlight": Color("#FFFF80"),
	"health_green": Color("#40C040"),
	"health_yellow": Color("#C0C040"),
	"health_red": Color("#C04040"),
}

# Building definitions
const BUILDINGS = {
	"construction_yard": {
		"name": "Construction Yard",
		"size": Vector2i(3, 3),
		"cost": 0,
		"health": 1000,
		"build_time": 0.0,
		"sight_range": 5,
		"power": 0,
		"produces": "buildings"
	},
	"concrete": {
		"name": "Concrete",
		"size": Vector2i(1, 1),
		"cost": 5,
		"health": 100,
		"build_time": 1.0,
		"sight_range": 0,
		"power": 0,
		"produces": null
	},
	"refinery": {
		"name": "Refinery",
		"size": Vector2i(3, 2),
		"cost": 300,
		"health": 500,
		"build_time": 10.0,
		"sight_range": 4,
		"power": -30,
		"produces": null,
		"storage": 1000,
		"spawns_harvester": true
	},
	"barracks": {
		"name": "Barracks",
		"size": Vector2i(2, 2),
		"cost": 200,
		"health": 400,
		"build_time": 8.0,
		"sight_range": 3,
		"power": -10,
		"produces": "infantry"
	},
	"light_factory": {
		"name": "Light Factory",
		"size": Vector2i(3, 2),
		"cost": 400,
		"health": 600,
		"build_time": 12.0,
		"sight_range": 3,
		"power": -20,
		"produces": "vehicles"
	}
}

# Unit definitions
const UNITS = {
	"harvester": {
		"name": "Harvester",
		"cost": 300,
		"health": 100,
		"speed": 50.0,
		"damage": 0,
		"attack_range": 0,
		"attack_speed": 0.0,
		"sight_range": 4,
		"build_time": 8.0,
		"capacity": 500
	},
	"infantry": {
		"name": "Light Infantry",
		"cost": 50,
		"health": 30,
		"speed": 80.0,
		"damage": 5,
		"attack_range": 2,
		"attack_speed": 1.0,
		"sight_range": 3,
		"build_time": 4.0
	},
	"tank": {
		"name": "Light Tank",
		"cost": 200,
		"health": 80,
		"speed": 120.0,
		"damage": 15,
		"attack_range": 4,
		"attack_speed": 1.5,
		"sight_range": 5,
		"build_time": 10.0
	}
}

# Game settings
const STARTING_CREDITS: int = 2000
const SPICE_HARVEST_RATE: int = 10
const SPICE_REGROW_TIME: float = 60.0

# Helper functions
static func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2, grid_pos.y * TILE_SIZE + TILE_SIZE / 2)

static func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

static func is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < MAP_WIDTH and grid_pos.y >= 0 and grid_pos.y < MAP_HEIGHT
