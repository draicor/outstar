class_name PriorityQueue
extends RefCounted

var _heap: Array = []


# Push a node with priority
func push(node: AStarNode) -> void:
	_heap.append(node)
	_heap.sort_custom(_compare_nodes)


# Pop the node with lowest F cost
func pop() -> AStarNode:
	if _heap.is_empty():
		return null
	return _heap.pop_front()


# Check if empty
func is_empty() -> bool:
	return _heap.is_empty()


# Clears the heap
func clear() -> void:
	_heap = []


# Comparator for sorting (lower F has higher priority)
func _compare_nodes(a: AStarNode, b: AStarNode) -> bool:
	return a.f < b.f
