extends Interactable

var counter: int = 1

func interact(interactor: Node) -> void:
	print("%s opened the crate %d times..." % [interactor.player_name, counter])
	counter += 1
