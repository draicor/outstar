extends Node

# Preload resources
const packets := preload("res://packets.gd")


func _ready() -> void:
	GameManager.set_state(GameManager.State.CONNECTED)


# We use the _process to check for input faster, its better than using _input
func _process(_delta):
	if Input.is_action_just_pressed("ui_enter"):
		Signals.ui_chat_input_toggle.emit()
	if Input.is_action_just_pressed("ui_escape"):
		Signals.ui_escape_menu_toggle.emit()
	elif Input.is_action_just_pressed("zoom_in"):
		Signals.ui_zoom_in.emit()
	elif Input.is_action_just_pressed("zoom_out"):
		Signals.ui_zoom_out.emit()
	elif Input.is_action_just_pressed("rotate_camera_left"):
		Signals.ui_rotate_camera_left.emit()
	elif Input.is_action_just_pressed("rotate_camera_right"):
		Signals.ui_rotate_camera_right.emit()
