extends Node
class_name PlayerMovement

# Preloading scripts
const Packets: GDScript = preload("res://packets.gd")
const Pathfinding: GDScript = preload("res://classes/pathfinding/pathfinding.gd")

# EXPORTED VARIABLES (always positive numbers)
@export var ROTATION_SPEED: float = 40.0 # Radians per second 
@export var ROTATION_ACCEL: float = 30.0
@export var ROTATION_DECEL: float = 20.0

# CONSTANTS
const SERVER_TICK: float = 0.5 # Controls local player move speed
const ANGLE_THRESHOLD: float = 0.01 # Radians threshold for considering rotation complete

# Signals
signal rotation_completed
signal movement_completed

# Tick related data
var movement_tick: float = SERVER_TICK # Defaults to server_tick

# Player variables
var player: Player = null # Our parent node

# Logic variables
var in_motion: bool = false # If the character is moving
var autopilot_active: bool = false # If the server is forcing the player to move

# Movement data set at spawn
var server_grid_position: Vector2i # Used to spawn the character and also to correct the player's position
var grid_position: Vector2i # Keeps track of our grid position locally
var grid_destination: Vector2i # Used in _raycast(), to tell the server where we want to move
var immediate_grid_destination: Vector2i # Used in case we want to change route in transit
var interpolated_position: Vector3 # Used to smoothly slide our character in our game client
# Path data
var server_path: Array[Vector2i] # Set at spawn and after server movement
var next_tick_server_path: Array[Vector2i] # Used to store the next server path

# Tick data
var cells_to_move_this_tick: int
var movement_elapsed_time: float = 0.0 # Used in _process to slide the character
var next_cell: Vector3 # Used in _process, its the next cell our player should move to

# Rotation state
var forward_direction: Vector3 # Used to keep track of our current forward direction
var is_rotating: bool = false # To prevent movement before rotation ends
var rotation_target: float = 0.0 # Rotation target in radians
var rotation_speed: float = 0.0

# Client prediction
var is_predicting: bool = false # Whether we are predicting or the server is moving us
var predicted_path: Array[Vector2i] = [] # Holds our most recent predicted_path
var next_tick_predicted_path: Array[Vector2i] = [] # Used to store our next tick predicted path
var unconfirmed_path: Array[Vector2i] = [] # Holds every vector2i coordinate the player has moved to locally


########################
# INITIALIZATION LOGIC #
########################

func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	player = get_parent()
	
	setup_movement_data_at_spawn()


# Helper function for _ready()
func setup_movement_data_at_spawn() -> void:
	player.position = interpolated_position # Has to be set after the player scene has been created
	# Convert our model's y-rotation (radians) to a forward direction vector
	forward_direction = Vector3(sin(player.spawn_rotation), 0, cos(player.spawn_rotation))


##################
# ROTATION LOGIC #
##################


func _update_forward_direction() -> void:
	var yaw: float = player.model.rotation.y
	forward_direction = Vector3(sin(yaw), 0, cos(yaw))


# Since our movement system snaps the character into the correct rotation pretty quickly,
# we need a smoother rotation when aiming a weapon to is not as twitchy
func handle_rotation(delta: float) -> void:
	if not is_rotating:
		return
	
	var current = player.model.rotation.y
	var target = rotation_target
	
	# Calculate the shortest angular difference with wrapping
	var diff = wrapf(target - current, -PI, PI)
	
	# Calculate desired rotation speed based on difference
	var target_speed = clamp(diff * 8, -ROTATION_SPEED, ROTATION_SPEED)
	
	# Smoothly adjust current rotation speed
	if abs(target_speed) > abs(rotation_speed):
		# Accelerate toward target speed
		rotation_speed = lerp(rotation_speed, target_speed, ROTATION_ACCEL * delta)
	else:
		# Decelerate when approaching target
		rotation_speed = lerp(rotation_speed, target_speed, ROTATION_DECEL * delta)
	
	# Apply the rotation
	player.model.rotation.y += rotation_speed * delta
	
	_update_forward_direction()
	
	# Calculate new difference after rotation
	var new_diff = wrapf(target - player.model.rotation.y, -PI, PI)
	
	# Check if we've reached the target
	if abs(new_diff) <= ANGLE_THRESHOLD:
		player.model.rotation.y = target
		is_rotating = false
		_update_forward_direction()
		rotation_completed.emit()


# Public method to rotate and await the rotation to complete
func await_rotation(direction: Vector3) -> void:
	if rotate_towards_direction(direction):
		await rotation_completed


