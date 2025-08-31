extends Node3D

@onready var label_3d: Label3D = $Label3D

@export var text: String = "":
	set(value):
		text = value
		if label_3d:
			label_3d.text = value

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		if label_3d:
			label_3d.modulate = value

@export var size: int = 10:
	set(value):
		size = value
		if label_3d:
			label_3d.font_size = value


var velocity: Vector3 = Vector3.ZERO
var gravity: float = -3.0
var lifetime: float = 1.0 # 1 second to fade away
var current_time: float = 0.0
var initial_velocity: Vector3 = Vector3(0, 2.0, 0)


func _ready() -> void:
	hide()


func _process(delta: float) -> void:
	current_time += delta
	# Apply gravity
	velocity.y += gravity * delta
	# Move the number
	position += velocity * delta
	# Fade out over time
	var alpha = 1.0 - (current_time / lifetime)
	label_3d.modulate.a = alpha
	# Remove when lifetime is over
	if current_time > lifetime:
		hide()
