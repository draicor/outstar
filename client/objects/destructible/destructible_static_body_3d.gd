extends StaticBody3D

@export var tooltip: String = ""
# NOTE THINGS TO ADD LATER
# hitpoints int
# can_be_damaged bool?


func _ready() -> void:
	# Register this character as an interactable object
	TooltipManager.register_interactable(self)


# Called when this object gets destroyed
func _exit_tree() -> void:
	TooltipManager.unregister_interactable(self)
