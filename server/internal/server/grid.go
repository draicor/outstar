package server

import (
	"server/internal/server/objects"
)

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
