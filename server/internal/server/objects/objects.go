package objects

import (
	"math"
	"server/internal/server/pathfinding"
)

const (
	MAX_SPEED        uint64  = 3
	MAX_WEAPON_SLOTS uint64  = 5
	NORTH            float64 = math.Pi          // 180°
	SOUTH            float64 = 0                // 0°
	EAST             float64 = math.Pi / 2      // 90°
	WEST             float64 = -math.Pi / 2     // -90°
	NORTHEAST        float64 = 3 * math.Pi / 4  // 135°
	NORTHWEST        float64 = -3 * math.Pi / 4 // -135°
	SOUTHEAST        float64 = math.Pi / 4      // 45°
	SOUTHWEST        float64 = -math.Pi / 4     // -45°
)

type WeaponSlot struct {
	WeaponName  string
	WeaponType  string
	DisplayName string
	Ammo        uint64
	FireMode    uint64
}

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
	speed     uint64 // Cells per tick
	health    uint64 // Current health
	maxHealth uint64 // Maximum health
	// Weapon state
	currentWeapon uint64        // Current weapon slot
	weapons       []*WeaponSlot // Array of weapon slots
	// Character state
	isCrouching bool
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

// Current weapon slot get/set
func (player *Player) GetCurrentWeapon() uint64 {
	return player.currentWeapon
}
func (player *Player) SetCurrentWeapon(slot uint64) {
	if slot < MAX_WEAPON_SLOTS {
		player.currentWeapon = slot
	}
}

// Weapon Slot get/set
func (player *Player) GetWeaponSlot(slot uint64) *WeaponSlot {
	if slot < MAX_WEAPON_SLOTS {
		return player.weapons[slot]
	}
	return nil
}
func (player *Player) SetWeaponSlot(slot uint64, weaponName, weaponType, displayName string, ammo, fireMode uint64) {
	if slot < MAX_WEAPON_SLOTS {
		player.weapons[slot] = &WeaponSlot{
			WeaponName:  weaponName,
			WeaponType:  weaponType,
			DisplayName: displayName,
			Ammo:        ammo,
			FireMode:    fireMode,
		}
	}
}

// Weapons get/set
func (player *Player) GetWeapons() *[]*WeaponSlot {
	return &player.weapons
}
func (player *Player) SetWeapons(newWeapons []*WeaponSlot) {
	player.weapons = newWeapons
}

// Current weapon ammo get/set
func (player *Player) GetCurrentWeaponAmmo() uint64 {
	return player.weapons[player.currentWeapon].Ammo
}
func (player *Player) SetCurrentWeaponAmmo(amount uint64) {
	player.weapons[player.currentWeapon].Ammo = amount
}

// Current weapon fire mode get/set
func (player *Player) GetCurrentWeaponFireMode() uint64 {
	return player.weapons[player.currentWeapon].FireMode
}
func (player *Player) SetCurrentWeaponFireMode(newFireMode uint64) {
	// TO FIX
	// I'm not checking if the new fire mode number is valid here
	player.weapons[player.currentWeapon].FireMode = newFireMode
}
func (player *Player) ToggleCurrentWeaponFireMode() {
	// If we are in semi-auto, switch to full-auto
	if player.GetCurrentWeaponFireMode() == 0 {
		player.SetCurrentWeaponFireMode(1)
	} else {
		// Switch to semi-auto
		player.SetCurrentWeaponFireMode(0)
	}
}

// Health get/set
func (player *Player) GetHealth() uint64 {
	return player.health
}
func (player *Player) SetHealth(newHealth uint64) {
	// Health shouldn't be greater than max health
	if newHealth > player.maxHealth {
		player.health = player.maxHealth
	} else {
		player.health = newHealth
	}
}

// MaxHealth get/set
func (player *Player) GetMaxHealth() uint64 {
	return player.maxHealth
}
func (player *Player) SetMaxHealth(newMaxHealth uint64) {
	player.maxHealth = newMaxHealth
	// If current health exceeds new max health, cap it
	if player.health > player.maxHealth {
		player.health = player.maxHealth
	}
}

// Health manipulation
func (player *Player) DecreaseHealth(amount uint64) {
	if amount >= player.health {
		player.health = 0
	} else {
		player.health -= amount
	}
}
func (player *Player) IncreaseHealth(amount uint64) {
	player.health += amount
	if player.health > player.maxHealth {
		player.health = player.maxHealth
	}
}

// Checks if this player is still alive
func (player *Player) IsAlive() bool {
	return player.health > 0
}

// Respawn resets the player's stats back to default
func (player *Player) Respawn(rotation float64) {
	player.health = player.maxHealth // Back to full health (could respawn with 10%?)
	player.SetCurrentWeaponAmmo(30)  // FIX THIS -> Back to full ammo
	player.RotationY = rotation      // Get the rotation from the server respawner
}

// Returns the default respawn location for this region
// We should probably set it up as a dictionary where each key is a region_id and the value
// is an array of valid respawn coordinates.
func (player *Player) GetRespawnLocation() (uint64, uint64) {
	// We'll use (0,0) as the default, customize this later!
	return 0, 0
}

// Static function to create a new player
func CreatePlayer(
	name string,
	gender string,
	speed uint64,
	rotationY float64,
	currentWeapon uint64,
	weapons []*WeaponSlot,
	// Stats
	level uint64,
	experience uint64,
	// Atributes
	health uint64,
	maxHealth uint64,
	isCrouching bool,
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
		speed:      speed,
		// Attributes
		health:    health,
		maxHealth: maxHealth,
		// Equipped Weapon Data
		currentWeapon: currentWeapon,
		weapons:       weapons,
		// Character state
		isCrouching: isCrouching,
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

func (player *Player) IsCrouching() bool {
	return player.isCrouching
}

func (player *Player) SetCrouching(crouching bool) {
	player.isCrouching = crouching
}
