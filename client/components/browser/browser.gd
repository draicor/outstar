extends Control

# Preload resources
const packets := preload("res://packets.gd")
const dialog_box_scene: PackedScene = preload("res://components/dialog_box/dialog_box.tscn")
@onready var join_room_button: Button = $MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/JoinRoomButton
@onready var create_room_button: Button = $MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/CreateRoomButton

# User Interface Variables
var ui_canvas: CanvasLayer
var dialog_box : Control

func initialize(canvas: CanvasLayer) -> void:
	ui_canvas = canvas

# Auxiliary function to create dialog boxes
func new_dialog_box(message: String, button_visible: bool) -> void:
	# If we already instantiated a dialog box
	if is_instance_valid(dialog_box):
		dialog_box.initialize(message, button_visible)
	else:
		# We instantiate the dialog box scene
		dialog_box = dialog_box_scene.instantiate()
		# We add it to our root with force readable name set to false
		ui_canvas.add_child(dialog_box, false)
		# The dialog_box starts as hidden, we pass the values that will
		# have, and then we show it from code
		dialog_box.initialize(message, button_visible)

# Hides the dialog box if its valid, after a delay (defaults to 1 second)
func hide_dialog_box(delay: float = 1.0) -> void:
	# Only attempt this if we have an instance
	if is_instance_valid(dialog_box):
		# Do some action
		await get_tree().create_timer(delay).timeout # waits for 1 second
# 		Do something afterwards
		dialog_box.hide()

func send_join_room_request_packet(room_id: int) -> bool:
	# We create a new packet
	var packet := packets.Packet.new()
	# We send the packet with the room_id we want to access
	var join_room_request_packet := packet.new_join_room_request()
	join_room_request_packet.set_room_id(room_id)

	# Serialize and send our packet
	var err := WebSocket.send(packet)
	# Report if we succeeded or failed
	if err:
		return false
	else:
		return true

func send_create_room_request_packet() -> bool:
	# We create a new packet
	var packet := packets.Packet.new()
	packet.new_create_room_request()

	# Serialize and send our packet
	var err := WebSocket.send(packet)
	# Report if we succeeded or failed
	if err:
		return false
	else:
		return true

func send_get_rooms_request() -> bool:
	# We create a new packet
	var packet := packets.Packet.new()
	packet.new_get_rooms_request()
	
	# Serialize and send our packet
	var err := WebSocket.send(packet)
	if err:
		return false
	else:
		return true

# Enable the buttons so the user can use them again
func enable_input() -> void:
	create_room_button.disabled = false
	join_room_button.disabled = false

# Disable the buttons so the user can't spam the server
func disable_input() -> void:
	create_room_button.disabled = true
	join_room_button.disabled = true

func _on_join_room_button_pressed() -> void:
	disable_input()
	
	# We create the packet and send it to the server
	if send_join_room_request_packet(1):
		# Show a dialog box to the user as he waits
		new_dialog_box("Joining room...", false)
	else:
		new_dialog_box("Error sending data to the server", true)
		enable_input()

func _on_create_room_button_pressed() -> void:
	# We disable the button so the user can't spam it
	disable_input()
	
	# We create the packet and send it to the server
	if send_create_room_request_packet():
		# Show a dialog box to the user as he waits
		new_dialog_box("Creating room...", false)
	else:
		new_dialog_box("Error sending data to the server", true)
		enable_input()

func _on_refresh_button_pressed() -> void:
	# We disable the button so the user can't spam it
	disable_input()
	
	# We create the packet and send it to the server
	if send_get_rooms_request():
		# Show a dialog box to the user as he waits
		new_dialog_box("Updating list...", false)
	else:
		new_dialog_box("Error sending data to the server", true)
	
	enable_input()
