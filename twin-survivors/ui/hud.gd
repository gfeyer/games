extends CanvasLayer

@onready var wave_label: Label = $WaveContainer/WaveLabel
@onready var credits_label: Label = $CreditsContainer/HBoxContainer/CreditsLabel
@onready var p1_health_bar: ProgressBar = $HealthBars/P1HealthBar
@onready var p2_health_bar: ProgressBar = $HealthBars/P2HealthBar
@onready var wave_announcement: Label = $WaveAnnouncement
@onready var upgrade_shop: Control = $UpgradeShop
@onready var game_over_panel: Control = $GameOverPanel

var credits_display: int = 0
var credits_target: int = 0


func _ready() -> void:
	# Connect signals
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.wave_ended.connect(_on_wave_ended)
	GameManager.credits_changed.connect(_on_credits_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.shop_opened.connect(_on_shop_opened)

	# Find players and connect health signals
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		if player is Player:
			if player.player_id == 1:
				player.health_changed.connect(_on_p1_health_changed)
			elif player.player_id == 2:
				player.health_changed.connect(_on_p2_health_changed)

	# Initial state
	wave_announcement.visible = false
	upgrade_shop.visible = false
	game_over_panel.visible = false
	update_credits_display()


func _process(delta: float) -> void:
	# Animate credits counter
	if credits_display != credits_target:
		var diff = credits_target - credits_display
		var step = max(1, abs(diff) / 10)
		if diff > 0:
			credits_display = min(credits_display + int(step), credits_target)
		else:
			credits_display = max(credits_display - int(step), credits_target)
		update_credits_display()


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "WAVE %d" % wave_number
	show_wave_announcement(wave_number)
	upgrade_shop.visible = false


func _on_wave_ended(_wave_number: int) -> void:
	# Wave ended - shop will open via shop_opened signal
	pass


func _on_shop_opened() -> void:
	upgrade_shop.visible = true
	upgrade_shop.refresh_shop()


func _on_credits_changed(amount: int) -> void:
	credits_target = amount
	# Pop effect on gain
	if amount > credits_display:
		var tween = create_tween()
		tween.tween_property(credits_label, "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(credits_label, "scale", Vector2(1.0, 1.0), 0.1)


func _on_p1_health_changed(current: int, max_health: int) -> void:
	if p1_health_bar:
		var tween = create_tween()
		tween.tween_property(p1_health_bar, "value", float(current) / max_health * 100, 0.2)


func _on_p2_health_changed(current: int, max_health: int) -> void:
	if p2_health_bar:
		var tween = create_tween()
		tween.tween_property(p2_health_bar, "value", float(current) / max_health * 100, 0.2)


func _on_game_over() -> void:
	game_over_panel.visible = true
	upgrade_shop.visible = false


func update_credits_display() -> void:
	credits_label.text = str(credits_display)


func show_wave_announcement(wave_number: int) -> void:
	wave_announcement.text = "WAVE %d" % wave_number
	wave_announcement.visible = true
	wave_announcement.modulate.a = 0
	wave_announcement.scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave_announcement, "modulate:a", 1.0, 0.3)
	tween.tween_property(wave_announcement, "scale", Vector2(1.2, 1.2), 0.3)

	await tween.finished

	await get_tree().create_timer(1.0).timeout

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave_announcement, "modulate:a", 0.0, 0.5)
	tween.tween_property(wave_announcement, "scale", Vector2(1.5, 1.5), 0.5)

	await tween.finished
	wave_announcement.visible = false


func _on_restart_pressed() -> void:
	game_over_panel.visible = false
	get_parent().restart_game()
