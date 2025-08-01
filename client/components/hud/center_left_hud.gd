extends Control


@onready var weapon_one_icon: TextureRect = $WeaponIcons/WeaponOneIcon
@onready var weapon_one_button: Button = $WeaponIcons/WeaponOneIcon/WeaponOneButton
@onready var weapon_two_icon: TextureRect = $WeaponIcons/WeaponTwoIcon
@onready var weapon_two_button: Button = $WeaponIcons/WeaponTwoIcon/WeaponTwoButton
@onready var weapon_three_icon: TextureRect = $WeaponIcons/WeaponThreeIcon
@onready var weapon_three_button: Button = $WeaponIcons/WeaponThreeIcon/WeaponThreeButton
@onready var weapon_four_icon: TextureRect = $WeaponIcons/WeaponFourIcon
@onready var weapon_four_button: Button = $WeaponIcons/WeaponFourIcon/WeaponFourButton
@onready var weapon_five_icon: TextureRect = $WeaponIcons/WeaponFiveIcon
@onready var weapon_five_button: Button = $WeaponIcons/WeaponFiveIcon/WeaponFiveButton


# NOTE
# Add a function to change the tooltip of one of the buttons
# Add a function to change the texture of one of the buttons
# Add a variable for each slot to hold a string with the name of the item
# Add a function that will be called from other places in the code,
# to change all of the above through one call.
# Add a function that will increase the scale of an item slightly to
# let the player know that item is in equipped.


func _on_weapon_one_button_pressed() -> void:
	print("Weapon one")


func _on_weapon_two_button_pressed() -> void:
	print("Weapon two")


func _on_weapon_three_button_pressed() -> void:
	print("Weapon three")


func _on_weapon_four_button_pressed() -> void:
	print("Weapon four")


func _on_weapon_five_button_pressed() -> void:
	print("Weapon five")
