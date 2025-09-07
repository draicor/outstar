package states

import (
	"context"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/math"
	"server/internal/server/objects"
	"time"

	"server/pkg/packets"
)

// SERVER TICKS
// Player movement runs at 2Hz (0.5s ticks)
const PlayerMoveTick float64 = 0.5

type Game struct {
	client                 server.Client
	player                 *objects.Player
	cancelPlayerUpdateLoop context.CancelFunc
	logger                 *log.Logger
}

func (state *Game) GetName() string {
	return "Game"
}

// SetClient gets called BEFORE OnEnter() from WebSocketClient
func (state *Game) SetClient(client server.Client) {
	// We save the client's data into this state
	state.client = client
	// We save the client's character data into this state too
	state.player = client.GetPlayerCharacter()

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

// Executed automatically when a client leaves the game state
func (state *Game) OnExit() {
	// We broadcast the client leaving in websocket.go close()
	// We save the client's data in the database in websocket.go close()
	// We remove the player from the grid in region.go

	// We stop the player update loop
	if state.cancelPlayerUpdateLoop != nil {
		state.cancelPlayerUpdateLoop()
	}

	// Remove this player from the list of players from the Hub
	state.client.GetHub().SharedObjects.Players.Remove(state.client.GetId())
}

func (state *Game) OnEnter() {
	// Add this client's character to the player map of the hub with the same ID as its client ID
	go state.client.GetHub().SharedObjects.Players.Add(state.player, state.client.GetId())

	// Move the client to the region his character is at in the database
	state.client.GetHub().JoinRegion(state.client.GetAccountUsername())

	state.logger.Printf("%s added to region %d", state.player.Name, state.player.GetRegionId())

	// Create a spawn packet to be sent to everyone in this region
	updatePlayerPacket := packets.NewSpawnCharacter(state.client.GetId(), state.player)

	// Spawn our own character in our client first
	state.client.SendPacket(updatePlayerPacket)
	// Tell everyone else to spawn our character too
	state.client.Broadcast(updatePlayerPacket)

	// Loop over all of the clients in this region
	state.client.GetRegion().Clients.ForEach(func(id uint64, client server.Client) {
		// Create a spawn packet to be sent to our new client
		updatePlayerPacket := packets.NewSpawnCharacter(id, client.GetPlayerCharacter())
		state.client.SendPacket(updatePlayerPacket)
	})

	// Start the player update loop in its own co-routine
	if state.cancelPlayerUpdateLoop == nil {
		ctx, cancel := context.WithCancel(context.Background())
		state.cancelPlayerUpdateLoop = cancel
		go state.playerUpdateLoop(ctx)
	}
}

// Runs in a loop updating the player
func (state *Game) playerUpdateLoop(ctx context.Context) {
	ticker := time.NewTicker(time.Duration(PlayerMoveTick*1000) * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			state.updateCharacter()
		case <-ctx.Done():
			return
		}
	}
}

// Keeps an accurate representation of the character's position on the server
func (state *Game) updateCharacter() {
	// If we are already at our destination, we are done moving
	if state.player.GetGridPosition() == state.player.GetGridDestination() {
		return
	}

	// Get the grid from this region
	grid := state.client.GetRegion().GetGrid()

	// Calculate the shortest path from our position to our new destination cell
	path := grid.AStar(state.player.GetGridPosition(), state.player.GetGridDestination(), state.player)

	// If the path is valid
	if len(path) > 1 {
		// We keep track of our steps
		var steps uint64 = 0
		totalSteps := uint64(len(path) - 1) // We subtract one because the first doesn't count

		// We account for our max distance per tick here using Speed
		stepsRemaining := math.MinimumUint64(totalSteps, state.player.GetSpeed())

		// Get the grid from this region
		grid := state.client.GetRegion().GetGrid()

		// Based on our player's speed and the remaining cells to traverse
		// We determine how many cells we can move
		for steps < stepsRemaining {
			// Get the current and next cell from our path before moving
			currentCell := state.player.GetGridPosition()
			nextCell := path[1]

			// If the next cell exists
			if nextCell != nil {
				// If the next cell is both reachable and not occupied
				if grid.IsCellReachable(nextCell) && grid.IsCellAvailable(nextCell) {
					// Move player to next cell in the grid
					grid.SetObject(nextCell, state.player)
					// Keep track of our position in our player object
					state.player.SetGridPosition(nextCell)
					// Calculate new rotation based on movement direction
					state.player.CalculateRotation(currentCell, nextCell)
					// We overwrite our path variable to remove the first cell
					path = path[1:]
					// We mark our step as completed
					steps++

				} else {
					// If the next cell is not valid or occupied
					fmt.Println("Next cell is not valid or occupied")
					break
				}
			} else {
				// If the next cell is invalid
				fmt.Println("Next cell is invalid")
				break
			}
		}

		// If we didn't move
		if steps == 0 {
			fmt.Println("We didn't move for some reason, so abort...")
			// We forget about our destination since its not reachable
			state.player.SetGridDestination(state.player.GetGridPosition())
		}

		// Create a packet and broadcast it to everyone to update the character's position
		moveCharacterPacket := packets.NewMoveCharacter(state.player)

		// Only if we moved
		if steps > 0 {
			// Broadcast the new position to everyone else
			state.client.Broadcast(moveCharacterPacket)
		}

		// Send the update to the client that owns this character,
		// so they can ensure they are in sync with the server.
		// We are sending this in a goroutine so we don't block our game loop
		go state.client.SendPacket(moveCharacterPacket)
	}
}

