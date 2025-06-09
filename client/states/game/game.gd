extends Node

# Preload resources
const packets := preload("res://packets.gd")
const Player := preload("res://objects/character/player/player.gd")
const game_escape_menu_scene: PackedScene = preload("res://components/escape_menu/game/game_escape_menu.tscn")

# Holds our current map node so we can spawn scenes into it
var _current_map_scene: Node

# Map of all the players in this region, where the key is the player's ID
var _players: Dictionary[int, Player]

# User Interface Variables
@onready var ui_canvas: CanvasLayer = $UI
@onready var chat: Control = $UI/VBoxContainer/Chat

var chat_container: VBoxContainer
var chat_input: LineEdit
var game_escape_menu


func _ready() -> void:
	_initialize()


func _initialize() -> void:
	# Get access to the child nodes of the chat UI
	chat_container = chat.find_child("ChatContainer")
	chat_input = chat.find_child("ChatInput")
	
	# Websocket signals
	Signals.connection_closed.connect(_on_websocket_connection_closed)
	Signals.packet_received.connect(_on_websocket_packet_received)
	Signals.heartbeat_attempt.connect(_on_websocket_heartbeat_attempt)
	# User Interface signals
	Signals.ui_escape_menu_toggle.connect(_on_ui_escape_menu_toggle)
	Signals.ui_logout.connect(_handle_signal_ui_logout)
	# Chat signals
	Signals.chat_public_message_sent.connect(_handle_signal_chat_public_message_sent)
	
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
	elif packet.has_update_player():
		_handle_update_player_packet(packet.get_update_player())
	elif packet.has_update_speed():
		_handle_update_speed_packet(sender_id, packet.get_update_speed())
	elif packet.has_region_data():
		_handle_region_data_packet(packet.get_region_data())
	elif packet.has_chat_bubble():
		_handle_chat_bubble_packet(sender_id, packet.get_chat_bubble())

# Print the message into our chat window and update that player's chat bubble
func _handle_public_message_packet(sender_id: int, packet_public_message: packets.PublicMessage) -> void:
	# We print the nickname and then the message contents in local chat
	chat.public("%s" % packet_public_message.get_nickname(), packet_public_message.get_text(), Color.LIGHT_SEA_GREEN)
	
	# If the id is on our players dictionary
	if sender_id in _players:
		# Attempt to retrieve the player character object
		var player: Player = _players[sender_id]
		# If its valid
		if player:
			# Update their chat bubble to reflect the text
			player.new_chat_bubble(packet_public_message.get_text())
			player.toggle_chat_bubble_icon(false) # Hide typing bubble


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
	# When a client connects, the server sends our data to him automatically
	pass


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
			# Remove this player from our grid
			RegionManager.remove_object(player.server_grid_position, player)
			# Remove this player from our array of players
			_players.erase(player_id)
			# Destroy it
			player.queue_free()
	
	# Displays a message in the chat window
	chat.info("%s left" % client_left_packet.get_nickname())


# if our client presses the enter key in the chat
func _handle_signal_chat_public_message_sent(text: String) -> void:
	# Ignore this if the message was empty
	if text.is_empty():
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
		chat.public(GameManager.client_nickname, text, Color.CYAN)
		# Update my character's chat bubble!
		GameManager.player_character.new_chat_bubble(text)


# If the ui_escape key is pressed, toggle the escape menu
func _on_ui_escape_menu_toggle() -> void:
	game_escape_menu.toggle()


# Used to request the server to switch us to the authentication state
func _handle_signal_ui_logout() -> void:
	# We create a new packet of type logout request
	var packet := packets.Packet.new()
	packet.new_logout_request()
	
	# This serializes and sends our message
	var err := WebSocket.send(packet)
	# If we sent the packet, emit it
	if !err:
		Signals.heartbeat_sent.emit()
		# Switch our local state to the authentication too
		GameManager.set_state(GameManager.State.AUTHENTICATION)


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


