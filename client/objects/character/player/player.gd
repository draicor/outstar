extends CharacterBody3D

const packets := preload("res://packets.gd")
const player_scene := preload("res://objects/character/player/player.tscn")
const Player := preload("res://objects/character/player/player.gd")

# Spawn data
var player_id: int
var player_name: String
var model_rotation_y: float
var server_grid_position: Vector2i
var my_player_character: bool
# Internal data
# We store our current grid_position and our grid_destination_position
var grid_position: Vector2i
var grid_destination: Vector2i
# Position is our current point in space but thats built-in Godot
# Destination is our destination point in space
var destination: Vector3
var walking = false
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
	spawn_model_rotation_y: float, # Used to update our model.rotation.y
	spawn_x: int,
	spawn_z: int,
	is_my_player_character: bool
) -> Player:
	# Instantiate a new empty player character
	var player := player_scene.instantiate()
	# Load the data from the function parameters into a new player character
	player.player_id = id
	player.player_name = nickname
	player.model_rotation_y = spawn_model_rotation_y
	player.server_grid_position.x = spawn_x
	player.server_grid_position.y = spawn_z
	player.my_player_character = is_my_player_character

	return player

func _ready() -> void:
	# Blend animations
	animation_player.set_blend_time("idle", "walk", 0.2)
	animation_player.set_blend_time("walk", "idle", 0.2)
	
	# Connect the signals
	Signals.ui_chat_input_toggle.connect(_on_chat_input_toggle)
	
	# Update our position with the data from the server
	position = Utils.map_to_local(server_grid_position)

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

func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# TO FIX -> This should only be called if there is a certain distance
	# between the client's position and the client's position in the server
	_sync_player()
	
	# If this is not my player character, move it with the data I got from the server
	if not my_player_character:
		_move_player()
		return
	
	_move_player()

func _move_player() -> void:
	position = Utils.map_to_local(grid_position)

# Overwrite our client's grid position locally with the one from the server
func _sync_player() -> void:
	grid_position = server_grid_position

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