func (state *Game) HandlePacket(senderId uint64, payload packets.Payload) {
	// If this packet was sent by our client
	if senderId == state.client.GetId() {
		// Switch based on the type of packet
		// We also save the casted packet in case we need to access specific fields
		switch casted_payload := payload.(type) {

		// PUBLIC MESSAGE
		case *packets.Packet_PublicMessage:
			// The server ignores the client's character name from the packet,
			// it broadcasts the message with the client's nickname from memory
			nickname := state.client.GetPlayerCharacter().Name
			state.HandlePublicMessage(nickname, casted_payload.PublicMessage.Text)

		// HEARTBEAT
		case *packets.Packet_Heartbeat:
			state.client.SendPacket(packets.NewHeartbeat())

		// CLIENT ENTERED
		case *packets.Packet_ClientEntered:
			state.HandleClientEntered(state.client.GetPlayerCharacter().Name)

		// CLIENT LEFT
		case *packets.Packet_ClientLeft:
			state.HandleClientLeft(state.client.GetId(), state.client.GetPlayerCharacter().Name)

		// DESTINATION
		case *packets.Packet_Destination:
			state.HandleDestination(casted_payload.Destination)

		// UPDATE SPEED
		case *packets.Packet_UpdateSpeed:
			state.HandleUpdateSpeed(casted_payload.UpdateSpeed)

		// JOIN REGION REQUEST
		case *packets.Packet_JoinRegionRequest:
			state.HandleJoinRegionRequest(casted_payload.JoinRegionRequest)

		// LOGOUT REQUEST
		case *packets.Packet_LogoutRequest:
			state.HandleLogoutRequest()

		// CHAT BUBBLE
		case *packets.Packet_ChatBubble:
			state.HandleChatBubble(casted_payload.ChatBubble)

		// SWITCH WEAPON
		case *packets.Packet_SwitchWeapon:
			state.HandleSwitchWeapon(casted_payload.SwitchWeapon)

		// RELOAD WEAPON
		case *packets.Packet_ReloadWeapon:
			state.HandleReloadWeapon(casted_payload.ReloadWeapon)

		// RAISE WEAPON
		case *packets.Packet_RaiseWeapon:
			state.HandleRaiseWeapon()

		// LOWER WEAPON
		case *packets.Packet_LowerWeapon:
			state.HandleLowerWeapon()

		// ROTATE CHARACTER
		case *packets.Packet_RotateCharacter:
			state.HandleRotateCharacter(casted_payload.RotateCharacter)

		// FIRE WEAPON
		case *packets.Packet_FireWeapon:
			state.HandleFireWeapon(casted_payload.FireWeapon)

		// TOGGLE FIRE MODE
		case *packets.Packet_ToggleFireMode:
			state.HandleToggleFireMode(casted_payload.ToggleFireMode)

		// START FIRING WEAPON
		case *packets.Packet_StartFiringWeapon:
			state.HandleStartFiringWeapon(casted_payload.StartFiringWeapon)

		// STOP FIRING WEAPON
		case *packets.Packet_StopFiringWeapon:
			state.HandleStopFiringWeapon(casted_payload.StopFiringWeapon)

		// REPORT PLAYER DAMAGE
		case *packets.Packet_ReportPlayerDamage:
			state.HandleReportPlayerDamage(casted_payload.ReportPlayerDamage)

		case nil:
			// Ignore packet if not a valid payload type
		default:
			// Ignore packet if no payload was sent
		}

	} else {
		// If another client passed us this packet, forward it to our client
		// <- TO FIX
		// Filter per packet type and distance so we can decide if we SHOULD see this
		state.client.SendPacketAs(senderId, payload)
	}
}

// Tell everybody we sent a public message
func (state *Game) HandlePublicMessage(nickname string, text string) {
	state.client.Broadcast(packets.NewPublicMessage(nickname, text))
}

// We send this message to everybody
func (state *Game) HandleClientEntered(nickname string) {
	// Tell everybody we connected!
	state.client.Broadcast(packets.NewClientEntered(nickname))
}

