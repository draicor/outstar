extends Node

# Constants
const CELL_SIZE = 1.0 # 1 meter width and height
const CELL_RADIUS = CELL_SIZE/2 # Distance to the center of each cell

# Transforms a point in space to a coordinate in our map
func local_to_map(point: Vector3) -> Vector2i:
	return Vector2i(floor(point.x), floor(point.z))

# Transforms a coordinate in our map to a point in space
func map_to_local(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) + CELL_RADIUS, 0, float(cell.y) + CELL_RADIUS)

# Retrieves and removes multiple elements from the front of an array.
func pop_multiple_front(array: Array, end: int) -> Array:
	# If the original array is empty or we try to use 0 or a negative number
	if array.is_empty() or end <= 0:
		return array
	
	# Store the elemnts we want to return
	var taken : Array = array.slice(0, end)
	# Store the remaining elements before clearing the array
	var remaining_elements = array.slice(end)
	# Clear the original array and then refill it with the remaining elements
	array.clear()
	array.append_array(remaining_elements)
	
	return taken
