@tool
extends Node3D
class_name Wall

@export_category("Wall Settings")
@export var wall_size: Vector3 = Vector3(2.0, 2.0, 0.2) :
	set(value):
		wall_size = value
		update_wall_size()

@export var wall_color: Color = Color.GRAY :
	set(value):
		wall_color = value
		update_wall_material()

@export var texture: Texture2D :
	set(value):
		texture = value
		update_wall_material()

@export_category("Collision Groups")
@export_flags_3d_physics var collision_layer: int = 1 :
	set(value):
		collision_layer = value
		update_collision_settings()

@export_flags_3d_physics var collision_mask: int = 1 :
	set(value):
		collision_mask = value
		update_collision_settings()

@export var groups: Array[StringName] = [] :
	set(value):
		groups = value
		update_groups()

# References
var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

func _ready() -> void:
	# Ensure we have the required nodes
	_setup_nodes()
	
	# Get references to child nodes
	collision_shape = $StaticBody3D/CollisionShape3D
	mesh_instance = $MeshInstance3D
	
	# Create a UNIQUE material for this specific wall instance
	material = StandardMaterial3D.new()
	material.flags_transparent = false
	mesh_instance.material_override = material  # This makes it unique to this mesh instance
	
	# Initialize wall size and color
	update_wall_size()
	update_wall_material()
	update_collision_settings()
	update_groups()

func _setup_nodes() -> void:
	# Create StaticBody3D if it doesn't exist
	if not has_node("StaticBody3D"):
		var static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		add_child(static_body)
		if Engine.is_editor_hint():
			static_body.owner = get_tree().edited_scene_root
	
	# Create CollisionShape3D if it doesn't exist
	if not has_node("StaticBody3D/CollisionShape3D"):
		var collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		$StaticBody3D.add_child(collision)
		if Engine.is_editor_hint():
			collision.owner = get_tree().edited_scene_root
	
	# Create MeshInstance3D if it doesn't exist
	if not has_node("MeshInstance3D"):
		var mesh = MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		add_child(mesh)
		if Engine.is_editor_hint():
			mesh.owner = get_tree().edited_scene_root

func update_wall_size() -> void:
	if not collision_shape or not mesh_instance:
		return
	
	# Update collision shape
	if collision_shape.shape is BoxShape3D:
		collision_shape.shape.size = wall_size
	else:
		# Create new shape if it doesn't exist
		var new_shape = BoxShape3D.new()
		new_shape.size = wall_size
		collision_shape.shape = new_shape
	
	# Update mesh
	if mesh_instance.mesh is BoxMesh:
		mesh_instance.mesh.size = wall_size
	else:
		# Create new mesh if it doesn't exist
		var new_mesh = BoxMesh.new()
		new_mesh.size = wall_size
		mesh_instance.mesh = new_mesh

func update_wall_material() -> void:
	if not material:
		return
		
	material.albedo_color = wall_color
	# Make it non-metallic and slightly rough for better wall appearance
	material.metallic = 0.0
	material.roughness = 0.8
	
	if texture:
		material.albedo_texture = texture
		# Adjust UV scaling based on wall size
		var uv_scale = Vector2(wall_size.x, wall_size.y) / 2.0
		material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)

func update_collision_settings() -> void:
	var static_body = $StaticBody3D
	if static_body:
		static_body.collision_layer = collision_layer
		static_body.collision_mask = collision_mask

func update_groups() -> void:
	var static_body = $StaticBody3D
	if static_body:
		# Clear existing groups first
		for group in static_body.get_groups():
			static_body.remove_from_group(group)
		
		# Add new groups
		for group in groups:
			static_body.add_to_group(group)