# Rotates our character towards a direction
# Returns true if rotation was started, false if already facing target
func rotate_towards_direction(direction: Vector3) -> bool:
	# Remove vertical component and normalize
	var horizontal_direction: Vector3 = direction.normalized()
	# Calculate target yaw directly from world direction
	var new_yaw: float = atan2(horizontal_direction.x, horizontal_direction.z)
	
	# Calculate shortest angle difference
	var current_yaw: float = player.model.rotation.y
	var angle_diff = wrapf(new_yaw - current_yaw, -PI, PI)
	
	# Check if we're already close enough to target
	if abs(angle_diff) <= ANGLE_THRESHOLD:
		return false
	
	# Set rotation target
	rotation_target = new_yaw
	is_rotating = true
	return true


#####################
# PATHFINDING LOGIC #
#####################

# Predicts a path from a grid position to another grid position using A*
func predict_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return Pathfinding.find_path(from, to, RegionManager.grid_width, RegionManager.grid_height, player)


# Helper function for click movement validation
func _validate_move_position(pos: Vector2i) -> bool:
	return RegionManager.is_cell_reachable(pos) and RegionManager.is_cell_available(pos)


# Calculates the amount of overlapping cells between two paths
func _calculate_path_overlap(current_path: Array[Vector2i], new_path: Array[Vector2i]) -> int:
	var overlap: int = 0
	for i in range(min(current_path.size(), new_path.size())):
		if current_path[current_path.size()-1-i] != new_path[i]:
			break
		overlap += 1
	return overlap


##################
# MOVEMENT LOGIC #
##################

# Helper function to handle common movement initiation logic
func start_movement_towards(start_position: Vector2i, target_position: Vector2i, target: Interactable = null) -> void:
	# Don't start movement if player is busy
	if player.is_busy:
		return
	
	# Predict a path towards our target
	var prediction: Array[Vector2i] = predict_path(start_position, target_position)
	if prediction.is_empty():
		return
	
	# Different handling based on current movement state
	# When already moving, append to existing path
	if in_motion:
		next_tick_predicted_path = prediction.slice(1) # Account for current cell
		grid_destination = target_position
	
	# When starting from idle
	else:
		# player_speed + 1 accounts for current cell
		predicted_path = Utils.pop_multiple_front(prediction, player.player_speed + 1)
		
		# If we are in the same cell as the target cell, our predicted_path will have 1 or 0 cells,
		# instead of moving towards it, we check if we are in range to activate
		if predicted_path.size() < 2:
			# If we are in range, we activate it, either way we return early
			if target and is_in_interaction_range(player.interaction_target):
				player.player_state_machine.change_state("interact")
			return
		
		# Get our immediate grid destination (this tick)
		immediate_grid_destination = predicted_path.back()
		# We add to our local unconfirmed path the next steps we'll take
		unconfirmed_path.append(immediate_grid_destination)
		# Remove the first cell from the predicted_path because we are already there
		predicted_path = predicted_path.slice(1)
		# Store the remaining prediction (if any) for next tick
		next_tick_predicted_path = prediction
		
		# Prepare everything to move correctly this tick
		cells_to_move_this_tick = predicted_path.size()
		setup_movement_step(predicted_path)
		
		# Switch our animation based on the distance we are going to traverse
		player.player_animator.update_locomotion_animation(cells_to_move_this_tick)
		
		is_predicting = true
		grid_destination = target_position
		
		# We need to send the packet here ONCE, when movement starts only
		var packet: Packets.Packet = player.player_packets.create_destination_packet(immediate_grid_destination)
		WebSocket.send(packet)


# Helper function to validate and get interaction position
func _get_valid_interaction_position(start_position: Vector2i, target: Interactable) -> Vector2i:
	var target_position: Vector2i = Utils.local_to_map(target.global_position)
	return RegionManager.get_available_positions_around_target(
		start_position,
		target_position,
		target.get_interaction_positions()
	)


# Helper function to handle common interaction path setup
func setup_interaction_movement(start_position: Vector2i, target: Interactable) -> bool:
	# Check if our target has available interact positions (not occupied by another character)
	var interaction_position: Vector2i = _get_valid_interaction_position(start_position, target)
	if interaction_position == Vector2i.ZERO:
		return false
	
	# Check if we can reach the target
	var interaction_path: Array[Vector2i] = predict_path(start_position, interaction_position) 
	if interaction_path.is_empty():
		return false
	
	start_movement_towards(start_position, interaction_position, target)
	return true


