extends CanvasLayer

@onready var label: Label = $MarginContainer/Label

# We hide the tooltip by default
func _ready() -> void:
	hide()


# Called to update the tooltip text and show it
func show_tooltip(text: String):
	label.text = text
	update_position()
	await get_tree().process_frame # Give it a frame to update
	show()


# Used to hide the tooltip when no longer hovering over something
func hide_tooltip():
	hide()


# This is called to update the position of the tooltip, to follow the mouse
func update_position(mouse_offset: Vector2 = Vector2(2, 6)):
	# Position slightly offset from the mouse
	var mouse_position = get_viewport().get_mouse_position()
	label.position = mouse_position + mouse_offset
	
	# Clamp to screen edges
	var viewport_size = get_viewport().get_window().size
	label.position.x = clamp(label.position.x, 0, viewport_size.x - label.size.x)
	label.position.y = clamp(label.position.y, 0, viewport_size.y - label.size.y)
