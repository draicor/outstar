extends CharacterBody3D

# Preloading scripts
const packets := preload("res://packets.gd")
const Player := preload("res://objects/character/player/player.gd")
const Pathfinding = preload("res://classes/pathfinding/pathfinding.gd")

# Preloading scenes
const player_scene := preload("res://objects/character/player/player.tscn")
# Character model selector
var character_scenes: Dictionary = {
	"female": preload("res://objects/characters/female_bot.tscn"),
	"male": preload("res://objects/characters/male_bot.tscn"),
}

# EXPORTED VARIABLES
@export var ROTATION_SPEED: float = 6.0
@export var RAYCAST_DISTANCE: float = 20 # 20 meters

# CONSTANTS
const SERVER_TICK: float = 0.5 # Controls local player move speed
const DIRECTION_THRESHOLD := 0.01 # Accounts for floating point imprecision

# Tick related data
var movement_tick: float = SERVER_TICK # Defaults to server_tick

# Spawn data
var player_id: int
var player_name: String
var gender: String = "female" # CAUTION gender should be set from the server
var tooltip: String = "" # Set on spawn from server packet
var model_rotation_y: float
var server_grid_position: Vector2i # Used to spawn the character and also to correct the player's position
var my_player_character: bool # Used to differentiate my character from remote players

# Internal data
var grid_position: Vector2i # Keeps track of our grid position locally
var grid_destination: Vector2i # Used in _raycast(), to tell the server where we want to move
var immediate_grid_destination: Vector2i # Used in case we want to change route in transit

var server_path: Array[Vector2i] # Set at spawn and after server movement
var next_tick_server_path: Array[Vector2i] # Used to store the next server path

var player_speed: int = 2 # Defaults to JOG at spawn
var cells_to_move_this_tick: int

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
var predicted_path: Array[Vector2i] = [] # Holds our most recent predicted_path
var next_tick_predicted_path: Array[Vector2i] = [] # Used to store our next tick predicted path
var unconfirmed_path: Array[Vector2i] = [] # Holds every vector2i coordinate the player has moved to locally

# Logic variables
var in_motion: bool = false # If the character is moving
var autopilot_active: bool = false # If the server is forcing the player to move
var is_typing: bool = false # To display a bubble when typing

# Animation state machine
var animation_library: String = "%s/%s_" % [gender, gender]
var current_animation: ASM = ASM.IDLE
enum ASM {
	IDLE,
	WALK,
	JOG,
	RUN,
}
# Character locomotion
var locomotion: Dictionary # This is set depending on the gender of this character
var female_locomotion: Dictionary = {
	0: {state = ASM.IDLE, animation = "female/female_idle", play_rate = 1.0},
	1: {state = ASM.WALK, animation = "female/female_walk", play_rate = 0.95},
	2: {state = ASM.JOG, animation = "female/female_run", play_rate = 0.70},
	3: {state = ASM.RUN, animation = "female/female_run", play_rate = 0.8}
}
var male_locomotion := {
	0: {state = ASM.IDLE, animation = "male/male_idle", play_rate = 1.0},
	1: {state = ASM.WALK, animation = "male/male_walk", play_rate = 1.1},
	2: {state = ASM.JOG, animation = "male/male_run", play_rate = 0.75},
	3: {state = ASM.RUN, animation = "male/male_run", play_rate = 0.9}
}

# Camera variables
var camera : PlayerCamera
var raycast : RayCast3D

# Character variables
var current_character: Node = null

# Scene tree nodes
@onready var animation_player: AnimationPlayer # Assigned by code later
@onready var model: Node3D = $Model # Used to attach the model and rotate it
@onready var camera_rig: Node3D = $CameraPivot/CameraRig # Used to attach the camera
@onready var chat_bubble: Node3D = $ChatBubbleOrigin/ChatBubble # Where chat bubbles spawn


static func instantiate(
	id: int,
	nickname: String,
	spawn_position: Vector2i,
	spawn_model_rotation_y: float, # Used to update our model.rotation.y
	is_my_player_character: bool
) -> Player:
	# Instantiate a new empty player character
	var player := player_scene.instantiate()
	# Load the data from the function parameters into a new player character
	player.player_id = id
	player.player_name = nickname
	player.tooltip = nickname
	player.model_rotation_y = spawn_model_rotation_y
	player.my_player_character = is_my_player_character
	
	# Overwrite our local copy of the grid positions
	player.server_grid_position = spawn_position
	player.grid_position = player.server_grid_position
	player.grid_destination = player.server_grid_position
	player.immediate_grid_destination = player.server_grid_position
	
	# Overwrite our local copy of the space positions
	player.interpolated_position = Utils.map_to_local(player.server_grid_position)
	
	return player


