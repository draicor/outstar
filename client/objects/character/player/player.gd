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
@export var CHAT_BUBBLE_OFFSET: Vector3 = Vector3(0, 0.4, 0)

# CONSTANTS
const SERVER_TICK: float = 0.5 # Controls local player move speed
const DIRECTION_THRESHOLD := 0.01 # Accounts for floating point imprecision

# Tick related data
var movement_tick: float = SERVER_TICK # Defaults to server_tick

# Spawn data
var player_id: int
var player_name: String
var gender: String
var player_speed: int
var tooltip: String
var model_rotation_y: float
var server_grid_position: Vector2i # Used to spawn the character and also to correct the player's position
var my_player_character: bool # Used to differentiate my character from remote players

# Internal data
var grid_position: Vector2i # Keeps track of our grid position locally
var grid_destination: Vector2i # Used in _raycast(), to tell the server where we want to move
var immediate_grid_destination: Vector2i # Used in case we want to change route in transit

var server_path: Array[Vector2i] # Set at spawn and after server movement
var next_tick_server_path: Array[Vector2i] # Used to store the next server path

var cells_to_move_this_tick: int

var interpolated_position: Vector3 # Used to smoothly slide our character in our game client
var movement_elapsed_time: float = 0.0 # Used in _process to slide the character
var next_cell: Vector3 # Used in _process, its the next cell our player should move to

# Rotation state
var forward_direction: Vector3 # Used to keep track of our current forward direction
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
var is_busy: bool = false # Blocks input during interactions

# Interaction system
var interaction_target: Interactable = null # The object we are trying to interact with
var pending_interaction: Interactable = null

# Animation state machine
var animation_library: String

# Character locomotion
var locomotion: Dictionary # This is set depending on the gender of this character
var female_locomotion: Dictionary = {
	"idle": {animation = "female/female_idle", play_rate = 1.0},
	"walk": {animation = "female/female_walk", play_rate = 0.95},
	"jog": {animation = "female/female_run", play_rate = 0.70},
	"run": {animation = "female/female_run", play_rate = 0.8}
}
var male_locomotion := {
	"idle": {animation = "male/male_idle", play_rate = 1.0},
	"walk": {animation = "male/male_walk", play_rate = 1.1},
	"jog": {animation = "male/male_run", play_rate = 0.75},
	"run": {animation = "male/male_run", play_rate = 0.9}
}

# Camera variables
var camera : PlayerCamera
var raycast : RayCast3D

# Character variables
var current_character: Node = null
var chat_bubble_icon: Sprite3D

# Scene tree nodes
@onready var animation_player: AnimationPlayer # Assigned by code later
@onready var model: Node3D = $Model # Used to attach the model and rotate it
@onready var camera_rig: Node3D = $CameraPivot/CameraRig # Used to attach the camera
@onready var chat_bubble_manager: Node3D = $ChatBubbleOrigin/ChatBubbleManager # Where chat bubbles spawn
@onready var player_state_machine: PlayerStateMachine = $PlayerStateMachine


static func instantiate(
	id: int,
	nickname: String,
	character_gender: String,
	character_speed: int,
	spawn_position: Vector2i,
	spawn_model_rotation_y: float, # Used to update our model.rotation.y
	is_my_player_character: bool
) -> Player:
	# Instantiate a new empty player character
	var player := player_scene.instantiate()
	# Load the data from the function parameters into a new player character
	player.player_id = id
	player.player_name = nickname
	player.gender = character_gender
	player.player_speed = character_speed
	player.animation_library = "%s/%s_" % [character_gender, character_gender]
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


# Called once this character has been created and instantiated
func _ready() -> void:
	_initialize_character()
	_setup_animations() # After _initialize_character()
	_setup_data_at_spawn()
	
	# Initialize state machine
	player_state_machine.set_active(true)
	
	# Do this only for my local character
	if my_player_character:
		_connect_signals()
		_setup_local_player_components()
		_register_global_references() # After _setup_local_player_components()	


# _physics_process runs at a fixed timestep
# Movement should be handled here because this runs before _process
#func _physics_process(delta: float) -> void:
#	_handle_rotation(delta)
#	_handle_movement(delta)
#	_show_debug_tools()


