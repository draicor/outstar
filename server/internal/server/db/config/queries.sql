-- name: GetUserByUsername :one
SELECT * FROM users
WHERE username = ? LIMIT 1;

-- name: GetUserByNickname :one
SELECT * FROM users
WHERE nickname = ? LIMIT 1;

-- name: CreateUser :one
INSERT INTO users (
  username, nickname, password_hash
) VALUES (
  ?, ?, ?
)
RETURNING *;