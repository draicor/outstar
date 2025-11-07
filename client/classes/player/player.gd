extends CharacterBody3D
class_name Player

# Preloading scripts
const Pathfinding: GDScript = preload("res://classes/pathfinding/pathfinding.gd")
# Preloading scenes
const player_scene: PackedScene = preload("res://objects/player/player.tscn")

# Preloading textures
const crosshair_cursor = preload("res://assets/textures/ui/circle_02.png")

# Character model selector
var character_scenes: Dictionary[String, PackedScene] = {
	"female": preload("res://objects/characters/female_bot.tscn"),
	"male": preload("res://objects/characters/male_bot.tscn"),
}

# EXPORTED VARIABLES
@export var RAYCAST_DISTANCE: float = 40 # meters
@export var CHAT_BUBBLE_OFFSET: Vector3 = Vector3(0, 0.4, 0)

# Spawn data
var player_id: int
var player_name: String
var gender: String
var player_speed: int
var spawn_position: Vector2i
var spawn_rotation: float
var tooltip: String
var is_local_player: bool # Used to differentiate my character from remote players
var spawn_weapon_slot: int = 0
var spawn_weapon_slots: Array[Dictionary] = []

# Logic variables
var is_busy: bool = false # Blocks input during interactions
var is_mouse_over_ui = false # Used to prevent input of certain actions while on the UI

# Interaction system
var interaction_target: Interactable = null # The object we are trying to interact with
var pending_interaction: Interactable = null

# Camera variables
var camera: PlayerCamera
var raycast: RayCast3D

# Character variables
var character: Node = null
var chat_bubble_icon: Sprite3D
var skeleton: Skeleton3D = null # Our character's skeleton

# Rotation broadcast logic
const AIM_ROTATION_INTERVAL: float = 1.0 # 1 second timer to update rotation
var rotation_sync_timer: float = 0.0
var last_sent_rotation: float = 0.0
var rotation_timer_interval: float = AIM_ROTATION_INTERVAL
const ROTATION_CHANGE_THRESHOLD: float = 0.1 # radians
var is_aim_rotating: bool = false

# Weapon firing logic
var dry_fired: bool = false
# Firearm automatic firing
var is_auto_firing: bool = false
var is_trying_to_syncronize: bool = false
var shots_fired: int = 0
var expected_shots_fired: int = -1

# Signals
var ui_hud_weapon_slot_signals_connected: bool = false

# Scene tree nodes
@onready var model: Node3D = $Model # Used to attach the model and rotate it
@onready var camera_rig: Node3D = $CameraPivot/CameraRig # Used to attach the camera
@onready var chat_bubble_manager: Node3D = $ChatBubbleOrigin/ChatBubbleManager # Where chat bubbles spawn
@onready var player_movement: PlayerMovement = $PlayerMovement
@onready var player_state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var player_animator: PlayerAnimator = $PlayerAnimator
@onready var player_audio: PlayerAudio = $PlayerAudio
@onready var player_equipment: PlayerEquipment = $PlayerEquipment
@onready var player_packets: PlayerPackets = $PlayerPackets
@onready var player_actions: PlayerActions = $PlayerActions


# Called each tick to draw debugging tools on screen
func _physics_process(_delta: float) -> void:
	_show_debug_tools()


# Called when this object gets destroyed
func _exit_tree() -> void:
	TooltipManager.unregister_interactable(self)


########################
# INITIALIZATION LOGIC #
########################

static func instantiate(
	id: int,
	nickname: String,
	character_gender: String,
	character_speed: int,
	server_spawn_position: Vector2i,
	server_spawn_rotation: float, # Used to update our model.rotation.y
	is_my_player_character: bool,
	server_weapon_slot: int,
	server_weapon_slots: Array[Dictionary]
) -> Player:
	# Instantiate a new empty player character
	var player: Player = player_scene.instantiate()
	# Load the data from the function parameters into a new player character
	player.player_id = id
	player.player_name = nickname
	player.gender = character_gender
	player.player_speed = character_speed
	player.spawn_position = server_spawn_position
	player.spawn_rotation = server_spawn_rotation
	player.is_local_player = is_my_player_character
	player.tooltip = nickname
	# Weapon data
	player.spawn_weapon_slot = server_weapon_slot
	player.spawn_weapon_slots = server_weapon_slots
	
	return player


