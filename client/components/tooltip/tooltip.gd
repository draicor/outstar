extends CanvasLayer

@onready var tooltip_panel: TextureRect = $TooltipPanel
@onready var label: Label = $TooltipPanel/Label


func _ready() -> void:
	hide_tooltip()


func show_tooltip(text: String, world_position: Vector3):
	var screen_position = get_viewport().get_camera_3d().unproject_position(world_position)
	label.text = text
	tooltip_panel.position = screen_position - Vector2(tooltip_panel.size.x * 0.5, tooltip_panel.size.y * 0.5)
	tooltip_panel.show()


func hide_tooltip():
	tooltip_panel.hide()
