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
	Destination *pathfinding.Cell   // Where the player wants to go
	Path        []*pathfinding.Cell // The path the player will take in a single tick
	FullPath    []*pathfinding.Cell // The full path the player will take
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

// Returns this object's path
func (player *Player) GetGridPath() []*pathfinding.Cell {
	return player.Path
}

// Updates this object's grid path
func (player *Player) SetGridPath(newPath []*pathfinding.Cell) {
	player.Path = newPath
}

// Returns this object's grid full path
func (player *Player) GetGridFullPath() []*pathfinding.Cell {
	return player.FullPath
}

// Updates this object's grid full path
func (player *Player) SetGridFullPath(newPath []*pathfinding.Cell) {
	player.FullPath = newPath
}

// Appends a new path to the end of the existent path
func (player *Player) AppendGridFullPath(newPath []*pathfinding.Cell) {
	// If we have a valid path
	if len(newPath) > 0 {
		// Append the new path to our previous path
		player.FullPath = append(player.GetGridFullPath(), newPath...)
	}
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
