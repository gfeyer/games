extends Node2D
class_name Tracer

var lifetime: float = 0.15
var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var tracer_color: Color = Color(1, 1, 0.5)

func setup(from: Vector2, to: Vector2, color: Color = Color(1, 1, 0.5)) -> void:
	start_pos = from
	end_pos = to
	tracer_color = color
	global_position = Vector2.ZERO  # Draw in global coords
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha = lifetime / 0.15
	var color = Color(tracer_color.r, tracer_color.g, tracer_color.b, alpha)
	draw_line(start_pos, end_pos, color, 2.0)

	# Bright core
	var core_color = Color(1, 1, 1, alpha * 0.8)
	draw_line(start_pos, end_pos, core_color, 1.0)