# We initialize our character hidden
func _init() -> void:
	hide()


# Called once this character has been created and instantiated
func _ready() -> void:
	_initialize_character()
	
	# Overwrite our local copy of the grid positions
	player_movement.server_grid_position = spawn_position
	player_movement.grid_position = spawn_position
	player_movement.grid_destination = spawn_position
	player_movement.immediate_grid_destination = spawn_position
	
	# Overwrite our local copy of the space positions
	player_movement.interpolated_position = Utils.map_to_local(spawn_position)
	# Rotate our character to match the server's rotation
	model.rotation.y = spawn_rotation
	
	# Do this only for my local character
	if is_local_player:
		_setup_local_player_components()
		_register_global_references() # After _setup_local_player_components()
	
	# Initialize state machine for all players
	player_state_machine.set_active(true, is_local_player)
	
	# CAUTION
	# Displays our character, replace with a spawn animation
	show()
	
	call_deferred("_post_ready_initialization")

# Called a frame later to let the child components catch up
func _post_ready_initialization() -> void:
	# Await an extra frame otherwise it won't work
	await get_tree().process_frame
	
	# Initialize equipment (spawn weapon)
	player_equipment.update_weapon_at_spawn()
	# Set the correct state based on equipped weapon
	var weapon_type: String = player_equipment.equipped_weapon_type
	var weapon_state: String = player_equipment.get_weapon_state_by_weapon_type(weapon_type)
	
	if weapon_state != "":
		# Only change state if we are not already in it
		if player_state_machine.get_current_state_name() != weapon_state:
			player_state_machine.change_state(weapon_state)
	else:
		# Unarmed
		player_state_machine.change_state("idle")


# Helper function for _ready()
func _initialize_character() -> void:
	load_character(gender) # CAUTION this shouldn't be gender but model_name
	if not character:
		push_error("Failed to load character")
		return
	
	# Find and store skeleton reference
	skeleton = character.find_child("GeneralSkeleton") as Skeleton3D
	if not skeleton:
		push_error("skeleton3D node not found in character")
		return
	
	# Register this character as an interactable object
	TooltipManager.register_interactable(self)
	
	# Wait until next frame to ensure nodes are ready
	call_deferred("_setup_bone_attachments")


# Used to load a character model and append it as a child of our model node
func load_character(character_type: String) -> void:
	# Remove existing character if any
	if character:
		character.queue_free()
	
	# Load and instantiate the new character
	if character_scenes.has(character_type):
		var character_scene = character_scenes[character_type]
		character = character_scene.instantiate()
		model.add_child(character)
	else:
		print("Character type %s not found" % [character_type])


# Used to create the attachments in our character's skeleton
func _setup_bone_attachments() -> void:
	# Create head bone attachment for our chat bubble
	var head_attachment: BoneAttachment3D = BoneAttachment3D.new()
	# Assign a bone to this attachment
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
	
	if is_local_player:
		# Hide/reveal the chat bubble icon based on our is_player_typing value
		toggle_chat_bubble_icon(GameManager.is_player_typing)
	else:
		# Start with the bubble hidden for everyone else
		chat_bubble_icon.visible = false


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


###############
# MOUSE LOGIC #
###############

# Returns a vector3 position in the world where the mouse is aiming at
func get_mouse_world_position() -> Vector3:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	return mouse_raycast(mouse_position)


