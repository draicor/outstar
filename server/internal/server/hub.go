package server

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"server/internal/server/adt"
	"server/internal/server/db"
	"server/internal/server/objects"
	"server/pkg/packets"
	"sync"
	"time"
)

var createUserMutex sync.Mutex

// The hub is the entry point for all connected clients and the only go routine
// that should write to the database. It also keeps track of every available region
// within the server.
type Hub struct {
	// Map of all the connected clients in the server
	Clients *adt.MapMutex[Client]

	// Map of every object in the server
	SharedObjects *SharedObjects

	// Packets in this channel will be processed by all connected clients
	BroadcastChannel chan *packets.Packet

	// Clients connected will be added to the Hub
	AddClientChannel chan Client

	// Clients that disconnect will be removed from the Hub
	RemoveClientChannel chan Client

	// Map of every region
	Regions *adt.MapMutex[*Region]

	// Maps username to client ID
	usernameToClient        map[string]uint64
	usernameToClientRWMutex sync.RWMutex // Protects the usernameToClient map

	// Only the hub writes to the DB
	Database *sql.DB
	queries  *db.Queries
}

// We keep in SharedObjects a list of all the objects in the server
// For example, to send a private message no matter in what region the player is
// Or to check if a ship is not docked, etc.
type SharedObjects struct {
	// The ID of the player is the ID of the ephemeral client connection
	Players *adt.MapMutex[*objects.Player]
}

// Creates a new empty hub object, we have to pass a valid DB connection
func CreateHub(database *sql.DB) *Hub {
	return &Hub{
		// Collection of every connected client in the server
		Clients:             adt.NewMapMutex[Client](),
		AddClientChannel:    make(chan Client),
		RemoveClientChannel: make(chan Client),
		BroadcastChannel:    make(chan *packets.Packet),
		// Collection of every available region in the server
		Regions: adt.NewMapMutex[*Region](),
		// Username-to-client map for O(1) lookups
		usernameToClient: make(map[string]uint64),
		// Database connection
		Database: database,
		queries:  db.New(database),
		// Game objects
		SharedObjects: &SharedObjects{
			// Create an empty map of players
			Players: adt.NewMapMutex[*objects.Player](),
		},
	}
}

// Creates a client for the new connection and begins the concurrent read and write pumps
func (h *Hub) Serve(getNewClient func(*Hub, http.ResponseWriter, *http.Request) (Client, error), writer http.ResponseWriter, request *http.Request) {
	// Because the connection goes through the onion protocol, the IP gets anonymized, we can only see the port
	log.Println("New client connected from", request.RemoteAddr)

	// Executes the function that was passed as a parameter
	client, err := getNewClient(h, writer, request)

	if err != nil {
		log.Printf("Error obtaining client for new connection: %v\n", err)
		return
	}

	// Send this client to the add client channel
	h.AddClientChannel <- client

	// Sends packets to the game client
	go client.StartWritePump()
	// Reads packets from the game client
	go client.StartReadPump()
}

// Listens for packets on each channel
func (h *Hub) Start() {
	log.Println("Starting hub...")

	// CREATE AND INITIALIZE REGIONS
	// Create a new region called Prototype with a grid of (X by Z) squares
	h.CreateRegion("Prototype", "prototype", 20, 40, 1)
	h.CreateRegion("Maze", "maze", 10, 10, 2)

	// TO IMPLEMENT -> Adding static obstacles to the current map
	// add obstacles [20, 33] = "stone_column", rotate it by 30°

	// Create a ticker that ticks every 0.2 seconds
	serverTick := 5 // Max 5 packets per second (5 Hz)
	ticker := time.NewTicker(time.Second / time.Duration(serverTick))
	defer ticker.Stop()

	log.Println("Hub created, awaiting clients...")

	// Infinite for loop
	for {
		// If there is no default case, the "select" statement blocks
		// until at least one of the communications can proceed
		select {

		// If a client connects to the server, add it to the Hub
		case client := <-h.AddClientChannel:
			// The Add method returns a client ID, which we use to Initialize the WebSocket Client's ID
			client.Initialize(h.Clients.Add(client))

		// If a client disconnects, remove him from the Hub
		case client := <-h.RemoveClientChannel:
			h.Clients.Remove(client.GetId())

		// NOTE:
		// No packets are being sent to the hub's broadcasting channel yet.
		// If we get a packet from the broadcast channel
		case packet := <-h.BroadcastChannel:
			// Go over every registered client in the Hub (whole server)
			h.Clients.ForEach(func(id uint64, client Client) {
				// Check that the sender does not send the packet to itself
				if client.GetId() != packet.SenderId {
					// Forces the packet to every client in the server
					client.ProcessPacket(packet.SenderId, packet.Payload)
				}
			})

		// Process one packet per client per tick from the client's processing channel
		case <-ticker.C:
			h.Clients.ForEach(func(id uint64, client Client) {
				select {
				case packet := <-client.GetProcessingChannel():
					client.ProcessPacket(packet.SenderId, packet.Payload)
				default:
					// If no packet is available, then skip to the next client
				}
			})
		}
	}
}

