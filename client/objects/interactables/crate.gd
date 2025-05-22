extends Interactable

func interact(interactor: Node) -> void:
	print("%s opened crate..." % [interactor.player_name])
