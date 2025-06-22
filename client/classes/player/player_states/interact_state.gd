extends BaseState
class_name InteractState


func _init() -> void:
	state_name = "interact"


func enter() -> void:
	player.execute_interaction()


# We have to update rotations here so we can rotate towards our interaction
func physics_update(delta: float) -> void:
	player.player_movement.handle_rotation(delta)


func exit() -> void:
	player.is_busy = false
