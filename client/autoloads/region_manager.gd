extends Node

# Game regions
enum Maps {
	NONE = 0,
	PROTOTYPE,
	MAZE,
}
var maps_scenes: Dictionary[Maps, String] = {
	Maps.PROTOTYPE: "res://maps/prototype/prototype.tscn",
	Maps.MAZE: "res://maps/prototype/maze.tscn",
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
	# Clear existing objects
	for cell in _grid:
		cell.object = null
	
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


# Returns the first valid cell position
func get_available_positions_around_target(start_position: Vector2i, target_position: Vector2i, relative_positions: Array[Vector2i]) -> Vector2i:
	var valid_positions: Array[Vector2i] = []
	
	# First pass: collect all valid positions
	# Convert relative positions around target to absolute grid positions
	for relative_position in relative_positions:
		var absolute_position: Vector2i = target_position + relative_position
		# Special case: current start_position is always considered valid
		if start_position == absolute_position:
			# Immediately return if we are already at a valid position
			return absolute_position
			
		if is_cell_reachable(absolute_position) and is_cell_available(absolute_position):
			valid_positions.append(absolute_position)
	
	# If none available, return zero
	if valid_positions.is_empty():
		return Vector2i.ZERO
	
	# Second pass: find nearest valid position to start_position
	var nearest_position: Vector2i = valid_positions[0]
	var min_distance: int = start_position.distance_squared_to(nearest_position)
	
	# Go over each valid position and check which one is closer to our start_position
	for pos in valid_positions.slice(1): # Skip first cell since we already have it
		var distance: int = start_position.distance_squared_to(pos)
		if distance < min_distance and RegionManager.is_cell_available(pos):
			min_distance = distance
			nearest_position = pos
	
	return nearest_position


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


# Removes the object passed from this cell
func remove_object(cell: Vector2i) -> void:
	if not is_in_grid(cell):
		return
	
	var index = cell.y * grid_width + cell.x
	_grid[index].object = null
