extends Node

# Preload resources
const packets := preload("res://packets.gd")
const lobby_escape_menu_scene: PackedScene = preload("res://components/escape_menu/lobby/lobby_escape_menu.tscn")

# User Interface Variables
@onready var ui_canvas: CanvasLayer = $UI
@onready var chat: Control = $UI/Chat
@onready var browser: Control = $UI/Browser

var chat_input: LineEdit
var lobby_escape_menu

func _ready() -> void:
	_initialize()
	# To initialize the browser, we need to pass it our UI (CanvasLayer)
	browser.initialize(ui_canvas)
	# Send a packet to the server to let everyone know we joined
	_send_client_entered_packet()

func _initialize() -> void:
	# Get access to the child nodes of the chat UI
	chat_input = chat.find_child("Input")
	
	# Websocket signals
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)
	Signals.heartbeat_attempt.connect(_on_websocket_heartbeat_attempt)
	# User Interface signals
	Signals.ui_escape_menu_toggle.connect(_on_ui_escape_menu_toggle)
	# Chat signals
	Signals.ui_chat_input_toggle.connect(_on_ui_chat_input_toggle)
	chat_input.text_submitted.connect(_on_chat_input_text_submitted)
	
	# Create and add the escape menu to the UI canvas layer
	lobby_escape_menu = lobby_escape_menu_scene.instantiate()
	ui_canvas.add_child(lobby_escape_menu)

func _on_websocket_connection_closed() -> void:
	chat.error("You have been disconnected from the server")

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	#var sender_id := packet.get_sender_id()
	
	if packet.has_public_message():
		_handle_public_message_packet(packet.get_public_message())
	elif packet.has_heartbeat():
		Signals.heartbeat_received.emit()
	elif packet.has_client_entered():
		_handle_client_entered_packet(packet.get_client_entered().get_nickname())
	elif packet.has_client_left():
		_handle_client_left_packet(packet.get_client_left())
	elif packet.has_join_room_success():
		_handle_join_room_success_packet()
	elif packet.has_request_denied():
		_handle_request_denied_packet(packet.get_request_denied().get_reason())
	elif packet.has_room_list():
		print(packet)
		_handle_room_list_packet(packet.get_room_list().get_room_list())

# Print the message into our chat window
func _handle_public_message_packet(packet_public_message: packets.PublicMessage) -> void:
	# We print the nickname and then the message contents
	chat.public("%s" % packet_public_message.get_nickname(), packet_public_message.get_text(), Color.LIGHT_SEA_GREEN)

# We send a heartbeat packet to the server every time the timer timeouts
func _on_websocket_heartbeat_attempt() -> void:
	# We create a new packet of type heartbeat
	var packet := packets.Packet.new()
	packet.new_heartbeat()
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	# If we sent the packet, emit it
	if !err:
		Signals.heartbeat_sent.emit()

# When a new client connects, we print the message into our chat window
func _handle_client_entered_packet(nickname: String) -> void:
	chat.info("%s has joined" % nickname)

# When a client leaves, we print the message into our chat window
func _handle_client_left_packet(client_left_packet: packets.ClientLeft) -> void:
	chat.info("%s left" % client_left_packet.get_nickname())
	
# To send messages
func _on_chat_input_text_submitted(text: String) -> void:
	# Ignore this if the message was empty and release focus!
	if chat_input.text.is_empty():
		chat_input.release_focus()
		return
	
	# Create the public_message packet
	var packet := packets.Packet.new()
	var public_message := packet.new_public_message()
	public_message.set_text(text)
	
	# Serialize and send our packet to the server
	var err := WebSocket.send(packet)
	if err:
		chat.error("You have been disconnected from the server")
	else:
		# We grab our client's nickname from the GameManager autoload
		# and display our own message in our client
		chat.public(GameManager.client_nickname, text, Color.CYAN)
	
	# We clear the line edit
	chat_input.text = ""

# If the ui_escape key is pressed, toggle the escape menu
func _on_ui_escape_menu_toggle() -> void:
	lobby_escape_menu.toggle()

# If the ui_enter key is pressed, toggle the chat input
func _on_ui_chat_input_toggle() -> void:
	chat_input.visible = !chat_input.visible
	if chat_input.visible:
		chat_input.grab_focus()

func _send_client_entered_packet() -> bool:
	# We create a new packet
	var packet := packets.Packet.new()
	# We send the packet with no data because the server will fill it up
	packet.new_client_entered()
	
	# Serialize and send our message
	var err := WebSocket.send(packet)
	# Report if we succeeded or failed
	if err:
		return false
	else:
		return true

func _handle_join_room_success_packet() -> void:
	# We transition into the Room scene
	GameManager.set_state(GameManager.State.ROOM)

func _handle_request_denied_packet(reason: String) -> void:
	# Show a dialog box to the user with the error
	browser.new_dialog_box(reason, true)
	browser.enable_input()

func _handle_room_list_packet(room_list_packet: Array):
	# Clear our list
	browser.delete_all_entries()
	# Go over each entry on our packet
	for entry in room_list_packet:
		# Create an entry for each room
		var room_info := entry as packets.RoomInfo
		# Use the data from the list to create the Entries
		if room_info:
			browser.add_room_entry(room_info)

	# Hide the dialog box
	browser.hide_dialog_box()
