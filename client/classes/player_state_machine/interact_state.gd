extends BaseState
class_name InteractState

func _init() -> void:
	state_name = "interact"

func enter() -> void:
	print("interact state")
	player._execute_interaction()

func physics_update(delta: float) -> void:
	player._handle_rotation(delta)

func exit() -> void:
	player.is_busy = false
