extends Node

const packets := preload("res://packets.gd")

func _ready() -> void:
	GameManager.set_state(GameManager.State.START)
