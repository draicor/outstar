extends Node

const packets := preload("res://packets.gd")

# User Interface
@onready var _log: Log = $UI/Log

func _ready() -> void:
	# Connecting signals
	WebSocket.connected_to_server.connect(_on_websocket_connected_to_server)
	WebSocket.connection_closed.connect(_on_websocket_connection_closed)
	WebSocket.packet_received.connect(_on_websocket_packet_received)
	
	# Try to open the websocket connection
	_log.info("Connecting to server...")
	WebSocket.connect_to_url("ws://localhost:2000/ws")

func _on_websocket_connected_to_server() -> void:
	_log.success("Connected to the server")

func _on_websocket_connection_closed() -> void:
	_log.error("Connection closed")

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	
	if packet.has_client_id():
		_handle_packet_client_id(sender_id, packet.get_client_id())

# FIX THIS -> sender_id is not being used!
func _handle_packet_client_id(sender_id: int, packet_client_id: packets.ClientId) -> void:
	# We are setting the client ID in the GameManager Global when we receive it
	GameManager.client_id = packet_client_id.get_id()
	# We can then transition into the Lobby scene
	GameManager.set_state(GameManager.State.LOBBY)
