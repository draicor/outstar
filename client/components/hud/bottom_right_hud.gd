extends Control

@onready var ammo_label: Label = $WeaponContainer/VBoxContainer/AmmoContainer/AmmoLabel


func _init() -> void:
	hide()


func _ready() -> void:
	Signals.ui_hide_bottom_right_hud.connect(_handle_signal_hide_buttom_right_hud)
	Signals.ui_show_bottom_right_hud.connect(_handle_signal_show_buttom_right_hud)
	Signals.ui_update_ammo.connect(_handle_signal_update_ammo)


func _handle_signal_hide_buttom_right_hud() -> void:
	hide()


func _handle_signal_show_buttom_right_hud() -> void:
	show()


func _handle_signal_update_ammo() -> void:
	ammo_label.text = str(GameManager.player_character.player_equipment.get_equipped_weapon_ammo())
