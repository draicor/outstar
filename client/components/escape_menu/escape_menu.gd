extends Control

@onready var version: Label = $Version
var is_active : bool = false

# Start hidden
func _init() -> void:
	self.hide()

func _ready() -> void:
	version.text = "v" + ProjectSettings.get_setting("application/config/version")

# Input Signals
func _on_resume_pressed() -> void:
	toggle()

# If we have a valid multiplayer peer, emit the disconnect signal to server.gd
func _on_disconnect_pressed() -> void:
	toggle()

func _on_quit_pressed() -> void:
	# Replace this with a better safer way to quit
	get_tree().quit()

# Used to show/hide this menu
func toggle() -> void:
	if is_active:
		self.hide()
		is_active = false
	else:
		self.show()
		is_active = true
