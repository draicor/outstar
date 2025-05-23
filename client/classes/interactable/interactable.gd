class_name Interactable
extends StaticBody3D

@export var tooltip: String = ""
@export var interaction_animation: String = "" # Animation that will play when interacting
@export var interaction_positions: Array[Vector2i] = [] # Grid positions where this object can be activated


func _ready() -> void:
	# Register this character as an interactable object
	TooltipManager.register_interactable(self)


# Called when this object gets destroyed
func _exit_tree() -> void:
	TooltipManager.unregister_interactable(self)


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


# Returns the animation name the character will play when interacting
func get_interaction_animation() -> String:
	return interaction_animation


# This has to be overriden
func interact(_interactor: Node) -> void:
	pass
