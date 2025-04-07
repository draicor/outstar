extends CharacterBody3D

const packets := preload("res://packets.gd")
const player_scene := preload("res://objects/character/player/player.tscn")
const Player := preload("res://objects/character/player/player.gd")

# EXPORTED VARIABLES
@export var rotation_speed: float = 6.0
@export var RAYCAST_DISTANCE : float = 20 # 20 meters

# CONSTANTS
const SERVER_TICK: float = 0.5

# Prediction system
var predicted_path: Array = []
var full_predicted_path: Array = []
var is_predicting: bool = false
var current_segment_index: int = 0
var confirmed_segments: Array = [] # Segments validated by the server
var server_validated_index: int = 0 # Validated by the server

# Tick related data
var movement_tick: float = SERVER_TICK # Defaults to server_tick

# Spawn data
var player_id: int
var player_name: String
var model_rotation_y: float
# Used to spawn the character and also to correct the player's position
var server_grid_position: Vector2i # ONLY USED AT SPAWN, we could use it to correct our position from the server
var my_player_character: bool
# Internal data
# We store our current grid_position and our grid_destination_position
var grid_position: Vector2i # NOT IN USE YET, we can use it to correct our player position
var grid_destination: Vector2i # Used in our raycast, to tell the server where we want to move

# Position is our current point in space but thats built-in Godot
# position: Vector3 # Where our player is in our screen

var player_path: Array # Set at spawn and after server movement
var player_next_tick_path: Array # Used to store the next path

var player_speed: int # Set at spawn and after server movement
var player_next_tick_speed: int # Used to store the next speed

var local_position: Vector3 # Where our player is in the server
var interpolated_position: Vector3 # Used in _process to slide the character
var movement_elapsed_time: float = 0.0 # Used in _process to slide the character
var next_cell: Vector3 # Used in _process, its the next cell our player should move to

# Rotation state
var is_rotating: bool = false # To prevent movement before rotation ends 
var rotation_elapsed: float = 0.0 # Used in _process to rotate the character
var start_yaw: float = 0.0
var target_yaw: float = 0.0

# Logic variables
var is_in_motion: bool = false # If the character is moving
var is_typing: bool = false # To display a bubble when typing

# Animation state machine
var current_animation : ASM = ASM.IDLE
enum ASM {
	IDLE,
	WALK,
	JOG,
	RUN,
}
# We have a dictionary connected to the enum above to switch animation states
var Animations: Dictionary[ASM, String] = {
	ASM.IDLE: "idle",
	ASM.WALK: "walk",
	ASM.JOG: "run",
	ASM.RUN: "run",
}

# Camera variables
var camera : Camera3D
var raycast : RayCast3D

# Scene nodes
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
	player.local_position = Utils.map_to_local(player.server_grid_position)
	player.interpolated_position = player.local_position
	
	return player


func _ready() -> void:
	# Blend animations
	animation_player.set_blend_time("idle", "walk", 0.2)
	animation_player.set_blend_time("walk", "idle", 0.15)
	animation_player.set_blend_time("idle", "run", 0.1)
	animation_player.set_blend_time("run", "idle", 0.15)
	animation_player.set_blend_time("walk", "run", 0.15)
	animation_player.set_blend_time("run", "walk", 0.15)
	
	# Connect the signals
	Signals.ui_chat_input_toggle.connect(_on_chat_input_toggle)
	
	position = local_position
	
	# Update any other spawn data here
	model.rotation.y = model_rotation_y
	
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


# Casts a ray from our camera to our mouse position and predicts the full path
# the player will have to traverse to get to that destination, then sends a packet
# to the server with the destination they want to reach
func _raycast(mouse_position: Vector2) -> void:
	# If our raycast node is not valid
	if not raycast:
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
		
		# Clean up any previous prediction
		_cleanup_prediction()
		
		# Generate and store full predicted path
		full_predicted_path = _predict_path(grid_position, grid_destination)
		# If we have a valid path after prediction
		if full_predicted_path.size() > 1:
			is_predicting = true
			
			# Start moving through the predicted path immediately
			player_path = full_predicted_path.duplicate()
			if player_path.size() > 1:
				player_speed = player_path.size()-1
				update_movement_tick(player_speed)
				next_cell = Utils.map_to_local(player_path[0])
				player_path.remove_at(0)
				movement_elapsed_time = 0
				is_in_motion = true
			
			# Create a new packet to send our full grid destination to the server
			var packet := packets.Packet.new()
			var player_destination_packet := packet.new_player_destination()
			player_destination_packet.set_x(grid_destination.x)
			player_destination_packet.set_z(grid_destination.y)
			
			# Send our new destination to the server
			WebSocket.send(packet)
			
			# DEBUG
			# print(grid_destination)
		#else:
			#print("no collision detected")


