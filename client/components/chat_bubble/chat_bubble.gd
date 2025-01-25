extends Node3D
@onready var sub_viewport: SubViewport = $Sprite3D/SubViewport
@onready var label: Label = $Sprite3D/SubViewport/PanelContainer/MarginContainer/Label
@onready var margin_container: MarginContainer = $Sprite3D/SubViewport/PanelContainer/MarginContainer
@onready var panel_container: PanelContainer = $Sprite3D/SubViewport/PanelContainer
@onready var timer: Timer = $Timer

const MIN_WIDTH = 18 # 10p for the font + 8 for the left/right margins
const MIN_HEIGHT = 31 # 23p for the font + 8 for top/bottom margins
const MAX_WIDTH = 190 # Max width in pixels
const CHAT_BUBBLE_ORIGIN_Y_OFFSET = 0.1 # Used to multiply against the number of lines
const FADE_IN_DURATION = 0.25
const FADE_OUT_DURATION = 0.25
const CHAT_SPEECH_DISPLAY_TIME = 5.0 # Time before fading out the speech bubble

var is_bubble_active = false # Used to reset the timer and update the text without fading
var fade_tween: Tween

# To get a character's width and height:
# print(label.get_theme_font("normal_font").get_string_size("a"))

# TO UPGRADE
# REPLACE PANEL CONTAINER WITH A NINE PATCH RECT with a custom texture!

func _init() -> void:
	# Hide this on _init() so we don't have to hide it in the editor
	hide()

func _ready() -> void:	
	# Make the panel transparent on _ready() because we can't do it on _init()
	panel_container.modulate = Color.TRANSPARENT
	_clear_text()
	show()

# Updates the chat bubble text
func set_text(new_text: String) -> void:
	# If the text is empty, ignore this
	if (new_text == ""):
		return
	
	# If a bubble is already active, reset the timer without fading
	if is_bubble_active:
		timer.stop()
		_fade_out(FADE_OUT_DURATION)
		await get_tree().create_timer(FADE_OUT_DURATION).timeout
	
	# We clear the previous message and resize our container
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
	
	_fade_in(FADE_IN_DURATION)
	
	timer.start(CHAT_SPEECH_DISPLAY_TIME)

# Used in between chat bubbles to clear the text just in case is a one liner
func _clear_text() -> void:
	# Clear the text and resize the containers
	label.text = ""
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Reset the margin container's size back to zero
	margin_container.custom_minimum_size = Vector2(MIN_WIDTH, MIN_HEIGHT)
	# Await a frame so the label and container size updates
	await get_tree().process_frame
	# Copy the new size to be the size of our sub viewport
	sub_viewport.size = margin_container.custom_minimum_size

# Used to start the fade out transition
func _on_timer_timeout() -> void:
	_fade_out(FADE_OUT_DURATION)

func _fade_out(fade_duration: float) -> void:
	if fade_tween: fade_tween.kill()
	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(panel_container, "modulate", Color.TRANSPARENT, fade_duration)
	# Create an anonymous funtion to report the bubble is NOT active
	fade_tween.finished.connect(func(): is_bubble_active = false)

func _fade_in(fade_duration: float) -> void:
	if fade_tween: fade_tween.kill()
	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(panel_container, "modulate", Color.WHITE, fade_duration)
	# Create an anonymous funtion to report the bubble is active
	fade_tween.finished.connect(func(): is_bubble_active = true)

#func _input(event):
#	if event.is_action_pressed("space"):
#		set_text("okay this is a test and it sucks!,okay this is a test and it sucks!")
