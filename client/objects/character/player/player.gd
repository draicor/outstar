extends CharacterBody3D

const packets := preload("res://packets.gd")
const player_scene := preload("res://objects/character/player/player.tscn")
const Player := preload("res://objects/character/player/player.gd")

# EXPORTED VARIABLES
@export var rotation_speed: float = 6.0
@export var RAYCAST_DISTANCE : float = 20 # 20 meters

# CONSTANTS
const SERVER_TICK: float = 0.5 # Controls local player move speed
const DIRECTION_THRESHOLD := 0.01 # Accounts for floating point imprecision

# Tick related data
var movement_tick: float = SERVER_TICK # Defaults to server_tick

# Spawn data
var player_id: int
var player_name: String
var model_rotation_y: float
var server_grid_position: Vector2i # Used to spawn the character and also to correct the player's position
var my_player_character: bool # Used to differentiate my character from remote players

# Internal data
var grid_position: Vector2i # Keeps track of our grid position locally
var grid_destination: Vector2i # Used in _raycast(), to tell the server where we want to move

var player_path: Array # Set at spawn and after server movement
var next_tick_player_path: Array # Used to store the next path

var player_speed: int # Set at spawn and after server movement

var interpolated_position: Vector3 # Used to smoothly slide our character in our game client
var movement_elapsed_time: float = 0.0 # Used in _process to slide the character
var next_cell: Vector3 # Used in _process, its the next cell our player should move to

# Rotation state
var forward_direction: Vector3 # Used to keep track of our current forward direction
var previous_forward_direction: Vector3 # We compare against this to check if we need to rotate
var is_rotating: bool = false # To prevent movement before rotation ends 
var rotation_elapsed: float = 0.0 # Used in _process to rotate the character
var start_yaw: float = 0.0
var target_yaw: float = 0.0

# Client prediction
var is_predicting: bool = false
var predicted_path: Array = [] # Holds our most recent predicted_path
var next_tick_predicted_path: Array = [] # Used to store our next tick predicted path
var unconfirmed_traversed_path: Array = [] # Holds every vector2i coordinate the player has moved to locally

# Logic variables
var in_motion: bool = false # If the character is moving
var autopilot_active: bool = false # If the server is forcing the player to move
var is_typing: bool = false # To display a bubble when typing

# Animation state machine
var current_animation : ASM = ASM.IDLE
enum ASM {
	IDLE,
	WALK,
	JOG,
	RUN,
}
# Locomotion
var locomotion := {
	0: {state = ASM.IDLE, animation = "idle", play_rate = 1.0},
	1: {state = ASM.WALK, animation = "walk", play_rate = 0.9},
	2: {state = ASM.JOG, animation = "run", play_rate = 0.65},
	3: {state = ASM.RUN, animation = "run", play_rate = 0.8}
}

# Camera variables
var camera : Camera3D
var raycast : RayCast3D

# Debugging
var debugging_enabled: bool = true

@onready var animation_player: AnimationPlayer = $Model/Body/AnimationPlayer
@onready var model: Node3D = $Model
@onready var camera_rig: Node3D = $CameraRig
@onready var chat_bubble: Node3D = $ChatBubbleOrigin/ChatBubble


static func instantiate(
	id: int,
	nickname: String,
	path: Array,
	spawn_model_rotation_y: float, # Used to update our model.rotation.y
	is_my_player_character: bool
) -> Player:
	# Instantiate a new empty player character
	var player := player_scene.instantiate()
	# Load the data from the function parameters into a new player character
	player.player_id = id
	player.player_name = nickname
	player.player_path = path
	player.model_rotation_y = spawn_model_rotation_y
	player.my_player_character = is_my_player_character
	
	# Overwrite our local copy of the grid positions
	player.server_grid_position = path.front()
	player.grid_position = player.server_grid_position
	
	# Overwrite our local copy of the space positions
	player.interpolated_position = Utils.map_to_local(player.server_grid_position)
	
	return player


func _ready() -> void:
	# Blend animations
	animation_player.set_blend_time("idle", "walk", 0.2)
	animation_player.set_blend_time("idle", "run", 0.1)
	animation_player.set_blend_time("walk", "idle", 0.15)
	animation_player.set_blend_time("walk", "run", 0.15)
	animation_player.set_blend_time("run", "idle", 0.15)
	animation_player.set_blend_time("run", "walk", 0.15)
	
	# Connect the signals
	Signals.ui_chat_input_toggle.connect(_on_chat_input_toggle)
	
	position = interpolated_position # Has to be set here after the scene has been created
	unconfirmed_traversed_path.append(grid_position) # Add our spawn position to our unconfirmed path
	
	# Update any other spawn data here
	model.rotation.y = model_rotation_y
	# Convert our model's y-rotation (radians) to a forward direction vector
	forward_direction = Vector3(-sin(model_rotation_y), 0, -cos(model_rotation_y))
	previous_forward_direction = forward_direction # At spawn, we make them equal
	
	# Update our player's movement tick at spawn
	update_movement_tick(player_speed)
	
	# Make our character spawn idling
	_change_animation("idle", 1.0)
	
	# Do this only for our player's character
	if my_player_character:
		# Add a camera to our character
		camera = Camera3D.new()
		camera_rig.add_child(camera)
		# Add a raycast 3d node to our camera
		raycast = RayCast3D.new()
		
		camera.add_child(raycast)
		
		# Stores our player character as a global variable
		GameManager.set_player_character(self)


