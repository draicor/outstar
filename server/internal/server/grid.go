package server

import "server/internal/server/objects"

type Grid struct {
	maxWidth  uint64                   // X axis size
	maxHeight uint64                   // Z axis size
	length    uint64                   // 2d array length as a 1d array (maxWidth * maxHeight)
	cells     map[uint64]*objects.Cell // A hash map between the 1d index and each cell in the 2d world
}

// Transforms a point in space to a coordinate in the grid
func (grid *Grid) LocalToMap(x, z uint64) *objects.Cell {
	// Clamp the x value
	if x >= grid.maxWidth {
		x = grid.maxWidth - 1
	}
	// Clamp the z value
	if z >= grid.maxHeight {
		z = grid.maxHeight - 1
	}

	// Convert the 2d point into a 1d index
	var index uint64 = grid.maxWidth*z + x
	// If the index is past the 1d array length, abort
	if index > grid.length {
		return nil
	}

	// If the index is valid, we get the cell at that index and return it
	return grid.cells[index]
}

func (grid *Grid) IsValidCell(cell *objects.Cell) bool {
	if cell != nil {
		// Check if the cell is reachable and available
		if cell.Reachable && cell.Object == nil {
			return true
		}
	}

	return false // Cell is not valid or already occupied
}

// Gets the cell at that point in space if the cell is reachable and unoccupied
func (grid *Grid) GetValidCell(x uint64, z uint64) *objects.Cell {
	// Get the grid cell at this point
	cell := grid.LocalToMap(x, z)
	// If valid, return it
	if grid.IsValidCell(cell) {
		return cell
	}

	return nil // Cell not valid or already occupied
}

// Used only to spawn the player
func (grid *Grid) GetSpawnCell(startX uint64, startZ uint64) *objects.Cell {
	// Keeps track of whether we have looped back into the starting cell
	hasLoopedBack := false

	// Clamp the starting coordinates so they are within the grid
	// Clamp the x value
	if startX >= grid.maxWidth {
		startX = grid.maxWidth - 1
	}
	// Clamp the z value
	if startZ >= grid.maxHeight {
		startZ = grid.maxHeight - 1
	}

	// Start at the target cell
	x, z := startX, startZ
	var directionX int = 1 // 1 = left-to-right, -1 = right-to-left
	var directionZ int = 1 // 1 = top-to-bottom, -1 = bottom-to-top

	// Endless loop until we find valid cell
	for {
		cell := grid.GetValidCell(x, z)
		// If cell is valid, use it to spawn our character
		if cell != nil {
			return cell
		}

		// Cell was not available, move to the next cell
		signed_x := int(x)
		signed_x += directionX
		x = uint64(signed_x)

		// If X reached the end of the grid
		if x >= grid.maxWidth {
			// Reverse directionX and get back into the grid
			directionX *= -1
			signed_x = int(x)
			signed_x += directionX
			x = uint64(signed_x) // x only allows unsigned int

			// Move to the next row
			signed_z := int(z)
			signed_z += directionZ
			z = uint64(signed_z)

			// If z reached the end of the grid
			if z >= grid.maxHeight {
				// Reverse directionZ and get back into the grid
				directionZ *= -1
				signed_z += directionZ
				z = uint64(signed_z)
			}
		}

		// If we looped back to the starting cell
		if x == startX && z == startZ {
			// If this is the second time we reach the start, break out
			if hasLoopedBack {
				break
			}
			// If this is the first time, we mark it and we keep going
			hasLoopedBack = true
			continue
		}
	}

	return nil // No available cell found
}

// Sets the object to a cell in the grid
// If we pass a nil object, it will free the cell in the grid
func (grid *Grid) SetObject(targetCell *objects.Cell, object objects.Object) {
	// If cell is not valid, abort
	if targetCell == nil {
		return
	}

	// If we pass a nil pointer as an object, it means we want to free the cell
	if object == nil {
		targetCell.Object = nil
		return
	}

	oldCell := object.GetGridPosition()
	// If the previous cell is valid
	if oldCell != nil {
		// Remove the object from the previous position
		oldCell.Object = nil
	}

	// Move the object to the new position
	targetCell.Object = object

	// Overwrite the object's position
	object.SetGridPosition(targetCell)
}

