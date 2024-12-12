extends Node

const packets := preload("res://packets.gd")

# Client info
var client_id: int
var client_name: String
# User Interface
@onready var _log: Log = $Log
@onready var _line_edit: LineEdit = $LineEdit

func _ready() -> void:
	# Connecting signals
	WebSocket.connected_to_server.connect(_on_websocket_connected_to_server)
	WebSocket.connection_closed.connect(_on_websocket_connection_closed)
	WebSocket.packet_received.connect(_on_websocket_packet_received)
	
	_line_edit.text_submitted.connect(_on_line_edit_text_entered)
	
	# Try to open the websocket connection
	_log.info("Connecting to server...")
	WebSocket.connect_to_url("ws://localhost:2000/ws")

func _on_websocket_connected_to_server() -> void:
	_log.success("Connected to the server")

func _on_websocket_connection_closed() -> void:
	_log.error("Connection closed")

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	
	# We determine what kind of packet we got, to know what to do
	if packet.has_client_id():
		_handle_packet_client_id(sender_id, packet.get_client_id())
	elif packet.has_chat_message():
		_handle_packet_chat_message(sender_id, packet.get_chat_message())

# I still don't know how this will be used, its redundant, the server doesn't seem to have
# a designated ID, which seems bad!
func _handle_packet_client_id(sender_id: int, id_sent_by_server: packets.ClientId) -> void:
	client_id = id_sent_by_server.get_id()
	client_name = "Client " + str(client_id)
	_log.info("Assigned client ID: %d" % client_id)

# We print the message into our chat window
func _handle_packet_chat_message(sender_id: int, chat_message: packets.Chat) -> void:
	_log.public_chat("Client %d" % sender_id, chat_message.get_text())

# To send messages
func _on_line_edit_text_entered(text: String) -> void:
	var packet := packets.Packet.new()
	var chat_message := packet.new_chat_message()
	chat_message.set_text(text)
	
	# This serializes our message
	var err := WebSocket.send(packet)
	if err:
		_log.error("Error sending chat message")
	else:
		_log.public_chat(client_name, text)
	
	# We clear the line edit
	_line_edit.text = ""
