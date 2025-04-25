package pathfinding

import (
	"container/heap"
	"server/internal/server/math"
)

// Every object that can be placed in the grid should implement these
type Object interface {
	GetRotation() float64          // Returns this object's model look at rotation
	GetGridPosition() *Cell        // Returns the cell where this object is
	SetGridPosition(cell *Cell)    // Updates this object's grid cell position
	GetGridDestination() *Cell     // Returns the cell where the object wants to move
	SetGridDestination(cell *Cell) // Updates this object's grid destination cell
}

// Represents a node in the priority queue
type PriorityNode struct {
	Node     *Node // Element that holds our node
	Priority int   // The priority of the Node in the queue (F cost)
	Index    int   // Index of this element in the heap
}

// Implements heap.Interface and holds items
// Represents a min heap priority queue made up of Nodes with a priority
type PriorityQueue []*PriorityNode

// Returns the length of the queue
func (pq PriorityQueue) Len() int {
	return len(pq)
}

// Returns true if the first element has a lower priority than the second element
// (lower F cost has higher priority)
func (pq PriorityQueue) Less(i, j int) bool {
	return pq[i].Priority < pq[j].Priority
}

// Swaps two elements in the queue
func (pq PriorityQueue) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
	pq[i].Index = i
	pq[j].Index = j
}

// Pushes an element to the end of the queue
func (pq *PriorityQueue) Push(x interface{}) {
	n := len(*pq)
	element := x.(*PriorityNode)
	element.Index = n
	*pq = append(*pq, element)
}

// Returns the last element in the queue, removing it from the queue
func (pq *PriorityQueue) Pop() interface{} {
	// Creates a copy of the queue
	old := *pq
	// Gets the last element in the queue
	n := len(old)
	element := old[n-1]
	// Deletes the index in the element for safety so we don't try to access it
	element.Index = -1
	// Deletes the last element in the queue
	*pq = old[0 : n-1]
	// Returns the element removed from the queue
	return element
}

// A square cell in the game grid
type Cell struct {
	X         uint64 // Left/Right
	Z         uint64 // Forward/Backward
	Reachable bool   // Whether this cell can be reached/stepped onto
	Object    Object // Generic interface object
}

// A single node in the A* algorithm
type Node struct {
	Cell   *Cell // Position in the grid
	Parent *Node // Pointer to this Node's parent, if its not the first node in the list
	G      int   // Cost from start position to this node
	H      int   // Heuristic cost from current position to goal
	F      int   // Total cost (G + H)
}

// 2D game grid represented as a 1D map
type Grid struct {
	maxWidth  uint64           // X axis size
	maxHeight uint64           // Z axis size
	length    uint64           // 2d array length as a 1d array (maxWidth * maxHeight)
	cells     map[uint64]*Cell // A hash map between the 1d index and each cell in the 2d world
}

// Returns the max width of this grid (X axis)
func (grid *Grid) GetMaxWidth() uint64 {
	return grid.maxWidth
}

// Returns the max height of this grid (Z axis)
func (grid *Grid) GetMaxHeight() uint64 {
	return grid.maxHeight
}

// Returns the length of this grid as a 1D array
func (grid *Grid) GetLength() uint64 {
	return grid.length
}

// Returns the hash map between the 1D index and each cell in the 2D grid
func (grid *Grid) GetCells() map[uint64]*Cell {
	return grid.cells
}

