extends Node


# Preloading scenes
const PROJECTILE_IMPACT_FLESH = preload("res://sfx/projectile/projectile_impact_flesh.tscn")
const PROJECTILE_IMPACT_HEADSHOT = preload("res://sfx/projectile/projectile_impact_headshot.tscn")
const PROJECTILE_IMPACT_CONCRETE = preload("res://sfx/projectile/projectile_impact_concrete.tscn")
# Decals
const CONCRETE_DECALS = [
	preload("res://decals/impact_concrete_decal_01.tscn"),
	preload("res://decals/impact_concrete_decal_02.tscn"),
	preload("res://decals/impact_concrete_decal_03.tscn"),
	preload("res://decals/impact_concrete_decal_04.tscn"),
	preload("res://decals/impact_concrete_decal_05.tscn"),
	preload("res://decals/impact_concrete_decal_06.tscn"),
	preload("res://decals/impact_concrete_decal_07.tscn"),
	preload("res://decals/impact_concrete_decal_08.tscn")
]

# Constants
const MAX_DECALS_PER_MESH: int = 64 # Forward+ renderer limitation


# PARTICLE EFFECTS #

func spawn_projectile_impact_flesh(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	_spawn_impact_effect(PROJECTILE_IMPACT_FLESH, spawn_position, spawn_normal)


func spawn_projectile_impact_headshot(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	_spawn_impact_effect(PROJECTILE_IMPACT_HEADSHOT, spawn_position, spawn_normal)


func spawn_projectile_impact_concrete(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	_spawn_impact_effect(PROJECTILE_IMPACT_CONCRETE, spawn_position, spawn_normal)


# Spawn decal for impacts based on material typed
func spawn_projectile_impact_decal(spawn_position: Vector3, spawn_normal: Vector3, target_mesh: Node3D, material_type: String = "concrete_material") -> void:
	# Select decal based on material type
	var decal_pool: Array
	match material_type:
		_: # Defaults to concrete
			decal_pool = CONCRETE_DECALS
	
	# Get random decal scene from selected pool
	var decal_scene = decal_pool[randi() % decal_pool.size()]
	_spawn_decal(decal_scene, spawn_position, spawn_normal, target_mesh)


# Handle cases where the direction is parallel to the global up vector
func get_safe_up_vector(direction: Vector3) -> Vector3:
	var up: Vector3 = Vector3.UP
	# Check if direction is near-parallel to UP vector
	if abs(direction.normalized().dot(up)) > 0.99:
		# Use right vector as fallback (perpendicular to default up)
		return Vector3.RIGHT
	return up


# Helper function to instantiate, spawn, position and oriente the sfx
func _spawn_impact_effect(effect_scene: PackedScene, spawn_position: Vector3, spawn_normal: Vector3) -> void:
	var effect := effect_scene.instantiate()
	add_child(effect)
	
	# Position and orient sfx
	effect.global_position = spawn_position
	# Use the reverse of the normal for bullet impacts (position - normal)
	var target_position = spawn_position - spawn_normal
	var safe_up = get_safe_up_vector(-spawn_normal)
	effect.look_at(target_position, safe_up)


# Get all decals on a specific mesh
func get_decals_on_mesh(mesh: Node3D) -> Array:
	var decals = []
	for child in mesh.get_children():
		if child is GenericDecal and child.parent_mesh == mesh:
			decals.append(child)
	return decals


# Helper function to instantiate, spawn, position and orientate decals
func _spawn_decal(decal_scene: PackedScene, spawn_position: Vector3, spawn_normal: Vector3, target_mesh: Node3D) -> void:
	# Get existing decals on this mesh
	var existing_decals = get_decals_on_mesh(target_mesh)
	
	# Remove oldest decals if we're at the limit
	if existing_decals.size() >= MAX_DECALS_PER_MESH:
		# Get the oldest element and free it
		existing_decals.pop_front().queue_free()
	
	# Create new decal and add it to the mesh
	var decal = decal_scene.instantiate()
	# Add decal to mesh
	decal.set_parent_mesh(target_mesh)
	target_mesh.add_child(decal)
	
	# Position decal at an offset to prevent z-fighting
	decal.global_position = spawn_position + (spawn_normal * 0.01)
	
	# Create proper basis for orientation
	var y_axis: Vector3 = spawn_normal.normalized()
	var x_axis: Vector3 = Vector3.UP.cross(y_axis)
	# Handle edge case when normal is parallel to UP
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT.cross(y_axis)
	
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = y_axis.cross(x_axis)
	# Apply the new basis
	decal.global_transform.basis = Basis(x_axis, y_axis, z_axis)