# Rotates our character on tick
func _handle_rotation(delta: float) -> void:
	if is_rotating:
		rotation_elapsed = min(rotation_elapsed + ROTATION_SPEED * delta, 1.0)
		model.rotation.y = lerp_angle(start_yaw, target_yaw, rotation_elapsed)
		
		# Check if rotation is complete after rotating
		# CAUTION this is not recalculating our current rotation, should fix this!
		if rotation_elapsed >= 1.0:
			is_rotating = false


# Moves our character on tick
func _handle_movement(delta: float) -> void:
	if in_motion:
		_process_movement_step(delta)


# Helper function for _ready()
func _initialize_character() -> void:
	var character = load_character(gender) # CAUTION this shouldn't be gender but model_name
	if not character:
		push_error("Failed to load character")
		return
		
	locomotion = male_locomotion if gender == "male" else female_locomotion
	# Register this character as an interactable object
	TooltipManager.register_interactable(self)
	
	# Wait until next frame to ensure nodes are ready
	call_deferred("_setup_bone_attachments")


# Used to create the attachments in our character's skeleton
func _setup_bone_attachments() -> void:
	# Find the skeleton
	var skeleton = current_character.find_child("GeneralSkeleton") as Skeleton3D
	if not skeleton:
		push_error("skeleton3D node not found in character")
		return
	
	# Add bone attachments
	var head_attachment = BoneAttachment3D.new()
	head_attachment.bone_name = "Head"
	
	# Add attachment to our skeleton3D
	skeleton.add_child(head_attachment)
	
	_setup_chat_bubble_sprite()
	# Attach the chat bubble to my Head bone
	head_attachment.add_child(chat_bubble_icon)


# Setups our chat bubble variables and components on init
func _setup_chat_bubble_sprite() -> void:
	chat_bubble_icon = Sprite3D.new()
	chat_bubble_icon.texture = preload("res://assets/icons/chat_bubble.png")
	# Make sure billboarding maintains center
	chat_bubble_icon.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	chat_bubble_icon.double_sided = false
	chat_bubble_icon.scale = Vector3(0.6, 0.6, 0.6)
	chat_bubble_icon.position = CHAT_BUBBLE_OFFSET
	# Make sure the sprite centers properly
	chat_bubble_icon.centered = true
	chat_bubble_icon.offset = Vector2(0, 0)
	
	if my_player_character:
		# Hide/reveal the chat bubble icon based on our is_player_typing value
		toggle_chat_bubble_icon(GameManager.is_player_typing)
	else:
		# Start with the bubble hidden for everyone else
		chat_bubble_icon.visible = false


# Helper function for _ready()
func _setup_animations() -> void:
	animation_player = find_child("AnimationPlayer", true, false)
	_setup_animation_blend_time()


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


# Helper function for _ready()
func _setup_data_at_spawn() -> void:
	position = interpolated_position # Has to be set here after the scene has been created
	model.rotation.y = model_rotation_y
	# Convert our model's y-rotation (radians) to a forward direction vector
	forward_direction = Vector3(-sin(model_rotation_y), 0, -cos(model_rotation_y))
	# Update our player's movement tick at spawn
	update_player_speed(player_speed)


# Helper function for _ready()
# Only for our local player character!
func _connect_signals() -> void:
	Signals.ui_change_move_speed_button.connect(_handle_signal_ui_update_speed_button)


# Helper function for _ready()
func _setup_local_player_components() -> void:
	# Add our player camera to our camera rig
	camera = PlayerCamera.new()
	camera_rig.add_child(camera)
	
	# Setup Camera Raycast
	# Add a raycast 3d node to our camera
	raycast = RayCast3D.new()
	raycast.collision_mask = 3 # Mask 1+2
	raycast.add_exception(self) # Ignore my own Player character in my own Raycast
	camera.add_child(raycast)


# Helper function for _ready()
func _register_global_references() -> void:
	# Stores our player character as a global variable
	GameManager.set_player_character(self)
	# Stores our player camera as a global variable too
	TooltipManager.set_player_camera(camera)
	# Report to the rest of the code we successfully spawned
	Signals.player_character_spawned.emit()


# Called when this object gets destroyed
func _exit_tree() -> void:
	TooltipManager.unregister_interactable(self)