# Toggles the bool that keeps track of the chat
func _on_chat_input_toggle() -> void:
	is_typing = !is_typing


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		var mouse_position : Vector2 = get_viewport().get_mouse_position()
		_raycast(mouse_position)


func _raycast(mouse_position: Vector2) -> void:
	# If our client is being moved automatically or our raycast node is invalid
	if autopilot_active or not raycast:
		return
	
	# Cast a ray from our camera to our mouse position
	raycast.target_position = camera.project_local_ray_normal(mouse_position) * RAYCAST_DISTANCE
	# Updates the collision information for the ray immediately,
	# without waiting for the next _physics_process call
	raycast.force_raycast_update()
	
	# If we collided with something
	if raycast.is_colliding():
		# Grab the collision point
		var local_point : Vector3 = raycast.get_collision_point()
			
		# Transform the local space position to our grid coordinate
		grid_destination = Utils.local_to_map(local_point)
		
		# If we were already predicting a path and moving towards it
		if in_motion and is_predicting:
			# Generate and store another path prediction towards the destination we want to reach
			# Take into consideration I'm between cells, so take the next_cell and not my current cell
			var prediction = _predict_path(Utils.local_to_map(next_cell), grid_destination)
			
			# If the predicted path is valid
			if prediction.size() > 1:
				# Since we are already between cells,
				# we need to wait until we complete our current tick movement,
				# so we store our prediction for the next tick
				next_tick_predicted_path = prediction.slice(1)
				
				# Create a new packet to hold our input and send it to the server
				var packet := _create_player_destination_packet(grid_destination)
				WebSocket.send(packet)
				
		# If we are IDLE
		else:
			# Generate and store a path prediction towards the destination we want to reach
			var prediction = _predict_path(grid_position, grid_destination)
			# If the prediction is valid
			# Make this prediction our current path and start moving right away
			if prediction.size() > 1:
				# Because we were idling, we need the first 4 cells for this tick
				predicted_path = Utils.pop_multiple_front(prediction, 4)
				# Store the remaining prediction for next tick
				next_tick_predicted_path = prediction
				# Prepare everything to move correctly this tick
				update_movement_tick(predicted_path.size()-1)
				_setup_next_movement_step(predicted_path, false)
				
				is_predicting = true
				
				# Create a new packet to hold our input and send it to the server
				var packet := _create_player_destination_packet(grid_destination)
				WebSocket.send(packet)
				
				# DEBUG
				# print(grid_destination)
		#else:
			#print("no collision detected")

# NOTE
# Simple straight line prediction for now, this needs to be replaced with A*
# Predicts a path from a grid position to another grid position
func _predict_path(from: Vector2i, to: Vector2i) -> Array:
	var path = []
	# We make our starting position be the first element in our path
	var current = from
	path.append(current)
	
	# While we haven't reached our destination
	while current != to:
		# Keep heading towards our target, one cell at a time and add it to our path array
		var dir = (to - current).sign()
		current += dir
		path.append(current)
	
	return path


# Creates and returns a player_destination_packet
func _create_player_destination_packet(grid_pos: Vector2i) -> packets.Packet:
	var packet := packets.Packet.new()
	var player_destination_packet := packet.new_player_destination()
	player_destination_packet.set_x(grid_pos.x)
	player_destination_packet.set_z(grid_pos.y)
	return packet


# _physics_process runs at a fixed timestep
# Movement should be handled here because this runs before _process
func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	_rotate_character(delta) # Handle rotation first
	
	if in_motion:
		_update_player_movement(delta)
	
	if debugging_enabled:
		DebugDraw3D.draw_line(position, position + forward_direction * 1, Color.RED) # 2 meters forward line


