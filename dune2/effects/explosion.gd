extends Node2D
class_name Explosion

var lifetime: float = 0.4
var max_lifetime: float = 0.4
var max_radius: float = 20.0
var explosion_color: Color = Color(1, 0.6, 0)  # Orange

func _ready() -> void:
	queue_redraw()

func setup(radius: float = 20.0, color: Color = Color(1, 0.6, 0)) -> void:
	max_radius = radius
	explosion_color = color
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress = 1.0 - (lifetime / max_lifetime)
	var radius = max_radius * progress
	var alpha = 1.0 - progress

	# Outer explosion (orange/red)
	draw_circle(Vector2.ZERO, radius, Color(explosion_color.r, explosion_color.g, explosion_color.b, alpha))

	# Inner bright core (yellow/white)
	var inner_radius = radius * 0.5
	var inner_alpha = alpha * 1.2
	draw_circle(Vector2.ZERO, inner_radius, Color(1, 1, 0.5, clampf(inner_alpha, 0, 1)))

	# Center flash (white)
	if progress < 0.3:
		var flash_alpha = (0.3 - progress) / 0.3
		draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, flash_alpha))
