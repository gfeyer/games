extends Node2D
class_name MuzzleFlash

var lifetime: float = 0.1
var flash_color: Color = Color(1, 1, 0.5)

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha = lifetime / 0.1
	draw_circle(Vector2.ZERO, 6, Color(flash_color.r, flash_color.g, flash_color.b, alpha))
	draw_circle(Vector2.ZERO, 3, Color(1, 1, 1, alpha))
