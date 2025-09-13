extends Node
class_name PlayerActions

# Preloading scripts
const Packets: GDScript = preload("res://packets.gd")
const Pathfinding: GDScript = preload("res://classes/pathfinding/pathfinding.gd")

var player: Player = null # Our parent node


enum ActionState {
	PENDING,
	PROCESSING,
	COMPLETED,
	FAILED,
}


class QueuedAction:
	var action_type: String
	var action_data: Variant
	var state: ActionState = ActionState.PENDING
	var packet: Variant = null
	
	func _init(type: String, data: Variant = null):
		action_type = type
		action_data = data


# Private variables
var _queue: Array[QueuedAction] = []
var _is_processing: bool = false
var _current_action: QueuedAction = null


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	# Wait a single frame to allow time for the other player components to load
	await get_tree().process_frame
	player = get_parent()


func add_action(action_type: String, action_data: Variant = null) -> QueuedAction:
	var action = QueuedAction.new(action_type, action_data)
	_queue.append(action)
	
	if not _is_processing:
		process_next_action()
	
	return action


func complete_action(success: bool) -> void:
	if not _current_action:
		return
	
	if success and _current_action.packet:
		# Send the packet
		WebSocket.send(_current_action.packet)
		_current_action.state = ActionState.COMPLETED
	else:
		_current_action.state = ActionState.FAILED
	
	_current_action = null
	
	if not _queue.is_empty():
		process_next_action()
	else:
		_is_processing = false


func process_next_action() -> void:
	if _queue.is_empty():
		_is_processing = false
		return
	
	_is_processing = true
	_current_action = _queue.pop_front() # Get the next action
	_current_action.state = ActionState.PROCESSING
	
	# Process based on action type
	match _current_action.action_type:
		"move":
			print("process move action")
			_process_move_character_action(_current_action.action_data)
		"raise_weapon":
			print("process raise weapon action")
			_process_raise_weapon_action()
		"lower_weapon":
			print("process lower weapon action")
			_process_lower_weapon_action()
		"single_fire":
			print("process single fire action")
			_process_single_fire_action(_current_action.action_data)
		"start_firing":
			print("process start firing action")
		"stop_firing":
			print("process stop firing action")
		"reload_weapon":
			print("process reload weapon action")
			_process_reload_weapon_action(_current_action.action_data)
		_:
			push_error("Unknown action type: ", _current_action.action_type)
			complete_action(false)

#################
# QUEUE ACTIONS #
#################

func queue_move_action(destination: Vector2i) -> void:
	add_action("move", destination)

func queue_raise_weapon_action() -> void:
	add_action("raise_weapon")

func queue_lower_weapon_action() -> void:
	add_action("lower_weapon")

func queue_single_fire_action(target: Vector3) -> void:
	add_action("single_fire", target)

func queue_start_firing_action() -> void:
	add_action("start_firing")

func queue_stop_firing_action() -> void:
	add_action("stop_firing")

func queue_reload_weapon_action(amount: int) -> void:
	add_action("reload_weapon", {"amount": amount})

func queue_toggle_fire_mode_action() -> void:
	add_action("toggle_fire_mode")

func queue_switch_weapon_action(slot: int) -> void:
	add_action("switch_weapon", slot)

###################
# PROCESS ACTIONS #
###################

# If our player is not busy,
# not in autopilot mode,
# not in any weapon aim state (can't move while aiming),
# and the cell is both reachable and available
func _validate_move_character(destination: Vector2i) -> bool:
	return (
		not player.is_busy and
		not player.player_movement.autopilot_active and
		not player.is_in_weapon_aim_state() and
		RegionManager.is_cell_reachable(destination) and 
		RegionManager.is_cell_available(destination)
	)


func _process_move_character_action(destination: Vector2i) -> void:
	if not _validate_move_character(destination):
		complete_action(false)
		return
	
	# Pathfind and movement setup
	var path = Pathfinding.find_path(
		player.player_movement.grid_position,
		destination,
		RegionManager.grid_width,
		RegionManager.grid_height,
		player
	)
	
	if path.is_empty():
		complete_action(false)
		return
	
	# Set up movement locally
	player.player_movement.start_movement_towards(
		player.player_movement.grid_position,
		destination
	)
	
	# Create the packet
	_current_action.packet = player.player_packets.create_destination_packet(destination)
	complete_action(true)


func _process_raise_weapon_action() -> void:
	# Check if we can raise weapon
	if not player.can_raise_weapon():
		complete_action(false)
		return
	
	# Perform local actions
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	await player.player_animator.play_weapon_animation_and_await(
		"down_to_aim",
		weapon_type
	)
	# Switch to this weapon state
	var target_state_name: String = weapon_type + "_aim_idle"
	player.player_state_machine.change_state(target_state_name)
	# Create the packet
	_current_action.packet = player.player_packets.create_raise_weapon_packet()
	complete_action(true)


func _process_lower_weapon_action() -> void:
	# Check if we can lower weapon
	if not player.can_lower_weapon():
		complete_action(false)
		return
	
	# Perform local actions
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	await player.player_animator.play_weapon_animation_and_await(
		"aim_to_down",
		weapon_type
	)
	# Switch to this weapon state
	var target_state_name: String = weapon_type + "_down_idle"
	player.player_state_machine.change_state(target_state_name)
	# Create the packet
	_current_action.packet = player.player_packets.create_lower_weapon_packet()
	complete_action(true)


func _process_reload_weapon_action(data: Dictionary) -> void:
	# Check if we can reload
	if not player.can_reload_weapon():
		complete_action(false)
		return
	
	var weapon_slot = player.player_equipment.current_slot
	var amount = data["amount"]
	
	# Perform local actions
	# Get the weapon type and play its animation
	var weapon_type: String = player.player_equipment.get_current_weapon_type()
	await player.player_animator.play_weapon_animation_and_await(
		"reload",
		weapon_type
	)
	# Update local state
	player.player_equipment.reload_equipped_weapon(amount)
	
	# Create the packet
	_current_action.packet = player.player_packets.create_reload_weapon_packet(weapon_slot, amount)
	complete_action(true)


func _process_single_fire_action(target: Vector3) -> void:
	# If target is invalid
	if target == Vector3.ZERO:
		complete_action(false)
		return
	
	# Check if we can fire regardless of ammo count
	if not player.can_fire_weapon():
		complete_action(false)
		return
	
	# Perform local actions
	# Get weapon data
	var weapon = player.player_equipment.equipped_weapon
	var anim_name: String = weapon.get_animation()
	var play_rate: float = weapon.get_animation_play_rate()
	
	# Check if we have ammo
	var has_ammo: bool = player.player_equipment.can_fire_weapon()
	
	# Adjust for dry fire
	if not has_ammo:
		play_rate = weapon.semi_fire_rate
		player.player_state_machine.get_current_state().dry_fired = true

	# Ammo decrement happens from player_equipment.weapon_fire()
	await player.player_animator.play_animation_and_await(anim_name, play_rate)
	
	# Create the packet
	_current_action.packet = player.player_packets.create_fire_weapon_packet(target, player.player_movement.rotation_target)
	complete_action(true)
