extends Node

# Protobuf file
const packets := preload("res://packets.gd")
# Scenes
const escape_menu_scene: PackedScene = preload("res://components/escape_menu/escape_menu.tscn")
# Global Variables
var escape_menu

func _ready() -> void:
	_initialize()
	GameManager.set_state(GameManager.State.START)

func _process(_delta):
	if Input.is_action_just_pressed("ui_escape"):
		toggle_escape_menu()

func _initialize() -> void:
	# Create the escape menu
	escape_menu = escape_menu_scene.instantiate()
	add_child(escape_menu)

# If the ui_escape key is pressed, toggle the escape menu
func toggle_escape_menu() -> void:
	escape_menu.toggle()
