extends Node3D
@onready var sub_viewport: SubViewport = $Sprite3D/SubViewport
@onready var label: Label = $Sprite3D/SubViewport/PanelContainer/MarginContainer/Label
@onready var margin_container: MarginContainer = $Sprite3D/SubViewport/PanelContainer/MarginContainer

const MIN_WIDTH = 18 # 10p for the font + 8 for the left/right margins
const MIN_HEIGHT = 31 # 23p for the font + 8 for top/bottom margins
const MAX_WIDTH = 190 # Max width in pixels
const CHAT_BUBBLE_ORIGIN_Y_OFFSET = 0.1 # Used to multiply against the number of lines

# To get a character's width and height:
# print(label.get_theme_font("normal_font").get_string_size("a"))

# TO FIX
# REPLACE PANEL CONTAINER WITH A NINE PATCH RECT with a custom texture!

func _init() -> void:
	hide()

func _ready() -> void:
	# Connect the public chat packet here so we can update the chat bubble
	# of the character that said something!
	pass

# Updates the chat bubble text
func set_text(new_text: String) -> void:
	# If the text hasn't changed, ignore this
	if (new_text == label.text):
		return
	
	# Hide the chat bubble, then clear the text
	hide()
	_clear_text()
	
	# Update our label's contents
	label.text = new_text
	
	# Await a frame so the label size updates
	await get_tree().process_frame
	
	# Update our container's minimum size
	margin_container.custom_minimum_size.x = min(margin_container.size.x, MAX_WIDTH)
	# Check if our container exceeds the max width
	if margin_container.size.x > MAX_WIDTH:
		# If it does, enable autowrap_mode to split the text into multiple lines
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Await a frame so the label size updates again
		await get_tree().process_frame
		# Since our Y size changed, we update it as well
		margin_container.custom_minimum_size.y = margin_container.size.y
	
	# After a frame, adjust the sub_viewport size to match the container size
	sub_viewport.size = margin_container.custom_minimum_size
	
	# Use the line count to correct the origin point of the chat bubble
	# so it doesn't clip with the character's head
	var chat_bubble_origin_y := label.get_line_count()
	position.y = chat_bubble_origin_y * CHAT_BUBBLE_ORIGIN_Y_OFFSET
	
	# Display the bubble
	show()

# Used in between chat bubbles to clear the text just in case is a one liner
func _clear_text() -> void:
	label.text = ""
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Reset the margin container's size back to zero
	margin_container.custom_minimum_size = Vector2(MIN_WIDTH, MIN_HEIGHT)
	# Await a frame so the label and container size updates
	await get_tree().process_frame
	# Copy the new size to be the size of our sub viewport
	sub_viewport.size = margin_container.custom_minimum_size

#func _input(event):
#	if event.is_action_pressed("space"):
#		set_text("okay this is a test and it sucks!,okay this is a test and it sucks!")
