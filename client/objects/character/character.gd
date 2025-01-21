extends CharacterBody3D

@onready var animation_player: AnimationPlayer = $Model/Body/AnimationPlayer
@onready var model: Node3D = $Model
@onready var camera_origin: Node3D = $CameraOrigin

const SPEED = 3.0
var walking = false
var chatting = false

func _ready() -> void:
	# Blend animations
	animation_player.set_blend_time("idle", "walk", 0.1)
	animation_player.set_blend_time("walk", "idle", 0.2)
	
	# Connect the signals
	Signals.ui_chat_input_toggle.connect(_on_chat_input_toggle)
	
	# FIX:
	# Do this only for the player's character
	# Stores our player character as a global variable
	GameManager.set_player_character(self)

# Toggles the bool that keeps track of the chat
func _on_chat_input_toggle() -> void:
	chatting = !chatting

func _physics_process(delta: float) -> void:
	var input_dir: Vector2
	
	# Apply gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if not chatting:
		# Get the input direction and handle the movement/deceleration.
		input_dir = Input.get_vector("turn_left", "turn_right", "forward", "backward")
	
	# Calculate the character's direction
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# If we are trying to move
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# Make our model look at the direction he is moving towards
		model.look_at(direction + position)
		
		# Update the character's state machine
		if not walking:
			walking = true
			# Only start playing the animation when the state changes
			animation_player.play("walk")
	
	# If we are not trying to move, stop
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
		# Update the character's state machine
		if walking:
			walking = false
			# Only start playing the animation when the state changes
			animation_player.play("idle")
	
	# Calculate physics
	move_and_slide()
