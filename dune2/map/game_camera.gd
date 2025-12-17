extends Camera2D
class_name GameCamera

@export var pan_speed: float = 500.0
@export var edge_margin: int = 20
@export var edge_scroll_enabled: bool = true
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var zoom_speed: float = 0.1

var map_bounds: Rect2

func _ready() -> void:
	# Calculate map bounds
	var map_size = Vector2(
		Constants.MAP_WIDTH * Constants.TILE_SIZE,
		Constants.MAP_HEIGHT * Constants.TILE_SIZE
	)
	map_bounds = Rect2(Vector2.ZERO, map_size)

	# Start centered on player area
	position = Vector2(200, 200)

func _process(delta: float) -> void:
	handle_keyboard_pan(delta)
	if edge_scroll_enabled:
		handle_edge_scroll(delta)
	clamp_to_bounds()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		zoom_camera(zoom_speed)
	elif event.is_action_pressed("zoom_out"):
		zoom_camera(-zoom_speed)

func handle_keyboard_pan(delta: float) -> void:
	var pan_direction = Vector2.ZERO

	if Input.is_action_pressed("camera_up"):
		pan_direction.y -= 1
	if Input.is_action_pressed("camera_down"):
		pan_direction.y += 1
	if Input.is_action_pressed("camera_left"):
		pan_direction.x -= 1
	if Input.is_action_pressed("camera_right"):
		pan_direction.x += 1

	if pan_direction != Vector2.ZERO:
		position += pan_direction.normalized() * pan_speed * delta / zoom.x

func handle_edge_scroll(delta: float) -> void:
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var pan_direction = Vector2.ZERO

	# Check if mouse is at screen edges
	if mouse_pos.x < edge_margin:
		pan_direction.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_margin:
		pan_direction.x += 1

	if mouse_pos.y < edge_margin:
		pan_direction.y -= 1
	elif mouse_pos.y > viewport_size.y - edge_margin:
		pan_direction.y += 1

	if pan_direction != Vector2.ZERO:
		position += pan_direction.normalized() * pan_speed * delta / zoom.x

func zoom_camera(amount: float) -> void:
	var new_zoom = clampf(zoom.x + amount, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

func clamp_to_bounds() -> void:
	var viewport_size = get_viewport_rect().size / zoom
	var half_viewport = viewport_size / 2

	position.x = clampf(position.x, half_viewport.x, map_bounds.size.x - half_viewport.x)
	position.y = clampf(position.y, half_viewport.y, map_bounds.size.y - half_viewport.y)

func center_on(world_pos: Vector2) -> void:
	position = world_pos
	clamp_to_bounds()

func get_world_mouse_position() -> Vector2:
	return get_global_mouse_position()

func screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport_size = get_viewport_rect().size
	var offset = screen_pos - viewport_size / 2
	return position + offset / zoom
