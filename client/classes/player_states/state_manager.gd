extends Node
class_name StateManager

var current_state = PlayerState
var states: Dictionary = {}


func _init(player: Node) -> void:
	# Initialize states
	states = {
		"unarmed": UnarmedState.new(player),
		#"rifle": RifleState.new(player), # We'll implement this later
	}
	change_state("unarmed")


func change_state(new_state_name: String) -> void:
	if states.has(new_state_name):
		if current_state:
			current_state.exit()
		
		current_state = states[new_state_name]
		current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)