# Used to cast a ray from the camera view to the mouse position
func mouse_raycast(mouse_position: Vector2) -> Vector3:
	var vector: Vector3 = Vector3.ZERO
	# If our client is being moved automatically or our raycast node is invalid
	if player_movement.autopilot_active or not raycast:
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
func handle_movement_click(mouse_position: Vector2) -> void:
	# Grab the collision point from our mouse click
	var local_point : Vector3 = mouse_raycast(mouse_position)
	# If the point was invalid, exit
	if local_point == Vector3.ZERO: return
	
	# Transform the local space position to our grid coordinate
	var new_destination: Vector2i = Utils.local_to_map(local_point)
	
	# If we are already there or moving there, ignore
	if new_destination == player_movement.immediate_grid_destination:
		return
	
	# Pathfind and movement setup
	var path = Pathfinding.find_path(
		player_movement.immediate_grid_destination,
		new_destination,
		RegionManager.grid_width,
		RegionManager.grid_height,
		self
	)
	
	if path.is_empty():
		return
	
	# If not moving
	if not player_movement.in_motion:
		# NOTE we only queue the action if we were idling
		player_actions.queue_move_action(new_destination)
	
	# If moving
	else:
		# Store the new path for later user, skipping the first cell
		# No need to add it to the queue, the player_movement system does this automatically
		player_movement.next_tick_predicted_path = path.slice(1)
	
	# Overwrite our current local grid destination
	player_movement.grid_destination = new_destination


# Detects and returns target after mouse click, if valid
func get_mouse_click_target(mouse_position: Vector2) -> Object:
	# Check if our click collided with something
	var local_point: Vector3 = mouse_raycast(mouse_position)
	if local_point == Vector3.ZERO: return null
	
	# Query for collisions
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		local_point,
		0b10 # Collision layer 2 for interactables
	)
	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		# NOTE Add more base classes here to detect them too
		if result.collider is Interactable:
			return result.collider
	
	# If we didn't collide with anything, return null
	return null


# Changes the mouse cursor
func set_mouse_cursor(cursor_type: String) -> void:
	match cursor_type:
		"crosshair":
			Input.set_custom_mouse_cursor(
				crosshair_cursor,
				Input.CURSOR_ARROW,
				crosshair_cursor.get_size() / 2
			)
		_:
			# Reset any custom cursor first
			Input.set_custom_mouse_cursor(null)
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)


#####################
# INTERACTION LOGIC #
#####################

# Traces a path to the interactable if not in range, and then calls the execute interaction
func start_interaction(target: Interactable) -> void:
	# If clicked on our already clicked interaction, ignore
	if interaction_target == target or pending_interaction == target: return
	
	if player_movement.in_motion:
		# If we were moving, see if we can reach our target, if we can,
		# _setup_interaction_movement updates our next_tick path towards it
		if player_movement.setup_interaction_movement(player_movement.immediate_grid_destination, target):
			pending_interaction = target
		return
	
	# If our character was idle, save our target
	interaction_target = target
	
	# Check if we are already in range to activate
	if player_movement.is_in_interaction_range(target):
		player_state_machine.change_state("interact")
		return
	
	# If we are far away, check if we can reach it
	# if we can, start moving towards it
	if player_movement.setup_interaction_movement(player_movement.grid_position, target):
		player_state_machine.change_state("move")
	
	# If we can't reach it, then forget about it
	else:
		interaction_target = null


# Handles the interaction itself when in range
func execute_interaction() -> void:
	if not interaction_target:
		is_busy = false
		return
	
	is_busy = true # Prevent input while busy
	
	# Stop moving and clear the paths first
	player_movement.in_motion = false
	player_movement.predicted_path = []
	player_movement.next_tick_predicted_path = []
	
	# Rotate towards the interaction target and await until facing it
	var look_direction: Vector3 = (interaction_target.global_position - global_position).normalized()
	await player_movement.await_rotation(look_direction)
	
	# Attempt to play the interaction animation
	var animation_name: String = interaction_target.get_interaction_animation()
	await player_animator.play_animation_and_await(animation_name)
	
	# Perform the interaction itself
	interaction_target.interact(self)
	
	# Cleanup
	interaction_target = null
	is_busy = false
	# Go into idle state
	player_state_machine.change_state(player_animator.get_idle_state_name())


# Called after movement completes, only when we have a pending interaction
func handle_pending_interaction() -> void:
	# If no path or already in position, try interaction
	if player_movement.is_in_interaction_range(pending_interaction):
		interaction_target = pending_interaction
		pending_interaction = null
		player_state_machine.change_state("interact")
		return
	
	# We are not in interaction range, so we'll have to trace a path to it
	# Calculate from current immediate destination if moving, else use our current grid position
	var start_position: Vector2i = player_movement.immediate_grid_destination if player_movement.in_motion else player_movement.grid_position
	if not player_movement.setup_interaction_movement(start_position, pending_interaction):
		pending_interaction = null
		return


