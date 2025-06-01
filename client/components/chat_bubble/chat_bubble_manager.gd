extends Node3D

const MAX_BUBBLES: int = 2
const MAX_TOTAL_HEIGHT: float = 3.0 # Max Height in meters
const BUBBLE_SPACING: float = 0.15 # Space between bubbles in meters
const MESSAGE_MAX_LENGTH: int = 50
const FADE_OUT_DURATION = 0.25

@onready var chat_bubble_scene: PackedScene = preload("res://components/chat_bubble/chat_bubble.tscn")

var active_bubbles = []
var bubble_queue = [] # Messages waiting to be shown


func show_bubble(message: String) -> void:
	# If message is too long
	if message.length() > MESSAGE_MAX_LENGTH:
		# Clear all existing bubbles and spawn the new bubble
		clear_all_bubbles()
		_create_bubble(message)
		return
	
	# If we are at max bubbles, remove the oldest bubble immediately
	if active_bubbles.size() >= MAX_BUBBLES:
		var oldest_bubble = active_bubbles[0]
		oldest_bubble.fade_out(FADE_OUT_DURATION)
		active_bubbles.remove_at(0)
	
	# Now create the new bubble
	_create_bubble(message)
	_position_bubbles()


func _process_queue() -> void:
	# Remove expired bubbles first
	_cleanup_expired_bubbles()
	
	# Show as many bubbles as possible
	while bubble_queue.size() > 0 and active_bubbles.size() < MAX_BUBBLES:
		var message: String = bubble_queue.pop_front()
		_create_bubble(message)
	
	# Update bubble positions
	_position_bubbles()


func _create_bubble(message: String) -> void:
	var new_bubble = chat_bubble_scene.instantiate()
	add_child(new_bubble)
	new_bubble.set_text(message)
	
	# Connect to bubble's finished signal
	if new_bubble.has_signal("bubble_finished"):
		new_bubble.bubble_finished.connect(_on_bubble_finished.bind(new_bubble))
	
	active_bubbles.append(new_bubble)


# Removes bubble from active list
func _on_bubble_finished(bubble: Node) -> void:
	var index = active_bubbles.find(bubble)
	if index != -1:
		active_bubbles.remove_at(index)
	
	# Process queue again
	_process_queue()


func _position_bubbles() -> void:
	var current_height = 0.0
	
	# Position bubbles from bottom to top in reverse order,
	# so newest bubbles are closer to the character
	for i in range(active_bubbles.size() -1, -1, -1):
		var bubble = active_bubbles[i]
		# Get the bubble height in 3D space 
		var bubble_height = bubble.get_bubble_height()
		
		# Position bubble
		bubble.position = Vector3(0, current_height, 0)
		
		# Update current height
		current_height += bubble_height + BUBBLE_SPACING
		
		# Stop if we've reached max height
		if current_height > MAX_TOTAL_HEIGHT:
			# Remove extra bubbles (oldest ones)
			for j in range(0, i):
				active_bubbles[j].queue_free()
			
			active_bubbles = active_bubbles.slice(i, active_bubbles.size())
			break


# Remove any bubbles that have finished
func _cleanup_expired_bubbles() -> void:
	for i in range(active_bubbles.size() -1, -1, -1):
		if not is_instance_valid(active_bubbles[i]) or active_bubbles[i].is_queued_for_deletion():
			active_bubbles.remove_at(i)


# Clears both bubble arrays and destroys every active bubble
func clear_all_bubbles() -> void:
	for bubble in active_bubbles:
		bubble.queue_free()
	active_bubbles.clear()
	bubble_queue.clear()


func get_bubble_height(bubble: Node) -> float:
	# Get the actual height from the bubble
	var pixel_height = bubble.get_bubble_height()
	# Convert to 3D space
	return pixel_height * 0.01 # Example scale factor