# Request the server to change the movement speed of my player
func _handle_signal_ui_update_speed_button(new_move_speed: int) -> void:
	var packet: packets.Packet
	packet = _create_update_speed_packet(new_move_speed)
	WebSocket.send(packet)


# Use _unhandled_input(), not _input(),
# _unhandled_input() only receives events that weren't processed by the UI
#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("left_click"):
		## If we are busy doing something, ignore input
		#if is_busy:
			#return
			#
		## If we are in autopilot, ignore mouse input
		#if autopilot_active:
			#return
		#
		## Get the mouse position and check what kind of target we have
		#var mouse_position : Vector2 = get_viewport().get_mouse_position()
		#var target := _get_mouse_click_target(mouse_position)
		#
		## If we have a valid target, we try to determine what kind of class it is
		#if target:
			#if target is Interactable:
				#_start_interaction(target)
		#
		## If we didn't click on anything interactable, then attempt to move to that cell
		#else:
			#_handle_movement_click(mouse_position)


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

# Casts a raycast from the mouse position to get our destination cell
func _handle_movement_click(mouse_position: Vector2) -> void:
	# Grab the collision point from our mouse click
	var local_point : Vector3 = _mouse_raycast(mouse_position)
	# If the point was invalid, exit
	if local_point == Vector3.ZERO: return
		
	# Transform the local space position to our grid coordinate
	var new_destination: Vector2i = Utils.local_to_map(local_point)
	
	_click_to_move(new_destination)


# Attempts to predict a path towards that cell to move our character
# if the cell is reachable and available
func _click_to_move(new_destination: Vector2i) -> void:
	if not _validate_move_position(new_destination):
		return
	
	# Clear any pending interactions
	interaction_target = null
	pending_interaction = null
	
	if in_motion:
		_update_existing_movement(new_destination)
	else:
		_start_new_movement(new_destination)
	
	player_state_machine.change_state("move")


# Predicts a path from a grid position to another grid position using A*
func _predict_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return Pathfinding.find_path(from, to, RegionManager.grid_width, RegionManager.grid_height, self)


# Detects and returns target after mouse click, if valid
func _get_mouse_click_target(mouse_position: Vector2) -> Object:
	# Check if our click collided with something
	var local_point: Vector3 = _mouse_raycast(mouse_position)
	if local_point == Vector3.ZERO: return null
	
	# Query for collisions
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		local_point,
		0b10 # Collision layer 2 for interactables
	)
	var result := space_state.intersect_ray(query)
	if result:
		# NOTE Add more base classes here to detect them too
		if result.collider is Interactable:
			return result.collider
	
	# If we didn't collide with anything, return null
	return null


# Traces a path to the interactable if not in range, and then calls the execute interaction
func _start_interaction(target: Interactable) -> void:
	# If clicked on our already clicked interaction, ignore
	if interaction_target == target or pending_interaction == target: return
	
	player_state_machine.change_state("interact")
	
	if in_motion:
		# If we were moving, see if we can reach our target, if we can,
		# _setup_interaction_movement updates our next_tick path towards it
		if _setup_interaction_movement(immediate_grid_destination, target):
			pending_interaction = target
		return
	
	# If our character was idle
	interaction_target = target
	# Check if we are already in range to activate
	if _is_in_interaction_range(target):
		_execute_interaction()
		return
	
	# If we are far away, check if we can reach it, if we can,
	# we will start to move towards it right away
	if _setup_interaction_movement(grid_position, target):
		interaction_target = target
	
	# If we can't reach it, then forget about it
	else:
		interaction_target = null


# Helper function to check if player is in interaction range
func _is_in_interaction_range(target: Interactable) -> bool:
	# Prevent interacting while moving towards immediate_grid_position
	if grid_position != immediate_grid_destination:
		return false
	
	# Check if we are at any valid position
	var target_position: Vector2i = Utils.local_to_map(target.global_position) 
	for relative_position in target.get_interaction_positions():
		if grid_position == target_position + relative_position:
			return true
	
	# Not in range to any of the valid interaction positions for this target
	return false


