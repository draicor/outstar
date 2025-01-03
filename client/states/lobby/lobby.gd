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
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)
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

# We print the message into our chat window
func _handle_packet_chat_message(sender_id: int, packet_chat_message: packets.Chat) -> void:
	chat.public("Client %d" % sender_id, packet_chat_message.get_text())

# To send messages
func _on_chat_input_text_submitted(text: String) -> void:
	# Ignore this is the message was empty and release focus!
	if chat_input.text.is_empty():
		chat_input.release_focus()
		return
	
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
