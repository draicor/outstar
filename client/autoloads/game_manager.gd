extends Node

const Player := preload("res://objects/character/player/player.gd")

# Game States
enum State {
	CONNECTED,
	AUTHENTICATION,
	GAME,
}

var _states_scenes: Dictionary[State, String] = {
	State.CONNECTED: "res://states/connected/connected.tscn",
	State.AUTHENTICATION: "res://states/authentication/authentication.tscn",
	State.GAME: "res://states/game/game.tscn",
}

# Expose the client's data globally
var client_id: int
var client_nickname: String
var player_character: Player
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
