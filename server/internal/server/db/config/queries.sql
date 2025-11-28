-- User Operations
-- name: CreateUser :one
INSERT INTO users (username, nickname, password_hash)
VALUES (?, ?, ?)
RETURNING id, username, nickname, password_hash;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = ?;

-- name: GetUserByUsername :one
SELECT id, username, nickname, password_hash, character_id
FROM users
WHERE username = ? COLLATE NOCASE
LIMIT 1;

-- name: GetUserByNickname :one
SELECT id, username, nickname, password_hash, character_id
FROM users
WHERE nickname = ?
LIMIT 1;

-- Character Operations
-- name: CreateCharacter :one
INSERT INTO characters (user_id, gender, region_id, map_id, x, z, health, max_health, speed, rotation_y, is_crouching)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: SetUserCharacterID :exec
UPDATE users SET character_id = ? WHERE id = ?;

-- name: GetCharacterByID :one
SELECT * FROM characters WHERE id = ?;

-- name: GetCharacterByUserID :one
SELECT * FROM characters WHERE user_id = ?;

-- name: UpdateFullCharacterData :exec
UPDATE characters
SET
  region_id = ?, map_id = ?, x = ?, z = ?, health = ?, max_health = ?, speed = ?, rotation_y = ?, weapon_slot = ?, is_crouching = ?
WHERE id = ?;

-- name: GetFullCharacterData :one
SELECT
  c.id, c.gender, c.region_id, c.map_id, c.x, c.z, c.health, c.max_health, c.speed, c.rotation_y, c.weapon_slot, c.is_crouching,
  u.username, u.nickname
FROM characters c
JOIN users u ON c.user_id = u.id
WHERE c.id = ?;

-- name: GetCharacterPosition :one
SELECT region_id, map_id, x, z FROM characters WHERE id = ? LIMIT 1;

-- name: UpdateCharacterStats :exec
UPDATE characters
set health = ?, max_health = ?
WHERE id = ?;

-- Weapon Slot Operations
-- name: DeleteWeaponSlots :exec
DELETE FROM character_weapons WHERE character_id = ?;

-- name: InsertWeaponSlot :exec
INSERT INTO character_weapons
  (character_id, slot_index, weapon_name, weapon_type, display_name, ammo, fire_mode)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- name: LoadWeaponSlots :many
SELECT slot_index, weapon_name, weapon_type, display_name, ammo, fire_mode
FROM character_weapons
WHERE character_id = ?