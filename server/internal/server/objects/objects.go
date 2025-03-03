package objects

type Cell struct {
	X         uint64 // Left/Right
	Z         uint64 // Forward/Backward
	reachable bool   // Wether this cell can be reached/stepped onto
}

type Player struct {
	Name     string
	RegionId uint64
	// Position
	X         uint64  // Left/Right
	Z         uint64  // Forward/Backward
	RotationY float64 // Model look at rotation
	// Destination
	DestinationX uint64 // Left/Right
	DestinationZ uint64 // Forward/Backward
	// Stats
	Level      uint64
	Experience uint64
	// Attributes
}

// Static function to create a new player
func CreatePlayer(
	name string, regionId uint64,
	// Position
	x uint64, z uint64, rotationY float64,
	// Destination
	destinationX uint64, destinationZ uint64,
	// Stats
	level uint64, experience uint64,
	// Atributes
) *Player {
	return &Player{
		Name:     name,
		RegionId: regionId,
		// Position
		X:         x,         // Default spawn location
		Z:         z,         // Default spawn location
		RotationY: rotationY, // Look at direction
		// Destination
		DestinationX: destinationX, // Target destination
		DestinationZ: destinationZ, // Target destination
		// Stats
		Level:      level,
		Experience: experience,
		// Attributes
	}
}
