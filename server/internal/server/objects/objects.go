package objects

type Character struct {
	Name     string
	RegionId uint64
	// Position
	X         float64
	Y         float64 // Up
	Z         float64 // Forward
	RotationY float64 // Model look at rotation
	// Movement
	DirectionX float64 // Input sent by the client
	DirectionZ float64 // Input sent by the client
	Speed      float64 // Client movement speed set by the server
	// Stats
	Level      uint64
	Experience uint64
	// Attributes
}

// Static function to load a new character
func LoadCharacter(
	name string, regionId uint64,
	// Position
	x float64, y float64, z float64, rotationY float64,
	// Movement
	directionX float64, directionZ float64, speed float64,
	// Stats
	level uint64, experience uint64,
	// Atributes
) *Character {
	return &Character{
		Name:     name,
		RegionId: regionId,
		// Position
		X:         x,         // Default spawn location
		Y:         y,         // Elevation
		Z:         z,         // Default spawn location
		RotationY: rotationY, // Look at direction
		// Movement
		DirectionX: directionX, // InputDirection
		DirectionZ: directionZ, // InputDirection
		Speed:      speed,      // Walk speed
		// Stats
		Level:      level,
		Experience: experience,
		// Attributes
	}
}