// Transforms a point in space to a coordinate in the grid
func (grid *Grid) LocalToMap(x, z uint64) *Cell {
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

func (grid *Grid) IsCellReachable(cell *Cell) bool {
	if cell != nil {
		// Check if the cell is reachable
		if cell.Reachable {
			return true
		}
	}

	return false // Cell is not reachable
}

func (grid *Grid) IsCellAvailable(cell *Cell) bool {
	if cell != nil {
		// Check if the cell is available
		if cell.Object == nil {
			return true
		}
	}

	return false // Cell is already occupied
}

// Returns the cell at that point in space if the cell is reachable, even if its occupied
func (grid *Grid) GetCell(x uint64, z uint64) *Cell {
	// Get the grid cell at this point
	cell := grid.LocalToMap(x, z)
	// If cell is reachable
	if grid.IsCellReachable(cell) {
		return cell
	}

	return nil // Cell not valid
}

// Returns the cell at that point in space if the cell is reachable and unoccupied
func (grid *Grid) GetValidCell(x uint64, z uint64) *Cell {
	// Get the grid cell at this point
	cell := grid.LocalToMap(x, z)
	// If cell is both reachable and available, the nits valid
	if grid.IsCellReachable(cell) && grid.IsCellAvailable(cell) {
		return cell
	}

	return nil // Cell not valid or already occupied
}

// Used only to spawn the player
func (grid *Grid) GetSpawnCell(startX uint64, startZ uint64) *Cell {
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
func (grid *Grid) SetObject(targetCell *Cell, object Object) {
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
func (grid *Grid) GetNeighbors(cell *Cell, size int) []*Cell {
	// If size passed is less than 1
	if size < 1 {
		// Make the minimum size permitted to be 1
		size = 1
	}

	// Initialize an empty array of pointers to Cell
	neighbors := []*Cell{}

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
					// Get the neighbor AFTER checking if its occupied
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
func (grid *Grid) AStar(start *Cell, goal *Cell) []*Cell {
	// We have two sets, one has nodes to check and the other nodes that have been revised
	openSet := make(PriorityQueue, 0)
	heap.Init(&openSet)

	closedSet := make(map[*Cell]*Node)

	// Make the start cell our start node and calculate costs
	startNode := &Node{
		Cell: start,
		G:    0,
		H:    CalculateHeuristic(int(start.X), int(start.Z), int(goal.X), int(goal.Z)),
	}
	startNode.F = startNode.G + startNode.H
	// Add it to our open set
	heap.Push(&openSet, &PriorityNode{Node: startNode, Priority: startNode.F})

	// Track nodes in the open set using a map
	openSetMap := make(map[*Cell]*Node)
	openSetMap[start] = startNode

	// While we still have nodes to check in our open set
	for openSet.Len() > 0 {
		// Get the node with the lowest F cost in our open set (it removes it from the open set)
		lowestElement := heap.Pop(&openSet).(*PriorityNode)
		current := lowestElement.Node

		// If the current node is the goal node
		if current.Cell == goal {
			// Reconstruct and return the path
			return ReconstructPath(current)
		}

		// Move the current node from the open set to the closed set
		closedSet[current.Cell] = current
		// Remove from the open set map
		delete(openSetMap, current.Cell)

		// Explore the neighbors next to our current cell (up to 1 cell away from our current cell)
		for _, neighborCell := range grid.GetNeighbors(current.Cell, 1) {
			// Skip if the cell is already in the closed set OR if the cell is not reachable OR if the cell is occupied
			if _, exists := closedSet[neighborCell]; exists || !grid.IsCellReachable(neighborCell) || !grid.IsCellAvailable(neighborCell) {
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
			neighborNode, exists := openSetMap[neighborCell]
			// If its NOT in the open set map OR we updated the G cost of that node
			if !exists || tentativeG < neighborNode.G {
				// If the node is NOT in the open set map
				if !exists {
					// We create the node
					neighborNode = &Node{Cell: neighborCell}
					// We add it to the open set map
					openSetMap[neighborCell] = neighborNode
				}
				// Calculate the data for this neighbor node
				neighborNode.Parent = current
				neighborNode.G = tentativeG
				neighborNode.H = CalculateHeuristic(int(neighborCell.X), int(neighborCell.Z), int(goal.X), int(goal.Z))
				neighborNode.F = neighborNode.G + neighborNode.H
				// Add the neighbor to our open set
				heap.Push(&openSet, &PriorityNode{Node: neighborNode, Priority: neighborNode.F})
			}
		}
	}

	// If the open set is empty and the goal was not reached, return an empty array
	return []*Cell{}
}

// Creates and initializes an empty grid
func CreateGrid(maxWidth uint64, maxHeight uint64) *Grid {
	length := maxWidth * maxHeight
	// Create an empty map with an initial value equal to the length
	emptyCells := make(map[uint64]*Cell, length)

	// Go over a virtual two dimensional array, cell by cell
	for row := range maxHeight {
		for col := range maxWidth {

			// Transform the 2D point into a 1D index and use it as the key
			// Z * MAXWIDTH + X
			key := row*maxWidth + col

			// Initialize the cell with the X and Z coordinates
			emptyCells[key] = &Cell{
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

// Calculates the heuristic cost between two positions
func CalculateHeuristic(aX, aZ, bX, bZ int) int {
	dx := math.Absolute(aX - bX)
	dz := math.Absolute(aZ - bZ)
	return 10*(dx+dz) + (14-20)*math.Minimum(dx, dz) // Diagonal shortcut
}

// Returns an array of pointers to Cell,
// from the last Node in a path all the way up to the first node
func ReconstructPath(node *Node) []*Cell {
	// Initialize an empty array of pointers to Cell that will hold our path
	path := []*Cell{}

	// As long as the current node is valid
	for node != nil {
		// Add it to our path
		path = append(path, node.Cell)
		// Make our next node be the parent of our current node
		node = node.Parent
	}

	// Reverse the path to get it from start to end
	for start, end := 0, len(path)-1; start < end; start, end = start+1, end-1 {
		path[start], path[end] = path[end], path[start]
	}
	return path
}
