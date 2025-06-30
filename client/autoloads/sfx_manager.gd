extends Node


# Preloading scenes
const projectile_impact_flesh_scene = preload("res://sfx/projectile_impact_flesh.tscn")
const projectile_impact_concrete_scene = preload("res://sfx/projectile_impact_concrete.tscn")
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
const MAX_DECALS_PER_MESH: int = 8 # Godot Mobile renderer limitation


# Particle effect for flesh impacts
func spawn_projectile_impact_flesh(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	var projectile_impact_flesh := projectile_impact_flesh_scene.instantiate()
	
	# Add to scene
	add_child(projectile_impact_flesh)
	
	# Position and orient sfx
	projectile_impact_flesh.global_position = spawn_position
	# Use the reverse of the normal for bullet impacts (position - normal)
	projectile_impact_flesh.look_at(spawn_position - spawn_normal, Vector3.UP)


# Particle effect for concrete impacts
func spawn_projectile_impact_concrete(spawn_position: Vector3, spawn_normal: Vector3) -> void:
	var projectile_impact_concrete := projectile_impact_concrete_scene.instantiate()
	
	# Add to scene
	add_child(projectile_impact_concrete)
	
	# Position and orient sfx
	projectile_impact_concrete.global_position = spawn_position
	# Use the reverse of the normal for bullet impacts (position - normal)
	projectile_impact_concrete.look_at(spawn_position - spawn_normal, Vector3.UP)


# Spawn decal for impacts based on material typed
func spawn_projectile_impact_decal(spawn_position: Vector3, spawn_normal: Vector3, target_mesh: Node3D, material_type: String = "concrete_material") -> void:
	# Select decal based on material type
	var decal_pool: Array
	match material_type:
		_: # Defaults to concrete
			decal_pool = CONCRETE_DECALS
	
	# Get random decal scene from selected pool
	var decal_scene = decal_pool[randi() % decal_pool.size()]
	
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
	var y_axis: Vector3 = spawn_position.normalized()
	var x_axis: Vector3 = Vector3.UP.cross(y_axis)
	# Handle edge case when normal is parallel to UP
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT.cross(y_axis)
	
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = y_axis.cross(x_axis)
	# Apply the new basis
	decal.global_transform.basis = Basis(x_axis, y_axis, z_axis)


# Get all decals on a specific mesh
func get_decals_on_mesh(mesh: Node3D) -> Array:
	var decals = []
	for child in mesh.get_children():
		if child is GenericDecal and child.parent_mesh == mesh:
			decals.append(child)
	return decals
