package objects

type Player struct {
	Name     string
	RegionId uint64
	// Position
	X         float64
	Y         float64 // Up
	Z         float64 // Forward
	RotationY float64 // Model look at rotation
	// Movement
	VelocityX float64 // Calculated from input in the client (X axis is left/right)
	VelocityY float64 // Calculated from input in the client (Y axis is vertical)
	VelocityZ float64 // Calculated from input in the client (Z axis is forward/backward)
	Speed     float64 // Player character movement speed set by the server
	// Stats
	Level      uint64
	Experience uint64
	// Attributes
}

// Static function to load a new player
func LoadPlayer(
	name string, regionId uint64,
	// Position
	x float64, y float64, z float64, rotationY float64,
	// Movement
	velocityX float64, velocityY float64, velocityZ float64, speed float64,
	// Stats
	level uint64, experience uint64,
	// Atributes
) *Player {
	return &Player{
		Name:     name,
		RegionId: regionId,
		// Position
		X:         x,         // Default spawn location
		Y:         y,         // Elevation
		Z:         z,         // Default spawn location
		RotationY: rotationY, // Look at direction
		// Movement
		VelocityX: velocityX, // Input velocity
		VelocityY: velocityY, // Input velocity
		VelocityZ: velocityZ, // Input velocity
		Speed:     speed,     // Movement constant speed
		// Stats
		Level:      level,
		Experience: experience,
		// Attributes
	}
}
