extends Node

# Preload resources
const packets := preload("res://packets.gd")
const lobby_escape_menu_scene: PackedScene = preload("res://components/escape_menu/lobby/lobby_escape_menu.tscn")

# User Interface Variables
@onready var ui_canvas: CanvasLayer = $UI
@onready var chat: Control = $UI/Chat
var chat_input: LineEdit
var lobby_escape_menu

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	# Get access to the child nodes of the chat UI
	chat_input = chat.find_child("Input")
	
	# Connecting signals
	WebSocket.connection_closed.connect(_on_websocket_connection_closed)
	WebSocket.packet_received.connect(_on_websocket_packet_received)
	# User Interface signals
	Signals.ui_escape_menu_toggle.connect(_on_ui_escape_menu_toggle)
	chat_input.text_submitted.connect(_on_chat_input_text_submitted)
	
	# Create and add the escape menu to the UI canvas layer
	lobby_escape_menu = lobby_escape_menu_scene.instantiate()
	ui_canvas.add_child(lobby_escape_menu)

func _on_websocket_connection_closed() -> void:
	chat.error("Connection closed")

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	
	if packet.has_chat_message():
		_handle_packet_chat_message(sender_id, packet.get_chat_message())

# We print the message into our chat window
func _handle_packet_chat_message(sender_id: int, packet_chat_message: packets.Chat) -> void:
	chat.public("Client %d" % sender_id, packet_chat_message.get_text())

# To send messages
func _on_chat_input_text_submitted(text: String) -> void:
	# Ignore this is the message was empty!
	if chat_input.text.is_empty():
		return
	
	var packet := packets.Packet.new()
	var chat_message := packet.new_chat_message()
	chat_message.set_text(text)
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	if err:
		chat.error("Error sending chat message")
	else:
		chat.public("Localhost", text)
	
	# We clear the line edit
	chat_input.text = ""

# If the ui_escape key is pressed, toggle the escape menu
func _on_ui_escape_menu_toggle() -> void:
	lobby_escape_menu.toggle()
