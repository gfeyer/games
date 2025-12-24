extends Control

signal names_submitted(p1_name: String, p2_name: String)

@onready var p1_input: LineEdit = $VBoxContainer/P1Container/P1NameInput
@onready var p2_input: LineEdit = $VBoxContainer/P2Container/P2NameInput
@onready var start_button: Button = $VBoxContainer/StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	p1_input.text_submitted.connect(_on_text_submitted)
	p2_input.text_submitted.connect(_on_text_submitted)
	p1_input.grab_focus()


func _on_start_pressed() -> void:
	submit_names()


func _on_text_submitted(_text: String) -> void:
	submit_names()


func submit_names() -> void:
	var p1_name = p1_input.text.strip_edges()
	var p2_name = p2_input.text.strip_edges()

	# Use placeholder names if empty
	if p1_name.is_empty():
		p1_name = "Seba"
	if p2_name.is_empty():
		p2_name = "Sofia"

	names_submitted.emit(p1_name, p2_name)
	hide()
