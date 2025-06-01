extends Node3D

@export var BUBBLE_HEIGHT_OFFSET = 0.0 # Y-axis offset

const MAX_BUBBLES: int = 2
const MAX_TOTAL_HEIGHT: float = 3.0 # Max Height in meters
const BUBBLE_SPACING: float = 0.1 # Space between bubbles in meters
const LINE_HEIGHT = 0.18 # Additional height per extra line
const FADE_OUT_DURATION = 0.25 # Same as chat_bubble.gd fade-out
# Character threshold, more than 50 and it won't display with other bubbles
const MESSAGE_MAX_LENGTH: int = 50

@onready var chat_bubble_scene: PackedScene = preload("res://components/chat_bubble/chat_bubble.tscn")

var active_bubbles = []


func show_bubble(message: String) -> void:
	# Check for existing long messages
	var has_long_message: bool = false
	for bubble in active_bubbles:
		if bubble.is_long_message:
			has_long_message = true
			break
	
	# Hand long messages (either new or existing)
	if has_long_message or message.length() > MESSAGE_MAX_LENGTH:
		# Clear all existing bubbles and spawn the new bubble
		clear_all_bubbles()
		var new_bubble = _create_bubble(message)
		if message.length() > MESSAGE_MAX_LENGTH:
			new_bubble.is_long_message = true
		return
	
	# Remove oldest bubble if we're at max capacity
	if active_bubbles.size() >= MAX_BUBBLES:
		var oldest_bubble = active_bubbles[0]
		oldest_bubble.fade_out(FADE_OUT_DURATION)
		active_bubbles.remove_at(0)
	
	# Now create the new bubble
	_create_bubble(message)
	_position_bubbles()


func _create_bubble(message: String) -> Node:
	var new_bubble = chat_bubble_scene.instantiate()
	add_child(new_bubble)
	new_bubble.set_text(message)
	
	# Connect to bubble's finished signal
	if new_bubble.has_signal("bubble_finished"):
		new_bubble.bubble_finished.connect(_on_bubble_finished.bind(new_bubble))
	
	active_bubbles.append(new_bubble)
	return new_bubble


# Removes bubble from active list
func _on_bubble_finished(bubble: Node) -> void:
	var index = active_bubbles.find(bubble)
	if index != -1:
		active_bubbles.remove_at(index)
	
	# After clearing a bubble re-position all bubbles
	_position_bubbles()


func _position_bubbles() -> void:
	# Don't create tween if no bubbles need moving
	if active_bubbles.size() == 0:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	var has_tweeners = false
	
	# Spawn the bubble here first
	var current_height = BUBBLE_HEIGHT_OFFSET
	
	# Position bubbles from bottom to top in reverse order,
	# so newest bubbles are closer to the character
	for i in range(active_bubbles.size() -1, -1, -1):
		var bubble = active_bubbles[i]
		var bubble_height = _get_bubble_height(bubble)
		
		# Get the visual center position for this bubble
		var bubble_center = current_height + (bubble_height / 2.0)
		
		# Bubble target position
		var target_pos = Vector3(0, bubble_center, 0)
		
		# Only tween if position changed
		if abs(bubble.position.y - target_pos.y) > 0.01:
			tween.tween_property(bubble, "position", target_pos, 0.2)
			has_tweeners = true
		
		# Move up for next bubble
		current_height += bubble_height + BUBBLE_SPACING
		
		# Stop if we've reached max height
		if current_height > MAX_TOTAL_HEIGHT:
			# Remove oldest bubbles that don't fit
			for j in range(0, i):
				active_bubbles[j].fade_out(FADE_OUT_DURATION)
			
			active_bubbles = active_bubbles.slice(i, active_bubbles.size())
			break
	
	# If we are not moving our bubble, clear the tween
	if not has_tweeners and tween:
		tween.kill()


# Returns the accurate height of the bubble's content
func _get_bubble_height(bubble: Node) -> float:
	return bubble.get_content_height()


# Clears array and destroys every active bubble
func clear_all_bubbles() -> void:
	for bubble in active_bubbles:
		bubble.fade_out(FADE_OUT_DURATION)
	active_bubbles.clear()


# Release the bubbles if this gets destroyed
func _exit_tree() -> void:
	clear_all_bubbles()
