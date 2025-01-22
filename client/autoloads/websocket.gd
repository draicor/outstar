extends Node

const packets := preload("res://packets.gd")
const heartbeat_wait_time := 10.0

var socket := WebSocketPeer.new()
var last_state := WebSocketPeer.STATE_CLOSED
var heartbeat : Timer

func connect_to_url(url: String, tls_options: TLSOptions = null) -> int:
	var err := socket.connect_to_url(url, tls_options)
	if err != OK:
		return err
	
	last_state = socket.get_ready_state()
	
	return OK

func send(packet: packets.Packet) -> int:
	# The server already knows the ID of my client, so I just send 0
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
			# We create a timer after the connection is sucessful
			heartbeat = new_heartbeat_timer()
			heartbeat.connect("timeout", _on_heartbeat_timeout)
			heartbeat.start()
			
			Signals.connected_to_server.emit()
		elif state == socket.STATE_CLOSED:
			# We stop and cleanup the heartbeat timer
			heartbeat_cleanup(heartbeat)
			
			Signals.connection_closed.emit()
	
	# Loop through every packet available
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		# Get the packet and then emit it
		Signals.packet_received.emit(get_packet())

# Initializes the heartbeat timer and returns it
func new_heartbeat_timer() -> Timer:
	var timer := Timer.new()
	timer.one_shot = false
	timer.autostart = false
	timer.wait_time = heartbeat_wait_time
	add_child(timer)
	return timer

func _on_heartbeat_timeout() -> void:
	Signals.heartbeat_attempt.emit()

# This destroys the timer
func heartbeat_cleanup(timer: Timer) -> void:
	if timer:
		timer.stop()
		timer.queue_free()

func _process(_delta: float) -> void:
	poll()