// Called when a client logins successfully
func (h *Hub) RegisterUsername(username string, clientId uint64) {
	h.usernameToClientRWMutex.Lock()
	defer h.usernameToClientRWMutex.Unlock()
	h.usernameToClient[username] = clientId
}

// Called when a client logs out
func (h *Hub) UnregisterUsername(username string) {
	h.usernameToClientRWMutex.Lock()
	defer h.usernameToClientRWMutex.Unlock()
	delete(h.usernameToClient, username)
}

// Retrieves the client (if found) in the Clients collection
func (h *Hub) GetClient(id uint64) (Client, bool) {
	return h.Clients.Get(id)
}

// Retrieves the client (if found) in the Clients collection using a more efficient lookup
func (h *Hub) GetClientByUsername(username string) (Client, bool) {
	h.usernameToClientRWMutex.RLock()
	clientId, exists := h.usernameToClient[username]
	h.usernameToClientRWMutex.RUnlock()

	if !exists {
		return nil, false
	}
	return h.Clients.Get(clientId)
}

// Returns true if the account is already logged in (registered in our Hub)
func (h *Hub) IsAlreadyConnected(username string) bool {
	h.usernameToClientRWMutex.RLock()
	_, exists := h.usernameToClient[username]
	h.usernameToClientRWMutex.RUnlock()
	return exists
}

// Retrieves the region (if found) in the Regions collection
func (h *Hub) GetRegionById(id uint64) (*Region, bool) {
	region, found := h.Regions.Get(id)
	if found {
		return region, true
	}
	return nil, false
}

// Creates a new region and adds it to Hub
func (h *Hub) CreateRegion(name string, gameMap string, gridWidth uint64, gridHeight uint64, regionId uint64) {
	region := CreateRegion(name, gameMap, gridWidth, gridHeight)

	// Dereference the pointer to add a REAL region object to the Hub's list of regions
	// If this is the first region, h.Regions.Add returns 1, and the initial value for the region was 0
	region.SetId(h.Regions.Add(region, regionId))

	// Start the region in a goroutine
	go region.Start()
}

// Spawns a client in a region that matches the one from the database, if valid
func (h *Hub) JoinRegion(username string) {
	// Search for this client by id
	client, clientExists := h.GetClientByUsername(username)
	// If the client is online and exists
	if clientExists {

		// Load position data from the database for this player
		spawnPosition, err := h.LoadCharacterPosition(client)
		if err != nil {
			log.Println("Error loading character position from DB: ", err)
		}

		// Store the regionId and mapId from the database
		regionId := uint64(spawnPosition.RegionID)
		mapId := uint64(spawnPosition.MapID)

		// Search for this region by id
		region, regionExists := h.GetRegionById(regionId)
		// If the region is valid
		if regionExists {
			// Register the client to the new region
			region.AddClientChannel <- client
			// Save the new region pointer in the client
			client.SetRegion(region)

			// Get our player character
			player := client.GetPlayerCharacter()

			// Save the region ID and map ID in the character
			player.SetRegionId(regionId)
			player.SetMapId(mapId)

			// Only spawn in this cell if its not occupied, if it is, find a cell nearby that is free
			grid := region.GetGrid()
			playerSpawnCell := grid.GetSpawnCell(uint64(spawnPosition.X), uint64(spawnPosition.Z))

			// If we looped through the whole map and no cell was available
			if playerSpawnCell == nil {
				log.Printf("No more space available in region %d", regionId)
				// TO FIX
				// This should teleport the client to the spawn map from the DB instead
				h.SwitchRegion(username, 1, 1)
				return
			}

			// Send the client this region's metadata
			client.SendPacket(packets.NewRegionData(region.GetId(), grid.GetMaxWidth(), grid.GetMaxHeight()))

			// Update the position and destination for this player character
			player.SetGridPosition(playerSpawnCell)
			player.SetGridDestination(playerSpawnCell)

			// Place the player in the grid for this region
			grid.SetObject(playerSpawnCell, player)

		} else { // If the region does not exist
			log.Printf("Region %d not available", regionId)

			// TO FIX
			// This should teleport the client to the spawn map from the DB instead
			h.SwitchRegion(username, 1, 1)
		}
	}
}

