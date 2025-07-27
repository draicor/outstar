extends Control

var is_active : bool = false


func _init() -> void:
	hide()


# Used to show/hide this menu
func toggle() -> void:
	if is_active:
		hide()
		is_active = false
	else:
		show()
		is_active = true