// We send this message to everybody
func (state *Game) HandleClientLeft(id uint64, nickname string) {
	// Tell everybody we disconnected
	state.client.Broadcast(packets.NewClientLeft(nickname))
}

// Sent from the client to the server to request setting a new destination for their player character
func (state *Game) HandleDestination(payload *packets.Destination) {
	// Get the grid from this region
	grid := state.client.GetRegion().GetGrid()
	// Get the cell the player wants to access
	destination := grid.LocalToMap(payload.X, payload.Z)
	// Only update the player's destination if the cell is valid and unoccupied
	if grid.IsCellReachable(destination) && grid.IsCellAvailable(destination) {
		// We compare our new destination to our previous one
		previousDestination := state.player.GetGridDestination()
		// If the new destination is NOT the same one we already had
		if previousDestination != destination {
			// Overwrite the destination
			state.player.SetGridDestination(destination)
		} // New destination is the same as our previous one, ignore
	} // New destination was invalid, ignore
}

// Sent by the client to request updating the movement speed
func (state *Game) HandleUpdateSpeed(payload *packets.UpdateSpeed) {
	newSpeed := payload.Speed
	if newSpeed != state.player.GetSpeed() {
		state.player.SetSpeed(newSpeed)

		// Create an update speed packet to be sent to the client
		// NOTE: use GetSpeed() because SetSpeed() has some validation, don't use newSpeed directly
		updateSpeedPacket := packets.NewUpdateSpeed(state.player.GetSpeed())
		state.client.SendPacket(updateSpeedPacket)
		// Broadcast this to everyone else too, so everyone moves their local version of this character,
		// at the accurate speed
		state.client.Broadcast(updateSpeedPacket)

	} // If the client sent the same speed, ignore
}

// Sent by the client to request joining another region
func (state *Game) HandleJoinRegionRequest(payload *packets.JoinRegionRequest) {
	// Before switching regions, save current rotation
	currentRotation := state.player.RotationY

	hub := state.client.GetHub()

	// TO FIX?
	// MAP_ID SHOULDNT be the same as REGION_ID if I want to use instances
	hub.SwitchRegion(state.client.GetAccountUsername(), payload.GetRegionId(), payload.GetRegionId())

	state.logger.Printf("%s added to region %d", state.player.Name, state.player.GetRegionId())

	// Wait a brief moment to ensure client receives packets
	time.Sleep(250 * time.Millisecond)

	// Restore rotation after switch
	state.player.RotationY = currentRotation

	// Create a spawn packet to be sent to everyone in this region
	spawnCharacterPacket := packets.NewSpawnCharacter(state.client.GetId(), state.player)

	// Spawn our own character in our client first
	state.client.SendPacket(spawnCharacterPacket)
	// Tell everyone else to spawn our character too
	state.client.Broadcast(spawnCharacterPacket)

	// Get every client in this region and send our client a packet for each client connected,
	// so we can also see the players that are already connected.
	// Loop over all of the clients in this region
	state.client.GetRegion().Clients.ForEach(func(id uint64, client server.Client) {
		// Create a spawn packet to be sent to our new client
		spawnCharacterPacket := packets.NewSpawnCharacter(id, client.GetPlayerCharacter())
		state.client.SendPacket(spawnCharacterPacket)
	})
}

// Sent by the client to go back to the login state
func (state *Game) HandleLogoutRequest() {
	character := state.client.GetPlayerCharacter()
	if character != nil {
		// Server logging
		state.logger.Printf("%s has logged out", character.Name)

		// Store this player's character data on logout
		err := state.client.GetHub().SaveCharacter(state.client)
		if err != nil {
			state.logger.Printf("Failed to save character to database: %v", err)
		}

		// Broadcast to everyone that this client left before we remove it from the hub/region
		state.client.Broadcast(packets.NewClientLeft(character.Name))
	}

	// If we are connected to a region, remove the client from this region
	if state.client.GetRegion() != nil {
		state.client.GetRegion().RemoveClientChannel <- state.client
		time.Sleep(50 * time.Millisecond) // Brief pause
		state.client.SetRegion(nil)
	}

	// Unregister this username from our Hub's usernameToClient map
	if username := state.client.GetAccountUsername(); username != "" {
		state.client.GetHub().UnregisterUsername(username)
	}

	// Clear the previous account data from this client connection
	state.client.SetAccountUsername("")
	state.client.SetCharacterId(0)
	state.client.SetPlayerCharacter(nil)

	// Switch the client to the Authentication state
	state.client.SetState(&Authentication{})
}

// Broadcast to everybody we either opened/closed our chat input
func (state *Game) HandleChatBubble(payload *packets.ChatBubble) {
	state.client.Broadcast(packets.NewChatBubble(payload.GetIsActive()))
}

