extends Node
class_name PlayerEquipment

# Preloading scripts
const Player: GDScript = preload("res://objects/player/player.gd")

# Weapon scene selector
var weapon_scenes: Dictionary[String, PackedScene] = {
	"projectile_rifle": preload("res://objects/weapons/projectile_rifle.tscn"),
}
var weapon_types: Dictionary[String, String] = {
	"projectile_rifle": "rifle",
}

# Player variables
var player: Player = null # Our parent node

# Weapon system
var right_hand_attachment: BoneAttachment3D
var left_hand_ik: SkeletonIK3D
var equipped_weapon_name: String = "unarmed"
var equipped_weapon_type: String = "unarmed" # Used to switch states and animations too
var equipped_weapon = null # Instantiated scene of our weapon


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
	left_hand_ik.interpolation = 1.0
	left_hand_ik.active = true
	
	# Add it to our skeleton
	player.skeleton.add_child(left_hand_ik)


# Stops IK and updates our left hand IK target, requires manual start() after
func set_left_hand_ik_target(weapon_target: Node3D) -> void:
	disable_left_hand_ik()
	# Update our target
	left_hand_ik.target_node = weapon_target.get_path()
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


# If left hand ik is active, disable it
func disable_left_hand_ik() -> void:
	left_hand_ik.active = false


# If left hand ik is not active, activate it
func enable_left_hand_ik() -> void:
		if equipped_weapon:
			left_hand_ik.active = true


# Used to load a weapon model and append it as a child of our player skeleton
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


func unequip_weapon() -> void:
	# Stop IK processing completely
	disable_left_hand_ik()
	left_hand_ik.stop()
	left_hand_ik.target_node = ""
	
	# Remove our equipped weapon, if any
	if equipped_weapon:
		equipped_weapon.queue_free()
	
	equipped_weapon_name = "unarmed"
	equipped_weapon_type = "unarmed"
