extends Node

const packets := preload("res://packets.gd")

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
# We make the enum and port easily accesible for testing
@export var server : Server
@export var port : int = 2000

func _ready() -> void:
	# Connecting signals
	WebSocket.connected_to_server.connect(_on_websocket_connected_to_server)
	WebSocket.connection_closed.connect(_on_websocket_connection_closed)
	WebSocket.packet_received.connect(_on_websocket_packet_received)
	
	# Construct the ip address and port at runtime
	var address = ip[server] + ":" + str(port)
	
	# Try to open the websocket connection
	var url_address = "ws://"+address+"/ws"
	print("Connecting to server at " + url_address)
	
	WebSocket.connect_to_url(url_address)

func _on_websocket_connected_to_server() -> void:
	print("Connected to the server")

func _on_websocket_connection_closed(close_code: int, close_reason: String) -> void:
	print("Connection closed, Code: ", close_code, ", Reason: ", close_reason)

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
