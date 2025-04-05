extends Node

const packets := preload("res://packets.gd")

@onready var status: Label = $UI/Status

enum Server {
	LOCAL,
	REMOTE,
}
# Used to switch between local and remote testing
var ip: Dictionary[Server, String] = {
	Server.LOCAL: "localhost",
	Server.REMOTE: "64.223.161.129"
}
var port: Dictionary[Server, int] = {
	Server.LOCAL: 31591,
	Server.REMOTE: 31591
}
# We make the enum easily accesible for testing
@export var server : Server

func _ready() -> void:
	# Connecting signals
	Signals.connected_to_server.connect(_on_websocket_connected_to_server)
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)
	
	# Construct the ip address and port at runtime
	var address = ip[server] + ":" + str(port[server])
	
	# Try to open the websocket connection
	var url_address = "ws://"+address+"/ws"
	print("Connecting to server at " + url_address)
	
	WebSocket.connect_to_url(url_address)

func _on_websocket_connected_to_server() -> void:
	status.text = "Connection established"

func _on_websocket_connection_closed() -> void:
	status.text = "Connection to the server failed"

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	# If the packet is a handshake packet
	if packet.has_handshake():
		# We get the sender_id and store it on our client
		_handle_packet_handshake(packet.get_sender_id(), packet.get_handshake().get_version())

func _handle_packet_handshake(sender_id: int, server_version: String) -> void:
	# We save the client ID in the GameManager Autoload
	GameManager.client_id = sender_id
	
	# Read-only at runtime
	var client_version = ProjectSettings.get_setting("application/config/version", "0.0.0.0")
	
	# If both versions are the same
	if server_version == client_version:
		# We create a handshake packet to send to server our client's version
		var packet := packets.Packet.new()
		var handshake := packet.new_handshake()
		handshake.set_version(client_version)
		
		# This serializes and sends our message
		var err := WebSocket.send(packet)
		# If we sent the packet
		if !err:
			# We can then transition into the Authentication scene
			GameManager.set_state(GameManager.State.AUTHENTICATION)
		else:
			status.text = "You have been disconnected from the server"
	else:
		status.text = "Client v%s is no longer supported.\nPlease update to version %s" % [client_version, server_version]
