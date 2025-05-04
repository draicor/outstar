class_name Cell
extends RefCounted

var x: int # left/right position
var z: int # forward/backward position
var reachable: bool # Whether this cell is walkable
var object: Object # Reference to a generic occupying object


func _init(_x: int, _z: int, _reachable: bool = true):
	x = _x
	z = _z
	reachable = _reachable
	object = null
