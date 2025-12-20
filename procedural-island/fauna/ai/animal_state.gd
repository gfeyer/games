extends Node
class_name AnimalState

## Base class for animal AI states

var state_machine: Node
var animal: AnimalBase

func enter() -> void:
	## Called when entering this state
	pass

func exit() -> void:
	## Called when exiting this state
	pass

func update(delta: float) -> void:
	## Called every physics frame while in this state
	pass

func get_state_name() -> String:
	return name.to_lower()
