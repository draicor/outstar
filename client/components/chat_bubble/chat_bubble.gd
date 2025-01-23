extends Node3D
@onready var sub_viewport: SubViewport = $Sprite3D/SubViewport
@onready var label: Label = $Sprite3D/SubViewport/PanelContainer/Label

# To get the font height:
# label.get_theme_font("normal_font").get_height()

func _ready() -> void:
	# Connect the chat signal here so we can update the chat bubble
	pass

# Updates the chat bubble text
func set_text(new_text: String) -> void:
	# If the text hasn't changed, ignore this
	if (new_text == label.text):
		return
	
	label.text = new_text
	
	# Use the line count to correct the origin point of the chat bubble
	#print(label.get_line_count())
	
	# Await a frame so the label size updates
	await get_tree().process_frame
	# After a frame, adjust the sub_viewport size to match the label size
	sub_viewport.size = label.size

func _input(event):
	if event.is_action_pressed("space"):
		set_text("okay this is a test and it sucks!")
