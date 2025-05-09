-- Users table (authentication)
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE COLLATE NOCASE, -- case-insensitive
  nickname TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  character_id INTEGER UNIQUE, -- 1:1 relationship (only one character per user)
  FOREIGN KEY (character_id) REFERENCES characters(id)
);

-- Characters table (game data)
CREATE TABLE IF NOT EXISTS characters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE, -- Ensures 1 character per user
  gender TEXT NOT NULL CHECK (gender IN ('male', 'female')),
  map_id INTEGER NOT NULL DEFAULT 1,
  x INTEGER NOT NULL DEFAULT 1,
  z INTEGER NOT NULL DEFAULT 1,
  hp INTEGER NOT NULL DEFAULT 100,
  max_hp INTEGER NOT NULL DEFAULT 100,
  FOREIGN KEY (user_id) REFERENCES users(id) -- 1:1 relationship (only one character per user)
);