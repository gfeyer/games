extends Unit
class_name Infantry

func _ready() -> void:
	unit_type = "infantry"
	super._ready()

func _draw() -> void:
	# Infantry is a small figure
	var base_color = Constants.COLORS["atreides"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen"]
	var border_color = Constants.COLORS["atreides_light"] if faction == Constants.Faction.ATREIDES else Constants.COLORS["harkonnen_light"]

	# Body (small oval)
	var body_size = Vector2(8, 12)
	draw_rect(Rect2(-body_size / 2, body_size), base_color)
	draw_rect(Rect2(-body_size / 2, body_size), border_color, false, 1.0)

	# Head
	draw_circle(Vector2(0, -body_size.y / 2 - 3), 4, base_color)
	draw_arc(Vector2(0, -body_size.y / 2 - 3), 4, 0, TAU, 16, border_color, 1.0)

	# Weapon (line pointing forward)
	draw_line(Vector2(0, -body_size.y / 2 - 3), Vector2(0, -body_size.y / 2 - 10), Constants.COLORS["ui_background"], 2.0)

	# Selection indicator
	if is_selected:
		draw_arc(Vector2.ZERO, 10, 0, TAU, 16, Color.WHITE, 2.0)

	# Counter-rotate for health bar so it stays horizontal
	draw_set_transform(Vector2.ZERO, -rotation)

	# Health bar
	var health_bar_width = 16
	var health_bar_height = 3
	var health_bar_pos = Vector2(-8, -body_size.y / 2 - 16)

	draw_rect(Rect2(health_bar_pos, Vector2(health_bar_width, health_bar_height)), Color(0.2, 0.2, 0.2))

	var health_percent = get_health_percent()
	var health_color = Constants.COLORS["health_green"]
	if health_percent < 0.3:
		health_color = Constants.COLORS["health_red"]
	elif health_percent < 0.6:
		health_color = Constants.COLORS["health_yellow"]

	draw_rect(Rect2(health_bar_pos, Vector2(health_bar_width * health_percent, health_bar_height)), health_color)