// Move this client to another region if valid
func (h *Hub) SwitchRegion(username string, regionId uint64, mapId uint64) {
	// Search for this client by id
	client, clientExists := h.GetClientByUsername(username)
	// If the client is online and exists
	if clientExists {
		// Search for this region by id in our Hub
		region, regionExists := h.GetRegionById(regionId)
		// If the region is valid
		if regionExists {

			// TO FIX (Each region should have a max_capacity variable)
			// Capacity Check
			if region.Clients.Len() >= 50 {
				client.SendPacket(packets.NewRequestDenied("Region is full"))
				return
			}

			// Get our player character
			player := client.GetPlayerCharacter()

			// Check if the client's previous region was valid
			if client.GetRegion() != nil {
				// Broadcast to everyone that this client left this region!
				client.Broadcast(packets.NewClientLeft(player.Name))
				// Unregister the client from that region
				client.GetRegion().RemoveClientChannel <- client
				time.Sleep(50 * time.Millisecond) // Brieft pause
			}

			// Register the client to the new region
			region.AddClientChannel <- client
			// Save the new region pointer in the client
			client.SetRegion(region)

			// Save the region ID and map ID in the character
			player.SetRegionId(regionId)
			player.SetMapId(mapId)

			// Get this region's grid
			grid := region.grid

			// Only spawn in this cell if its not occupied, if it is, find a cell nearby that is free
			playerSpawnCell := grid.GetSpawnCell(0, 0) // TO FIX <- Each region should have its own spawn zone

			// If we looped through the whole map and no cell was available
			if playerSpawnCell == nil {
				log.Printf("No more space available in region %d", regionId)
				// TO FIX
				// This should teleport the client to the spawn map from the DB instead
				h.SwitchRegion(username, 1, 1)
				return
			}

			// Place the player in the server grid for this region
			grid.SetObject(playerSpawnCell, player)

			// Send this client this region's metadata
			client.SendPacket(packets.NewRegionData(region.GetId(), grid.GetMaxWidth(), grid.GetMaxHeight()))

			// Update the position and destination for this player character
			player.SetGridPosition(playerSpawnCell)
			player.SetGridDestination(playerSpawnCell)

		} else { // If the region does not exist
			log.Printf("Region %d not available", regionId)

			// TO FIX
			// This should teleport the client to the spawn map from the DB instead
			// Force this client to the first map
			h.SwitchRegion(username, 1, 1)
		}
	}
}

// Returns the total number of clients connected to the Hub
func (h *Hub) GetConnectedClients() uint64 {
	return uint64(h.Clients.Len())
}

// Returns the total number of logged in accounts connected to the Hub
func (h *Hub) GetConnectedAccounts() uint64 {
	return uint64(len(h.usernameToClient))
}

