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
var grid: Array[Object] = [] # Array of objects (any class)


# Used to update/overwite our current region data
func update_region_data(new_region_id: int, max_width: int, max_height: int) -> void:
	region_id = new_region_id
	initialize_grid(max_width, max_height)


func initialize_grid(max_width: int, max_height: int) -> void:
	grid = [] # Reset the grid
	grid_width = max_width
	grid_height = max_height
	grid.resize(grid_width * grid_height)
	# Make every cell null/empty
	for i in grid.size():
		grid[i] = null


# Returns true if the cell is inside the grid
func is_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height
	

# If the cell is valid, returns the object at that position, else return null
func get_cell(cell: Vector2i) -> Object:
	if is_in_grid(cell):
		return grid[cell.y * grid_width + cell.x] # Convert the 2d point into a 1d index
	return null


# Attempts to place the object passed into the cell specified
func set_object(cell: Vector2i, object: Object) -> void:
	if is_in_grid(cell):
		grid[cell.y * grid_width + cell.x] = object
		print("Adding object to grid at ", cell)


# Attempts to remove the object passed from this cell
func remove_object(cell: Vector2i, object: Object) -> void:
	if is_in_grid(cell):
		# If the object at this cell is the same as the object I want to remove
		if grid[cell.y * grid_width + cell.x] == object:
			grid[cell.y * grid_width + cell.x] = null
			print("Removing object from grid at ", cell)
