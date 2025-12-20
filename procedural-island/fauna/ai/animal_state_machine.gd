extends Node
class_name AnimalStateMachine

## State machine for animal AI behavior

var current_state: AnimalState
var states: Dictionary = {}
var animal: AnimalBase

@export var initial_state: String = "idle"
@export var debug_mode: bool = false

func _ready() -> void:
	# Get reference to parent animal
	animal = get_parent() as AnimalBase

	# Collect all state children
	for child in get_children():
		if child is AnimalState:
			var state_name = child.get_state_name()
			states[state_name] = child
			child.state_machine = self
			child.animal = animal

	# Start in initial state
	await get_tree().process_frame
	if states.has(initial_state):
		change_state(initial_state)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func change_state(new_state_name: String) -> void:
	if not states.has(new_state_name):
		push_warning("State not found: " + new_state_name)
		return

	var new_state = states[new_state_name]

	if current_state == new_state:
		return

	if debug_mode:
		print(animal.name + " changing state: " + (current_state.name if current_state else "none") + " -> " + new_state_name)

	if current_state:
		current_state.exit()

	current_state = new_state
	current_state.enter()

func get_current_state_name() -> String:
	if current_state:
		return current_state.get_state_name()
	return ""
