extends CharacterBody3D

const packets := preload("res://packets.gd")
const player_scene := preload("res://objects/character/player/player.tscn")
const Player := preload("res://objects/character/player/player.gd")

# Spawn data
var player_id: int
var player_name: String
var x: float
var y: float
var z: float
var model_rotation_y: float
var velocity_x: float
var velocity_y: float # Not used for now, maybe some abilities will use this
var velocity_z: float
var speed: float
var my_player_character: bool
# Internal data
var walking = false
var chatting = false
var last_input_direction: Vector2

@onready var animation_player: AnimationPlayer = $Model/Body/AnimationPlayer
@onready var model: Node3D = $Model
@onready var camera_rig: Node3D = $CameraRig
@onready var chat_bubble: Node3D = $ChatBubbleOrigin/ChatBubble

static func instantiate(
	id: int,
	nickname: String,
	spawn_x: float,
	spawn_y: float,
	spawn_z: float,
	spawn_model_rotation_y: float, # Used to update our model.rotation.y
	spawn_velocity_x: float,
	spawn_velocity_y: float,
	spawn_velocity_z: float,
	spawn_speed: float,
	is_my_player_character: bool
) -> Player:
	# Instantiate a new empty player character
	var player := player_scene.instantiate()
	# Load the data from the function parameters into a new player character
	player.player_id = id
	player.player_name = nickname
	player.x = spawn_x
	player.y = spawn_y
	player.z = spawn_z
	player.model_rotation_y = spawn_model_rotation_y
	player.velocity_x = spawn_velocity_x
	player.velocity_y = spawn_velocity_y
	player.velocity_z = spawn_velocity_z
	player.speed = spawn_speed
	player.my_player_character = is_my_player_character

	return player

func _ready() -> void:
	# Blend animations
	animation_player.set_blend_time("idle", "walk", 0.1)
	animation_player.set_blend_time("walk", "idle", 0.2)
	
	# Connect the signals
	Signals.ui_chat_input_toggle.connect(_on_chat_input_toggle)
	
	# Update the spawn data
	position.x = x
	position.y = y
	position.z = z
	model.rotation.y = model_rotation_y
	# Update any other spawn data here
	
	# Do this only for our player's character
	if my_player_character:
		# Add a camera to our character
		var camera := Camera3D.new()
		camera_rig.add_child(camera)
		
		# Stores our player character as a global variable
		GameManager.set_player_character(self)

# Toggles the bool that keeps track of the chat
func _on_chat_input_toggle() -> void:
	chatting = !chatting

func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# If this is not my player character, move it with the data I got from the server
	if not my_player_character:
		# Calculate the character's direction (Ignore Y axis)
		var player_direction := (transform.basis * Vector3(velocity_x, 0, velocity_z)).normalized()
		# We calculate the velocity from the character's direction
		_move_player(_calculate_velocity(player_direction))
		_animate_character(player_direction)
		return
	
	# If this is MY player character
	var input_direction: Vector2
	# Prevent WASD movement if we are trying to type in the chat
	if not chatting:
		# Get the input direction and handle the movement/deceleration.
		input_direction = Input.get_vector("turn_left", "turn_right", "forward", "backward")
	
	# Calculate the character's direction from our input (ignores Y axis)
	# Note: Input.get_vector is a Vector2D, so there is only X and Y here, but
	# we are taking it as X and Z, since Y is vertical in 3D
	# that's why we use input_direction.y, but its in the Z axis in the Vector3(x, y, z)
	var character_direction_from_input := (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	_move_player(_calculate_velocity(character_direction_from_input))
	_animate_character(character_direction_from_input)
	
	# If our input changed, tell the server
	# Create a new packet to hold our input velocity
	var packet := packets.Packet.new()
	var player_velocity_packet := packet.new_player_velocity()
	# We pass the velocity vector to the server to keep both in sync
	player_velocity_packet.set_velocity_x(velocity.x)
	player_velocity_packet.set_velocity_y(velocity.y)
	player_velocity_packet.set_velocity_z(velocity.z)
		
	# Send our input direction to the server
	WebSocket.send(packet)

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

# Predicts the velocity based on the input
func _calculate_velocity(direction: Vector3) -> Vector3:
	var new_velocity : Vector3
	# If we are trying to move
	if direction:
		new_velocity.x = direction.x * speed # left/right
		new_velocity.z = direction.z * speed # forward/backward
	# If we are not trying to move, stop
	else:
		new_velocity.x = move_toward(velocity.x, 0, speed)
		new_velocity.z = move_toward(velocity.z, 0, speed)
	
	# Assign the same Y velocity our character had
	new_velocity.y = velocity.y
	return new_velocity

# Apply physics and moves the player
func _move_player(new_velocity: Vector3) -> void:
	velocity.x = new_velocity.x
	velocity.y = new_velocity.y
	velocity.z = new_velocity.z
	
	# Apply physics with the new velocity
	move_and_slide()

# Used to update the text inside our chat bubble!
func new_chat_bubble(message: String) -> void:
	chat_bubble.set_text(message)
