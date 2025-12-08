extends Node
class_name BaseState

signal finished(next_state_name)

var player_state_machine: PlayerStateMachine = null
var player: Player = null
var state_name: String = "unnamed_state"


func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass


# Called on physics_update to check if we need to broadcast the rotation update
func broadcast_rotation_if_changed():
	# Check if the rotation changed significantly
	var current_rotation: float = player.model.rotation.y
	if abs(current_rotation - player.last_sent_rotation) >= player.ROTATION_CHANGE_THRESHOLD:
		player.last_sent_rotation = current_rotation
		# Send a non-blocking rotation packet
		player.player_packets.send_rotate_character_packet(current_rotation, false)


# Returns true if this character has its weapon down
func is_weapon_down_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_down_idle", "rifle_crouch_down_idle",\
		"shotgun_down_idle", "shotgun_crouch_down_idle":
			return true
		_:
			return false


# Returns true if this character has its weapon up
func is_weapon_aim_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_aim_idle", "rifle_crouch_aim_idle",\
		"shotgun_aim_idle", "shotgun_crouch_aim_idle":
			return true
		_:
			return false


# Helper function to skip input if one of these is valid
func ignore_input() -> bool:
	if player.is_busy:
		return true
	if player.player_movement.autopilot_active:
		return true
	if player.is_mouse_over_ui:
		return true
	
	return false
