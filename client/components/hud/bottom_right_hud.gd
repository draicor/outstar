extends Control

@onready var ammo_label: Label = $WeaponContainer/VBoxContainer/AmmoContainer/AmmoLabel
@onready var reserve_ammo_label: Label = $WeaponContainer/VBoxContainer/AmmoContainer/ReserveAmmoLabel
@onready var weapon_icon: TextureRect = $WeaponContainer/VBoxContainer/WeaponIcon

# Textures
const ICON_WEAPON_M16 = preload("res://assets/icons/icon_weapon_m16.png")
const ICON_WEAPON_AKM = preload("res://assets/icons/icon_weapon_akm.png")
const ICON_WEAPON_REMINGTON870 = preload("res://assets/icons/icon_weapon_remington870.png")


func _init() -> void:
	hide()


func _ready() -> void:
	Signals.ui_hide_bottom_right_hud.connect(_handle_signal_hide_buttom_right_hud)
	Signals.ui_show_bottom_right_hud.connect(_handle_signal_show_buttom_right_hud)
	Signals.ui_update_ammo.connect(_handle_signal_update_ammo)


func _handle_signal_hide_buttom_right_hud() -> void:
	hide()


func _handle_signal_show_buttom_right_hud() -> void:
	update_weapon_icon()
	show()


func _handle_signal_update_ammo() -> void:
	ammo_label.text = str(GameManager.player_character.player_equipment.get_current_ammo())
	reserve_ammo_label.text = str(GameManager.player_character.player_equipment.get_current_reserve_ammo())


func update_weapon_icon() -> void:
	var weapon_name: String = GameManager.player_character.player_equipment.get_current_weapon_name()
	match weapon_name:
		"m16_rifle":
			weapon_icon.texture = ICON_WEAPON_M16
		"akm_rifle":
			weapon_icon.texture = ICON_WEAPON_AKM
		"remington870_shotgun":
			weapon_icon.texture = ICON_WEAPON_REMINGTON870
		"_":
			weapon_icon.texture = null
