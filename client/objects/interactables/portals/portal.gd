extends Interactable

# Preloading scripts
const Player := preload("res://objects/character/player/player.gd")

@export var region_id: int = 1

func interact(interactor: Node) -> void:
	interactor.request_switch_region(region_id)
