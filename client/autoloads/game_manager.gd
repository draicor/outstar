extends Node

# Game States
enum State {
	START,
	AUTHENTICATION,
	LOBBY,
	ROOM,
}

# Replace with Dictionary[State, String] in new version of Godot v4.4+
var _states_scenes: Dictionary = {
	State.START: "res://states/start/start.tscn",
	State.AUTHENTICATION: "res://states/authentication/authentication.tscn",
	State.LOBBY: "res://states/lobby/lobby.tscn",
	State.ROOM: "res://states/room/room.tscn",
}

# Expose the client's data globally
var client_id: int
var client_nickname: String
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
