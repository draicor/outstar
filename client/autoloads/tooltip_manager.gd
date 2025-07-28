extends Node

@export var RAYCAST_DISTANCE: float = 40 # 20 meters

var tooltip: CanvasLayer = null
var player_camera: PlayerCamera = null
var current_hovered_object = null
var interactables = []


# Instantiate the tooltip scene at start up
func _ready() -> void:
	tooltip = preload("res://components/tooltip/tooltip.tscn").instantiate()
	add_child(tooltip)


# Check on tick if the tooltip has to be displayed
# It checks if our interactables array contains the object the raycast collided with
# NOTE interactable objects should have a tooltip string variable thats not empty
func _process(_delta: float) -> void:
	# If we don't have a camera ready, abort
	if not player_camera:
		# When switching maps, the camera gets destroyed, so hide the tooltip
		tooltip.hide()
		return
	
	# If we have a menu open, we hide the tooltip
	if GameManager.is_ui_menu_active():
		if tooltip.visible:
			tooltip.hide()
		return
	
	if tooltip.visible:
		tooltip.update_position()
	
	var mouse_position = get_viewport().get_mouse_position()
	var from = player_camera.project_ray_origin(mouse_position)
	var to = from + player_camera.project_ray_normal(mouse_position) * RAYCAST_DISTANCE
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = player_camera.get_world_3d().direct_space_state.intersect_ray(query)
	
	# If our raycast hit something
	if result:
		var new_hovered = result.collider
		
		# If our raycast hit something different
		if new_hovered != current_hovered_object:
			# If we had another tooltip, hide it
			if current_hovered_object:
				tooltip.hide_tooltip()
		
		# Start new hover if the object is interactable (in our array)
		if interactables.has(new_hovered):
			# If the object has a tooltip text set
			if not new_hovered.tooltip.is_empty():
				# Don't display a tooltip for our own local player character
				if new_hovered == GameManager.player_character:
					return
				
				tooltip.show_tooltip(new_hovered.tooltip)
				# Make this our new hovered object
				current_hovered_object = new_hovered
		
	# If we stop hovering over any object
	elif current_hovered_object:
		tooltip.hide_tooltip()
		current_hovered_object = null


# Called from player.gd after the camera has been initialized
func set_player_camera(camera: PlayerCamera) -> void:
	player_camera = camera


# Adds a new interactable object to our array of objects
func register_interactable(object) -> void:
	interactables.append(object)


# Removes an interactable object from our array of objects
func unregister_interactable(object) -> void:
	interactables.erase(object)
