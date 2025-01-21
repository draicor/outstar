package objects

type Character struct {
	Name string
	// Transforms
	X         float64
	Y         float64 // Up
	Z         float64 // Forward
	Direction float64
	Speed     float64
	// Add stats here
	Level      uint64
	Experience uint64
}

// Static function to create a new character
func NewCharacter(name string) *Character {
	return &Character{
		Name:       name,
		Level:      1,
		Experience: 0,
	}
}

// Returns this character's name
func (c *Character) GetName() string {
	return c.Name
}
