extends CharacterBody3D

const packets := preload("res://packets.gd")
const character_scene := preload("res://objects/character/character.tscn")
const Character := preload("res://objects/character/character.gd")

# Spawn data
var character_id: int
var character_name: String
var x: float
var y: float
var z: float
var model_rotation_y: float
var direction_x: float
var direction_z: float
var speed: float
var my_player_character: bool
# Internal data
var walking = false
var chatting = false
var last_input_direction: Vector2

@onready var animation_player: AnimationPlayer = $Model/Body/AnimationPlayer
@onready var model: Node3D = $Model
@onready var camera_rig: Node3D = $CameraRig

static func instantiate(
	id: int,
	nickname: String,
	spawn_x: float,
	spawn_y: float,
	spawn_z: float,
	spawn_model_rotation_y: float, # Used to update our model.rotation.y
	spawn_direction_x: float,
	spawn_direction_z: float,
	spawn_speed: float,
	is_my_player_character: bool
) -> Character:
	# Instantiate a new empty character
	var character := character_scene.instantiate()
	# Load the data from the function parameters into our new character
	character.character_id = id
	character.character_name = nickname
	character.x = spawn_x
	character.y = spawn_y
	character.z = spawn_z
	character.model_rotation_y = spawn_model_rotation_y
	character.direction_x = spawn_direction_x
	character.direction_z = spawn_direction_z
	character.speed = spawn_speed
	character.my_player_character = is_my_player_character

	return character

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
	
	# Do this only for the player's character
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
		# Calculate the character's direction (ignore Y axis)
		var character_direction := (transform.basis * Vector3(direction_x, 0, direction_z)).normalized()
		_move_character(character_direction)
		return
	
	# If this is MY player character
	var input_dir: Vector2
	# Prevent WASD movement if we are trying to type in the chat
	if not chatting:
		# Get the input direction and handle the movement/deceleration.
		input_dir = Input.get_vector("turn_left", "turn_right", "forward", "backward")
	
	# Calculate the character's direction from our input (ignore Y axis)
	# Note: Input.get_vector is a Vector2D, so there is only X and Y here, but
	# we are taking it as X and Z, since Y is vertical in 3D
	# that's why we use input_dir.y, but its in the Z axis in the Vector3(x, y, z)
	var character_direction_from_input := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	_move_character(character_direction_from_input)
	
	# If our input changed, tell the server
	# We create a new packet to hold our input direction
	var packet := packets.Packet.new()
	var character_direction_packet := packet.new_character_direction()
	# We store input as separate values since Golang doesn't handle Vector3
	character_direction_packet.set_direction_x(character_direction_from_input.x)
	# We ignore the Y axis
	character_direction_packet.set_direction_z(character_direction_from_input.z)
	# Send our input direction to the server
	WebSocket.send(packet)

# Utility function to apply physics to our character and rotate our model
func _move_character(direction: Vector3) -> void:
	# If we are trying to move
	if direction:
		velocity.x = direction.x * speed # left/right
		velocity.z = direction.z * speed # forward/backward
		
		# Make our model look at the direction he is moving towards
		model.look_at(direction + position)
		# model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
		
		# Update the character's state machine
		if not walking:
			walking = true
			# Only start playing the animation when the state changes
			animation_player.play("walk")
	
	# If we are not trying to move, stop
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		# Update the character's state machine
		if walking:
			walking = false
			# Only start playing the animation when the state changes
			animation_player.play("idle")
	
	# Calculate physics
	move_and_slide()
