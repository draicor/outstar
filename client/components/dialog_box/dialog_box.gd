extends Control

@onready var message_label: Label = $PanelContainer/VBoxContainer/MessageLabel
@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton

# Initialize this scene as hidden since it won't have any data
func _init() -> void:
	hide()

# Initialize the data this scene needs to display the user
# This will also be called to update the data after instancing
func initialize(message: String, button_visible: bool) -> void:
	# Hide it for a brief moment to update the data
	# Making it look as if it was creating a new dialog box
	hide()
	
	message_label.text = message
	
	if button_visible:
		close_button.show()
	else:
		close_button.hide()
	
	show()

func _on_close_button_pressed() -> void:
	hide()