# Simple straight-line prediction
func _predict_path(from: Vector2i, to: Vector2i) -> Array:
	var path = []
	var current = from
	path.append(current)
	
	while current != to:
		var dir = (to - current).sign()
		current += dir
		path.append(current)
	
	return path


# _process runs every frame (dependent on FPS)
func _process(_delta: float) -> void:
	# if not my_player_character:
	pass


# _physics_process runs at a fixed timestep
# Movement should be handled here because this runs before _process
func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	_rotate_character(delta) # Handle rotation first
	
	if is_in_motion:
		_update_player_movement(delta)


# Called on tick from the _process function
func _update_player_movement(delta: float) -> void:
	if movement_elapsed_time < movement_tick:
		move_player_locally(delta)
		
	# If elapsed time is past the tick
	else:
		# Update the local player position for our interpolated movement
		local_position = next_cell
		# Update our local grid position
		# NOTE: We can use grid_position to display our coordinates in the HUD
		grid_position = Utils.local_to_map(local_position)
		
		# If we still have a path to traverse this tick
		if player_path.size() > 0:
			# Get the next cell in our path to make it our move target
			next_cell = Utils.map_to_local(player_path.pop_front())
			# Rotate our character towards the next cell
			_calculate_rotation(next_cell)
			# Reset our move variable 
			movement_elapsed_time = 0
			move_player_locally(delta)
			# Update our locomation after moving
			switch_locomotion(player_speed)
		
		# If we already completed the path we had
		else:
			# Check if we have a second path, if not, we stopped moving
			if player_next_tick_path.is_empty():
				# Snap the player's position to the grid after movement ends
				# So its always exactly at the center of the cell in the grid
				position = next_cell
				local_position = next_cell
				# Update our local grid position
				grid_position = Utils.local_to_map(local_position)
				is_in_motion = false
				
				# After we stop, we go back to idle
				current_animation = ASM.IDLE
				_change_animation("idle", 1.0)

			# If we have a second path
			else:
				# We add the second path to the current one
				player_path.append_array(player_next_tick_path)
				# We clear the next path since we already used it
				player_next_tick_path = []
				# Update our player's movement tick to match our new path
				# Without removing -1 because overlap already took care of it
				update_movement_tick(player_next_tick_speed)
				# Get the next cell in our path to make it our move target
				next_cell = Utils.map_to_local(player_path.pop_front())
				# Rotate our character towards the next cell
				_calculate_rotation(next_cell)
				# Reset our move variable 
				movement_elapsed_time = 0
				move_player_locally(delta)
				# Update our locomotion
				switch_locomotion(player_next_tick_speed)
				# We overwrite our speed with the next tick speed
				player_speed = player_next_tick_speed


# Used to switch the current animation state
func switch_locomotion(steps: int) -> void:
	match steps:
		1: # WALK
			current_animation = ASM.WALK
			_change_animation("walk", 0.9)
		2: # JOG
			current_animation = ASM.JOG
			_change_animation("run", 0.65)
		_: # RUN
			current_animation = ASM.RUN
			_change_animation("run", 0.8)


# Called on tick by _update_player_movement to interpolate the position of the player
func move_player_locally(delta: float) -> void:
	# We use delta time to advance our player's movement
	movement_elapsed_time += delta
	# How far we've moved towards our target based on server_tick / player_speed
	var t : float = movement_elapsed_time / movement_tick
	# Interpolate our position based on the previous values
	interpolated_position = local_position.lerp(next_cell, t)
	# Override our current position in our screen
	position = interpolated_position


# Updates the player's path and sets the next cell the player should traverse
func update_destination(new_path: Array) -> void:
	# Handles local player prediction
	if my_player_character and is_predicting:
		# Only reconcile if this is a server update (not empty and different start point)
		if new_path.size() > 0 and (player_path.size() == 0 or new_path[0] != player_path[0]):
			print("Reconcile attempt")
			_reconcile_movement(new_path)
			return
	
	# If we are already in motion
	if is_in_motion:
		# If we haven't completed the first path yet
		if not player_path.is_empty():
			# Find the overlap at the end of our path with the start of the next path
			var overlap := 0
			for i in range(min(player_path.size(), new_path.size())):
				if player_path[player_path.size() - 1 - i] != new_path[i]:
					break
				overlap += 1
			
			# Add remaining path to next tick
			var next_path := new_path.slice(overlap)
			# Append the new path to our next tick path
			player_next_tick_path.append_array(next_path)
			# NOTE: we don't remove -1 from this speed
			# Because the overlap already took care of it
			player_next_tick_speed = next_path.size()
		
		# If we have completed the first path but NOT the second one
		elif not player_next_tick_path.is_empty():
			# We add the second path to the current one
			player_path.append_array(player_next_tick_path)
			# We clear the second path since we already used it
			player_next_tick_path = []
			# We overwrite our speed with the next tick speed
			player_speed = player_next_tick_speed
			# Update our player's movement tick to match our new path
			update_movement_tick(player_speed)
			
			# Store our next tick move speed after removing the first cell
			player_next_tick_speed = new_path.size()-1
			# We make the new path our next path, skipping the current cell
			player_next_tick_path.append_array(new_path.slice(1))
			
		# If the player already completed both paths
		else:
			# Store our next tick move speed after removing the first cell
			player_next_tick_speed = new_path.size()-1
			# We make the new path our next path, skipping the current cell
			player_next_tick_path.append_array(new_path.slice(1))
	
	# If we are not moving, start new movement
	else:
		# We make the new path our current path
		player_path = new_path.duplicate()
		print("bottom of update_destination ", player_path)
		
		# If we have a path to traverse (two cells or more)
		if player_path.size() > 1:
			# Store this tick move speed before removing the first cell
			player_speed = player_path.size()-1
			# Update our player's movement tick to match our new path
			update_movement_tick(player_speed)
			# Get the next cell in our path to make it our move target
			next_cell = Utils.map_to_local(player_path.pop_front())
			# Reset our move variable in _process
			movement_elapsed_time = 0
			is_in_motion = true


