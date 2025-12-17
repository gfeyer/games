extends Unit
class_name Tank

var turret_rotation: float = 0.0

func _ready() -> void:
	unit_type = "tank"
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Turret tracks target
	if attack_target and is_instance_valid(attack_target):
		var target_dir = (attack_target.global_position - global_position).normalized()
		var target_angle = target_dir.angle() + PI / 2
		turret_rotation = lerp_angle(turret_rotation, target_angle - rotation, delta * 5.0)
		queue_redraw()

func _draw() -> void:
	var base_color = Constants.COLORS["atreides"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen"]
	var border_color = Constants.COLORS["atreides_light"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen_light"]

	# Tank body
	var body_size = Vector2(18, 24)
	draw_rect(Rect2(-body_size / 2, body_size), base_color)
	draw_rect(Rect2(-body_size / 2, body_size), border_color, false, 2.0)

	# Tracks
	var track_width = 4
	draw_rect(Rect2(-body_size.x / 2 - track_width, -body_size.y / 2, track_width, body_size.y), Constants.COLORS["ui_background"])
	draw_rect(Rect2(body_size.x / 2, -body_size.y / 2, track_width, body_size.y), Constants.COLORS["ui_background"])

	# Turret (rotates independently)
	draw_set_transform(Vector2.ZERO, turret_rotation)

	# Turret base
	draw_circle(Vector2.ZERO, 7, base_color.lightened(0.1))
	draw_arc(Vector2.ZERO, 7, 0, TAU, 16, border_color, 1.0)

	# Gun barrel
	draw_line(Vector2.ZERO, Vector2(0, -16), Constants.COLORS["ui_background"], 3.0)
	draw_line(Vector2.ZERO, Vector2(0, -16), border_color, 1.0)

	draw_set_transform(Vector2.ZERO, 0)

	# Selection indicator
	if is_selected:
		draw_rect(Rect2(-body_size / 2 - Vector2(6, 6), body_size + Vector2(12, 12)), Color.WHITE, false, 2.0)

	# Health bar
	var health_bar_width = body_size.x + 8
	var health_bar_height = 4
	var health_bar_pos = Vector2(-health_bar_width / 2, -body_size.y / 2 - 12)

	draw_rect(Rect2(health_bar_pos, Vector2(health_bar_width, health_bar_height)), Color(0.2, 0.2, 0.2))

	var health_percent = get_health_percent()
	var health_color = Constants.COLORS["health_green"]
	if health_percent < 0.3:
		health_color = Constants.COLORS["health_red"]
	elif health_percent < 0.6:
		health_color = Constants.COLORS["health_yellow"]

	draw_rect(Rect2(health_bar_pos, Vector2(health_bar_width * health_percent, health_bar_height)), health_color)
