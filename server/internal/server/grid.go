package server

import (
	"server/internal/server/objects"
)

type Grid struct {
	max_width  uint64                   // X axis size
	max_height uint64                   // Z axis size
	length     uint64                   // 2d array length as a 1d array (max_width * max_height)
	cells      map[uint64]*objects.Cell // A hash map between the 1d index and each cell in the 2d world
}

// Transforms a 2D point into a pointer to a cell in the grid
func (grid *Grid) GetCell(x uint64, z uint64) *objects.Cell {
	// If the player clicked past the max grid width, abort
	if x >= grid.max_width {
		return nil
	}
	// If the player clicked past the max grid height, abort
	if z >= grid.max_height {
		return nil
	}
	// Convert the 2d point into a 1d index
	var index uint64 = grid.max_width*z + x
	// If the index is past the 1d array length, abort
	if index > grid.length {
		return nil
	}

	// If the index is valid, we get the cell at that index and return it
	return grid.cells[index]
}

func (grid *Grid) GetValidatedCell(x uint64, z uint64) *objects.Cell {
	// Get from the grid the cell we need
	cell := grid.GetCell(x, z)

	// If the cell is valid
	if cell != nil {
		// If the cell is reachable
		if cell.Reachable {
			// If the cell is empty
			if cell.Object == nil {
				return cell
			} else {
				// Cell is occupied
				return nil
			}
		} else {
			// Cell is valid but not reachable
			println("Cell is valid but not reachable")
			return nil
		}
	} else {
		// Invalid cell
		return nil
	}
}

// Sets the object to a cell in the grid
func (grid *Grid) SetObject(targetCell *objects.Cell, object objects.Object) {
	// If cell is not valid, abort
	if targetCell == nil {
		return
	}

	// Get the current cell the object is at
	oldX := object.GetX()
	oldZ := object.GetZ()
	oldCell := grid.GetCell(oldX, oldZ)
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
func CreateGrid(max_width uint64, max_height uint64) *Grid {
	length := max_width * max_height
	// Create an empty map with an initial value equal to the length
	emptyCells := make(map[uint64]*objects.Cell, length)

	// Go over a virtual two dimensional array, cell by cell
	for row := range max_height {
		for col := range max_width {

			// Transform the 2D point into a 1D index and use it as the key
			// Z * MAX_WIDTH + X
			key := row*max_width + col

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
		max_width:  max_width,              // X axis
		max_height: max_height,             // Z axis
		length:     max_width * max_height, // Number of cells in 1D
		cells:      emptyCells,             // Grid made up of empty cells
	}
}
