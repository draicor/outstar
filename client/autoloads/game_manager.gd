extends Node

# Game States
enum State {
	START,
	CONNECTED,
	AUTHENTICATION,
	GAME,
}

var _states_scenes: Dictionary[State, String] = {
	State.START: "res://states/start/start.tscn",
	State.CONNECTED: "res://states/connected/connected.tscn",
	State.AUTHENTICATION: "res://states/authentication/authentication.tscn",
	State.GAME: "res://states/game/game.tscn",
}

# Keep track of all connected players with a map of all the players in this region
var _players: Dictionary[int, Player] = {} # key: player_id, value: Player class
# Expose the client's data globally
var client_id: int
var client_nickname: String
var player_character: Player
# Prevents rotation and other actions while typing, also
# holds state in between map changes for my player character
var is_player_typing: bool = false
# Prevents game world tooltip to display over menus
var ui_menu_active: bool = false
# Keep track of packets
var packets_sent: int = 0
var packets_received: int = 0
var packets_lost: int = 0

# Internal variables
var _current_scene_root: Node


# A method to change the game's state
func set_state(state: State) -> void:
	# If we haven't destroyed the current scene, destroy it
	if _current_scene_root != null:
		_current_scene_root.queue_free()
	
	# Load the next scene
	var scene: PackedScene = load(_states_scenes[state])
	_current_scene_root = scene.instantiate()
	
	# Add it to the root
	add_child(_current_scene_root)


# After instancing the player character, store it as a global variable
func set_player_character(player_node: Player):
	player_character = player_node


func is_ui_menu_active() -> bool:
	return ui_menu_active


func set_ui_menu_active(is_active: bool) -> void:
	ui_menu_active = is_active

# Adds a Player to the map by id
func register_player(player_id: int, player: Player) -> void:
	_players[player_id] = player

# Deletes the player from the map
func unregister_player(player_id: int) -> void:
	if is_player_valid(player_id):
		_players.erase(player_id)
		

# Returns the Player by id
func get_player_by_id(player_id: int) -> Player:
	if is_player_valid(player_id):
		return _players.get(player_id)
	return null

# Used to check if the player is in our map
func is_player_valid(player_id: int) -> bool:
	return player_id in _players

# Clears the map of players and frees every resource
func clear_players() -> void:
	# If our local _players list if not empty
	if not _players.is_empty():
		# Attempt to delete each player instance
		for player_id in _players:
			var player = _players[player_id]
			if is_instance_valid(player):
				player.queue_free()
		# Clear our _players map immediately
		_players.clear()