# Called on tick from the _process function
func _update_player_movement(delta: float) -> void:
	if movement_elapsed_time < movement_tick:
		move_and_slide_player(delta)
		
	# If elapsed time is past the tick
	else:
		# Update the local player position for our interpolated movement
		interpolated_position = next_cell
		# Keep track of our position in the grid, locally
		grid_position = Utils.local_to_map(interpolated_position)
		
		# If our traversed path doesn't have our current grid position, add it
		if not unconfirmed_traversed_path.has(grid_position):
			unconfirmed_traversed_path.append(grid_position)
		
		# If this is our character and we are predicting
		if my_player_character and is_predicting:
			if predicted_path.size() > 0:
				# Append our next step since we are already moving towards it to prevent desync,
				# because the server packet might arrive before we finish moving
				unconfirmed_traversed_path.append(predicted_path[0])
				# Update our speed, adjust our locomotion and start moving
				_setup_next_movement_step(predicted_path, true)
				move_and_slide_player(delta)
				switch_locomotion(player_speed)
			
			# If we already completed the path we had
			else:
				# Check if we have a second predicted path, if not, we stopped moving
				if next_tick_predicted_path.is_empty():
					# Snap the player's position to the grid after movement ends
					# So its always exactly at the center of the cell in the grid
					position = next_cell
					interpolated_position = next_cell
					# After IDLE, we set is motion to false and turn off autopilot too
					in_motion = false
					autopilot_active = false
					switch_locomotion(0) # IDLE
				
				# If we have a next tick predicted path
				else:
					# Only get the first 3 cells from our next tick path
					predicted_path.append_array(Utils.pop_multiple_front(next_tick_predicted_path, 3))
					# Update our speed, adjust our locomotion and start moving
					update_movement_tick(predicted_path.size())
					_setup_next_movement_step(predicted_path, true)
					switch_locomotion(player_speed) # update_movement_tick updated this
					move_and_slide_player(delta)
		
		
		# Every other player or us if we are not predicting
		else:
			# If we still have a path to traverse this tick
			if player_path.size() > 0:
				# Append our next step since we are already moving towards it
				# so it doesn't desync, because the server packet will arrive before we finish
				unconfirmed_traversed_path.append(player_path[0])
				# Update our speed, adjust our locomotion and start moving
				_setup_next_movement_step(player_path, true)
				switch_locomotion(player_speed)
				move_and_slide_player(delta)
			
			# If we already completed the path we had
			else:
				# Check if we have a second path, if not, we stopped moving
				if next_tick_player_path.is_empty():
					# Snap the player's position to the grid after movement ends
					# So its always exactly at the center of the cell in the grid
					position = next_cell
					interpolated_position = next_cell
					# After IDLE, we set is motion to false and turn off autopilot too
					in_motion = false
					autopilot_active = false
					switch_locomotion(0) # IDLE

				# If we have a second path
				else:
					# Only get the first 3 cells from our next tick path
					player_path.append_array(Utils.pop_multiple_front(next_tick_player_path, 3))
					# Update our speed, adjust our locomotion and start moving
					update_movement_tick(player_path.size())
					_setup_next_movement_step(player_path, true)
					move_and_slide_player(delta)
					switch_locomotion(player_speed)  # update_movement_tick updated this


# Used to switch the current animation state
func switch_locomotion(steps: int) -> void:
	var settings = locomotion.get(steps, locomotion[0]) # Defaults to IDLE
	current_animation = settings.state
	_change_animation(settings.animation, settings.play_rate)


# Called on tick by _update_player_movement to interpolate the position of the player
func move_and_slide_player(delta: float) -> void:
	# We use delta time to advance our player's movement
	movement_elapsed_time += delta
	# How far we've moved towards our target based on server_tick / player_speed
	var t: float = movement_elapsed_time / movement_tick
	# Interpolate our position based on the previous values
	position = interpolated_position.lerp(next_cell, t)


# Updates the player's path and sets the next cell the player should traverse
func update_destination(new_path: Array) -> void:
	# Only do the reconciliation for my player, not the other players
	if my_player_character and is_predicting:
		# We are ahead of the server (we predicted our path and moved already)
		# If we have unconfirmed movement
		if not unconfirmed_traversed_path.is_empty():
			var confirmed_steps: int = _validate_move_prediction(unconfirmed_traversed_path, new_path)
			# If none of the steps from the packet was valid
			if confirmed_steps == 0:
				print("Synchronizing")
				#autopilot_active = true # NOTE this will be implemented soon
				unconfirmed_traversed_path = []
				player_path = []
				
				# CAUTION
				# Teleport the player to the correct server position
				# Replace this with a graceful prediction from current pos to server_pos
				grid_position = new_path.pop_back()
				interpolated_position = Utils.map_to_local(grid_position)
			
			# If we have at least one confirmed step
			else:
				# Remove it from the unconfirmed_traversed_path array and exit early
				unconfirmed_traversed_path = unconfirmed_traversed_path.slice(confirmed_steps)
				return
	
	else:
		if in_motion:
			# If we haven't completed the first path yet
			if not player_path.is_empty():
				# Find the overlap at the end of our path with the start of the next path
				var overlap := _calculate_path_overlap(player_path, new_path)
				var next_path := new_path.slice(overlap)
				# Append the new path to our next tick path
				next_tick_player_path.append_array(next_path)
			
			# If we have completed the first path but NOT the second one
			elif not next_tick_player_path.is_empty():
				# Get the first 3 cells from our next tick path
				player_path.append_array(Utils.pop_multiple_front(next_tick_player_path, 3))
				
			# If the player already completed both paths
			else:
				# We make the new path our next path, skipping the current cell
				next_tick_player_path.append_array(new_path.slice(1))
		
		# If we are idling
		else:
			# If we have a path to traverse (two cells or more)
			if new_path.size() > 1:
				# We make the new path our current path
				player_path = new_path
				# Update our player's speed to match our new path (remove overlap)
				update_movement_tick(player_path.size()-1)
				_setup_next_movement_step(player_path, false) # This starts movement


