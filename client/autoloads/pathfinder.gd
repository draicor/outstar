extends Node

# Static cache for reusable objects
static var _cache := {
	"open_set": PriorityQueue.new(),
	"closed_set": {},
	"open_set_map": {},
}


# Returns our cache after reset, without extra reallocation of memory
static func _get_reusable_objects() -> Dictionary:
	# Reset cached objects
	_cache.open_set.clear()
	_cache.closed_set.clear()
	_cache.open_set_map.clear()
	# Return a copy to avoid thread conflicts
	return _cache.duplicate()


# Same heuristic as server, diagonal shortcut
static func calculate_heuristic(a: Vector2i, b: Vector2i) -> int:
	var dx = absi(a.x - b.x)
	var dz = absi(a.y - b.y)
	return 10 * (dx + dz) + (14 - 20) * mini(dx, dz)


# Get neighbors (8-directional)
static func get_neighbors(cell: Vector2i, grid_width: int, grid_height: int) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue # Skip self
			var x = cell.x + dx
			var z = cell.y + dz
			if x >= 0 and x < grid_width and z >= 0 and z < grid_height:
				neighbors.append(Vector2i(x, z))
	
	return neighbors


# Reconstruct path from goal to start
static func _reconstruct_path(end_node: AStarNode) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = end_node
	while current != null:
		path.append(Vector2i(current.cell.x, current.cell.z))
		current = current.parent
	path.reverse()
	return path


# A* Pathfinding Algorithm
# Returns a path as an array Vector2i or an empty array if no path was valid
static func find_path(start: Vector2i, goal: Vector2i, grid_width: int, grid_height: int) -> Array[Vector2i]:
	# We get our objects from our cache so we don't reallocate resources
	var cache = _get_reusable_objects()
	var open_set: PriorityQueue = cache.open_set
	var closed_set: Dictionary = cache.closed_set # Dictionary[Vector2i: AStarNode]
	var open_set_map: Dictionary = cache.open_set_map # Dictionary[Vector2i: AStarNode]
	
	# Make the start cell our start node and calculate costs
	var start_node = AStarNode.new(
		Cell.new(start.x, start.y),
		null,
		0,
		calculate_heuristic(start, goal)
	)
	open_set.push(start_node)
	open_set_map[start] = start_node
	
	# While we still have nodes to check in our open set
	while not open_set.is_empty():
		# Get the node with the lowest F cost in our open set (it removes it from the open set)
		var current = open_set.pop()
		var current_pos = Vector2i(current.cell.x, current.cell.z)
		
		# Goal reached
		if current_pos == goal:
			return _reconstruct_path(current)
		
		# Move the current node from the open set to the closed set
		closed_set[current_pos] = current
		# Remove from the open set map
		open_set_map.erase(current_pos)
		
		# Explore neighbors
		for neighbor_pos in get_neighbors(current_pos, grid_width, grid_height):
			# Skip if the cell is already in the closed set OR if the cell is not reachable OR if the cell is occupied
			if neighbor_pos in closed_set:
				continue
			if not RegionManager.is_cell_reachable(neighbor_pos):
				continue
			if not RegionManager.is_cell_available(neighbor_pos) and neighbor_pos != goal:
				continue
			
			# Cost calculation (10 for straight, 14 for diagonal)
			var is_diagonal = (neighbor_pos.x != current_pos.x) and (neighbor_pos.y != current_pos.y)
			var move_cost = 14 if is_diagonal else 10
			var tentative_g = current.g + move_cost
			
			# Check if neighbor is in open set
			var neighbor_node = open_set_map.get(neighbor_pos)
			# If its NOT in the open set map OR we updated the G cost of that node
			if neighbor_node == null or tentative_g < neighbor_node.g:
				# If the node is NOT in the open set map
				if neighbor_node == null:
					# We create the node and add it to the open set map
					neighbor_node = AStarNode.new(
						Cell.new(neighbor_pos.x, neighbor_pos.y),
						current,
						tentative_g,
						calculate_heuristic(neighbor_pos, goal)
					)
					open_set_map[neighbor_pos] = neighbor_node
				else:
					neighbor_node.parent = current
					neighbor_node.g = tentative_g
					neighbor_node.f = neighbor_node.g + neighbor_node.h
				
				open_set.push(neighbor_node)
	
	# If we got here, then no valid path found
	return []
