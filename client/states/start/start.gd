extends Node

const packets := preload("res://packets.gd")

@onready var status: Label = $UI/Status

enum Server {
	LOCAL,
	PROXY,
}
# We have a dictionary connected to the enum above to switch
# between local and remote testing
var ip: Dictionary = {
	Server.LOCAL: "localhost",
	Server.PROXY: "64.223.161.129"
}
var port: Dictionary = {
	Server.LOCAL: 31591,
	Server.PROXY: 2000
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
	# We don't do anything because we change states immediately
	pass

func _on_websocket_connection_closed() -> void:
	status.text = "Connection to the server failed"

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	# If the packet is a handshake packet
	if packet.has_handshake():
		# We get the sender_id and store it on our client
		_handle_packet_handshake(packet.get_sender_id())

func _handle_packet_handshake(sender_id: int) -> void:
	# We save the client ID in the GameManager Autoload
	GameManager.client_id = sender_id
	# We can then transition into the Authentication scene
	GameManager.set_state(GameManager.State.AUTHENTICATION)
