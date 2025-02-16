extends Node

# Preload resources
const packets := preload("res://packets.gd")
const Player := preload("res://objects/character/player/player.gd")
const game_escape_menu_scene: PackedScene = preload("res://components/escape_menu/game/game_escape_menu.tscn")

# Holds our current map node so we can spawn scenes into it
var _current_map_scene: Node

# Map of all the players in this region, where the key is the player's ID
var _players: Dictionary

# User Interface Variables
@onready var ui_canvas: CanvasLayer = $UI
@onready var chat: Control = $UI/VBoxContainer/Chat

var chat_input: LineEdit
var game_escape_menu

func _ready() -> void:
	_initialize()
	# Send a packet to the server to let everyone know we joined
	_send_client_entered_packet()
	
	# TO FIX
	# We need to get which map to load from the server instead!
	# Loads the map from our game manager
	_load_map(GameManager.Maps.PROTOTYPE)

func _initialize() -> void:
	# Get access to the child nodes of the chat UI
	chat_input = chat.find_child("Input")
	
	# Websocket signals
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)
	Signals.heartbeat_attempt.connect(_on_websocket_heartbeat_attempt)
	# User Interface signals
	Signals.ui_escape_menu_toggle.connect(_on_ui_escape_menu_toggle)
	# Chat signals, ui_chat_input_toggle is called from Main.gd
	Signals.ui_chat_input_toggle.connect(_on_ui_chat_input_toggle)
	chat_input.text_submitted.connect(_on_chat_input_text_submitted)
	
	# Create and add the escape menu to the UI canvas layer, hidden
	game_escape_menu = game_escape_menu_scene.instantiate()
	ui_canvas.add_child(game_escape_menu)

# If our connection to the server closed
func _on_websocket_connection_closed() -> void:
	chat.error("You have been disconnected from the server")
	# Display some kind of dialog box that the user can accept to go back to
	# the main menu

func _on_websocket_packet_received(packet: packets.Packet) -> void:
	var sender_id := packet.get_sender_id()
	
	if packet.has_public_message():
		_handle_public_message_packet(sender_id, packet.get_public_message())
	elif packet.has_heartbeat():
		Signals.heartbeat_received.emit()
	elif packet.has_client_entered():
		_handle_client_entered_packet(packet.get_client_entered().get_nickname())
	elif packet.has_client_left():
		_handle_client_left_packet(packet.get_client_left())
	elif packet.has_request_denied():
		_handle_request_denied_packet(packet.get_request_denied().get_reason())
	elif packet.has_spawn_player():
		_handle_spawn_player_packet(packet.get_spawn_player())

# Print the message into our chat window and update that player's chat bubble
func _handle_public_message_packet(sender_id: int, packet_public_message: packets.PublicMessage) -> void:
	# We print the nickname and then the message contents
	# chat.public("%s" % packet_public_message.get_nickname(), packet_public_message.get_text(), Color.LIGHT_SEA_GREEN)
	# If the id is on our players dictionary
	if sender_id in _players:
		# Attempt to retrieve the player character object
		var player: Player = _players[sender_id]
		# If its valid
		if player:
			# Update their chat bubble to reflect the text
			player.new_chat_bubble(packet_public_message.get_text())

# We send a heartbeat packet to the server every time the timer timeouts
func _on_websocket_heartbeat_attempt() -> void:
	# We create a new packet of type heartbeat
	var packet := packets.Packet.new()
	packet.new_heartbeat()
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	# If we sent the packet, emit it
	if !err:
		Signals.heartbeat_sent.emit()

# When a new client connects, we print the message into our chat window
func _handle_client_entered_packet(_nickname: String) -> void:
	pass
	
	# Displays a message in the chat window
	# chat.info("%s has joined" % nickname)
	
	# To fix?
	# Spawning the character is being handled elsewhere below

