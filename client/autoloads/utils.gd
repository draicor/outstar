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