###################
# DEBUGGING LOGIC #
###################

func _show_debug_tools() -> void:
	 # Only draw in editor/debug builds
	if OS.is_debug_build():
		if is_local_player:
			_draw_circle(Utils.map_to_local(player_movement.grid_destination), 0.5, Color.RED, 16) # Grid destination
			_draw_circle(Utils.map_to_local(player_movement.immediate_grid_destination), 0.4, Color.YELLOW, 16) # Immediate grid destination
			_draw_circle(Utils.map_to_local(player_movement.grid_position), 0.3, Color.GREEN, 16) # Grid position
		
		# Draw the forward direction and server position for all characters on screen
		DebugDraw3D.draw_line(position, position + player_movement.forward_direction * 1, Color.RED) # 1 meter forward line
		_draw_circle(Utils.map_to_local(player_movement.server_grid_position), 0.6, Color.REBECCA_PURPLE, 16) # Server position for my character


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

##############
# CHAT LOGIC #
##############

# Used to update the text inside our chat bubble
func new_chat_bubble(message: String) -> void:
	chat_bubble_manager.show_bubble(message)


# Toggles the chat bubble icon on screen
func toggle_chat_bubble_icon(is_typing: bool) -> void:
	if chat_bubble_icon:
		chat_bubble_icon.visible = is_typing


####################
# HELPER FUNCTIONS #
####################

func is_in_weapon_aim_state() -> bool:
	var current_state: String = player_state_machine.get_current_state_name()
	return current_state in [player_packets.WEAPON_AIM_STATES]


func can_raise_weapon() -> bool:
	# If we are busy, we can't
	if is_busy:
		return false
	
	# Check if we are in the right player state
	var weapon_type: String = player_equipment.get_current_weapon_type()
	var target_state_name: String = weapon_type + "_down_idle"
	# If our weapon is equipped but down, we can raise it
	return player_state_machine.get_current_state_name() == target_state_name


func can_lower_weapon() -> bool:
	# If we are busy, we can't
	if is_busy:
		return false
	
	# Check if we are in the right player state
	var weapon_type: String = player_equipment.get_current_weapon_type()
	var target_state_name: String = weapon_type + "_aim_idle"
	# If our weapon is equipped and raised, we can lower it
	return player_state_machine.get_current_state_name() == target_state_name


func can_reload_weapon() -> bool:
	if is_busy:
		return false
	
	# CAUTION update this to check if we ammo available
	return true


# Fire weapon has nothing to do with ammo, because we have dry firing
func can_fire_weapon() -> bool:
	if is_busy:
		return false
	if player_movement.autopilot_active:
		return false
	if is_mouse_over_ui:
		return false
	if player_equipment.equipped_weapon_name == "unarmed":
		return false
	
	# Check if player is in a weapon state
	var current_state_name: String = player_state_machine.get_current_state_name()
	if not current_state_name in player_packets.WEAPON_AIM_STATES:
		return false
	
	return true


func can_toggle_fire_mode() -> bool:
	if is_busy:
		return false
	if player_movement.autopilot_active:
		return false
	if player_equipment.equipped_weapon_name == "unarmed":
		return false
	if player_equipment.equipped_weapon:
		if not player_equipment.equipped_weapon.has_method("set_fire_mode"):
			return false
	
	return true


func can_switch_weapon(slot: int) -> bool:
	if is_busy:
		return false
	if player_movement.autopilot_active:
		return false
	if player_equipment.current_slot == slot:
		return false
	if player_equipment.is_invalid_weapon_slot(slot):
		return false
	
	return true


func can_start_firing() -> bool:
	if is_busy:
		return false
	if player_movement.autopilot_active:
		return false
	if is_mouse_over_ui:
		return false
	# If no weapon is equipped
	if player_equipment.equipped_weapon_name == "unarmed":
		return false
	
	# If not in a weapon state
	var current_state_name: String = player_state_machine.get_current_state_name()
	if not current_state_name in player_packets.WEAPON_STATES:
		return false
	
	# If already firing
	if is_auto_firing:
		return false
	
	# If weapon is in semi-auto fire mode
	if player_equipment.get_fire_mode() == 0:
		return false
	
	return true