# Helper function for new movement initiation
func _start_new_movement(target_position: Vector2i) -> void:
	var prediction: Array[Vector2i] = predict_path(grid_position, target_position)
	if prediction.size() > 1: # Accounts for current cell (Need 2 cells minimum to move)
		start_movement_towards(grid_position, target_position)


# Helper function for updating existing movement
func _update_existing_movement(target_position: Vector2i) -> void:
	var prediction: Array[Vector2i] = predict_path(immediate_grid_destination, target_position)
	if prediction.size() > 0:
		next_tick_predicted_path = prediction.slice(1) # Remove starting cell
		grid_destination = target_position


# Returns true if the next step is going to be a diagonal step
func _is_step_diagonal(current: Vector2i, next: Vector2i) -> bool:
	return abs(next.x - current.x) > 0 && abs(next.y - current.y) > 0


# Calculates how long should this tick last and updates the tick accordingly
func update_movement_tick(is_diagonal: bool) -> void:
	if is_diagonal:
		# Diagonal movement should take longer because its more distance
		movement_tick = (SERVER_TICK / cells_to_move_this_tick) * 1.414 # sqrt(2) = 1.414
	else:
		movement_tick = SERVER_TICK / cells_to_move_this_tick


# Used to update this step movement tick
func calculate_step_duration(current: Vector2i, next: Vector2i) -> void:
	if _is_step_diagonal(current, next):
		update_movement_tick(true)
	else:
		update_movement_tick(false)


# Used to reconcile movement with the server
func _apply_path_correction(new_path: Array[Vector2i]) -> void:
	if not autopilot_active:
		# If our character is idle
		if not in_motion:
			# Overwrite our next tick path with the correction path
			next_tick_predicted_path = new_path
			# Prepare everything to move correctly next tick
			cells_to_move_this_tick = next_tick_predicted_path.size()-1
			setup_movement_step(next_tick_predicted_path)
			player.player_animator.update_locomotion_animation(cells_to_move_this_tick)
		else:
			# If we were already moving just replace the path
			next_tick_predicted_path = new_path.slice(1)
		
		# Turn on autopilot either way so the player can't keep sending packets
		autopilot_active = true


# Determines if the last valid server position is anywhere in my local traversed path
func _prediction_was_valid(client_path: Array[Vector2i], last_valid_position: Vector2i) -> bool:
	# Look for the index of the element
	if client_path.find(last_valid_position) == -1:
		return false
	else:
		return true


