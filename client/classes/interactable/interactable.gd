class_name Interactable
extends StaticBody3D

@export var interaction_name := "Interact" # What will display on the tooltip
@export var interaction_range: int = 1 # Grid minimum distance to activate
@export var interaction_animation: String = "" # Animation that will play when interacting
@export var interaction_positions: Array[Vector2i] = [] # Grid positions where this object can be activated


# Returns the off-set positions this object can be activated from
func get_interaction_positions() -> Array[Vector2i]:
	# Default implementation returns adjacent cells if no positions are specified
	if interaction_positions.is_empty():
		return [
			Vector2i.UP,
			Vector2i.DOWN,
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i(-1, -1), # NW
			Vector2i(1, -1),  # NE
			Vector2i(-1, 1),  # SW
			Vector2i(1, 1),   # SE
		]
	return interaction_positions


# Returns the interaction position closer to our player
func get_nearest_interaction_position(player_grid_position: Vector2i) -> Vector2i:
	var positions = get_interaction_positions()
	var nearest_position = positions[0]
	var min_distance = player_grid_position.distance_squared_to(nearest_position)
	
	for pos in positions.slice(1): # Skip first cell since we already have it
		var distance = player_grid_position.distance_squared_to(pos)
		if distance < min_distance and RegionManager.is_cell_available(pos):
			min_distance = distance
			nearest_position = pos
	
	return nearest_position


# Returns the animation name the character will play when interacting
func get_interaction_animation() -> String:
	return interaction_animation


# This has to be overriden
func interact(_interactor: Node) -> void:
	pass
