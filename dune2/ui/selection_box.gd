extends Node2D

var selection_rect: Rect2 = Rect2()
var is_selecting: bool = false

func set_selection(rect: Rect2, selecting: bool) -> void:
	selection_rect = rect
	is_selecting = selecting
	queue_redraw()

func _draw() -> void:
	if is_selecting and selection_rect.size.length() > 5:
		draw_rect(selection_rect, Color(1, 1, 1, 0.2))
		draw_rect(selection_rect, Color(1, 1, 1, 0.8), false, 2.0)
