extends CanvasLayer

signal build_requested(building_type: String)
signal minimap_clicked(world_position: Vector2)

@onready var sidebar: Sidebar = $RightPanel/VBoxContainer/Sidebar
@onready var minimap: Minimap = $RightPanel/VBoxContainer/Minimap
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/ResultLabel

func _ready() -> void:
	sidebar.build_requested.connect(_on_build_requested)
	minimap.clicked.connect(_on_minimap_clicked)
	GameManager.game_over.connect(_on_game_over)
	game_over_panel.visible = false

func setup(terrain_manager: TerrainManager, fog: FogOfWar, camera: GameCamera = null) -> void:
	minimap.setup(terrain_manager, fog, camera)

func _on_build_requested(building_type: String) -> void:
	build_requested.emit(building_type)

func _on_minimap_clicked(world_position: Vector2) -> void:
	minimap_clicked.emit(world_position)

func _on_game_over(winner: int) -> void:
	game_over_panel.visible = true
	if winner == GameManager.player_faction:
		game_over_label.text = "VICTORY!"
		game_over_label.modulate = Color.GREEN
	else:
		game_over_label.text = "DEFEAT"
		game_over_label.modulate = Color.RED