# When a client leaves, print the message into our chat window
# If that client was on our player list, we destroy his character to free resources
func _handle_client_left_packet(client_left_packet: packets.ClientLeft) -> void:
	# Get the player id from the packet
	var player_id := client_left_packet.get_id()
	# If the id is on our players dictionary
	if player_id in _players:
		# Attempt to retrieve the player character object
		var player: Player = _players[player_id]
		# If its valid
		if player:
			# Destroy it
			player.queue_free()
	
	# Displays a message in the chat window
	# chat.info("%s left" % client_left_packet.get_nickname())
	
# if our client presses the enter key in the chat
func _on_chat_input_text_submitted(text: String) -> void:
	# Ignore this if the message was empty and release focus!
	if chat_input.text.is_empty():
		chat_input.release_focus()
		return
	
	# Create the public_message packet
	var packet := packets.Packet.new()
	var public_message := packet.new_public_message()
	public_message.set_text(text)
	
	# Serialize and send our packet to the server
	var err := WebSocket.send(packet)
	if err:
		chat.error("You have been disconnected from the server")
	else:
		# Grab our client's nickname from the GameManager autoload
		# and display our own message in our client
		# chat.public(GameManager.client_nickname, text, Color.CYAN)
		# Update my character's chat bubble!
		GameManager.player_character.new_chat_bubble(text)
	
	# We clear the line edit
	chat_input.text = ""

# If the ui_escape key is pressed, toggle the escape menu
func _on_ui_escape_menu_toggle() -> void:
	game_escape_menu.toggle()

# If the ui_enter key is pressed, toggle the chat input
func _on_ui_chat_input_toggle() -> void:
	chat_input.visible = !chat_input.visible
	if chat_input.visible:
		chat_input.grab_focus()

func _send_client_entered_packet() -> bool:
	# We create a new packet
	var packet := packets.Packet.new()
	# We send the packet with no data because the server will fill it up
	packet.new_client_entered()
	
	# Serialize and send our message
	var err := WebSocket.send(packet)
	# Report if we succeeded or failed
	if err:
		return false
	else:
		return true

func _handle_request_denied_packet(reason: String) -> void:
	# Just jog the error to console for now
	print(reason)
	
	# TO UPGRADE
	# We need to have a Callable that we assign a different function
	# everytime we want to request something to the server so we don't
	# have a packet type for every type of request unless we have to!

func _handle_spawn_player_packet(spawn_player_packet: packets.SpawnPlayer) -> void:
	var player_id := spawn_player_packet.get_id()

	# If this character is NOT in our list of players
	# is a new character so we need to instantiate it
	if player_id not in _players:
		# Check if our client id is the same as this spawn character packet sender id
		var is_my_player_character := player_id == GameManager.client_id
		
		# Grab all of the data from the server and we use it to create this character
		var player := Player.instantiate(
			player_id,
			spawn_player_packet.get_name(),
			spawn_player_packet.get_x(),
			spawn_player_packet.get_y(),
			spawn_player_packet.get_z(),
			spawn_player_packet.get_rotation_y(),
			spawn_player_packet.get_velocity_x(),
			spawn_player_packet.get_velocity_y(),
			spawn_player_packet.get_velocity_z(),
			spawn_player_packet.get_speed(),
			is_my_player_character
		)
		# Add this character to our list of players
		_players[player_id] = player
		
		# Spawn the character
		_current_map_scene.add_child(player)
	
	# This is an existing player in our list
	else:
		# Fetch the character from our list of players
		var player: Player = _players[player_id]
		# Update this character's data
		player.server_position.x = spawn_player_packet.get_x()
		# Ignore the Y axis since our maps will be flat, for now at least
		player.server_position.z = spawn_player_packet.get_z()
		# Update the X, Y and Z velocity so our model can rotate correctly
		player.velocity_x = spawn_player_packet.get_velocity_x()
		player.velocity_y = spawn_player_packet.get_velocity_y()
		player.velocity_z = spawn_player_packet.get_velocity_z()
		# Overwrite the speed just in case it changes in the server
		player.speed = spawn_player_packet.get_speed()

func _load_map(map: GameManager.Maps) -> void:
	# Load the next scene
	var map_scene: PackedScene = load(GameManager.maps_scenes[map])
	# Create the map scene
	_current_map_scene = map_scene.instantiate()
	# Add it to the game root
	add_child(_current_map_scene)
