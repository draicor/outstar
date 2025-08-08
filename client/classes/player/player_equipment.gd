extends Node
class_name PlayerEquipment

const MAX_WEAPON_SLOTS: int = 5
var current_slot: int = 0
var weapon_slots: Array[Dictionary] = []

# Weapon scene selector
var weapon_scenes: Dictionary[String, PackedScene] = {
	"unarmed": null,
	"m16_rifle": preload("res://objects/weapons/m16_rifle.tscn"),
	"akm_rifle": preload("res://objects/weapons/akm_rifle.tscn"),
}
var weapon_types: Dictionary[String, String] = {
	"unarmed": "unarmed",
	"m16_rifle": "rifle",
	"akm_rifle": "rifle",
}
var weapon_states: Dictionary[String, String] = {
	"unarmed": "idle",
	"rifle": "rifle_down_idle",
}

# Player variables
var player: Player = null # Our parent node

# Weapon system
var right_hand_attachment: BoneAttachment3D
var left_hand_ik: SkeletonIK3D
var left_hand_ik_tween: Tween # Smooths out the transition for ik enable/disable
var equipped_weapon_name: String = "unarmed"
var equipped_weapon_type: String = "unarmed" # Used to switch states and animations too
var equipped_weapon = null # Instantiated scene of our weapon
var max_correction_angle: float = deg_to_rad(5.0) # 5 degrees deviation


func _ready() -> void:
	# Wait for parent to be ready, then store a reference to it
	await get_parent().ready
	player = get_parent()
	
	# Create right hand bone attachment for our weapon
	right_hand_attachment = BoneAttachment3D.new()
	right_hand_attachment.bone_name = "RightHand"
	player.skeleton.add_child(right_hand_attachment)
	
	# Create and add our IK nodes
	_setup_left_hand_ik()
	
	# Initialize weapon slots from player's spawn data
	weapon_slots = player.spawn_weapon_slots
	# Equip the weapon slot from the server packet
	current_slot = player.spawn_weapon_slot


# Creates and configurates a left hand IK 3D node, then adds it to our skeleton
func _setup_left_hand_ik() -> void:
	left_hand_ik = SkeletonIK3D.new()
	left_hand_ik.name = "LeftHandIK"
	left_hand_ik.root_bone = "LeftShoulder"
	left_hand_ik.tip_bone = "LeftHand"
	# Calculate the interpolation every frame but don't display it yet
	left_hand_ik.interpolation = 0.0
	left_hand_ik.active = true
	
	# Add it to our skeleton
	player.skeleton.add_child(left_hand_ik)


# Stops IK and updates our left hand IK target, requires manual start() after
func set_left_hand_ik_target(left_hand_target: Node3D) -> void:
	disable_left_hand_ik()
	# Update our target
	left_hand_ik.target_node = left_hand_target.get_path()
	# Start calculating IK
	left_hand_ik.start()


# Updates the current equipped weapon type to change the animation library
func set_equipped_weapon_type(new_weapon: String) -> void:
	# If already equipped, ignore
	if new_weapon == equipped_weapon_type:
		return
	
	match new_weapon:
		"unarmed": equipped_weapon_type = "unarmed"
		"rifle": equipped_weapon_type = "rifle"
		_: push_error("Weapon not valid")


# Stops displaying the left hand IK
func disable_left_hand_ik() -> void:
	if left_hand_ik_tween:
		left_hand_ik_tween.kill()
	
	left_hand_ik_tween = create_tween()
	left_hand_ik_tween.tween_property(
		left_hand_ik,
		"interpolation",
		0.0, # target interpolation
		0.1 # duration in seconds
	).set_ease(Tween.EASE_IN)


