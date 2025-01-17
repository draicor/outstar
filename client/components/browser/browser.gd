extends Control

# Preload resources
const packets := preload("res://packets.gd")
const dialog_box_scene: PackedScene = preload("res://components/dialog_box/dialog_box.tscn")
const entry_scene: PackedScene = preload("res://components/browser/entry.tscn")
@onready var create_room_button: Button = $MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/CreateRoomButton
@onready var room_list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/RoomListContainer

# User Interface Variables
var ui_canvas: CanvasLayer
var dialog_box : Control

func initialize(canvas: CanvasLayer) -> void:
	ui_canvas = canvas
	# Connect the browser_join_room signal
	Signals.browser_join_room.connect(_on_join_room_button_pressed)

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

# Disable the buttons so the user can't spam the server
func disable_input() -> void:
	create_room_button.disabled = true

func _on_join_room_button_pressed(room_id: int) -> void:
	disable_input()
	
	# We create the packet and send it to the server
	if send_join_room_request_packet(room_id):
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

# Delete every entry from our room list
func delete_all_entries() -> void:
	for i in range(0, room_list_container.get_child_count()):
		room_list_container.get_child(i).queue_free()

# Adds a single entry to the list
func add_room_entry(room_info: packets.RoomInfo) -> void:
	# We instantiate an entry
	var entry := entry_scene.instantiate()
	# We add it to our browser room list with force readable name set to false
	room_list_container.add_child(entry, false)
	# The entry starts as hidden, we pass the values that will
	# have, and then we show it from code
	entry.initialize(
		room_info.get_master(),
		room_info.get_map_name(),
		room_info.get_players_online(),
		room_info.get_max_players(),
		room_info.get_room_id(),
		)
