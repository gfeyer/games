extends Node3D

@onready var terrain: TerrainGenerator = $TerrainGenerator
@onready var player: Player = $Player
@onready var vegetation_spawner: VegetationSpawner = $VegetationSpawner
@onready var fauna_spawner: FaunaSpawner = $FaunaSpawner
@onready var sun: DirectionalLight3D = $DirectionalLight3D

func _ready() -> void:
	# Add sun to group for ecosystem manager to control
	sun.add_to_group("sun")

	# Wait for terrain to generate and collision to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	# Initialize ecosystem manager references
	if EcosystemManager:
		EcosystemManager.terrain = terrain
		EcosystemManager.player = player

	# Initialize vegetation spawner
	if vegetation_spawner and terrain and player:
		vegetation_spawner.initialize(terrain, player)

	# Position player on the island
	if terrain and player:
		var spawn_pos = terrain.get_spawn_position()
		player.global_position = spawn_pos
		print("Player spawned at: ", spawn_pos)

	# Initialize fauna spawner (after player is positioned)
	if fauna_spawner and terrain and player:
		fauna_spawner.initialize(terrain, player)
