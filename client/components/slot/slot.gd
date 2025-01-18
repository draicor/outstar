extends Control

@onready var portrait: TextureRect = $Button/HBoxContainer/Portrait
@onready var level: Label = $Button/HBoxContainer/VBoxContainer/Level
@onready var nickname: Label = $Button/HBoxContainer/VBoxContainer/Nickname
@onready var guild: Label = $Button/HBoxContainer/VBoxContainer/Guild

var slot_number : int

# Start hidden until we call initialize
func _init() -> void:
	hide()

# TO DO ->
# Implement a way to switch portraits too! maybe using enums instead of paths?

func initialize(
	new_slot_number: int,
	new_nickname: String,
	new_level: int, new_guild: String,
	portrait_path: String = "res://assets/icons/icon.png") -> void:
	set_slot_number(new_slot_number)
	set_nickname(new_nickname)
	set_level(new_level)
	set_guild(new_guild)
	set_portrait(portrait_path)
	show()

func set_nickname(new_nickname: String) -> void:
	nickname.text = new_nickname

func set_level(new_level: int) -> void:
	level.text = str(new_level)

func set_guild(new_guild: String) -> void:
	guild.text = new_guild

func set_portrait(path: String) -> void:
	portrait.texture = load(path)

func set_slot_number(new_slot_number: int) -> void:
	slot_number = new_slot_number

# Used to retrieve what slot the player clicked
func get_slot_number() -> int:
	return slot_number

func _on_button_pressed() -> void:
	print("Pressed to occupy slot: ", slot_number)