func _ready() -> void:
	load_character(gender) # CAUTION this shouldn't be gender
	if gender == "male":
		locomotion = male_locomotion
	else:
		locomotion = female_locomotion
	
	# Fetch our animation player AFTER we loaded our character
	animation_player = find_child("AnimationPlayer", true, false)
	_setup_animation_blend_time()
	
	position = interpolated_position # Has to be set here after the scene has been created
	
	# Update any other spawn data here
	model.rotation.y = model_rotation_y
	# Convert our model's y-rotation (radians) to a forward direction vector
	forward_direction = Vector3(-sin(model_rotation_y), 0, -cos(model_rotation_y))
	previous_forward_direction = forward_direction # At spawn, we make them equal
	
	# Update our player's movement tick at spawn
	update_player_speed(player_speed)
	
	# Make our character spawn idling
	_change_animation(animation_library+"idle", 1.0)
	
	# Register this character as an interactable object
	TooltipManager.register_interactable(self)
	
	# Do this only for our player's character
	if my_player_character:
		# Connect the signals ONLY for our player character!
		Signals.ui_chat_input_toggle.connect(_handle_signal_ui_chat_input_toggle)
		Signals.ui_change_move_speed_button.connect(_handle_signal_ui_update_speed_button)
	
		# Add our player camera to our camera rig
		camera = PlayerCamera.new()
		camera_rig.add_child(camera)
		# Add a raycast 3d node to our camera
		raycast = RayCast3D.new()
		raycast.collision_mask = 3 # Mask 1+2
		raycast.add_exception(self) # Ignore my own Player
		
		camera.add_child(raycast)
		
		# Stores our player character as a global variable
		GameManager.set_player_character(self)
		# Stores our player camera as a global variable too
		TooltipManager.set_player_camera(camera)


# Helper function to properly setup animation blend times
func _setup_animation_blend_time() -> void:
	if not animation_player:
		push_error("AnimationPlayer not set")
		return
	
	match animation_library:
		# Blend female locomotion animations
		"female/female_":
			animation_player.set_blend_time("female/female_idle", "female/female_walk", 0.2)
			animation_player.set_blend_time("female/female_idle", "female/female_run", 0.1)
			animation_player.set_blend_time("female/female_walk", "female/female_idle", 0.15)
			animation_player.set_blend_time("female/female_walk", "female/female_run", 0.15)
			animation_player.set_blend_time("female/female_run", "female/female_idle", 0.15)
			animation_player.set_blend_time("female/female_run", "female/female_walk", 0.15)
		
		# Blend male locomotion animations
		"male/male_":
			animation_player.set_blend_time("male/male_idle", "male/male_walk", 0.2)
			animation_player.set_blend_time("male/male_idle", "male/male_run", 0.1)
			animation_player.set_blend_time("male/male_walk", "male/male_idle", 0.15)
			animation_player.set_blend_time("male/male_walk", "male/male_run", 0.15)
			animation_player.set_blend_time("male/male_run", "male/male_idle", 0.15)
			animation_player.set_blend_time("male/male_run", "male/male_walk", 0.15)


# Called when this object gets destroyed
func _exit_tree() -> void:
	TooltipManager.unregister_interactable(self)


# Toggles the bool that keeps track of the chat
func _handle_signal_ui_chat_input_toggle() -> void:
	is_typing = !is_typing


# Request the server to change the movement speed of my player
func _handle_signal_ui_update_speed_button(new_move_speed: int) -> void:
	var packet: packets.Packet
	packet = _create_update_speed_packet(new_move_speed)
	WebSocket.send(packet)


# CAUTION
# Move this to main.gd, all input should be there
# It should also check what we clicked to see if we attacked/moved/interacted, etc
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		var mouse_position : Vector2 = get_viewport().get_mouse_position()
		_click_to_move(mouse_position)


# Used to cast a ray from the camera view to the mouse position
func _mouse_raycast(mouse_position: Vector2) -> Vector3:
	var vector: Vector3 = Vector3.ZERO
	# If our client is being moved automatically or our raycast node is invalid
	if autopilot_active or not raycast:
		return vector
	
	# Cast a ray from our camera to our mouse position
	raycast.target_position = camera.project_local_ray_normal(mouse_position) * RAYCAST_DISTANCE
	# Updates the collision information for the ray immediately,
	# without waiting for the next _physics_process call
	raycast.force_raycast_update()
	
	# If we collided with something
	if raycast.is_colliding():
		# Grab the collision point
		return raycast.get_collision_point()
	
	return vector


