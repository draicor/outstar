package objects

import (
	"math"
	"server/internal/server/pathfinding"
)

const (
	MAX_SPEED uint64  = 3
	NORTH     float64 = math.Pi          // 180°
	SOUTH     float64 = 0                // 0°
	EAST      float64 = math.Pi / 2      // 90°
	WEST      float64 = -math.Pi / 2     // -90°
	NORTHEAST float64 = 3 * math.Pi / 4  // 135°
	NORTHWEST float64 = -3 * math.Pi / 4 // -135°
	SOUTHEAST float64 = math.Pi / 4      // 45°
	SOUTHWEST float64 = -math.Pi / 4     // -45°
)

type Player struct {
	Name string
	// Model string // Determines which model should godot load
	regionId uint64 // Which server region this player is at
	mapId    uint64 // Which map file should this client load
	// Character
	gender string
	// Position
	Position  *pathfinding.Cell // Where this player is
	RotationY float64           // Model look at rotation
	// Pathfinding
	Destination *pathfinding.Cell // Where the player wants to go
	// Stats
	Level      uint64
	Experience uint64
	// Attributes
	speed uint64 // Cells per tick
}

// RegionId get/set
func (player *Player) GetRegionId() uint64 {
	return player.regionId
}
func (player *Player) SetRegionId(regionId uint64) {
	player.regionId = regionId
}

// MapId get/set
func (player *Player) GetMapId() uint64 {
	return player.mapId
}
func (player *Player) SetMapId(mapId uint64) {
	player.mapId = mapId
}

// Model look at rotation get/set
func (player *Player) GetRotation() float64 {
	return player.RotationY
}
func (player *Player) SetRotation(newRotation float64) {
	player.RotationY = newRotation
}

// Grid Position get/set
func (player *Player) GetGridPosition() *pathfinding.Cell {
	return player.Position
}
func (player *Player) SetGridPosition(cell *pathfinding.Cell) {
	player.Position = cell
}

// Grid Destination get/set
func (player *Player) GetGridDestination() *pathfinding.Cell {
	return player.Destination
}
func (player *Player) SetGridDestination(cell *pathfinding.Cell) {
	player.Destination = cell
}

// Move speed get/set
func (player *Player) GetSpeed() uint64 {
	return player.speed
}
func (player *Player) SetSpeed(newSpeed uint64) {
	// If trying to move faster than allowed
	player.speed = min(newSpeed, MAX_SPEED)
}

// Gender get/set
func (player *Player) GetGender() string {
	return player.gender
}
func (player *Player) SetGender(newGender string) {
	player.gender = newGender
}

// Static function to create a new player
func CreatePlayer(
	name string,
	gender string,
	speed uint64,
	rotationY float64,
	// Stats
	level uint64,
	experience uint64,
	// Atributes
) *Player {
	return &Player{
		Name:   name,
		gender: gender,
		// Position
		Position:  nil,
		RotationY: rotationY, // Look at direction
		// Stats
		Level:      level,
		Experience: experience,
		// Attributes
		speed: speed,
	}
}

// Calculate rotation from movement vector
func (player *Player) CalculateRotation(currentCell, nextCell *pathfinding.Cell) {
	var dx int64 = int64(nextCell.X - currentCell.X)
	var dz int64 = int64(nextCell.Z - currentCell.Z)

	// Map direction vector to rotation
	switch {
	// North
	case dx == 0 && dz < 0:
		player.SetRotation(NORTH)
	// South
	case dx == 0 && dz > 0:
		player.SetRotation(SOUTH)
	// East
	case dx > 0 && dz == 0:
		player.SetRotation(EAST)
	// West
	case dx < 0 && dz == 0:
		player.SetRotation(WEST)
	// North-East
	case dx > 0 && dz < 0:
		player.SetRotation(NORTHEAST)
	// North-West
	case dx < 0 && dz < 0:
		player.SetRotation(NORTHWEST)
	// South-East
	case dx > 0 && dz > 0:
		player.SetRotation(SOUTHEAST)
	// South-West
	case dx < 0 && dz > 0:
		player.SetRotation(SOUTHWEST)
	}
}
