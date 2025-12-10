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
  region_id INTEGER NOT NULL DEFAULT 1, -- Server region this character is at
  map_id INTEGER NOT NULL DEFAULT 1, -- Which map file to load
  x INTEGER NOT NULL DEFAULT 1,
  z INTEGER NOT NULL DEFAULT 1,
  health INTEGER NOT NULL DEFAULT 100,
  max_health INTEGER NOT NULL DEFAULT 100,
  speed INTEGER NOT NULL DEFAULT 1 CHECK (speed BETWEEN 1 and 3), -- Clamp speed
  rotation_y REAL NOT NULL DEFAULT 0.0,
  weapon_slot INTEGER NOT NULL DEFAULT 0 CHECK (weapon_slot BETWEEN 0 and 4), -- Clamp weapon slot
  is_crouching INTEGER NOT NULL DEFAULT 0, -- 0 = standing, 1 = crouching
  FOREIGN KEY (user_id) REFERENCES users(id) -- 1:1 relationship (only one character per user)
);

-- Weapon slots for each character (game data)
CREATE TABLE IF NOT EXISTS character_weapons (
  character_id INTEGER NOT NULL,
  slot_index INTEGER NOT NULL CHECK (slot_index BETWEEN 0 AND 4), -- 0 to 4 (5 slots)
  weapon_name TEXT NOT NULL DEFAULT 'unarmed',
  weapon_type TEXT NOT NULL DEFAULT 'unarmed',
  ammo INTEGER NOT NULL DEFAULT 0,
  reserve_ammo INTEGER NOT NULL DEFAULT 0,
  fire_mode INTEGER NOT NULL DEFAULT 0, -- 0: semi, 1: auto
  display_name TEXT NOT NULL DEFAULT 'Empty',
  PRIMARY KEY (character_id, slot_index),
  FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
);