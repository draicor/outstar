extends CanvasLayer

@onready var tooltip_panel: TextureRect = $TooltipPanel
@onready var label: Label = $TooltipPanel/Label


func _ready() -> void:
	hide()


func show_tooltip(text: String):
	label.text = text
	update_position()
	show()


func hide_tooltip():
	hide()


func update_position(mouse_offset: Vector2 = Vector2(12, 12)):
	# Position slightly offset from the mouse
	var mouse_position = get_viewport().get_mouse_position()
	label.position = mouse_position + mouse_offset
	
	# Clamp to screen edges
	var viewport_size = get_viewport().get_window().size
	label.position.x = clamp(label.position.x, 0, viewport_size.x - label.size.x)
	label.position.y = clamp(label.position.y, 0, viewport_size.y - label.size.y)