# Starts displaying the left hand IK if a weapon is equipped
func enable_left_hand_ik() -> void:
		if equipped_weapon:
			if left_hand_ik_tween:
				left_hand_ik_tween.kill()
			
			left_hand_ik_tween = create_tween()
			left_hand_ik_tween.tween_property(
				left_hand_ik,
				"interpolation",
				1.0, # target interpolation
				0.1 # duration in seconds
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# Loads a weapon model and append it as a child of our player skeleton
func equip_weapon(weapon_name: String) -> void:
	# Remove our equipped weapon, if any
	if equipped_weapon:
		equipped_weapon.queue_free()
	
	# If we want to be unarmed, return
	if weapon_name == "unarmed":
		return
	
	# Load and instantiate the new weapon
	if weapon_scenes.has(weapon_name) and weapon_types.has(weapon_name):
		var weapon_scene = weapon_scenes[weapon_name]
		equipped_weapon = weapon_scene.instantiate()
		# If we have a valid weapon instance
		if equipped_weapon:
			if equipped_weapon.has_method("set_fire_mode"):
				equipped_weapon.set_fire_mode(weapon_slots[current_slot]["fire_mode"])
			
			# Attach it to our right hand bone
			right_hand_attachment.add_child(equipped_weapon)
			equipped_weapon_name = weapon_name
			equipped_weapon_type = weapon_types[weapon_name]
			# If our equipped weapon has a valid left hand target
			if equipped_weapon.get_node("LeftHandMarker3D"):
				# Update our left hand target and start calculating IK
				set_left_hand_ik_target(equipped_weapon.get_node("LeftHandMarker3D"))
			
			# Display the weapon hud after spawning the weapon
			show_weapon_hud()
			# Initialize the weapon sounds for this weapon
			player.player_audio.setup_weapon_audio_players(weapon_name)
	else:
		print("Weapon %s (%s) not found" % [weapon_name, weapon_types[weapon_name]])


# Stops left hand IK and removes our equipped weapon
func unequip_weapon() -> void:
	# Stop IK processing completely
	left_hand_ik.stop()
	left_hand_ik.target_node = ""
	
	# Remove our equipped weapon, if any
	if equipped_weapon:
		equipped_weapon.queue_free()
	
	# Set our equipped weapon and type to be unarmed
	equipped_weapon_name = "unarmed"
	equipped_weapon_type = "unarmed"


# Reloads our ammo based on our weapon type (for now)
func reload_equipped_weapon() -> void:
	var weapon_name = weapon_slots[current_slot]["weapon_name"]
	match weapon_name:
		"m16_rifle", "akm_rifle":
			set_current_ammo(30)
		_:
			return


# Decreases the amount of ammo in our equipped weapon
func decrement_ammo(amount: int = 1) -> bool:
	if get_current_ammo() >= amount:
		set_current_ammo(get_current_ammo() - amount) # Emits signal inside
		return true
	# If we don't have enough ammo, return false
	return false


# Checks if we have ammo to fire, if we do, return true, else return false
func can_fire_weapon() -> bool:
	return get_current_ammo() > 0


# Fires the actual weapon (the fire animation is already playing here)
func weapon_fire() -> void:
	# If we don't have a weapon equipped or we do but we can't fire it
	if not equipped_weapon or not can_fire_weapon():
		return
	
	equipped_weapon.fire()
	decrement_ammo()


# Returns the muzzle position for firearms
func get_muzzle_position() -> Vector3:
	if equipped_weapon and equipped_weapon.has_node("MuzzleMarker3D"):
		return equipped_weapon.get_node("MuzzleMarker3D").global_position
	# Fallback if the node is not set
	push_error("MuzzleMarker3D not set")
	return player.global_position


# Calculate accurate firing direction using our weapon's muzzle marker 3d
func calculate_weapon_direction(target_position: Vector3) -> void:
	if not equipped_weapon:
		return
	
	# Get weapon's natural forward direction using the muzzle position as the start position
	var muzzle_position: Vector3 = get_muzzle_position()
	var weapon_forward: Vector3 = -equipped_weapon.muzzle_marker_3d.global_transform.basis.z
	# Calculate vector to target
	var to_target: Vector3 = target_position - muzzle_position
	
	# Calculate angle between weapon forward and target direction
	var angle: float = weapon_forward.angle_to(to_target)
	
	# If target is within correction cone, use exact target direction
	if angle < max_correction_angle:
		equipped_weapon.target_direction = to_target
	else:
		# Otherwise, blend toward max allowed angle
		equipped_weapon.target_direction = weapon_forward.slerp(
			to_target,
			max_correction_angle / angle
		)


# CAUTION this should be replaced with a packet from the server to assign a weapon to this slot
# CAUTION this will override existent weapons in that slot,
# fix this after having drop mechanics?
# It doesn't check against slot already being in use!
# Assigns a weapon to one of the weapon slots
func add_weapon_to_slot(slot: int, weapon_name: String, ammo: int = 0, fire_mode: int = 0) -> void:
	# Check we didn't pass an invalid slot
	if slot < 0 or slot >= MAX_WEAPON_SLOTS:
		push_error("Invalid slot: %d" % slot)
		return
	
	if weapon_name != "unarmed":
		# Check that we didn't pass an invalid weapon name
		if not weapon_scenes.has(weapon_name) or not weapon_types.has(weapon_name):
			push_error("Weapon %s not found in dictionaries" % weapon_name)
			return
	
	# Set weapon name and weapon type
	weapon_slots[slot]["weapon_name"] = weapon_name
	weapon_slots[slot]["weapon_type"] = weapon_types[weapon_name]
	# Set display name
	match weapon_name:
		"unarmed": weapon_slots[slot]["display_name"] = "Unarmed"
		"akm_rifle": weapon_slots[slot]["display_name"] = "AKM Rifle"
		"m16_rifle": weapon_slots[slot]["display_name"] = "M16 Rifle"
		_: weapon_slots[slot]["display_name"] = "Unknown Weapon"
	
	# Set initial ammo
	weapon_slots[slot]["ammo"] = ammo
	# Set fire mode
	weapon_slots[slot]["fire_mode"] = fire_mode


func switch_weapon_by_slot(slot: int) -> void:
	if is_invalid_weapon_slot(slot):
		return
	
	unequip_weapon()
	current_slot = slot
	update_equipped_weapon()


func update_equipped_weapon() -> void:
	var weapon_name: String = weapon_slots[current_slot]["weapon_name"]
	if weapon_name != "":
		equip_weapon(weapon_name)
	else:
		equipped_weapon_name = "unarmed"
		equipped_weapon_type = "unarmed"
		hide_weapon_hud()


func get_current_ammo() -> int:
	return weapon_slots[current_slot]["ammo"]


func set_current_ammo(amount: int) -> void:
	weapon_slots[current_slot]["ammo"] = amount
	update_hud_ammo()


# 0 is semi-auto, 1 is full-auto
func get_fire_mode() -> int:
	return weapon_slots[current_slot]["fire_mode"]


func get_current_weapon_type() -> String:
	return weapon_slots[current_slot]["weapon_type"]


func get_current_weapon_name() -> String:
	return weapon_slots[current_slot]["weapon_name"]


func get_weapon_state_by_weapon_type(weapon_type: String) -> String:
	if weapon_states.has(weapon_type):
		return weapon_states[weapon_type]
	return ""


# Check we didn't pass an invalid slot
func is_invalid_weapon_slot(slot: int) -> bool:
	return slot < 0 or slot >= MAX_WEAPON_SLOTS


func toggle_fire_mode() -> void:
	var current_mode: int = weapon_slots[current_slot]["fire_mode"]
	weapon_slots[current_slot]["fire_mode"] = 1 - current_mode # Toggle between 0 and 1
	
	if equipped_weapon and equipped_weapon.has_method("set_fire_mode"):
		equipped_weapon.set_fire_mode(weapon_slots[current_slot]["fire_mode"])


func update_hud_ammo() -> void:
	# Do this only for my local character
	if player.my_player_character:
		Signals.ui_update_ammo.emit() # Update our ammo counter
		# Update our weapon's fire mode too
		# CAUTION Update our weapon icon too


func hide_weapon_hud() -> void:
	# Do this only for my local character
	if player.my_player_character:
		Signals.ui_hide_bottom_right_hud.emit()


func show_weapon_hud() -> void:
	# Do this only for my local character
	if player.my_player_character:
		# We update our ammo counter and then we display it
		Signals.ui_update_ammo.emit()
		Signals.ui_show_bottom_right_hud.emit()


# Calls update_equipped weapon to spawn weapons and update the animation library
func update_weapon_at_spawn() -> void:
	# Equip the weapon for the current slot
	update_equipped_weapon()
	
	# Update animation library based on equipped weapon type and gender
	var anim_library: String = player.player_animator.get_animation_library(
		equipped_weapon_type,
		player.gender
	)
	player.player_animator.switch_animation_library(anim_library)
