# Outstar

Outstar is a grid-based multiplayer online prototype built around an authoritative Go backend and a Godot 4.5 client. The backend exposes a single `/ws` WebSocket endpoint, simulates the world on a tick loop, and persists every player and weapon slot in SQLite. The Godot client renders the scene, orchestrates input/camera/UI through autoloaded managers, and speaks the shared protobuf protocol. This README describes the feature set and shows how to run or extend the project.

## Table of Contents
- [Overview](#overview)
- [Highlights](#highlights)
- [Repository Layout](#repository-layout)
- [Requirements](#requirements)
- [Usage](#usage)
  - [Start the Go backend](#start-the-go-backend)
  - [Run the Godot client](#run-the-godot-client)
  - [Gameplay & controls](#gameplay--controls)
- [Development Workflow](#development-workflow)
  - [Database & SQL generation](#database--sql-generation)
  - [Packet schema](#packet-schema)
  - [Regions & maps](#regions--maps)
  - [Client / server versioning](#client--server-versioning)
  - [Assets & tooling](#assets--tooling)
- [Deployment Notes](#deployment-notes)
- [Lore & Design Docs](#lore--design-docs)

## Overview

The `server/` tree contains a Go 1.23 application that accepts WebSocket connections, validates credentials, joins players to regions, and broadcasts authoritative state at 5 Hz. A hub (`server/internal/server/hub.go`) keeps a registry of connected clients, shared objects, and region workers, while SQLite (via `modernc.org/sqlite`) acts as the persistent store. The `client/` tree is a Godot 4.5 project configured for GL Compatibility mode. Autoloaded managers (GameManager, WebSocket, Signals, etc.) coordinate scene changes, heartbeats, player discovery, chat, and camera behavior. Both sides share `shared/packets.proto`, so every gameplay interaction (movement, chat, weapon handling, respawns, damage) stays type safe.

## Highlights

### Authoritative MMO loop
- Hub -> Region architecture keeps all writes on the main goroutine and per-region goroutines (`hub.go`, `region.go`).
- Regions own `pathfinding.Grid` instances that implement A* plus spawn/respawn helpers, so the server remains the source of truth for player movement.
- Shared object maps (`SharedObjects` and `objects.Player`) provide O(1) access to any player regardless of region for cross-region whispers or inspections.

### Persistent accounts & characters
- Authentication state (`server/internal/server/states/authentication.go`) handles register/login flows, bcrypt password checks, idle timeouts, and duplicate-session prevention.
- Schema (`server/internal/server/db/config/schema.sql`) models users, characters, and five weapon slots per character; `sqlc` generates the strongly-typed queries in `server/internal/server/db`.
- Character loading rehydrates stats, position, gender, rotation, weapons, and health before the client is allowed into the `Game` state.

### Combat, chat, and social features
- `server/internal/server/states/game.go` processes grid-based movement, calculates rotations, applies weapon damage ranges, handles respawns, and broadcasts chat/public events.
- Packets defined in `shared/packets.proto` cover handshake, heartbeat, server metrics, region data, spawn/move/rotate/destination updates, chat bubbles, weapon switching, reload, fire/toggle fire mode, damage, death, and respawn requests.
- Weapon slots (up to five per player) include ammo, fire mode, and display names; damage rolls live server-side in `states/game.go` and `objects/objects.go`.

### Godot 4.5 client & tooling
- Autoloads (`client/autoloads/*.gd`) provide the WebSocket peer (with heartbeat timers), global GameManager state machine, tooltip/audio managers, and a typed signal bus so gameplay code does not depend on singletons directly.
- Player scripts (`client/classes/player/*`) implement action queues, animation controllers, equipment logic, packets, movement, and camera controls; they mirror the server protocol for immediate local responsiveness while waiting for authoritative corrections.
- `client/main.gd` centralizes input-to-signal translation for zoom, camera rotation, chat toggles, and menus, keeping UI code decoupled from direct input polling.
- The `addons/protobuf` plugin (enabled in `project.godot`) can regenerate `client/packets.gd` straight from the shared `.proto`.

### Ops-ready documentation
- `docs/` contains detailed runbooks for compiling Go for multiple targets (`compiling_golang.txt`), setting up sqlc/SQLite (`setup_database.txt`), provisioning or updating Linux hosts (`setup_linux_server_directly.txt`, `updating_linux_server.txt`), configuring reverse proxies, TOR relays, and socat bridges (`setup_reverse_proxy.txt`, `setup_tor_for_the_mmo_server.txt`, `torrc`), and helper notes for coordinate systems or icon generation.

## Repository Layout

| Path | Description |
| --- | --- |
| `client/` | Godot 4.5 project (scenes, states, autoloads, player classes, audio/SFX, assets, and protobuf addon). |
| `server/` | Go backend with `main.go`, `internal/server` packages (hub, states, math, pathfinding, db), and `pkg/packets` generated from protobuf. |
| `shared/packets.proto` | Canonical protobuf definition shared by the server and client. |
| `docs/` | Ops guides, deployment notes, lore, factions, locations, AI sketches, and TOR/reverse-proxy configs. |
| `art/` | Concept art and media for the project. |
| `.vscode/` | Workspace settings and tasks for local development. |

## Requirements

- Go 1.23.x or newer (`go.mod` pins the minimum version).
- `protoc` plus the Go plugin (`protoc-gen-go`) to regenerate packet structs.
- `sqlc` (see `docs/setup_database.txt`) when editing the database schema.
- Godot 4.5 (GL Compatibility profile) with the bundled protobuf addon enabled.
- SQLite is embedded via `modernc.org/sqlite`, so no separate DB service is required.
- Optional: `certbot`, `nginx`, `tor`, and `socat` when following the deployment recipes under `docs/`.

## Usage

### Start the Go backend

1. Install Go dependencies (once per machine):

   ```powershell
   cd server
   go mod download
   ```

2. Run the server in development mode (creates `db.sqlite` next to the executable and serves `/ws` on port 31591 by default):

   ```powershell
   go run . -port 31591
   ```

3. For distributable builds, follow `docs/compiling_golang.txt` (examples use `go build -o cmd/mmo-server-windows-amd64-v0.0.3.9 main.go` or change `GOOS/GOARCH` for Linux/ARM).

4. Database schema migrations live in `server/internal/server/db/config/schema.sql`. The schema is embedded via `go:embed`, so a fresh `db.sqlite` will auto-initialize whenever you run a new binary.

5. Logs indicate the executable folder, database path, regions created (`Prototype`, `Maze`), and the listening port.

### Run the Godot client

1. Open Godot 4.5, choose **Import**, and point it to `client/project.godot`.

2. The `states/connected/connected.tscn` scene exposes an enum (`server`) with `LOCAL` and `REMOTE` options. Select `LOCAL` to talk to `ws://localhost:31591/ws`, or edit the `ip` / `port` dictionaries in `connected.gd` to add more targets.

3. Press **Play**. On `Signals.connected_to_server`, the client sends and expects a handshake whose `version` must match `server/internal/server/info/version.go` and `client/project.godot` `config/version`.

4. Connection lifecycle is handled by `autoloads/websocket.gd` (buffer sizing, TCP_NODELAY, heartbeat timer). If versions mismatch, the Connected state shows the server version and asks you to update.

### Gameplay & controls

1. `GameManager` cycles scenes through `START -> CONNECTED -> AUTHENTICATION -> GAME`.

2. During **AUTHENTICATION**, use the UI panels to register or log in. Registration collects username, nickname, password, and gender (the server validates casing and account uniqueness).

3. After login, the server hydrates your character, joins the region stored in SQLite, spawns your avatar, and broadcasts your presence.

Common inputs (defined in `client/project.godot` and translated in `client/main.gd`):

- `Left Click`: set a movement destination or fire the equipped weapon depending on state.
- `Right Click`: raise/aim the current weapon; release to lower.
- Scroll wheel or `+` / `-`: zoom the tactical camera in/out.
- `Q` / `E`: rotate the camera (Signals `ui_rotate_camera_left/right`).
- `Enter`: focus chat input, `Esc`: toggle menus, `Space`: context-specific shortcuts.
- `1-5`: select weapon slots, `H`: holster (`weapon_unequip`), `R`: reload (`weapon_reload`), `T`: toggle fire mode, `R` (`respawn` action) to request a respawn when dead.

Chat bubbles, damage numbers, heartbeats, and server metrics all ride over protobuf packets so the HUD stays in sync with authoritative state (`client/classes/player/*` handles the local prediction side).

## Development Workflow

### Database & SQL generation

- Update schema logic in `server/internal/server/db/config/schema.sql` and add/edit queries in `queries.sql`.
- Regenerate type-safe Go code with `sqlc`:

  ```powershell
  sqlc generate -f server/internal/server/db/config/sqlc.yml
  ```

- The generated files under `server/internal/server/db` are imported by `hub.go` to read/write users, characters, and weapons. Only the hub writes to SQLite to avoid locking issues.

### Packet schema

- Edit `shared/packets.proto` whenever you add new gameplay events.
- Regenerate Go structs:

  ```powershell
  protoc -I shared --go_out=server/pkg --go_opt=paths=source_relative shared/packets.proto
  ```

- Regenerate the Godot bindings by opening the **Protobuf** dock (enabled via `addons/protobuf/plugin.cfg`) and generating `client/packets.gd` from the same `.proto`.
- Keep the Godot and Go outputs in sync so serialization stays compatible.

### Regions & maps

- New server regions are registered in `hub.go` (`CreateRegion("Name", "map_resource_name", width, height, regionId)`).
- Each region owns a grid; add static obstacles or spawn rules inside `server/internal/server/region.go` or `pathfinding/grid.go`.
- Matching Godot map scenes live under `client/maps/` and `client/states/game`. Use `docs/coordinate_systems.txt` when exporting Blender scenes so axes align with Godot expectations.

### Client / server versioning

- Server version: `server/internal/server/info/version.go`.
- Client version: `client/project.godot` -> `[application] config/version`.
- Connected state (`client/states/connected/connected.gd`) enforces the match; bump both values whenever you cut a new release.

### Assets & tooling

- Concept art, icons, and marketing assets live under `art/` with helpers like `docs/create_ico.txt`.
- `docs/ai.txt`, `docs/outstar/*.txt`, and `docs/outstar/to_purchase.txt` track gameplay ideas, factions, political axes, and future asset wishlists.
- Use the Godot protobuf addon, tooltip manager, and `client/components/` UI scripts as templates when introducing new HUD widgets.

## Deployment Notes

- Follow `docs/compiling_golang.txt` to cross-compile binaries for Windows and Linux (x86 and ARM).
- `docs/setup_database.txt` explains installing `sqlc` and regenerating Go database bindings.
- `docs/setup_linux_server_directly.txt` plus `docs/updating_linux_server.txt` cover provisioning, system updates, and service management.
- `docs/generating_ssh_keys.txt` walks through SSH key creation.
- `docs/setup_reverse_proxy.txt` details hardening a VPS with `nginx`, `socat`, and TOR socks proxies, including the `http-to-socks-proxy@.service` unit file.
- `docs/setup_tor_for_the_mmo_server.txt` and `docs/torrc` describe exposing the MMO server through TOR hidden services.
- Keep those notes handy when promoting a new build to your remote host.

## Lore & Design Docs

World-building lives beside the code:

- `docs/outstar/character_creation.txt` - player alignment grid (politics, faith, principles).
- `docs/outstar/factions.txt`, `locations.txt`, `lore.txt`, `to_purchase.txt` - story seeds, setting references, and future asset wishlists.
- `docs/ai.txt` - current AI goals/actions matrix.

Use these documents when designing missions, NPCs, or narrative beats so the gameplay systems stay anchored to the intended universe.
