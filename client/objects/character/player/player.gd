extends CharacterBody3D

const packets := preload("res://packets.gd")
const player_scene := preload("res://objects/character/player/player.tscn")
const Player := preload("res://objects/character/player/player.gd")

# EXPORTED VARIABLES
@export var rotation_speed: float = 6.0
@export var RAYCAST_DISTANCE : float = 20 # 20 meters

# CONSTANTS
const SERVER_TICK: float = 0.5

# Tick related data
var movement_tick: float = SERVER_TICK # Defaults to server_tick

# Spawn data
var player_id: int
var player_name: String
var model_rotation_y: float
# Used to spawn the character and also to correct the player's position
var server_grid_position: Vector2i # ONLY USED AT SPAWN FOR NOW, we will use it to correct our local grid position compared to the server
var my_player_character: bool

# Internal data
var grid_position: Vector2i # Keeps track of our grid position locally
var grid_destination: Vector2i # Used in _raycast(), to tell the server where we want to move

var player_path: Array # Set at spawn and after server movement
var player_next_tick_path: Array # Used to store the next path

var player_speed: int # Set at spawn and after server movement
var player_next_tick_speed: int # Used to store the next speed

var interpolated_position: Vector3 # Used to smoothly slide our character in our game client
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
		
		# Create a new packet to hold our input and send it to the server
		var packet := _create_player_destination_packet(grid_destination)
		WebSocket.send(packet)
		
		# DEBUG
		# print(grid_destination)
	#else:
		#print("no collision detected")


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
	
	if is_in_motion:
		_update_player_movement(delta)


# Called on tick from the _process function
func _update_player_movement(delta: float) -> void:
	if movement_elapsed_time < movement_tick:
		move_player_locally(delta)
		
	# If elapsed time is past the tick
	else:
		# Update the local player position for our interpolated movement
		interpolated_position = next_cell
		
		# If we still have a path to traverse this tick
		if player_path.size() > 0:
			_setup_next_movement_step(true)
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
				interpolated_position = next_cell
				is_in_motion = false
				
				switch_locomotion(0) # 0 steps means IDLE

			# If we have a second path
			else:
				# We add the second path to the current one
				player_path.append_array(player_next_tick_path)
				# We clear the next path since we already used it
				player_next_tick_path = []
				# Update our player's movement tick to match our new path
				# Without removing -1 because overlap already took care of it
				update_movement_tick(player_next_tick_speed)
				_setup_next_movement_step(true)
				move_player_locally(delta)
				# Update our locomotion
				switch_locomotion(player_next_tick_speed)
				# We overwrite our speed with the next tick speed
				player_speed = player_next_tick_speed
		
		# After moving a cell in the grid,
		# Keep track of our position in the grid, locally
		if grid_position != Utils.local_to_map(interpolated_position):
			grid_position = Utils.local_to_map(interpolated_position)
			print(grid_position)


# Used to switch the current animation state
func switch_locomotion(steps: int) -> void:
	var settings = locomotion.get(steps, locomotion[0]) # Defaults to IDLE
	current_animation = settings.state
	_change_animation(settings.animation, settings.play_rate)


# Called on tick by _update_player_movement to interpolate the position of the player
func move_player_locally(delta: float) -> void:
	# We use delta time to advance our player's movement
	movement_elapsed_time += delta
	# How far we've moved towards our target based on server_tick / player_speed
	var t: float = movement_elapsed_time / movement_tick
	# Interpolate our position based on the previous values
	position = interpolated_position.lerp(next_cell, t)


# Updates the player's path and sets the next cell the player should traverse
func update_destination(new_path: Array) -> void:
	# If we are already in motion
	if is_in_motion:
		# If we haven't completed the first path yet
		if not player_path.is_empty():
			# Find the overlap at the end of our path with the start of the next path
			var overlap := _calculate_path_overlap(player_path, new_path)
			
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
	
	# If we are not moving
	else:
		# We make the new path our current path
		player_path = new_path
		
		# If we have a path to traverse (two cells or more)
		if player_path.size() > 1:
			# Store this tick move speed after removing the first cell
			player_speed = player_path.size()-1
			# Update our player's movement tick to match our new path
			update_movement_tick(player_speed)
			_setup_next_movement_step(false)
			is_in_motion = true


# Prepare the variables before starting a new move
func _setup_next_movement_step(should_rotate: bool) -> void:
	# Get the next cell in our path to make it our next move target
	next_cell = Utils.map_to_local(player_path.pop_front())
	
	# CAUTION: rotation should happen AFTER updating next_cell
	if should_rotate:
		# Rotate our character towards the next cell
		_calculate_rotation(next_cell)
		
	# Reset our move variable in _process
	movement_elapsed_time = 0


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
	movement_tick = SERVER_TICK / new_speed