# Handles the interaction itself when in range
func _execute_interaction() -> void:
	if not interaction_target:
		is_busy = false
		return
	
	is_busy = true # Prevent input while busy
	
	# Stop moving and clear the paths first
	in_motion = false
	predicted_path = []
	next_tick_predicted_path = []
	
	# Face the interaction target
	var look_direction := (interaction_target.global_position - global_position).normalized()
	_rotate_towards_direction(look_direction)
	
	# Attempt to play the interaction animation
	var animation_name: String = interaction_target.get_interaction_animation()
	if animation_player.has_animation(animation_name):
		#_switch_locomotion(ASM.INTERACTING)
		animation_player.play(animation_name)
		# Wait until it finishes playing
		await animation_player.animation_finished
	
	# Perform the interaction itself
	interaction_target.interact(self)
	
	# Cleanup
	interaction_target = null
	_switch_locomotion("idle")
	#interaction_finished.emit() # Emit signal
	is_busy = false # Always release busy state at the end


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


# Creates and returns a join_region_request packet
func _create_join_region_request_packet(region_id: int) -> packets.Packet:
	var packet := packets.Packet.new()
	var join_region_request_packet := packet.new_join_region_request()
	join_region_request_packet.set_region_id(region_id)
	return packet


func _show_debug_tools() -> void:
	 # Only draw in editor/debug builds for my character
	if my_player_character and OS.is_debug_build():
		DebugDraw3D.draw_line(position, position + forward_direction * 1, Color.RED) # 1 meter forward line
		_draw_circle(Utils.map_to_local(grid_destination), 0.5, Color.RED, 16) # Grid destination
		_draw_circle(Utils.map_to_local(immediate_grid_destination), 0.4, Color.YELLOW, 16) # Immediate grid destination
		_draw_circle(Utils.map_to_local(grid_position), 0.3, Color.GREEN, 16) # Grid position
		_draw_circle(Utils.map_to_local(server_grid_position), 0.6, Color.REBECCA_PURPLE, 16) # Server position for my character


# Called on tick from the _process function
func _process_movement_step(delta: float) -> void:
	# If we haven't completed the step, keep sliding until we do
	if movement_elapsed_time < movement_tick:
		_interpolate_position(delta)
		return
	
	_update_grid_position()
	
	if my_player_character and is_predicting:
		_process_path_segment(delta, predicted_path, next_tick_predicted_path)
	else:
		_process_path_segment(delta, server_path, next_tick_server_path)


# Called on tick by _process_movement_step to interpolate the position of the player
func _interpolate_position(delta: float) -> void:
	# We use delta time to advance our player's movement
	movement_elapsed_time += delta
	# How far we've moved towards our target based on server_tick / player_speed
	var t: float = movement_elapsed_time / movement_tick
	# Interpolate our position based on the previous values
	position = interpolated_position.lerp(next_cell, t)


# Update this player's local position after each completed step
func _update_grid_position() -> void:
	interpolated_position = next_cell
	grid_position = Utils.local_to_map(interpolated_position)


# Helper function to process the movement logic for both local and remote players
func _process_path_segment(delta: float, current_path: Array[Vector2i], next_path: Array[Vector2i]) -> void:
	# If our current path still has cells remaining
	if current_path.size() > 0:
		_setup_movement_step(current_path)
		_interpolate_position(delta)
		#_switch_locomotion(cells_to_move_this_tick)
	# If our current path has no more cells but our next path does
	elif next_path.size() > 0:
		# Get the first cells from our next tick path (based on our speed)
		current_path.append_array(Utils.pop_multiple_front(next_path, player_speed))
		# Update our immediate grid destination
		immediate_grid_destination = current_path.back()
		
		# Update speed only once per path segment
		cells_to_move_this_tick = current_path.size()
		_setup_movement_step(current_path)
		_interpolate_position(delta)
		#_switch_locomotion(cells_to_move_this_tick)
		
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
	# Check for interactions first
	if interaction_target:
		if _is_in_interaction_range(interaction_target):
			player_state_machine.change_state("interact")
			return # Stop here to prevent movement reset
	
	#_finalize_movement()


# Movement cleanup and executes the post movement logic
func _finalize_movement() -> void:
	position = next_cell
	in_motion = false
	_switch_locomotion("idle")
	_handle_post_movement_logic()


