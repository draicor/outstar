extends CanvasLayer

@onready var label: Label = $MarginContainer/Label

func _ready() -> void:
	hide()


func show_tooltip(text: String):
	label.text = text
	update_position()
	await get_tree().process_frame # Give it a frame to update
	show()


func hide_tooltip():
	hide()


func update_position(mouse_offset: Vector2 = Vector2(6, 6)):
	# Position slightly offset from the mouse
	var mouse_position = get_viewport().get_mouse_position()
	label.position = mouse_position + mouse_offset
	
	# Clamp to screen edges
	var viewport_size = get_viewport().get_window().size
	label.position.x = clamp(label.position.x, 0, viewport_size.x - label.size.x)
	label.position.y = clamp(label.position.y, 0, viewport_size.y - label.size.y)
