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
	"server/internal/server/pathfinding"
	"server/pkg/packets"
	"time"
)

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

	// Only the hub writes to the DB
	Database *sql.DB
	queries  *db.Queries
}

// Any state from any client can access and modify these objects
type SharedObjects struct {
	// The ID of the player is the ID of the client
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

	// Create a new region called Prototype with a grid of (X by Z) squares
	h.CreateRegion("Prototype", "prototype", 20, 40)

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

// Retrieves the client (if found) in the Clients collection
func (h *Hub) GetClient(id uint64) (Client, bool) {
	return h.Clients.Get(id)
}

// Returns true if the account is already logged in
func (h *Hub) IsAlreadyConnected(username string) bool {
	found := false
	// Goes over the whole list of clients
	h.Clients.ForEachWithBreak(func(id uint64, client Client) bool {
		// If this account is already connected
		if client.GetAccountUsername() == username {
			found = true
		}
		return found
	})
	return found
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
func (h *Hub) CreateRegion(name string, gameMap string, gridWidth uint64, gridHeight uint64) {
	region := CreateRegion(name, gameMap, gridWidth, gridHeight)

	// Dereference the pointer to add a REAL region object to the Hub's list of regions
	// If this is the first region, h.Regions.Add returns 1, and the initial value for the region was 0
	region.SetId(h.Regions.Add(region))

	// Start the region in a goroutine
	go region.Start()
}

// Registers the client to this region if it exists and its available
func (h *Hub) JoinRegion(clientId uint64, regionId uint64) {
	// Search for this client by id
	client, clientExists := h.GetClient(clientId)
	// If the client is online and exists
	if clientExists {

		// Search for this region by id
		region, regionExists := h.GetRegionById(regionId)
		// If the region is valid
		if regionExists {

			// TO DO ->
			// CHECK IF CLIENT CAN JOIN THIS REGION (LEVEL REQ)

			// If the client was already at another region
			if client.GetRegion() != nil {
				// Broadcast to everyone that this client left this region!
				client.Broadcast(packets.NewClientLeft(client.GetId(), client.GetPlayerCharacter().Name))
				// Unregister the client from that region
				client.GetRegion().RemoveClientChannel <- client
			}

			// Register the client to the new region
			region.AddClientChannel <- client
			// Save the new region pointer in the client
			client.SetRegion(region)

			// Send this client this region's metadata
			client.SendPacket(packets.NewRegionData(region.GetId(), region.Grid.GetMaxWidth(), region.Grid.GetMaxHeight()))

			// Load region and position from the database for this player
			playerSpawnCell, err := h.LoadCharacterPosition(client)
			if err != nil {
				log.Println("Error loading character position from DB: ", err)
			}

			// playerSpawnCell := region.Grid.GetSpawnCell(0, 0)

			// Update the position and destination for this player character
			client.GetPlayerCharacter().SetGridPosition(playerSpawnCell)
			client.GetPlayerCharacter().SetGridDestination(playerSpawnCell)

			// Place the player in the grid for this region
			region.Grid.SetObject(playerSpawnCell, client.GetPlayerCharacter())

		} else { // If the region does not exist
			log.Printf("Region %d not available", regionId)
		}
	}
}

// Returns the total number of clients connected to the Hub
func (h *Hub) GetClientsOnline() uint64 {
	return uint64(h.Clients.Len())
}

// DATABASE USER OPERATIONS HANDLERS
func (h *Hub) CreateUser(username, nickname, passwordHash, gender string) (db.User, error) {
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
		UserID: user.ID,
		Gender: gender,
		MapID:  1, // We could have the player choose his starting location
		X:      0, // Update this depending on the spawn location?
		Z:      0, // Update this depending on the spawn location?
		Hp:     100,
		MaxHp:  100,
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

	// Get complete user data before committing
	fullUser, err := q.GetUserByID(ctx, user.ID)
	if err != nil {
		return db.User{}, fmt.Errorf("get user: %w", err)
	}

	// Commit transaction
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
func (h *Hub) SaveCharacterPosition(client Client) error {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	character := client.GetPlayerCharacter()

	return h.queries.UpdateCharacterPosition(ctx, db.UpdateCharacterPositionParams{
		MapID: int64(character.RegionId),
		X:     int64(character.GetGridPosition().X),
		Z:     int64(character.GetGridPosition().Z),
		ID:    client.GetCharacterId(),
	})
}

func (h *Hub) LoadCharacterPosition(client Client) (*pathfinding.Cell, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	position, err := h.queries.GetCharacterPosition(ctx, client.GetCharacterId())
	if err != nil {
		return nil, fmt.Errorf("load character position: %w", err)
	}

	// Missing region ID from here!!
	return &pathfinding.Cell{
		X:         uint64(position.X),
		Z:         uint64(position.Z),
		Reachable: true,
	}, nil
}
