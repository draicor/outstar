extends Interactable

@export var region_id: int = 1

func interact(interactor: Node) -> void:
	interactor.player_packets.request_switch_region(region_id)
