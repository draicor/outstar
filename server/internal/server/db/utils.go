package db

import (
	"context"
	"database/sql"
	"errors"
	"server/internal/server/objects"
)

// This requires creading an index on the database itself:
/*
 CREATE UNIQUE INDEX idx_character_weapons_unique ON character_weapons (
	character_id,
	slot_index
);
*/
func BulkUpsertWeaponSlots(ctx context.Context, tx *sql.Tx, characterID int64, slots []*objects.WeaponSlot) error {
	// Ensure we have exactly 5 slots
	if len(slots) != 5 {
		return errors.New("exactly 5 weapon slots must be provided")
	}

	query := `
		INSERT INTO character_weapons 
		(character_id, slot_index, weapon_name, weapon_type, display_name, ammo, reserve_ammo, fire_mode)
		VALUES 
		(?, ?, ?, ?, ?, ?, ?, ?),
		(?, ?, ?, ?, ?, ?, ?, ?),
		(?, ?, ?, ?, ?, ?, ?, ?),
		(?, ?, ?, ?, ?, ?, ?, ?),
		(?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT (character_id, slot_index) DO UPDATE SET
		weapon_name = excluded.weapon_name,
		weapon_type = excluded.weapon_type,
		display_name = excluded.display_name,
		ammo = excluded.ammo,
		reserve_ammo = excluded.reserve_ammo,
		fire_mode = excluded.fire_mode;
	`

	args := []interface{}{
		// Slot 0
		characterID, 0, slots[0].WeaponName, slots[0].WeaponType, slots[0].DisplayName, slots[0].Ammo, slots[0].ReserveAmmo, slots[0].FireMode,
		// Slot 1
		characterID, 1, slots[1].WeaponName, slots[1].WeaponType, slots[1].DisplayName, slots[1].Ammo, slots[1].ReserveAmmo, slots[1].FireMode,
		// Slot 2
		characterID, 2, slots[2].WeaponName, slots[2].WeaponType, slots[2].DisplayName, slots[2].Ammo, slots[2].ReserveAmmo, slots[2].FireMode,
		// Slot 3
		characterID, 3, slots[3].WeaponName, slots[3].WeaponType, slots[3].DisplayName, slots[3].Ammo, slots[3].ReserveAmmo, slots[3].FireMode,
		// Slot 4
		characterID, 4, slots[4].WeaponName, slots[4].WeaponType, slots[4].DisplayName, slots[4].Ammo, slots[4].ReserveAmmo, slots[4].FireMode,
	}

	_, err := tx.ExecContext(ctx, query, args...)
	return err
}