func (state *Game) HandleSwitchWeapon(payload *packets.SwitchWeapon) {
	slot := payload.GetSlot()
	// Validate slot (don't trust the client)
	if slot > 5 {
		return // Invalid slot
	}

	// Get the weapon at that slot
	weapon := state.player.GetWeaponSlot(slot)
	if weapon == nil || weapon.WeaponName == "" {
		return // Invalid slot or empty
	}

	// Update current slot
	state.player.SetCurrentWeapon(slot)

	// Broadcast weapon switch update to everyone in the region
	state.client.Broadcast(packets.NewSwitchWeapon(slot))
}

func (state *Game) HandleReloadWeapon(payload *packets.ReloadWeapon) {
	slot := payload.GetSlot()
	// Validate slot (don't trust the client)
	if slot > 5 {
		return // Invalid slot
	}

	// Get the weapon at that slot
	weapon := state.player.GetWeaponSlot(slot)
	if weapon == nil || weapon.WeaponName == "" {
		return // Invalid slot or empty
	}

	amount := payload.GetAmount()

	// TO FIX
	// Add a check here for the amount to reload
	// Create a way to check in the server for the max amount to reload for each weapon name

	// Update ammo for this weapon
	state.player.SetCurrentWeaponAmmo(amount) // <-- Trusting the client here, fix this

	// Broadcast weapon reload to everyone in the region
	state.client.Broadcast(packets.NewReloadWeapon(slot, amount))
}

func (state *Game) HandleRaiseWeapon() {
	// Broadcast to everyone in the region
	state.client.Broadcast(packets.NewRaiseWeapon())
}

func (state *Game) HandleLowerWeapon() {
	// Broadcast to everyone in the region
	state.client.Broadcast(packets.NewLowerWeapon())
}

func (state *Game) HandleRotateCharacter(payload *packets.RotateCharacter) {
	// Get the rotation from the packet
	newRotation := payload.GetRotationY()
	// Overwrite this character's rotation
	state.player.SetRotation(newRotation)
	// Broadcast to everyone in the region
	state.client.Broadcast(packets.NewRotateCharacter(newRotation))
}

func (state *Game) HandleFireWeapon(payload *packets.FireWeapon) {
	// Get the target position and attacker's rotation from the packet and broadcast to everyone in the region
	state.client.Broadcast(packets.NewFireWeapon(payload.GetX(), payload.GetY(), payload.GetZ(), payload.GetRotationY()))
}

func (state *Game) HandleToggleFireMode(payload *packets.ToggleFireMode) {
	// Overwrite this character's fire mode
	state.player.ToggleCurrentWeaponFireMode()
	// Broadcast to everyone in the region
	state.client.Broadcast(packets.NewToggleFireMode())
}

func (state *Game) HandleStartFiringWeapon(payload *packets.StartFiringWeapon) {
	// Get the attacker's rotation and available ammo from the packet and broadcast to everyone in the region
	state.client.Broadcast(packets.NewStartFiringWeapon(payload.GetRotationY(), payload.GetAmmo()))
}

func (state *Game) HandleStopFiringWeapon(payload *packets.StopFiringWeapon) {
	// Get the attacker's rotation and how many shots were fired from the packet and broadcast to everyone in the region
	state.client.Broadcast(packets.NewStopFiringWeapon(payload.GetRotationY(), payload.GetShotsFired()))
}

func (state *Game) HandleReportPlayerDamage(payload *packets.ReportPlayerDamage) {
	// Validate the target exists
	targetId := payload.GetTargetId()
	targetClient, exists := state.client.GetRegion().Clients.Get(targetId)
	if !exists {
		state.logger.Printf("Invalid target ID %d in damage report packet", targetId)
		return
	}

	// Get attacker's weapon information
	attackerWeapon := state.player.GetWeaponSlot(state.player.GetCurrentWeapon())
	if attackerWeapon == nil {
		state.logger.Printf("Attacker has no weapon equipped")
		return
	}

	// Calculate damage based on weapon type and weapon name?
	var damage uint64 = 5 // CAUTION placeholder

	// If was critical damage, then do double damage
	if payload.GetIsCritical() {
		damage = damage * 2
	}

	// Apply damage to target at server level here

	// DEBUG: Print the equipped weapon info
	state.logger.Printf("%s got hit with %s (%s)", targetClient.GetPlayerCharacter().Name, attackerWeapon.WeaponType, attackerWeapon.WeaponName)

	// Create apply damage packet and load it
	applyDamagePacket := packets.NewApplyPlayerDamage(
		state.client.GetId(),
		targetId,
		damage,
		"bullet",
		payload.GetX(),
		payload.GetY(),
		payload.GetZ(),
	)

	// Tell everyone to apply the damage (including the attacker)
	state.client.SendPacket(applyDamagePacket)
	state.client.Broadcast(applyDamagePacket)
}
