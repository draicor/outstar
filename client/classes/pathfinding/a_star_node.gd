class_name AStarNode
extends RefCounted

var cell: Cell # Grid position
var parent: AStarNode # For path reconstruction
var g: int # Cost from start
var h: int # Heuristic cost to goal
var f: int # Total cost (g + h)


func _init(_cell: Cell, _parent: AStarNode = null, _g: int = 0, _h: int = 0):
	cell = _cell
	parent = _parent
	g = _g
	h = _h
	f = g + h