func _handle_update_player_packet(update_player_packet: packets.UpdatePlayer) -> void:
	var player_id := update_player_packet.get_id()

	# If this player is NOT in our list of players
	# then is a new player so we need to spawn it
	if player_id not in _players:
		# Check if our client id is the same as this update player packet sender id
		var is_my_player_character := player_id == GameManager.client_id
		
		# Get the spawn position from the packet
		var spawn_position: Vector2i = Vector2i(update_player_packet.get_position().get_x(), update_player_packet.get_position().get_z())
		
		# Grab all of the data from the server and use it to create this player character
		var player := Player.instantiate(
			player_id,
			update_player_packet.get_name(),
			update_player_packet.get_gender(),
			update_player_packet.get_speed(),
			spawn_position,
			update_player_packet.get_rotation_y(),
			is_my_player_character
		)
		# Add this player to our list of players
		_players[player_id] = player
		
		# For remote players
		if not is_my_player_character:
			# Add the player to the new position in my local grid
			RegionManager.set_object(spawn_position, player)
		
		# Spawn the player
		_current_map_scene.add_child(player)
	
	# If the player is already in our local list of players
	# Then we just need to update it
	else:
		# Fetch the player from our list of players
		var player: Player = _players[player_id]
		
		# Get the server position from the packet
		var server_position: Vector2i = Vector2i(update_player_packet.get_position().get_x(), update_player_packet.get_position().get_z())
		
		# Remove the player from the grid position it was
		RegionManager.remove_object(player.server_grid_position, player)
		# Add the player to the new position in my local grid
		RegionManager.set_object(server_position, player)
		
		# Update this player's movement
		player.update_destination(server_position)


func _handle_update_speed_packet(sender_id: int, update_speed_packet: packets.UpdateSpeed) -> void:
	# If the id is on our players dictionary
	if sender_id in _players:
		# Attempt to retrieve the player character object
		var player: Player = _players[sender_id]
		# If its valid
		if player:
			player.update_player_speed(update_speed_packet.get_speed())


func _handle_region_data_packet(region_data_packet: packets.RegionData) -> void:
	var region_id: int = region_data_packet.get_region_id()
	
	if region_id in RegionManager.Maps.values():
		# Initialize region first
		RegionManager.update_region_data(
			region_id,
			region_data_packet.get_grid_width(),
			region_data_packet.get_grid_height()
		)
		
		# Wait for map load before sending notifications
		await _load_map(region_id as RegionManager.Maps)
		
		# Send a packet to the server to let everyone know we joined,
		# after full initialization
		_send_client_entered_packet()
		
	else:
		# If the region id is invalid, load the prototype map
		_load_map(RegionManager.Maps.PROTOTYPE)
		# CAUTION Replace this with a request to the server to switch us to another map


# Used to switch regions/maps
func _load_map(map: RegionManager.Maps) -> void:
	# Clear previous map and players
	if _current_map_scene:
		_current_map_scene.queue_free()
		# Wait a frame to ensure cleanup
		await get_tree().process_frame
		
		# If our local _players list if not empty
		if not _players.is_empty():
			# Attempt to delete each player instance
			for player_id in _players:
				var player = _players[player_id]
				if player:
					player.queue_free()
			# Clear our _players list
			_players.clear()
	
	# Load new map
	var map_scene: PackedScene = load(RegionManager.maps_scenes[map])
	if map_scene:
		# Create the map scene
		_current_map_scene = map_scene.instantiate()
		# Add it to the game root
		add_child(_current_map_scene)


# Used to toggle the chat bubble of this character
func _handle_chat_bubble_packet(sender_id: int, chat_bubble_packet: packets.ChatBubble) -> void:
	# If the id is on our players dictionary
	if sender_id in _players:
		# Attempt to retrieve the player character object
		var player: Player = _players[sender_id]
		# If its valid
		if player:
			# Toggle the chat bubble for this player
			player.toggle_chat_bubble_icon(chat_bubble_packet.get_is_active())
