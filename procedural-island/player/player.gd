extends CharacterBody3D
class_name Player

@export var move_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 20.0

var camera: Camera3D
var camera_pivot: Node3D

func _ready() -> void:
	# Create camera pivot (for vertical rotation)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)
	camera_pivot.position.y = 1.6  # Eye height

	# Create camera
	camera = Camera3D.new()
	camera.name = "Camera"
	camera_pivot.add_child(camera)
	camera.current = true

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Handle mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (y-axis) on the player body
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Vertical rotation (x-axis) on the camera pivot
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)

		# Clamp vertical look
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2 + 0.1, PI/2 - 0.1)

	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	# Calculate movement direction relative to camera
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Determine speed (sprint or normal)
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else move_speed

	# Apply movement
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Decelerate
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
