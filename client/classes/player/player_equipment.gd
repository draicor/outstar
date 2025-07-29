extends Node
class_name PlayerEquipment


# Weapon scene selector
var weapon_scenes: Dictionary[String, PackedScene] = {
	"m16_rifle": preload("res://objects/weapons/m16_rifle.tscn"),
	"akm_rifle": preload("res://objects/weapons/akm_rifle.tscn"),
}
var weapon_types: Dictionary[String, String] = {
	"m16_rifle": "rifle",
	"akm_rifle": "rifle",
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
# Ammo system
var equipped_weapon_ammo: int = 30


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


func get_equipped_weapon_type() -> String:
	return equipped_weapon_type


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
	# If we already have this equipped, ignore
	if equipped_weapon_name == weapon_name:
		return
	
	# Remove our equipped weapon, if any
	if equipped_weapon:
		equipped_weapon.queue_free()
	
	# Load and instantiate the new weapon
	if weapon_scenes.has(weapon_name) and weapon_types.has(weapon_name):
		var weapon_scene = weapon_scenes[weapon_name]
		equipped_weapon = weapon_scene.instantiate()
		# If we have a valid weapon instance
		if equipped_weapon:
			# Attach it to our right hand bone
			right_hand_attachment.add_child(equipped_weapon)
			equipped_weapon_name = weapon_name
			equipped_weapon_type = weapon_types[weapon_name]
			# If our equipped weapon has a valid left hand target
			if equipped_weapon.get_node("LeftHandMarker3D"):
				# Update our left hand target and start calculating IK
				set_left_hand_ik_target(equipped_weapon.get_node("LeftHandMarker3D"))
	else:
		print("Weapon %s (%s) not found" % [weapon_name, weapon_types[weapon_name]])


# Stops left hand IK and removes our equipped weapon
func unequip_weapon() -> void:
	# Stop IK processing completely
	disable_left_hand_ik()
	left_hand_ik.stop()
	left_hand_ik.target_node = ""
	
	# Remove our equipped weapon, if any
	if equipped_weapon:
		equipped_weapon.queue_free()
	
	# Set our equipped weapon and type to be unarmed
	equipped_weapon_name = "unarmed"
	equipped_weapon_type = "unarmed"


# Returns the current ammo in our equipped weapon
func get_equipped_weapon_ammo() -> int:
	return equipped_weapon_ammo


# Reloads our ammo based on our weapon type (for now)
func reload_equipped_weapon() -> void:
	match equipped_weapon_name:
		"unarmed": return
		"m16_rifle": equipped_weapon_ammo = 30
		"akm_rifle": equipped_weapon_ammo = 30
		_:
			push_error("reload_equipment_weapon failed, weapon not found")
			return


# Decreases the amount of ammo in our equipped weapon
func decrement_ammo(amount: int = 1) -> bool:
	if equipped_weapon_ammo >= amount:
		equipped_weapon_ammo -= amount
		Signals.ui_update_ammo.emit() # Update our ammo counter
		return true
	# If we don't have enough ammo, return false
	return false


# Checks if we have ammo to fire, if we do, return true, else return false
func can_fire_weapon() -> bool:
	if equipped_weapon_ammo > 0:
		return true
	else:
		return false


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
	
	equipped_weapon.target_direction = (target_position - get_muzzle_position()).normalized()


# Cycles through the weapon modes of this weapon, if available
func toggle_weapon_fire_mode() -> void:
	# If we have a weapon equipped and this weapon has more than one weapon mode
	if equipped_weapon and equipped_weapon.has_multiple_modes:
		equipped_weapon.toggle_fire_mode()
