extends CharacterBody3D

const packets := preload("res://packets.gd")
const player_scene := preload("res://objects/character/player/player.tscn")
const Player := preload("res://objects/character/player/player.gd")

# CONSTANTS
const SERVER_TICK: float = 0.5

# Tick related data
var movement_tick: float = SERVER_TICK # Defaults to server_tick

# Spawn data
var player_id: int
var player_name: String
var player_path: Array
var model_rotation_y: float
var player_speed: int
# Used to spawn the character and also to correct the player's position
var server_grid_position: Vector2i
var my_player_character: bool
# Internal data
# We store our current grid_position and our grid_destination_position
var grid_position: Vector2i
var grid_destination: Vector2i

# Position is our current point in space but thats built-in Godot
# position: Vector3 # Where our player is in our screen

var local_position: Vector3 # Where our player is in the server
var interpolated_position: Vector3 # Used in _process to slide the character
var elapsed_time: float = 0.0
var next_cell: Vector3 # Next cell our player should move to

# Used to determine if the player is already in motion
var is_in_motion = false
# Walking is used to switch between the different animations
var walking = false
# Chatting is used to display a bubble on top of the player's head when writing
var chatting = false

var camera : Camera3D
var raycast : RayCast3D
# Constants
const RAYCAST_DISTANCE : float = 20

@onready var animation_player: AnimationPlayer = $Model/Body/AnimationPlayer
@onready var model: Node3D = $Model
@onready var camera_rig: Node3D = $CameraRig
@onready var chat_bubble: Node3D = $ChatBubbleOrigin/ChatBubble

static func instantiate(
	id: int,
	nickname: String,
	path: Array,
	spawn_model_rotation_y: float, # Used to update our model.rotation.y
	speed: int,
	is_my_player_character: bool
) -> Player:
	# Instantiate a new empty player character
	var player := player_scene.instantiate()
	# Load the data from the function parameters into a new player character
	player.player_id = id
	player.player_name = nickname
	player.player_path = path
	player.model_rotation_y = spawn_model_rotation_y
	player.player_speed = speed
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
	animation_player.set_blend_time("walk", "idle", 0.2)
	
	# Connect the signals
	Signals.ui_chat_input_toggle.connect(_on_chat_input_toggle)
	
	position = local_position

	# Update any other spawn data here
	model.rotation.y = model_rotation_y
	
	# Update our player's movement tick at spawn
	update_movement_tick()
	
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
	chatting = !chatting

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
		
		_rotate_player(grid_destination)
		
		# Create a new packet to hold our input velocity
		var packet := packets.Packet.new()
		var player_destination_packet := packet.new_player_destination()
		player_destination_packet.set_x(grid_destination.x)
		player_destination_packet.set_z(grid_destination.y)
		
		# Send our new destination to the server
		WebSocket.send(packet)
		
		# DEBUG
		# print(grid_destination)
	else:
		print("no collision detected")

func _process(delta: float) -> void:
	# if not my_player_character:
	
	# move players with the data from the server
	if is_in_motion:
		_move_player(delta)

# Keep characters stuck to the floor
func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

# Called every tick from the _process function
func _move_player(delta: float) -> void:
	if elapsed_time < movement_tick:
		elapsed_time += delta
		var t : float = elapsed_time / movement_tick
		interpolated_position = local_position.lerp(next_cell, t)
		position = interpolated_position
		
	# If elapsed time is past the tick
	else:
		# Snap the player's position
		local_position = next_cell
		# If we still have a cell to traverse
		if player_path.size() > 0:
			# Get the next cell in our path to make it our move target
			next_cell = Utils.map_to_local(player_path.pop_front())
			# Reset our move variable 
			elapsed_time = 0
		
		# If we don't have a valid path anymore, we are NOT moving!
		else:
			is_in_motion = false

# Updates the player's path and sets the next cell the player should traverse
func update_destination(path: Array) -> void:
	# We add the new path at the end of the previous one
	player_path.append_array(path)
	
	# If we have a path to traverse (two cells or more)
	if player_path.size() > 1:
		
		# If our character is already moving
		if is_in_motion:
			# Overwrite our server grid position with the data from the server
			server_grid_position = player_path.pop_front()
			
			# Get the first position in our path as our local_position
			# CAUTION this will make our character rubber band to where he is on the server!
			local_position = Utils.map_to_local(server_grid_position)

			# Get the next cell in our path to make it our move target
			next_cell = Utils.map_to_local(player_path.pop_front())
			
			# Reset our move variable in _process
			elapsed_time = 0
		
		# If this is our first move
		else:
			next_cell = Utils.map_to_local(player_path.pop_front())
			is_in_motion = true

# Overwrite our client's grid position locally with the one from the server
func _sync_player() -> void:
	pass
	# grid_position = player_path.front()

# Rotates our character to look at the target cell
func _rotate_player(target: Vector2i) -> void:
	# If we click our own cell, ignore
	if grid_position == target:
		return
	
	model.look_at(Utils.map_to_local(target))

# Utility function to rotate our model and change the animation
func _animate_character(direction: Vector3) -> void:
	# If we are trying to move
	if direction:
		# Make our model look at the direction he is moving towards
		model.look_at(direction + position)
		
		# Update the character's state machine
		if not walking:
			walking = true
			# Only start playing the animation when the state changes
			animation_player.play("walk")
	
	# If we are not trying to move, stop
	else:
		# Update the character's state machine
		if walking:
			walking = false
			# Only start playing the animation when the state changes
			animation_player.play("idle")

# Used to update the text inside our chat bubble!
func new_chat_bubble(message: String) -> void:
	chat_bubble.set_text(message)

# Calculates how quickly I should move based on my speed
func update_movement_tick() -> void:
	movement_tick = SERVER_TICK / player_speed
