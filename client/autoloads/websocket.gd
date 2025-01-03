extends Node

const packets := preload("res://packets.gd")

var socket := WebSocketPeer.new()
var last_state := WebSocketPeer.STATE_CLOSED

func connect_to_url(url: String, tls_options: TLSOptions = null) -> int:
	var err := socket.connect_to_url(url, tls_options)
	if err != OK:
		return err
	
	last_state = socket.get_ready_state()
	return OK

func send(packet: packets.Packet) -> int:
	# The server already knows the ID of my client
	packet.set_sender_id(0)
	# Serializing data into binary
	var data := packet.to_bytes()
	return socket.send(data)

func get_packet() -> packets.Packet:
	if socket.get_available_packet_count() < 1:
		return null
	
	var data := socket.get_packet()
	# Deserialize the data from binary into a packet
	var packet := packets.Packet.new()
	var result := packet.from_bytes(data)
	if result != OK:
		printerr("Error forming packet from data %s" % data.get_string_from_utf8())
	
	return packet

func close(code: int = 1000, reason: String = "") -> void:
	socket.close(code, reason)
	last_state = socket.get_ready_state()

# Unsure what this does but it seems like it would reset the connection
func clear() -> void:
	socket = WebSocketPeer.new()
	last_state = socket.get_ready_state()

func get_socket() -> WebSocketPeer:
	return socket

# Called every tick to get updates from the WebSocket connection
func poll() -> void:
	if socket.get_ready_state() != socket.STATE_CLOSED:
		socket.poll()
	
	var state := socket.get_ready_state()
	
	# If the websocket connection state changed (opened or closed)
	if last_state != state:
		last_state = state
		# Send some signals
		if state == socket.STATE_OPEN:
			Signals.connected_to_server.emit()
		# FIX THIS -> changes to STATE_CLOSED when the server goes offline,
		# but it doesn't seem to trigger when the proxy goes offline.
		elif state == socket.STATE_CLOSED:
			Signals.connection_closed.emit()
	
	# Loop through every packet available
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		# Get the packet and then emit it
		Signals.packet_received.emit(get_packet())

func _process(_delta: float) -> void:
	poll()
