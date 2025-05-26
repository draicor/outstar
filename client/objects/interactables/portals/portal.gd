extends Interactable

# Preloading scripts
const Player := preload("res://objects/character/player/player.gd")

@export var region_id: int = 1

func interact(interactor: Node) -> void:
	print("%s activated the portal to region %d..." % [interactor.player_name, region_id])
	interactor.request_switch_region(region_id)
