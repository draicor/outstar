package objects

// Every object should implement these
type Object interface {
	GetRotation() float64          // Model look at rotation
	GetRadius() uint64             // Simplified radius of this object (used in collisions)
	GetGridPosition() *Cell        // Returns the cell where this object is
	SetGridPosition(cell *Cell)    // Updates this object's grid cell position
	GetGridDestination() *Cell     // Returns the cell where the object wants to move
	SetGridDestination(cell *Cell) // Updates this object's grid destination cell
}

type Cell struct {
	X         uint64 // Left/Right
	Z         uint64 // Forward/Backward
	Reachable bool   // Wether this cell can be reached/stepped onto
	Object    Object // Generic interface object
}

type Player struct {
	Name string
	// Model string // Determines which model should godot load
	RegionId uint64
	// Position
	Position  *Cell   // Where this player is
	RotationY float64 // Model look at rotation
	Radius    uint64  // Radius used for collisions
	// Destination
	Destination *Cell // Where the player wants to go
	// Stats
	Level      uint64
	Experience uint64
	// Attributes
}

func (player *Player) GetRotation() float64 {
	return player.RotationY
}

func (player *Player) GetRadius() uint64 {
	return player.Radius
}

func (player *Player) GetGridPosition() *Cell {
	return player.Position
}

func (player *Player) SetGridPosition(cell *Cell) {
	player.Position = cell
}

func (player *Player) GetGridDestination() *Cell {
	return player.Destination
}

func (player *Player) SetGridDestination(cell *Cell) {
	player.Destination = cell
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
