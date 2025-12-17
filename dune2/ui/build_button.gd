extends Control
class_name BuildButton

signal pressed(item_id: String)

var item_id: String = ""
var item_name: String = ""
var item_cost: int = 0
var is_producing: bool = false
var is_ready: bool = false
var progress: float = 0.0
var pulse_time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 32)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(id: String, data: Dictionary) -> void:
	item_id = id
	item_name = data.get("name", "Unknown")
	item_cost = data.get("cost", 0)
	queue_redraw()

func set_production_state(producing: bool, prod_progress: float = 0.0, ready: bool = false) -> void:
	is_producing = producing
	progress = prod_progress
	is_ready = ready
	queue_redraw()

func _process(delta: float) -> void:
	if is_ready:
		pulse_time += delta * 3.0
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed.emit(item_id)
			accept_event()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)

	# Background
	var bg_color = Constants.COLORS["ui_background"]
	if is_ready:
		# Pulsing highlight when ready
		var pulse = (sin(pulse_time) + 1.0) / 2.0
		bg_color = bg_color.lerp(Constants.COLORS["ui_highlight"], pulse * 0.5)
	draw_rect(rect, bg_color)

	# Progress bar overlay (from left side)
	if is_producing and not is_ready:
		var progress_rect = Rect2(Vector2.ZERO, Vector2(size.x * progress, size.y))
		draw_rect(progress_rect, Color(0.2, 0.5, 0.2, 0.6))

	# Border
	var border_color = Constants.COLORS["ui_border"]
	if is_ready:
		border_color = Constants.COLORS["ui_highlight"]
	draw_rect(rect, border_color, false, 2.0)

	# Text
	var font = ThemeDB.fallback_font
	var font_size = ThemeDB.fallback_font_size
	var text = item_name + " ($" + str(item_cost) + ")"

	if is_ready:
		text = "READY - " + item_name
	elif is_producing:
		text = item_name + " " + str(int(progress * 100)) + "%"

	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos = Vector2((size.x - text_size.x) / 2, (size.y + text_size.y) / 2 - 4)

	var text_color = Constants.COLORS["ui_text"]
	if is_ready:
		text_color = Constants.COLORS["ui_highlight"]

	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
