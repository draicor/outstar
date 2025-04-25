package objects

import "server/internal/server/pathfinding"

type Player struct {
	Name string
	// Model string // Determines which model should godot load
	RegionId uint64
	// Position
	Position  *pathfinding.Cell // Where this player is
	RotationY float64           // Model look at rotation
	// Pathfinding
	Destination *pathfinding.Cell // Where the player wants to go
	// Stats
	Level      uint64
	Experience uint64
	// Attributes
	Speed uint64 // Cells per tick
}

// Returns this object's model look at rotation
func (player *Player) GetRotation() float64 {
	return player.RotationY
}

// Updates this object's model look at rotation
func (player *Player) SetRotation(newRotation float64) {
	player.RotationY = newRotation
}

// Returns the cell where this object is
func (player *Player) GetGridPosition() *pathfinding.Cell {
	return player.Position
}

// Updates this object's grid cell position
func (player *Player) SetGridPosition(cell *pathfinding.Cell) {
	player.Position = cell
}

// Returns the cell where the object wants to move
func (player *Player) GetGridDestination() *pathfinding.Cell {
	return player.Destination
}

// Updates this object's grid destination cell
func (player *Player) SetGridDestination(cell *pathfinding.Cell) {
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
		Speed: 3, // Humanoid characters have a max speed of 3 for movement
	}
}
