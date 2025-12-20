extends Node3D

@onready var terrain = $TerrainGenerator
@onready var player = $Player

func _ready() -> void:
	# Wait one frame for terrain to generate
	await get_tree().process_frame

	# Position player on the island
	if terrain and player:
		var spawn_pos = terrain.get_spawn_position()
		player.global_position = spawn_pos
		print("Player spawned at: ", spawn_pos)