# Initializes movement parameters for a new path segment
func setup_movement_step(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	
	# Get the next cell from this path to make it our next move target
	var next_grid_position = path.pop_front()
	next_cell = Utils.map_to_local(next_grid_position)
	
	# Check that we are not already at the next position to rotate
	if next_grid_position != grid_position:
		# Calculate the direction to target
		var move_direction = (next_cell - player.position).normalized()
		
		# Compare with previous direction using a threshold
		if move_direction.distance_to(forward_direction) > ANGLE_THRESHOLD:
			# Handle rotation if direction changed
			rotate_towards_direction(move_direction)
	
	# Update our step duration based on the distance we have to traverse
	calculate_step_duration(grid_position, next_grid_position)
	
	# Reset movement counters for
	movement_elapsed_time = 0.0
	in_motion = true


# Called when we receive a new position packet from the server to make sure we are synced locally
func handle_server_reconciliation(new_server_position: Vector2i) -> void:
	if _prediction_was_valid(unconfirmed_path.duplicate(), new_server_position):
		# If the server position is the same as our final destination, clear our path
		if new_server_position == grid_destination:
			unconfirmed_path = []
		
		# If our prediction has been valid, then don't do anything
		return
	
	# If our prediction was invalid or our character did an invalid movement
	else:
		# Clear interactions on server correction
		player.pending_interaction = null
		player.interaction_target = null
		# Calculate correction from our immediate grid_destination to the last valid server position!
		var correction_path: Array[Vector2i] = predict_path(immediate_grid_destination, new_server_position)
		if correction_path.size() > 0:
			_apply_path_correction(correction_path)
			player.player_state_machine.change_state("move")


# Called when we receive a new position packet to move remote players (always in sync)
func handle_remote_player_movement(new_server_position: Vector2i) -> void:
	var next_path: Array[Vector2i] = predict_path(server_grid_position, new_server_position)
	# If our next path is valid
	if next_path.size() > 1:
		if in_motion:
			# Append the next path to our next tick server path, removing the overlap
			next_tick_server_path.append_array(next_path.slice(1))
		
		# If we are idling
		else:
			# If we are not in the same position as the server,
			# pathfind from our current position to the first server position,
			# and append the rest of the path we moved in for next tick
			if grid_position != next_path[0]:
				var sync_path: Array[Vector2i] = predict_path(grid_position, next_path[0])
				# Take the first segment based on player's speed and remove overlap
				server_path = Utils.pop_multiple_front(sync_path, player.player_speed + 1)
				# Save the rest of the path for next tick
				next_tick_server_path.append_array(sync_path)
				next_tick_server_path.append_array(next_path.slice(1))
			
			# If we are in sync with the server
			else:
				# Take the first segment based on player's speed and remove overlap
				server_path = Utils.pop_multiple_front(next_path, player.player_speed + 1)
				# Set the remaining path for next ticks
				next_tick_server_path = next_path
			
			
			cells_to_move_this_tick = server_path.size()-1
			immediate_grid_destination = server_path.back() if server_path.size() > 0 else server_grid_position
			
			# If we have cells to move
			if server_path.size() > 0:
				setup_movement_step(server_path) # This starts movement
				player.player_state_machine.change_state("move")


# Called on tick from the _process function
func process_movement_step(delta: float) -> void:
	# If we haven't completed the step, keep sliding until we do
	if movement_elapsed_time < movement_tick:
		_interpolate_position(delta)
		return
	
	_update_grid_position() # locally
	
	if player.my_player_character and is_predicting:
		_process_path_segment(delta, predicted_path, next_tick_predicted_path)
	else:
		# We need to update the locomotion animation before _process_path_segment
		if not player.my_player_character:
			player.player_animator.update_locomotion_animation(cells_to_move_this_tick)
		# This has to be after update_locomotion_animation(),
		# otherwise we don't transition into the idle animation correctly
		_process_path_segment(delta, server_path, next_tick_server_path)
		


# Called on tick by _process_movement_step to interpolate the position of the player
func _interpolate_position(delta: float) -> void:
	# We use delta time to advance our player's movement
	movement_elapsed_time += delta
	# How far we've moved towards our target based on server_tick / player_speed
	var t: float = movement_elapsed_time / movement_tick
	# Interpolate our position based on the previous values
	player.position = interpolated_position.lerp(next_cell, t)


# Update this player's local position after each completed step
func _update_grid_position() -> void:
	interpolated_position = next_cell
	grid_position = Utils.local_to_map(interpolated_position)


# Helper function to process the movement logic for both local and remote players
func _process_path_segment(delta: float, current_path: Array[Vector2i], next_path: Array[Vector2i]) -> void:
	# If our current path still has cells remaining
	if current_path.size() > 0:
		setup_movement_step(current_path)
		_interpolate_position(delta)
		return # Abort here since we still have to move this tick
	
	# If our current path has no more cells but our next path does
	elif next_path.size() > 0:
		# Get the first cells from our next tick path (based on our speed)
		current_path.append_array(Utils.pop_multiple_front(next_path, player.player_speed))
		# Update our immediate grid destination
		immediate_grid_destination = current_path.back()
		
		# Update speed only once per path segment
		cells_to_move_this_tick = current_path.size()
		setup_movement_step(current_path)
		_interpolate_position(delta)
		
		# Trigger this after each segment to update our animation
		player.player_animator.update_locomotion_animation(cells_to_move_this_tick)
		
		if player.my_player_character:
			unconfirmed_path.append(immediate_grid_destination)
			
			# Only send a packet if we are not correcting our position
			if not autopilot_active:
				# Create a new packet to report our new immediate destination to the server
				var packet: Packets.Packet = player.player_packets.create_destination_packet(immediate_grid_destination)
				WebSocket.send(packet)
		else:
			player.player_animator.update_locomotion_animation(cells_to_move_this_tick)
	
	# If we don't have any more cells to traverse
	else:
		complete_movement()


# Snap the player's position to the grid after movement ends,
# so its always exactly at the center of the cell in the grid,
# stops movement and switches the character back to idle animation
func complete_movement() -> void:
	if not in_motion:
		return
	
	# Check for interactions first
	if player.interaction_target:
		if is_in_interaction_range(player.interaction_target):
			player.player_state_machine.change_state("interact")
			return # Stop here to prevent movement reset
	
	_finalize_movement()
	movement_completed.emit()
	
	# Signal packet completion
	if player.player_packets.is_processing_packet():
		player.player_packets.complete_packet()


# Movement cleanup and executes the post movement logic
func _finalize_movement() -> void:
	player.position = next_cell
	in_motion = false
	
	# If we have to sync with the server
	if autopilot_active:
		# We clear our interactions
		player.interaction_target = null
		player.pending_interaction = null
		_handle_autopilot()
		return
	
	# After movement, check if we have a pending interaction and deal with it
	elif player.pending_interaction:
		player.handle_pending_interaction()
	# If we don't have to server sync or interact with anything,
	# then we are done moving, so we go into idle state
	else:
		if player.player_state_machine.get_current_state_name().ends_with("idle"):
			player.player_state_machine.change_state(player.player_animator.get_idle_state_name())
		else:
			player.player_state_machine.change_state(player.player_animator.get_aim_state_name())


# Called when we have to sync with the server position
func _handle_autopilot() -> void:
	# If we are at the same position as in the server
	if grid_position == server_grid_position and immediate_grid_destination == server_grid_position:
		in_motion = false
		autopilot_active = false
		grid_destination = grid_position
		# Go into idle state
		player.player_state_machine.change_state(player.player_animator.get_idle_state_name())
		
	# If our position is not synced
	else: 
		# Predict a path from our current grid position to the server position
		next_tick_predicted_path = predict_path(grid_position, server_grid_position)

		# If our prediction is valid
		if next_tick_predicted_path.size() > 1:
			# Because we were already idle here, we need to remove the overlap
			next_tick_predicted_path = next_tick_predicted_path.slice(1)
			# Get the first cells from our next tick path (based on our speed)
			predicted_path.append_array(Utils.pop_multiple_front(next_tick_predicted_path, player.player_speed+1))
			
			# If we have a valid path for this tick
			if predicted_path.size() > 1:
				# Update our immediate grid destination
				immediate_grid_destination = predicted_path.back()
				unconfirmed_path.append(immediate_grid_destination)
				
				# Update only once per path segment
				cells_to_move_this_tick = predicted_path.size()-1 # We subtract one since this is counting grid cells
				setup_movement_step(predicted_path)
				player.player_animator.update_locomotion_animation(cells_to_move_this_tick)
			else:
				teleport_to_position(server_grid_position)
		
		# If we couldn't find a valid prediction towards our target, we teleport to it
		else:
			teleport_to_position(server_grid_position)


# Helper function to immediately move a character without traversing the grid
# Used to reset our player position to sync with the server
func teleport_to_position(new_grid_position: Vector2i) -> void:
	# Update all position references
	grid_position = new_grid_position
	grid_destination = new_grid_position
	immediate_grid_destination = new_grid_position
	
	# Update visual position
	interpolated_position = Utils.map_to_local(new_grid_position)
	player.position = interpolated_position
	next_cell = interpolated_position
	
	# Reset movement state
	in_motion = false
	is_rotating = false
	movement_elapsed_time = 0
	
	# Clear any pending paths
	predicted_path = []
	next_tick_predicted_path = []
	unconfirmed_path = []
	
	# Exit autopilot mode
	autopilot_active = false
	
	# Force state update if needed
	if player.player_state_machine.get_current_state_name() == "move":
		player.player_state_machine.change_state(player.player_animator.get_idle_state_name())


# Attempts to predict a path towards that cell to move our character,
# but only if the cell is reachable and available
func click_to_move(new_destination: Vector2i) -> void:
	# Don't start movement if player is busy
	if player.is_busy:
		return
	
	if not _validate_move_position(new_destination):
		return
	
	# Clear any pending interactions
	player.interaction_target = null
	player.pending_interaction = null
	
	if in_motion:
		_update_existing_movement(new_destination)
	else:
		_start_new_movement(new_destination)
	
	player.player_state_machine.change_state("move")


# Helper function to check if player is in interaction range
func is_in_interaction_range(target: Interactable) -> bool:
	# Prevent interacting while moving towards immediate_grid_position
	if grid_position != immediate_grid_destination:
		return false
	
	# Check if we are at any valid position
	var target_position: Vector2i = Utils.local_to_map(target.global_position) 
	for relative_position in target.get_interaction_positions():
		if grid_position == target_position + relative_position:
			return true
	
	# Not in range to any of the valid interaction positions for this target
	return false
