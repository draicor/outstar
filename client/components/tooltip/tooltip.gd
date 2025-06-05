extends CanvasLayer

@onready var tooltip: CanvasLayer = $"."
@onready var panel_container: PanelContainer = $PanelContainer
@onready var margin_container: MarginContainer = $PanelContainer/MarginContainer
@onready var label: Label = $PanelContainer/MarginContainer/Label

var tooltip_offset: Vector2 = Vector2(0, 20)

# We hide the tooltip by default
func _ready() -> void:
	hide()


# Called to update the tooltip text and show it
func show_tooltip(text: String) -> void:
	if text != label.text:
		label.text = text
		# Force containers to recalculate their size
		label.reset_size()
		margin_container.reset_size()
		panel_container.reset_size()
	
	update_position()
	await get_tree().process_frame # Give it a frame to update
	show()


# Used to hide the tooltip when no longer hovering over something
func hide_tooltip():
	hide()


# This is called to update the position of the tooltip, to follow the mouse
func update_position():
	var mouse_position = get_viewport().get_mouse_position()
	# Position slightly offset from the mouse
	panel_container.position = mouse_position + tooltip_offset
	
	# Clamp to screen edges
	var viewport_size = get_viewport().get_window().size
	panel_container.position.x = clamp(panel_container.position.x, 0, viewport_size.x - panel_container.size.x)
	panel_container.position.y = clamp(panel_container.position.y, 0, viewport_size.y - panel_container.size.y)