# Called after movement is complete
func _handle_post_movement_logic() -> void:
	# If we have to sync with the server
	if autopilot_active: _handle_autopilot()
	# After movement, check if we have a pending interaction and deal with it
	elif pending_interaction: _handle_pending_interaction()


# Called when we have to sync with the server position
func _handle_autopilot() -> void:
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
			_setup_movement_step(predicted_path)
		else:
			# To prevent an input lock, we turn off autopilot if we get here
			autopilot_active = false
			# Reset our destinations
			grid_destination = grid_position
			immediate_grid_destination = grid_position


# Called after movement completes, only when we have a pending interaction
func _handle_pending_interaction() -> void:
	# If no path or already in position, try interaction
	if _is_in_interaction_range(pending_interaction):
		interaction_target = pending_interaction
		pending_interaction = null
		_execute_interaction()
		return
	
	# We are not in interaction range, so we'll have to trace a path to it
	# Calculate from current immediate destination if moving, else use our current grid position
	var start_position := immediate_grid_destination if in_motion else grid_position
	if not _setup_interaction_movement(start_position, pending_interaction):
		pending_interaction = null
		return


# Used to switch the current animation state
func _switch_locomotion(anim_state: String) -> void:
	var gender_prefix = "male/male_" if gender == "male" else "female/female_"
	var anim_name = gender_prefix + anim_state
	
	if animation_player.has_animation(anim_name):
		var settings = locomotion[anim_state]
		animation_player.play(settings.animation)
		animation_player.speed_scale = settings.play_rate
	
		# Only emit this signal for my own character
		if my_player_character:
			Signals.player_locomotion_changed.emit(anim_state)


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
			_setup_movement_step(server_path) # This starts movement


# Called when we receive a new position packet from the server to make sure we are synced locally
func _handle_server_reconciliation(new_server_position: Vector2i) -> void:
	if _prediction_was_valid(unconfirmed_path.duplicate(), new_server_position):
		if new_server_position == grid_destination:
			unconfirmed_path = []
			return
		else:
			return
	
	# If our prediction was invalid
	else:
		# Clear pending interactions on server correction
		pending_interaction = null
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
			_setup_movement_step(next_tick_predicted_path)
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


