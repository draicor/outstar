package objects

// Every object should implement these
type Object interface {
	GetRotation() float64          // Returns this object's model look at rotation
	GetGridPosition() *Cell        // Returns the cell where this object is
	SetGridPosition(cell *Cell)    // Updates this object's grid cell position
	GetGridDestination() *Cell     // Returns the cell where the object wants to move
	SetGridDestination(cell *Cell) // Updates this object's grid destination cell
	GetGridPath() []*Cell          // Returns this object's path
	SetGridPath([]*Cell)           // Updates this object's grid path
}

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

type Player struct {
	Name string
	// Model string // Determines which model should godot load
	RegionId uint64
	// Position
	Position  *Cell   // Where this player is
	RotationY float64 // Model look at rotation
	// Pathfinding
	Destination *Cell // Where the player wants to go
	Path        []*Cell
	// Stats
	Level      uint64
	Experience uint64
	// Attributes
}

// Returns this object's model look at rotation
func (player *Player) GetRotation() float64 {
	return player.RotationY
}

// Returns the cell where this object is
func (player *Player) GetGridPosition() *Cell {
	return player.Position
}

// Updates this object's grid cell position
func (player *Player) SetGridPosition(cell *Cell) {
	player.Position = cell
}

// Returns the cell where the object wants to move
func (player *Player) GetGridDestination() *Cell {
	return player.Destination
}

// Updates this object's grid destination cell
func (player *Player) SetGridDestination(cell *Cell) {
	player.Destination = cell
}

// Returns this object's path
func (player *Player) GetGridPath() []*Cell {
	return player.Path
}

// Updates this object's grid path
func (player *Player) SetGridPath(newPath []*Cell) {
	player.Path = newPath
}

// Static function to create a new player
func CreatePlayer(
	name string,
	regionId uint64,
	rotationY float64,
	// Stats
	level uint64,
	experience uint64,
	// Atributes
) *Player {
	return &Player{
		Name:     name,
		RegionId: regionId,
		// Position
		Position:  nil,
		RotationY: rotationY, // Look at direction
		// Stats
		Level:      level,
		Experience: experience,
		// Attributes
	}
}

// Returns the absolute value of an integer
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

// Returns the minimum value among two integers
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// Calculates the heuristic cost between two positions
func CalculateHeuristic(aX, aZ, bX, bZ int) int {
	dx := abs(aX - bX)
	dz := abs(aZ - bZ)
	return 10*(dx+dz) + (14-20)*min(dx, dz) // Diagonal shortcut
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