# Compares the traversed path by the client to the server path (true authoritative path)
# and returns an integer with the number of confirmed steps
func _validate_move_prediction(client_path, authoritative_path) -> int:
	print("client prediction: ", client_path)
	print("server path: ", authoritative_path)
	
	var confirmed_steps = 0
	# For each cell in the server's path
	for i in range(authoritative_path.size()):
		# Iterate over the 3 oldest steps our character traversed in the client
		for j in range(min(client_path.size(), 3)):
			# If one of the 3 steps we predicted was part of our server packet
			if authoritative_path[i] == client_path[j]:
				# If the paths converged, we need to check by how much
				# If this step was further ahead, overwrite our variable
				if confirmed_steps < j+1:
					confirmed_steps = j+1
	
	return confirmed_steps

# Prepare the variables before starting a new move
func _setup_next_movement_step(path: Array, should_rotate: bool) -> void:
	# Get the next cell from this path to make it our next move target
	next_cell = Utils.map_to_local(path.pop_front())
	
	# CAUTION: rotation should happen AFTER updating next_cell
	if should_rotate:
		# Rotate our character towards the next cell
		_calculate_rotation(next_cell)
		
	# Reset our move variable in _process
	movement_elapsed_time = 0
	# Specify our character is moving
	in_motion = true


func _calculate_path_overlap(current_path: Array, new_path: Array) -> int:
	var overlap: int = 0
	for i in range(min(current_path.size(), new_path.size())):
		if current_path[current_path.size()-1-i] != new_path[i]:
			break
		overlap += 1
	return overlap


# NOTE: this will be implemented later
# Overwrite our client's grid position locally with the one from the server
#func _sync_player() -> void:
	#pass
	# grid_position = server_grid_position


# Calculates the rotation
func _calculate_rotation(target: Vector3) -> void:
	# Skip if we clicked our current cell
	if position == target:
		is_rotating = false
		return
	
	# Calculate the direction to target
	forward_direction = (target - position)
	# Remove the vertical component for ground-based characters
	forward_direction.y = 0
	
	# Normalize our forward direction for comparison with the previous forward direction
	var normalized_forward_direction: Vector3 = Vector3.ZERO
	if forward_direction.length() > 0:
		normalized_forward_direction = forward_direction.normalized()
	
	# Check if direction has changed significantly AND we have a valid forward direction
	if (normalized_forward_direction.distance_to(previous_forward_direction) > DIRECTION_THRESHOLD) and forward_direction.length() > 0.001:
		forward_direction = normalized_forward_direction
		# Calculate yaw
		start_yaw = model.rotation.y
		# Calculate target rotation quaternion
		# NOTE: Direction has to be negative so the model faces forward
		target_yaw = atan2(-forward_direction.x, -forward_direction.z)
		# Reset rotation state
		rotation_elapsed = 0.0
		is_rotating = true
		
		# Store the new forward direction
		previous_forward_direction = forward_direction
	
	# No rotation needed
	else:
		is_rotating = false


# Rotates our character on tick
func _rotate_character(delta: float) -> void:
	if is_rotating:
		rotation_elapsed = min(rotation_elapsed + rotation_speed * delta, 1.0)
		model.rotation.y = lerp_angle(start_yaw, target_yaw, rotation_elapsed)
		
		# Check if rotation is complete after rotating
		if rotation_elapsed >= 1.0:
			is_rotating = false


func _change_animation(animation: String, play_rate: float) -> void:
	animation_player.play(animation)
	animation_player.speed_scale = play_rate


# Used to update the text inside our chat bubble
func new_chat_bubble(message: String) -> void:
	chat_bubble.set_text(message)


# Calculates how quickly I should move based on my speed
func update_movement_tick(new_speed: int) -> void:
	# Clamp speed to 1-3 range
	new_speed = clamp(new_speed, 1, 3)
	player_speed = new_speed # Overwrite our player's speed
	movement_tick = SERVER_TICK / new_speed
