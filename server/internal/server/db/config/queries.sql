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
INSERT INTO characters (user_id, gender, region_id, map_id, x, z, hp, max_hp)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: SetUserCharacterID :exec
UPDATE users SET character_id = ? WHERE id = ?;

-- name: GetCharacterByID :one
SELECT * FROM characters WHERE id = ?;

-- name: GetCharacterByUserID :one
SELECT * FROM characters WHERE user_id = ?;

-- name: GetFullCharacterData :one
SELECT
  c.id, c.gender, c.region_id, c.map_id, c.x, c.z, c.hp, c.max_hp,
  u.username, u.nickname
FROM characters c
JOIN users u ON c.user_id = u.id
WHERE c.id = ?;

-- name: UpdateCharacterPosition :exec
UPDATE characters
SET region_id = ?, map_id = ?, x = ?, z = ?
WHERE id = ?;

-- name: GetCharacterPosition :one
SELECT region_id, map_id, x, z FROM characters WHERE id = ? LIMIT 1;

-- name: UpdateCharacterStats :exec
UPDATE characters
set hp = ?, max_hp = ?
WHERE id = ?;