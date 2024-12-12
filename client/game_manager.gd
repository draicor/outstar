extends Node

# Game States
enum State {
	START,
	LOBBY
}

# Replace with Dictionary[State, String] in new version of Godot v4.4+
var _states_scenes: Dictionary = {
	State.START: "res://states/start/start.tscn",
	State.LOBBY: "res://states/lobby/lobby.tscn",
}

# Expose the client's ID globally
var client_id: int
var _current_scene_root: Node

# A method to change the game's state
func set_state(state: State) -> void:
	if _current_scene_root != null:
		_current_scene_root.queue_free()
	
	var scene: PackedScene = load(_states_scenes[state])
	_current_scene_root = scene.instantiate()
	
	add_child(_current_scene_root)
