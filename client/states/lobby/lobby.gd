extends Node

const packets := preload("res://packets.gd")

# User Interface
@onready var _log: Log = $UI/Log
@onready var _line_edit: LineEdit = $UI/LineEdit

func _ready() -> void:
	# Connecting signals
	WebSocket.connection_closed.connect(_on_websocket_connection_closed)
	WebSocket.packet_received.connect(_on_websocket_packet_received)
	# User Interface signals
	_line_edit.text_submitted.connect(_on_line_edit_text_submitted)

func _on_websocket_connection_closed() -> void:
	_log.error("Connection closed")

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	
	if packet.has_chat_message():
		_handle_packet_chat_message(sender_id, packet.get_chat_message())

# We print the message into our chat window
func _handle_packet_chat_message(sender_id: int, packet_chat_message: packets.Chat) -> void:
	_log.public_chat("Client %d" % sender_id, packet_chat_message.get_text())

# To send messages
func _on_line_edit_text_submitted(text: String) -> void:
	var packet := packets.Packet.new()
	var chat_message := packet.new_chat_message()
	chat_message.set_text(text)
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	if err:
		_log.error("Error sending chat message")
	else:
		_log.public_chat(">>>>", text)
	
	# We clear the line edit
	_line_edit.text = ""
