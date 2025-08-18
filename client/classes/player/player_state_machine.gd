extends Node
class_name PlayerStateMachine

signal player_state_changed(previous_state, new_state)

var states_map: Dictionary = {}
var current_state: BaseState = null
var previous_state: BaseState = null
var is_active: bool = true : set = set_active
var is_local_player: bool = false # set to true for local player
var player: Player = null


func _ready() -> void:
	# Wait for parent to be ready
	await get_parent().ready
	# Wait a single frame to allow time for the player_animator to initialize
	await get_tree().process_frame
	
	player = get_parent()
	if player.my_player_character:
		is_local_player = true
	
	# Collect all child states
	for child in get_children():
		if child is BaseState:
			states_map[child.state_name] = child
			child.player_state_machine = self
			child.player = player
			child.is_local_player = is_local_player


# Returns the current state name
func get_current_state_name() -> String:
	if current_state:
		return current_state.state_name
	else:
		return ""


# Returns the current state
func get_current_state() -> BaseState:
	if current_state:
		return current_state
	else:
		return null


func change_state(new_state_name: String) -> void:
	# If our state machine is not active, abort
	if not is_active:
		return
	# If the state doesn't exists, abort
	if not states_map.has(new_state_name):
		push_error("State %s doesn't exist in state machine" % new_state_name)
		return
	
	var new_state = states_map[new_state_name]
	
	if current_state:
		# If we are already in this state, ignore
		if current_state == new_state:
			return
		
		# Force process any pending packets when leaving this state
		# Use call_deferred to ensure safe execution
		player.player_packets.call_deferred("try_process_next")
		
		# Exit current state
		current_state.exit()
		previous_state = current_state
	
	# Enter new state
	current_state = new_state
	current_state.enter()
	
	emit_signal("player_state_changed",
		previous_state.state_name if previous_state else "",
		new_state_name)


# When toggling this state, toggle the functions that run on tick too
func set_active(value: bool) -> void:
	is_active = value
	set_physics_process(value)
	
	# Disable these for remote players 
	set_process(value and is_local_player)
	set_process_unhandled_input(value and is_local_player)
	set_process_input(value and is_local_player)


# Each state will handle its on tick
func _physics_process(delta: float) -> void:
	if current_state and is_active:
		current_state.physics_update(delta)


# Each state will handle its on tick
func _process(delta: float) -> void:
	if current_state and is_active:
		current_state.update(delta)


# Each state will handle its on tick
# Using _unhandled_input(), not _input(), because
# _unhandled_input() only receives events that weren't processed by the UI
func _unhandled_input(event: InputEvent) -> void:
	if current_state and is_active:
		current_state.handle_input(event)