# Handles reconciliation between client prediction and server authority
func _reconcile_movement(server_path: Array) -> void:
	if not is_predicting:
		return
	
	# Get our exact current position in the path
	var current_cell = Utils.local_to_map(position)
	var client_path_index = full_predicted_path.find(current_cell)
	var server_path_index = full_predicted_path.find(server_path.back())
	
	print("client: ", client_path_index, "/", full_predicted_path.size()-1)
	print("server: ", server_path_index, "/", full_predicted_path.size()-1)
	
	# Complete mismatch, reset to server's path
	if server_path_index == -1:
		print("Complete mismatch, overwriting predicted path with server path")
		player_path = server_path.duplicate()
		full_predicted_path = server_path.duplicate()
		_cleanup_prediction()
	
	else:
		# If we have completed the full path according to the server
		if server_path_index >= full_predicted_path.size() - 1:
			print("we have completed our path according to the server")
			_cleanup_prediction()
			return
		
		# Only correct if server is significantly ahead (at least 2 cells)
		if server_path_index > client_path_index + 1:
			print("Correction needed, jumping ahead to server position")
			# Jump forward to server's position
			player_path = full_predicted_path.slice(server_path_index)
			
			# If moving between cells, complete current move immediately
			if is_in_motion:
				next_cell = Utils.map_to_local(player_path[0])
				position = next_cell
				local_position = next_cell
				grid_position = Utils.local_to_map(next_cell)
				movement_elapsed_time = 0
	
	# Start moving if we have a path but we aren't moving
	if not is_in_motion and player_path.size() > 0:
		# Store this tick move speed before removing the first cell
		player_speed = player_path.size()-1
		# Update our player's movement tick to match our new path
		update_movement_tick(player_speed)
		next_cell = Utils.map_to_local(player_path[1])
		player_path.remove_at(0) # Remove current position
		movement_elapsed_time = 0
		is_in_motion = true


# Clean up prediction state
func _cleanup_prediction() -> void:
	is_predicting = false
	full_predicted_path = []
	server_validated_index = 0
	confirmed_segments = []


# Overwrite our client's grid position locally with the one from the server
func _sync_player() -> void:
	pass
	# grid_position = server_grid_position


# Calculates the rotation
func _calculate_rotation(target: Vector3) -> void:
	# Can't change rotation within our own cell
	if position == target:
		return
	
	# Calculate the direction to target
	var direction := (target - position)
	# Remove the vertical component for ground-based characters
	direction.y = 0
	
	# Only rotate if we have a valid direction
	if direction.length() > 0.001:
		direction = direction.normalized()
		# Calculate yaw
		start_yaw = model.rotation.y
		# Calculate target rotation quaternion
		# NOTE: Direction has to be negative so the model faces forward
		target_yaw = atan2(-direction.x, -direction.z)
		# Reset rotation state
		rotation_elapsed = 0.0
		is_rotating = true
	
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


# Animates our character using the animation player
# IDLE 1.0
# WALK 0.9 (speed 1)
# JOG  0.6 (speed 2)
# RUN  0.8 (speed 3)
func _change_animation(animation: String, play_rate: float) -> void:
	animation_player.play(animation)
	animation_player.speed_scale = play_rate


# Used to update the text inside our chat bubble
func new_chat_bubble(message: String) -> void:
	chat_bubble.set_text(message)


# Calculates how quickly I should move based on my speed
func update_movement_tick(new_speed: int) -> void:
	# Clamp speed to maximum 3
	if new_speed > 3:
		new_speed = 3
		
	# If new_speed is valid
	if new_speed > 1:
		movement_tick = SERVER_TICK / new_speed
	# If not, just make our movement_tick be our SERVER_TICK
	else:
		movement_tick = SERVER_TICK
