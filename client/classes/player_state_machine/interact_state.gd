extends BaseState
class_name InteractState

func _init() -> void:
	state_name = "interact"

func enter() -> void:
	print("interact state")
	player._switch_locomotion("interacting")
	player._execute_interaction()
	# Connect to interaction completion signal
	player.interaction_finished.connect(_on_interaction_finished, CONNECT_ONE_SHOT)

func _on_interaction_finished() -> void:
	finished.emit("idle")

func exit() -> void:
	player.is_busy = false