// DATABASE USER OPERATIONS HANDLERS
func (h *Hub) CreateUser(username, nickname, passwordHash, gender string) (db.User, error) {
	createUserMutex.Lock()
	defer createUserMutex.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	tx, err := h.Database.BeginTx(ctx, nil)
	if err != nil {
		return db.User{}, fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback()

	q := h.queries.WithTx(tx)

	// Step 1: Create User (without character_id)
	user, err := q.CreateUser(ctx, db.CreateUserParams{
		Username:     username,
		Nickname:     nickname,
		PasswordHash: passwordHash,
	})
	if err != nil {
		return db.User{}, fmt.Errorf("create user: %w", err)
	}

	// Step 2: Create Character
	character, err := q.CreateCharacter(ctx, db.CreateCharacterParams{
		UserID:    user.ID,
		Gender:    gender,
		RegionID:  1,             // We could have the player choose his starting location
		MapID:     1,             // We could have the player choose his starting location
		X:         0,             // Update this depending on the spawn location?
		Z:         0,             // Update this depending on the spawn location?
		Health:    100,           // Health
		MaxHealth: 100,           // Max Health
		Speed:     2,             // Create character with speed set to jog
		RotationY: objects.SOUTH, // Always spawn looking south when creating the character
		// Weapon data
	})
	if err != nil {
		return db.User{}, fmt.Errorf("create character: %w", err)
	}

	// Step 3: Update user with character_id
	if err := q.SetUserCharacterID(ctx, db.SetUserCharacterIDParams{
		ID:          user.ID,
		CharacterID: sql.NullInt64{Int64: character.ID, Valid: true},
	}); err != nil {
		return db.User{}, fmt.Errorf("set character id: %w", err)
	}

	// Step 4: Initialize and save default weapon slots
	defaultSlots := []*objects.WeaponSlot{
		{WeaponName: "unarmed", WeaponType: "unarmed", DisplayName: "Empty", Ammo: 0, FireMode: 0},
		{WeaponName: "akm_rifle", WeaponType: "rifle", DisplayName: "AKM Rifle", Ammo: 30, FireMode: 0},
		{WeaponName: "m16_rifle", WeaponType: "rifle", DisplayName: "M16 Rifle", Ammo: 30, FireMode: 0},
		{WeaponName: "unarmed", WeaponType: "unarmed", DisplayName: "Empty", Ammo: 0, FireMode: 0},
		{WeaponName: "unarmed", WeaponType: "unarmed", DisplayName: "Empty", Ammo: 0, FireMode: 0},
	}

	// Step 5: Execute bulk upsert using helper function
	if err := db.BulkUpsertWeaponSlots(ctx, tx, character.ID, defaultSlots); err != nil {
		return db.User{}, fmt.Errorf("bulk insert weapon slots: %w", err)
	}

	// Step 6: Get complete user data before committing
	fullUser, err := q.GetUserByID(ctx, user.ID)
	if err != nil {
		return db.User{}, fmt.Errorf("get user: %w", err)
	}

	// Step 7: Commit transaction
	if err := tx.Commit(); err != nil {
		return db.User{}, fmt.Errorf("commit transaction: %w", err)
	}

	// Return complete user data
	return fullUser, nil
}

func (h *Hub) GetUserByUsername(username string) (db.User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	return h.queries.GetUserByUsername(ctx, username)
}

func (h *Hub) GetUserByNickname(nickname string) (db.User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	return h.queries.GetUserByNickname(ctx, nickname)
}

// DATABASE CHARACTER OPERATIONS HANDLERS
func (h *Hub) SaveCharacter(client Client) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	tx, err := h.Database.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback()

	character := client.GetPlayerCharacter()

	// Save character data
	err = h.queries.UpdateFullCharacterData(ctx, db.UpdateFullCharacterDataParams{
		RegionID:   int64(character.GetRegionId()),
		MapID:      int64(character.GetMapId()),
		X:          int64(character.GetGridPosition().X),
		Z:          int64(character.GetGridPosition().Z),
		Health:     int64(character.GetHealth()),
		MaxHealth:  int64(character.GetMaxHealth()),
		Speed:      int64(character.GetSpeed()),
		RotationY:  float64(character.GetRotation()),
		WeaponSlot: int64(character.GetCurrentWeapon()),
		ID:         client.GetCharacterId(), // Character ID to find it in the DB
	})
	if err != nil {
		return fmt.Errorf("update character data: %w", err)
	}

	// Update all weapon slots
	// Execute bulk upsert using helper function
	if err := db.BulkUpsertWeaponSlots(ctx, tx, client.GetCharacterId(), *character.GetWeapons()); err != nil {
		return fmt.Errorf("bulk insert weapon slots: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
	}

	return nil
}

// Used to get this character's region, map and position
func (h *Hub) LoadCharacterPosition(client Client) (*db.GetCharacterPositionRow, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	position, err := h.queries.GetCharacterPosition(ctx, client.GetCharacterId())
	if err != nil {
		return nil, fmt.Errorf("load character position: %w", err)
	}

	return &position, nil
}

// Returns character and weapons as separate
func (h *Hub) GetFullCharacterData(characterId int64) (*db.GetFullCharacterDataRow, *[]*objects.WeaponSlot, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	character, err := h.queries.GetFullCharacterData(ctx, characterId)
	if err != nil {
		return nil, nil, fmt.Errorf("load full character data: %w", err)
	}

	weapons, err := h.LoadWeaponSlots(character.ID)
	if err != nil {
		return nil, nil, fmt.Errorf("load full weapon data: %w", err)
	}

	return &character, weapons, nil
}

func (h *Hub) LoadWeaponSlots(characterId int64) (*[]*objects.WeaponSlot, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	rows, err := h.queries.LoadWeaponSlots(ctx, characterId)
	if err != nil {
		return nil, fmt.Errorf("load weapon slots: %w", err)
	}

	slots := make([]*objects.WeaponSlot, 5)
	// Initialize empty slots
	for i := 0; i < 5; i++ {
		slots[i] = &objects.WeaponSlot{
			WeaponName:  "unarmed",
			WeaponType:  "unarmed",
			DisplayName: "Empty",
			Ammo:        0,
			FireMode:    0,
		}
	}

	for _, row := range rows {
		slotIndex := row.SlotIndex
		if slotIndex < 5 {
			slots[slotIndex] = &objects.WeaponSlot{
				WeaponName:  row.WeaponName,
				WeaponType:  row.WeaponType,
				DisplayName: row.DisplayName,
				Ammo:        uint64(row.Ammo),
				FireMode:    uint64(row.FireMode),
			}
		}
	}

	return &slots, nil
}