# Casts a raycast from the mouse position to get our destination cell,
# and then attempts to predict a path towards that cell to move our character
func _click_to_move(mouse_position: Vector2) -> void:
	# If we are in autopilot, prevent mouse input
	if autopilot_active:
		return
	
	# Grab the collision point from our mouse click
	var local_point : Vector3 = _mouse_raycast(mouse_position)
	# If the point was invalid, exit
	if local_point == Vector3.ZERO:
		return
		
	# Transform the local space position to our grid coordinate
	var new_destination: Vector2i = Utils.local_to_map(local_point)
	
	# If the new destination is not walkable, abort
	if not RegionManager.is_cell_reachable(new_destination):
		return
	
	# CAUTION extend this code to interact differently with objects and players, etc
	# If the new destination is already occupied, abort
	if not RegionManager.is_cell_available(new_destination):
		return
	
	# If we are not moving
	if not in_motion:
		# Generate and store a path prediction towards the destination we want to reach
		var prediction = _predict_path(grid_position, new_destination)
		# If the prediction is valid
		# Make this prediction our current path and start moving right away
		if prediction.size() > 1:
			# Because we were idling, we need to get 1 more cell for this tick
			predicted_path = Utils.pop_multiple_front(prediction, player_speed+1)
			# Get our immediate grid destination (this tick)
			immediate_grid_destination = predicted_path.back()
			# Remove the first cell from the predicted_path because we are already there
			predicted_path = predicted_path.slice(1)
			# We add to our local unconfirmed path the next steps we'll take
			unconfirmed_path.append(immediate_grid_destination)
			
			# Store the remaining prediction (if any) for next tick
			next_tick_predicted_path = prediction
			# Prepare everything to move correctly this tick
			cells_to_move_this_tick = predicted_path.size()
			_setup_next_movement_step(predicted_path, true)
			_switch_locomotion(cells_to_move_this_tick)
			
			is_predicting = true
			# Overwrite our new grid destination
			grid_destination = new_destination
			
			# NOTE: We need to send the packet here ONCE, when movement starts only!
			# Create a new packet to hold our input and send it to the server
			var packet := _create_player_destination_packet(immediate_grid_destination)
			WebSocket.send(packet)
			
	# If we were already moving
	else:
		# Generate and store another path prediction towards the destination we want to reach,
		# using our immediate grid destination as our starting point
		var prediction = _predict_path(immediate_grid_destination, new_destination)
		
		# If the predicted path is valid
		if prediction.size() > 0:
			# Overwrite the next tick predicted path, removing the first cell since its repeated 
			next_tick_predicted_path = prediction.slice(1)
			
			# Overwrite our new grid destination
			grid_destination = new_destination


# Predicts a path from a grid position to another grid position using A*
func _predict_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return Pathfinding.find_path(from, to, RegionManager.grid_width, RegionManager.grid_height, self)


# Creates and returns a player_destination_packet
func _create_player_destination_packet(grid_pos: Vector2i) -> packets.Packet:
	var packet := packets.Packet.new()
	var player_destination_packet := packet.new_player_destination()
	player_destination_packet.set_x(grid_pos.x)
	player_destination_packet.set_z(grid_pos.y)
	return packet


# Creates and returns an update_speed packet
func _create_update_speed_packet(new_speed: int) -> packets.Packet:
	var packet := packets.Packet.new()
	var update_speed_packet := packet.new_update_speed()
	update_speed_packet.set_speed(new_speed)
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
	
	if my_player_character:
		if OS.is_debug_build():  # Only draw in editor/debug builds
			DebugDraw3D.draw_line(position, position + forward_direction * 1, Color.RED) # 1 meter forward line
			_draw_circle(Utils.map_to_local(grid_destination), 0.5, Color.RED, 16) # Grid destination
			_draw_circle(Utils.map_to_local(immediate_grid_destination), 0.4, Color.YELLOW, 16) # Immediate grid destination
			_draw_circle(Utils.map_to_local(grid_position), 0.3, Color.GREEN, 16) # Grid position
			_draw_circle(Utils.map_to_local(server_grid_position), 0.6, Color.REBECCA_PURPLE, 16) # Server position for my character


