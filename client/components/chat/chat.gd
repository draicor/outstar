extends Control

@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer

func info(message: String) -> void:
	var _m = Message.new()
	v_box_container.add_child(_m)
	_m.info(message)

func warning(message: String) -> void:
	var _m = Message.new()
	v_box_container.add_child(_m)
	_m.warning(message)

func error(message: String) -> void:
	var _m = Message.new()
	v_box_container.add_child(_m)
	_m.error(message)

func success(message: String) -> void:
	var _m = Message.new()
	v_box_container.add_child(_m)
	_m.success(message)

func public(sender_name: String, message: String) -> void:
	var _m = Message.new()
	v_box_container.add_child(_m, false)
	_m.public(sender_name, message)
