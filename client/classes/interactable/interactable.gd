class_name Interactable
extends StaticBody3D

@export var interaction_name := "Interact" # What will display on the tooltip
@export var interaction_range: int = 1 # Grid minimum distance to activate
@export var interaction_animation: String = "" # Animation that will play when interacting


# Returns the position the character will have to stand in to activate
func get_interaction_position() -> Vector3:
	return global_position # + Vector3(0, 0, 0) # Example offset


# Returns the animation name the character will play when interacting
func get_interaction_animation() -> String:
	return interaction_animation


# This has to be overriden
func interact(_interactor: Node) -> void:
	pass
