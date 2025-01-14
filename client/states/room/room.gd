extends Node

# Preload resources
const packets := preload("res://packets.gd")
const room_escape_menu_scene: PackedScene = preload("res://components/escape_menu/room/room_escape_menu.tscn")
const dialogue_box_scene: PackedScene = preload("res://components/dialog_box/dialog_box.tscn")

# User Interface Variables
@onready var ui_canvas: CanvasLayer = $UI
@onready var chat: Control = $UI/Chat
var chat_input: LineEdit
var room_escape_menu
@onready var leave_room: Button = $LeaveRoom

func _ready() -> void:
	_initialize()
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
	room_escape_menu = room_escape_menu_scene.instantiate()
	ui_canvas.add_child(room_escape_menu)

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
	elif packet.has_leave_room_success():
		_handle_leave_room_success_packet()

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
	
	# Create the chat_message packet
	var packet := packets.Packet.new()
	var public_message := packet.new_public_message()
	public_message.set_text(text)
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	if err:
		chat.error("You have been disconnected from the server")
	else:
		# We grab our client's nickname from the GameManager autoload
		chat.public(GameManager.client_nickname, text, Color.CYAN)
	
	# We clear the line edit
	chat_input.text = ""

# If the ui_escape key is pressed, toggle the escape menu
func _on_ui_escape_menu_toggle() -> void:
	room_escape_menu.toggle()

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

func _send_leave_room_request_packet() -> bool:
	# We create a new packet
	var packet := packets.Packet.new()
	# We send the packet requesting the server to leave the room
	packet.new_leave_room_request()

	# Serialize and send our message
	var err := WebSocket.send(packet)
	# Report if we succeeded or failed
	if err:
		return false
	else:
		return true

func _handle_leave_room_success_packet() -> void:
	# We transition into the Lobby scene
	GameManager.set_state(GameManager.State.LOBBY)

func _on_leave_room_pressed() -> void:
	_send_leave_room_request_packet()
	# We hide the leave room button so the user can't spam it
	leave_room.hide()
	
	# We instantiate the dialogue box scene
	var dialogue_box := dialogue_box_scene.instantiate()
	# We add it to our root with force readable name set to false
	ui_canvas.add_child(dialogue_box, false)
	# The dialogue_box starts as hidden, we pass the values that will
	# have, and then we show it from code
	dialogue_box.initialize("Disconnecting...", false)