# Called on tick from the _process function
func _update_player_movement(delta: float) -> void:
	# If we haven't completed the step, keep sliding until we do
	if movement_elapsed_time < movement_tick:
		move_and_slide_player(delta)
		return
	
	# Update this player's local position after each completed step
	interpolated_position = next_cell
	grid_position = Utils.local_to_map(interpolated_position)
	
	if my_player_character and is_predicting:
		_process_path_segment(delta, predicted_path, next_tick_predicted_path)
	else:
		_process_path_segment(delta, server_path, next_tick_server_path)


# Helper function to process the movement logic for both local and remote players
func _process_path_segment(delta: float, current_path: Array[Vector2i], next_path: Array[Vector2i]) -> void:
	# If our current path still has cells remaining
	if current_path.size() > 0:
		_setup_next_movement_step(current_path, true)
		move_and_slide_player(delta)
		_switch_locomotion(cells_to_move_this_tick)
	# If our current path has no more cells but our next path does
	elif next_path.size() > 0:
		# Get the first cells from our next tick path (based on our speed)
		current_path.append_array(Utils.pop_multiple_front(next_path, player_speed))
		# Update our immediate grid destination
		immediate_grid_destination = current_path.back()
		
		# Update speed only once per path segment
		cells_to_move_this_tick = current_path.size()
		_setup_next_movement_step(current_path, true)
		move_and_slide_player(delta)
		_switch_locomotion(cells_to_move_this_tick)
		
		if my_player_character:
			unconfirmed_path.append(immediate_grid_destination)
			
			# Only send a packet if we are not correcting our position
			if not autopilot_active:
				# Create a new packet to report our new immediate destination to the server
				var packet := _create_player_destination_packet(immediate_grid_destination)
				WebSocket.send(packet)
		
	else:
		_complete_movement()


# Snap the player's position to the grid after movement ends,
# so its always exactly at the center of the cell in the grid,
# stops movement and switches the character back to idle animation
func _complete_movement() -> void:
	interpolated_position = next_cell
	position = next_cell
	in_motion = false
	_switch_locomotion(ASM.IDLE)
	
	if autopilot_active:
		# If we are at the same position as in the server
		if grid_position == server_grid_position and immediate_grid_destination == server_grid_position or grid_position == grid_destination:
			autopilot_active = false
			grid_destination = grid_position
		else:
			# If our position is not synced, predict a path from our current grid position to the server position,
			# and store it to be used next tick
			next_tick_predicted_path = _predict_path(grid_position, server_grid_position)
			# If our prediction is valid
			if next_tick_predicted_path.size() > 0:
				# Get the first cells from our next tick path (based on our speed)
				predicted_path.append_array(Utils.pop_multiple_front(next_tick_predicted_path, player_speed+1))
				# Update our immediate grid destination
				immediate_grid_destination = predicted_path.back()
				
				unconfirmed_path.append(immediate_grid_destination)
				
				# Update only once per path segment
				cells_to_move_this_tick = predicted_path.size()-1
				_setup_next_movement_step(predicted_path, false)
			else:
				# To prevent an input lock, we turn off autopilot if we get here
				autopilot_active = false
				# Reset our destinations
				grid_destination = grid_position
				immediate_grid_destination = grid_position


# Used to switch the current animation state
func _switch_locomotion(steps: int) -> void:
	var settings = locomotion.get(steps, locomotion[ASM.IDLE]) # Defaults to IDLE
	_change_animation(settings.animation, settings.play_rate)
	current_animation = settings.state
	
	# Only emit this signal for my own character
	if my_player_character:
		Signals.player_locomotion_changed.emit()

# Called on tick by _update_player_movement to interpolate the position of the player
func move_and_slide_player(delta: float) -> void:
	# We use delta time to advance our player's movement
	movement_elapsed_time += delta
	# How far we've moved towards our target based on server_tick / player_speed
	var t: float = movement_elapsed_time / movement_tick
	# Interpolate our position based on the previous values
	position = interpolated_position.lerp(next_cell, t)


# Updates the player's position
func update_destination(new_server_position: Vector2i) -> void:
	# Only do the reconciliation for my player, not the other players
	if my_player_character and is_predicting:
		_handle_server_reconciliation(new_server_position)
	# Remote players are always in sync
	else:
		_handle_remote_player_movement(new_server_position)
	
	# Update our server grid position locally
	server_grid_position = new_server_position


# Called when we receive a new position packet to move remote players (always in sync)
func _handle_remote_player_movement(new_server_position: Vector2i) -> void:
	var next_path: Array[Vector2i] = _predict_path(server_grid_position, new_server_position)
	# If our next path is valid
	if next_path.size() > 1:
		if in_motion:
			# Append the next path to our next tick server path, removing the overlap
			next_tick_server_path.append_array(next_path.slice(1))
		
		# If we are idling
		else:
			# We make the new path our current path
			server_path = next_path
			# Update our new path (remove overlap)
			cells_to_move_this_tick = server_path.size()-1
			_setup_next_movement_step(server_path, true) # This starts movement


