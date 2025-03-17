extends CharacterBody3D

const packets := preload("res://packets.gd")
const player_scene := preload("res://objects/character/player/player.tscn")
const Player := preload("res://objects/character/player/player.gd")

# CONSTANTS
const SERVER_TICK: float = 0.5

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
var current_position: Vector3
var target_position: Vector3
var elapsed_time: float = 0.0

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
	
	# At spawn, we need to make our positions the same as our spawn position
	player.server_grid_position = path.front()
	player.grid_position = player.server_grid_position

	return player

func _ready() -> void:	
	# Blend animations
	animation_player.set_blend_time("idle", "walk", 0.2)
	animation_player.set_blend_time("walk", "idle", 0.2)
	
	# Connect the signals
	Signals.ui_chat_input_toggle.connect(_on_chat_input_toggle)
	
	# Update our position with the data from the server
	# We need to override our current and target positions, both used to interpolate
	current_position = Utils.map_to_local(server_grid_position)
	target_position = current_position
	# We also set our position which is where the character is placed at the world
	position = current_position

	# Update any other spawn data here
	model.rotation.y = model_rotation_y
	
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
		
		# DEBUG
		print(grid_destination)
		
		_rotate_player(grid_destination)
		
		# Create a new packet to hold our input velocity
		var packet := packets.Packet.new()
		var player_destination_packet := packet.new_player_destination()
		player_destination_packet.set_x(grid_destination.x)
		player_destination_packet.set_z(grid_destination.y)
		
		# Send our new destination to the server
		WebSocket.send(packet)
		
	else:
		print("no collision detected")

func _process(delta: float) -> void:
	# Rotate the player before syncing with the server
	# _rotate_player(grid_destination)
	
	# TO FIX -> This should only be called if there is a certain distance
	# between the client's position and the client's position in the server
	_sync_player()
	
	# If this is not my player character, move it with the data I got from the server
	if not my_player_character:
		_move_player(delta)
		return
	
	_move_player(delta)

func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

func _move_player(delta: float) -> void:
	if elapsed_time < (SERVER_TICK / player_speed):
		elapsed_time += delta
		var t : float = elapsed_time / (SERVER_TICK / player_speed)
		var new_position: Vector3 = current_position.lerp(target_position, t)
		position = new_position
	else:
		position = target_position
		#position = Utils.map_to_local(grid_position)

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

func update_destination(path: Array) -> void:
	player_path = path
	# Overwrite our server grid position with the data from the server
	server_grid_position = player_path.front()
	
	# TO FIX, this should be interpolated
	# Get the first position in our path as our current_position
	current_position = Utils.map_to_local(server_grid_position)
	
	# If we have a path to traverse (two cells or more)
	if player_path.size() > 1:
		# Get the next position in our path as our target_position
		target_position = Utils.map_to_local(player_path[1])
		elapsed_time = 0
	
	# If we don't have a path, our current_position will be our target_position
	else:
		target_position = current_position
