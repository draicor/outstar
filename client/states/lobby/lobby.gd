extends Node

# Preload resources
const packets := preload("res://packets.gd")
const lobby_escape_menu_scene: PackedScene = preload("res://components/escape_menu/lobby/lobby_escape_menu.tscn")

# User Interface Variables
@onready var ui_canvas: CanvasLayer = $UI
@onready var chat: Control = $UI/Chat
var chat_input: LineEdit
var lobby_escape_menu
@onready var button: Button = $Button

func _ready() -> void:
	_initialize()
	# Send a packet to the server to let everyone know we joined
	_send_packet_client_entered()

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
	var sender_id := packet.get_sender_id()
	
	if packet.has_chat_message():
		_handle_packet_chat_message(sender_id, packet.get_chat_message())
	elif packet.has_heartbeat():
		Signals.heartbeat_received.emit()
	elif packet.has_client_entered():
		_handle_packet_client_entered(packet.get_client_entered().get_nickname())
	elif packet.has_client_left():
		_handle_packet_client_left(packet.get_client_left())

# We print the message into our chat window
func _handle_packet_chat_message(sender_id: int, packet_chat_message: packets.Chat) -> void:
	chat.public("Client %d" % sender_id, packet_chat_message.get_text())

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
func _handle_packet_client_entered(nickname: String) -> void:
	chat.info("%s has joined" % nickname)

# When a client leaves, we print the message into our chat window
func _handle_packet_client_left(packet_client_left: packets.ClientLeft) -> void:
	chat.info("%s left" % packet_client_left.get_nickname())
	
# To send messages
func _on_chat_input_text_submitted(text: String) -> void:
	# Ignore this if the message was empty and release focus!
	if chat_input.text.is_empty():
		chat_input.release_focus()
		return
	
	# Create the chat_message packet
	var packet := packets.Packet.new()
	var chat_message := packet.new_chat_message()
	chat_message.set_text(text)
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	if err:
		chat.error("You have been disconnected from the server")
	else:
		# FIX THIS -> Replace Localhost with nickname!
		chat.public("Localhost", text)
	
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

func _send_packet_client_entered() -> bool:
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

func _send_packet_switch_request(zone_id: int) -> bool:
	# We create a new packet
	var packet := packets.Packet.new()
	# We send the packet with the zone_id we want to access
	var switch_request_packet := packet.new_switch_request()
	switch_request_packet.set_zone_id(zone_id)

	# Serialize and send our message
	var err := WebSocket.send(packet)
	# Report if we succeeded or failed
	if err:
		return false
	else:
		return true

func _on_button_pressed() -> void:
	_send_packet_switch_request(1)
	button.hide()