# Called when we receive a new position packet from the server to make sure we are synced locally
func _handle_server_reconciliation(new_server_position: Vector2i) -> void:
	if _prediction_was_valid(unconfirmed_path.duplicate(), new_server_position):
		if new_server_position == grid_destination:
			unconfirmed_path = []
			return
		else:
			return
	else: # If our prediction was invalid
		# Calculate correction from our grid_destination to the last valid server position!
		var correction_path: Array[Vector2i] = _predict_path(grid_destination, new_server_position)
		if correction_path.size() > 0:
			_apply_path_correction(correction_path)


# Used to reconcile movement with the server
func _apply_path_correction(new_path: Array[Vector2i]) -> void:
	if not autopilot_active:
		# If our character is idle
		if not in_motion:
			# Overwrite our next tick path with the correction path
			next_tick_predicted_path = new_path
			# Prepare everything to move correctly next tick
			cells_to_move_this_tick = next_tick_predicted_path.size()-1
			_setup_next_movement_step(next_tick_predicted_path, false)
		else:
			# If we were already moving just append the correction path
			# while removing the overlapping cell
			next_tick_predicted_path.append_array(new_path.slice(1))
		
		# Turn on autopilot either way so the player can't keep sending packets
		autopilot_active = true


# Determines if the last valid server position is anywhere in my local traversed path
func _prediction_was_valid(client_path: Array[Vector2i], last_valid_position: Vector2i) -> bool:
	# Look for the index of the element
	if client_path.find(last_valid_position) == -1:
		return false
	else:
		return true


# Prepare the variables before starting a new move
func _setup_next_movement_step(path: Array[Vector2i], should_rotate: bool) -> void:
	# Get the next cell from this path to make it our next move target
	next_cell = Utils.map_to_local(path.pop_front())
	
	# CAUTION rotation should happen AFTER updating next_cell
	if should_rotate:
		# Rotate our character towards the next cell
		_calculate_rotation(next_cell)
	
	_calculate_step_duration(grid_position, Utils.local_to_map(next_cell))
		
	# Reset our move variable in _process
	movement_elapsed_time = 0
	# Specify our character is moving
	in_motion = true


func _calculate_path_overlap(current_path: Array[Vector2i], new_path: Array[Vector2i]) -> int:
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
		rotation_elapsed = min(rotation_elapsed + ROTATION_SPEED * delta, 1.0)
		model.rotation.y = lerp_angle(start_yaw, target_yaw, rotation_elapsed)
		
		# Check if rotation is complete after rotating
		if rotation_elapsed >= 1.0:
			is_rotating = false


# Changes the current animation and its play_rate as well
func _change_animation(animation: String, play_rate: float) -> void:
	animation_player.play(animation)
	animation_player.speed_scale = play_rate


# Used to update the text inside our chat bubble
func new_chat_bubble(message: String) -> void:
	chat_bubble.set_text(message)


# Should be called once per path slice to recalculate the move speed
func update_player_speed(new_speed: int) -> void:
	# Clamp speed to 1-3 range
	player_speed = clamp(new_speed, 1, 3)


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
func _calculate_step_duration(current: Vector2i, next: Vector2i) -> void:
	if _is_step_diagonal(current, next):
		update_movement_tick(true)
	else:
		update_movement_tick(false)


# Used to draw a circle for debugging purposes
func _draw_circle(center: Vector3, radius: float, color: Color, resolution: int = 16):
	var points = PackedVector3Array()
	
	#Generate points around the circle
	for i in range(resolution + 1): # +1 to close the loop
		var angle = i * (TAU/resolution) # TAU = 2*PI
		var x = center.x + cos(angle) * radius
		var z = center.z + sin(angle) * radius
		points.append(Vector3(x, center.y, z))
	
	# Draw lines between each point
	for i in range(points.size() - 1):
		DebugDraw3D.draw_line(points[i], points[i + 1], color)


# Used to load a character model and append it as a child of our model node
func load_character(character_type: String) -> void:
	# Remove existing character if any
	if current_character:
		current_character.queue_free()
	
	# Load and instantiate the new character
	if character_scenes.has(character_type):
		var character_scene = character_scenes[character_type]
		current_character = character_scene.instantiate()
		model.add_child(current_character)
	else:
		print("Character type %s not found" % [character_type])
