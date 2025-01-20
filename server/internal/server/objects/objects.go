package objects

type Character struct {
	Name       string
	Level      uint64
	Experience uint64
	// Add stats here
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
