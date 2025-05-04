extends Node

# Game regions
enum Maps {
	NONE = 0,
	PROTOTYPE,
}
var maps_scenes: Dictionary[Maps, String] = {
	Maps.PROTOTYPE: "res://maps/prototype/prototype.tscn"
}

# Expose the current region's data globally
var region_id: int
var grid_width: int
var grid_height: int
var _grid: Array[Cell] = []

# Used to update/overwite our current region data
func update_region_data(new_region_id: int, max_width: int, max_height: int) -> void:
	region_id = new_region_id
	initialize_grid(max_width, max_height)


func initialize_grid(max_width: int, max_height: int) -> void:
	grid_width = max_width
	grid_height = max_height
	_grid = [] # Reset the grid
	_grid.resize(grid_width * grid_height)

	for z in grid_height:
		for x in grid_width:
			var index = z * grid_width + x
			_grid[index] = Cell.new(x, z, true) # All cells reachable by default


# Returns true if the cell is inside the grid
func is_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height


# Returns true if the cell is walkable
func is_cell_reachable(cell: Vector2i) -> bool:
	if not is_in_grid(cell):
		return false
	var index = cell.y * grid_width + cell.x
	return _grid[index].reachable


# Returns true if the cell is not occupied by another object
func is_cell_available(cell: Vector2i) -> bool:
	if not is_in_grid(cell):
		return false
	var index = cell.y * grid_width + cell.x
	return _grid[index].object == null


# If the cell is valid, returns the object at that position, else return null
func get_object(cell: Vector2i) -> Object:
	if is_in_grid(cell):
		var index = cell.y * grid_width + cell.x
		return _grid[index].object
	return null


# Attempts to place the object passed into the cell specified
func set_object(cell: Vector2i, object: Object) -> void:
	if is_cell_reachable(cell) and is_cell_available(cell):
		var index = cell.y * grid_width + cell.x
		_grid[index].object = object


# Attempts to remove the object passed from this cell
func remove_object(cell: Vector2i, object: Object) -> void:
	if is_in_grid(cell):
		var index = cell.y * grid_width + cell.x
		# If the object at this cell is the same as the object I want to remove
		if _grid[index].object == object:
			_grid[index].object = null
