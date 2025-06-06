class_name PlayerState

# Preloading scripts
const Player := preload("res://objects/character/player/player.gd")

# Internal variables
var player: Player

# Initializes our state machine, storing our player character here
func _init(player_node: Player) -> void:
	player = player_node

func enter() -> void:
	pass

static func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