// Returns the neighbors around a Cell in the grid
// If size is 1, it will get an area of 3x3
// If size is 2, it will get an area of 5x5
// If size is 3, it will get an area of 7x7
func (grid *Grid) GetNeighbors(cell *objects.Cell, size int) []*objects.Cell {
	// If size passed is less than 1
	if size < 1 {
		// Make the minimum size permitted to be 1
		size = 1
	}

	// Initialize an empty array of pointers to Cell
	neighbors := []*objects.Cell{}

	// Iterate over an area around the cell
	for dx := -size; dx <= size; dx++ {
		for dz := -size; dz <= size; dz++ {
			// Skip the current cell
			if dx == 0 && dz == 0 {
				continue
			}

			// Cast to unsigned int
			x := cell.X + uint64(dx)
			z := cell.Z + uint64(dz)

			// Check if the neighbor is within the grid bounds
			if x < grid.maxWidth {
				if z < grid.maxHeight {
					// Check if the neighbor is reachable and unoccupied
					cell := grid.GetValidCell(x, z)
					// If the cell is valid
					if cell != nil {
						// Add it to the list of neighbors
						neighbors = append(neighbors, cell)
					}
				}
			}
		}
	}
	return neighbors
}

// A* Pathfinding Algorithm
// Returns a path as an array of pointers to Cell or an empty array if no path was valid
func (grid *Grid) AStar(start, goal *objects.Cell) []*objects.Cell {
	// We have two sets, one has nodes to check and the other nodes that have been revised
	openSet := make(map[*objects.Cell]*objects.Node)
	closedSet := make(map[*objects.Cell]*objects.Node)

	// Make the start cell our start node and calculate costs
	startNode := &objects.Node{
		Cell: start,
		G:    0,
		H:    objects.CalculateHeuristic(int(start.X), int(start.Z), int(goal.X), int(goal.Z)),
	}
	startNode.F = startNode.G + startNode.H
	// Add it to our open set
	openSet[start] = startNode

	// While we still have nodes to check in our open set
	for len(openSet) > 0 {
		// Find the node with the lowest F cost in our open set
		var current *objects.Node
		for _, node := range openSet {
			if current == nil || node.F < current.F { // This always selects the lowest cost node available
				current = node
			}
		}

		// If the current node is the goal node
		if current.Cell == goal {
			// Reconstruct and return the path
			return objects.ReconstructPath(current)
		}

		// Move the current node from the open set to the closed set
		delete(openSet, current.Cell)
		closedSet[current.Cell] = current

		// Explore neighbors
		for _, neighborCell := range grid.GetNeighbors(current.Cell, 1) {
			// Skip if the neighbor is already in the closed set OR if the neighbor is not reachable or already occupied
			if _, exists := closedSet[neighborCell]; exists || !grid.IsValidCell(neighborCell) {
				continue
			}

			// Calculate tentative G cost
			tentativeG := current.G + 10 // Default cost for horizontal/vertical movement
			if neighborCell.X != current.Cell.X {
				if neighborCell.Z != current.Cell.Z {
					// Then it means the neighbor cell is diagonally from the current cell
					tentativeG = current.G + 14 // Assign the diagonal movement cost
				}
			}

			// Check if the neighbor is already in the open set
			neighborNode, exists := openSet[neighborCell]
			// If its NOT in the open set OR we updated the G cost of that node
			if !exists || tentativeG < neighborNode.G {
				// If the node is NOT in the open set
				if !exists {
					// We create the node and add it to the open set
					neighborNode = &objects.Node{Cell: neighborCell}
					openSet[neighborCell] = neighborNode
				}

				neighborNode.Parent = current
				neighborNode.G = tentativeG
				neighborNode.H = objects.CalculateHeuristic(int(neighborCell.X), int(neighborCell.Z), int(goal.X), int(goal.Z))
				neighborNode.F = neighborNode.G + neighborNode.H
			}
		}
	}

	// If the open set is empty and the goal was not reached, return an empty array
	return []*objects.Cell{}
}

// Creates and initializes an empty grid
func CreateGrid(maxWidth uint64, maxHeight uint64) *Grid {
	length := maxWidth * maxHeight
	// Create an empty map with an initial value equal to the length
	emptyCells := make(map[uint64]*objects.Cell, length)

	// Go over a virtual two dimensional array, cell by cell
	for row := range maxHeight {
		for col := range maxWidth {

			// Transform the 2D point into a 1D index and use it as the key
			// Z * MAXWIDTH + X
			key := row*maxWidth + col

			// Initialize the cell with the X and Z coordinates
			emptyCells[key] = &objects.Cell{
				X:         col,
				Z:         row,
				Reachable: true,
				Object:    nil,
			}
		}
	}

	// Returns a pointer to the newly created grid
	return &Grid{
		maxWidth:  maxWidth,             // X axis
		maxHeight: maxHeight,            // Z axis
		length:    maxWidth * maxHeight, // Number of cells in 1D
		cells:     emptyCells,           // Grid made up of empty cells
	}
}
