extends Node3D

const MAX_BUBBLES: int = 2
const MAX_TOTAL_HEIGHT: float = 3.0 # Max Height in meters
const BUBBLE_SPACING: float = 0.3 # Space between bubbles in meters
const MESSAGE_MAX_LENGTH: int = 50

@onready var chat_bubble_scene: PackedScene = preload("res://components/chat_bubble/chat_bubble.tscn")

var active_bubbles = []
var bubble_queue = [] # Messages waiting to be shown


func show_bubble(message: String) -> void:
	# If message is too long, clear all existing bubbles
	if message.length() > MESSAGE_MAX_LENGTH:
		clear_all_bubbles()
	
	# Add bubble to queue and process
	bubble_queue.append(message)
	_process_queue()


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
	
	# Position bubbles from bottom to top
	for bubble in active_bubbles:
		# Get the bubble height in 3D space 
		var bubble_height = bubble.get_bubble_height()
		
		# Position bubble
		bubble.position = Vector3(0, current_height, 0)
		
		# Update current height
		current_height += bubble_height + BUBBLE_SPACING
		
		# Stop if we've reached max height
		if current_height > MAX_TOTAL_HEIGHT:
			# Remove extra bubbles
			var index = active_bubbles.find(bubble)
			for j in range(index, active_bubbles.size()):
				active_bubbles[j].queue_free()
			active_bubbles.resize(index)
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
