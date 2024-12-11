extends Node

const packets := preload("res://packets.gd")

func _ready() -> void:
	# Connecting signals
	WebSocket.connected_to_server.connect(_on_websocket_connected_to_server)
	WebSocket.connection_closed.connect(_on_websocket_connection_closed)
	WebSocket.packet_received.connect(_on_websocket_packet_received)
	
	print("Connecting to server...")
	WebSocket.connect_to_url("ws://localhost:2000/ws")

func _on_websocket_connected_to_server() -> void:
	var packet := packets.Packet.new()
	var chat_message := packet.new_chat_message()
	chat_message.set_text("Hello, Golang!")
	
	var err := WebSocket.send(packet)
	if err:
		print("Error sending packet")
	else:
		print("Sent packet")

func _on_websocket_connection_closed() -> void:
	print("Connection closed")

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	print("Received packet from the server: %s" % packet)
