package objects

type WeaponStats struct {
	MinDamage        uint64
	MaxDamage        uint64
	Projectiles      int    // Number of projects per shot
	MagazineCapacity uint64 // Max bullets in magazine (excluding chambered)
	ReserveCapacity  uint64 // Max extra bullets player can carry
}

// Weapon statistics
var WeaponData = map[string]WeaponStats{
	// player_equipment.gd add_weapon_to_slot()
	"unarmed": {MinDamage: 0, MaxDamage: 0, Projectiles: 0, MagazineCapacity: 0, ReserveCapacity: 0},
	// Rifles
	"m16_rifle": {MinDamage: 10, MaxDamage: 20, Projectiles: 1, MagazineCapacity: 30, ReserveCapacity: 90},
	"akm_rifle": {MinDamage: 12, MaxDamage: 24, Projectiles: 1, MagazineCapacity: 30, ReserveCapacity: 90},
	// Shotguns
	"remington870_shotgun": {MinDamage: 5, MaxDamage: 10, Projectiles: 9, MagazineCapacity: 6, ReserveCapacity: 24},
}

// Helper function to get weapon stats
func GetWeaponStats(weaponName string) (WeaponStats, bool) {
	stats, exists := WeaponData[weaponName]
	return stats, exists
}