# Initializes movement parameters for a new path segment
func _setup_movement_step(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	
	# Get the next cell from this path to make it our next move target
	var next_grid_position = path.pop_front()
	next_cell = Utils.map_to_local(next_grid_position)
	
	# Check that we are not already at the next position to rotate
	if next_grid_position != grid_position:
		# Calculate the direction to target
		var move_direction = (next_cell - position).normalized()
		
		# Compare with previous direction using a threshold
		if move_direction.distance_to(forward_direction) > DIRECTION_THRESHOLD:
			# Handle rotation if direction changed
			_rotate_towards_direction(move_direction)
	
	# Update our step duration based on the distance we have to traverse
	_calculate_step_duration(grid_position, next_grid_position)
	
	# Reset movement counters for
	movement_elapsed_time = 0.0
	in_motion = true


func _calculate_path_overlap(current_path: Array[Vector2i], new_path: Array[Vector2i]) -> int:
	var overlap: int = 0
	for i in range(min(current_path.size(), new_path.size())):
		if current_path[current_path.size()-1-i] != new_path[i]:
			break
		overlap += 1
	return overlap


# Rotates our character towards a direction to interact
func _rotate_towards_direction(direction: Vector3) -> void:
	# Remove vertical component and normalize
	var horizontal_direction = direction.normalized()
	# Calculate target yaw directly from world direction (flip the sign to match Godot's system)
	var new_yaw := atan2(-horizontal_direction.x, -horizontal_direction.z)
	
	# Update forward direction immediately to target rotation
	forward_direction = Vector3(-sin(new_yaw), 0, -cos(new_yaw))
	
	# Only rotate if significant change in angle
	if abs(model.rotation.y - new_yaw) > DIRECTION_THRESHOLD:
		# Set rotation targets
		start_yaw = model.rotation.y
		target_yaw = new_yaw
		is_rotating = true
		rotation_elapsed = 0.0


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
func load_character(character_type: String) -> Node3D:
	# Remove existing character if any
	if current_character:
		current_character.queue_free()
	
	# Load and instantiate the new character
	if character_scenes.has(character_type):
		var character_scene = character_scenes[character_type]
		current_character = character_scene.instantiate()
		model.add_child(current_character)
		return current_character
	else:
		print("Character type %s not found" % [character_type])
		return null


# Helper function to handle common movement initiation logic
func _start_movement_towards(start_position: Vector2i, target_position: Vector2i, target: Interactable = null) -> void:
	var prediction: Array[Vector2i] = _predict_path(start_position, target_position)
	if prediction.is_empty():
		return
	
	# Different handling based on current movement state
	if in_motion:
		# When already moving, append to existing path
		next_tick_predicted_path = prediction.slice(1)
		grid_destination = target_position
	
	# When starting from idle
	else:
		 # player_speed + 1 accounts for current cell
		predicted_path = Utils.pop_multiple_front(prediction, player_speed + 1)
		
		# If we are in the same cell as the target cell, our predicted_path will have 1 or 0 cells,
		# instead of moving towards it, we check if we are in range to activate
		if predicted_path.size() < 2:
			# If we are in range, we activate it, either way we return early
			if target and _is_in_interaction_range(interaction_target):
				_execute_interaction()
			return
		
		# Get our immediate grid destination (this tick)
		immediate_grid_destination = predicted_path.back()
		# We add to our local unconfirmed path the next steps we'll take
		unconfirmed_path.append(immediate_grid_destination)
		# Remove the first cell from the predicted_path because we are already there
		predicted_path = predicted_path.slice(1)
		# Store the remaining prediction (if any) for next tick
		next_tick_predicted_path = prediction
		
		# Prepare everything to move correctly this tick
		cells_to_move_this_tick = predicted_path.size()
		_setup_movement_step(predicted_path)
		#_switch_locomotion(cells_to_move_this_tick)
		is_predicting = true
		grid_destination = target_position
		
		# We need to send the packet here ONCE, when movement starts only
		var packet := _create_player_destination_packet(immediate_grid_destination)
		WebSocket.send(packet)


# Helper function to validate and get interaction position
func _get_valid_interaction_position(start_position: Vector2i, target: Interactable) -> Vector2i:
	var target_position: Vector2i = Utils.local_to_map(target.global_position)
	return RegionManager.get_available_positions_around_target(
		start_position,
		target_position,
		target.get_interaction_positions()
	)


# Helper function to handle common interaction path setup
func _setup_interaction_movement(start_position: Vector2i, target: Interactable) -> bool:
	# Check if our target has available interact positions (not occupied by another character)
	var interaction_position: Vector2i = _get_valid_interaction_position(start_position, target)
	if interaction_position == Vector2i.ZERO:
		return false
	
	# Check if we can reach the target
	var interaction_path: Array[Vector2i] = _predict_path(start_position, interaction_position) 
	if interaction_path.is_empty():
		return false
	
	_start_movement_towards(start_position, interaction_position, target)
	return true


# Helper function for click movement validation
func _validate_move_position(pos: Vector2i) -> bool:
	return RegionManager.is_cell_reachable(pos) and RegionManager.is_cell_available(pos)


# Helper function for new movement initiation
func _start_new_movement(target_position: Vector2i) -> void:
	var prediction: Array[Vector2i] = _predict_path(grid_position, target_position)
	if prediction.size() > 1: # Accounts for current cell (Need 2 cells minimum to move)
		_start_movement_towards(grid_position, target_position)


# Helper function for updating existing movement
func _update_existing_movement(target_position: Vector2i) -> void:
	var prediction: Array[Vector2i] = _predict_path(immediate_grid_destination, target_position)
	if prediction.size() > 0:
		next_tick_predicted_path = prediction.slice(1) # Remove starting cell
		grid_destination = target_position


# Creates and sends a packet to the server requesting to switch regions/maps
func request_switch_region(new_region: int) -> void:
	var packet := _create_join_region_request_packet(new_region)
	WebSocket.send(packet)


# Used to update the text inside our chat bubble
func new_chat_bubble(message: String) -> void:
	chat_bubble_manager.show_bubble(message)


# Toggles the chat bubble icon on screen
func toggle_chat_bubble_icon(is_typing: bool) -> void:
	if chat_bubble_icon:
		chat_bubble_icon.visible = is_typing
