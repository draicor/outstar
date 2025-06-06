class_name PlayerStateMachine
extends Node

signal player_state_changed(previous_state, new_state)

var states_map: Dictionary = {}
var current_state: BaseState = null
var previous_state: BaseState = null
var is_active: bool = true : set = set_active


func _ready() -> void:
	for child in BaseState:
		if child is BaseState:
			states_map[child.state_name] = child
			child.state_machine = self
			child.player = get_parent()
	
	await owner.ready
	if states_map.size() > 0:
		var initial_state = states_map.values()[0].state_name
		change_state(initial_state)


func change_state(new_state_name: String) -> void:
	if not is_active:
		return
	if not states_map.has(new_state_name):
		push_error("State %s doesn't exist" % new_state_name)
		return
	
	var new_state = states_map[new_state_name]
	
	# Exit current state
	if current_state:
		current_state.exit()
		previous_state = current_state
	
	# Enter new state
	current_state = new_state
	current_state.enter()
	
	emit_signal("state_changed", previous_state.state_name if previous_state else new_state_name)


# When toggling this state, toggle the functions that run on tick too
func set_active(value: bool) -> void:
	is_active = value
	set_physics_process(value)
	set_process(value)
	set_process_unhandled_input(value)


# We pass the buck to the state
func _physics_process(delta: float) -> void:
	if current_state and is_active:
		current_state.physics_update(delta)


# We pass the buck to the state
func _process(delta: float) -> void:
	if current_state and is_active:
		current_state.update(delta)


# We pass the buck to the state
func _unhandled_input(event: InputEvent) -> void:
	if current_state and is_active:
		current_state.handle_input(event)
