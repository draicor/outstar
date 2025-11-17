package states

import (
	"errors"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/objects"
	"strings"
	"time"

	"server/pkg/packets"

	"golang.org/x/crypto/bcrypt"
)

const disconnectTimeout time.Duration = 2 // 2 minutes

type Authentication struct {
	client          server.Client
	logger          *log.Logger
	lastActivity    time.Time   // Track last activity
	inactivityTimer *time.Timer // Disconnects player due to inactivity
}

func (state *Authentication) GetName() string {
	return "Authentication"
}

func (state *Authentication) SetClient(client server.Client) {
	// We save the client's data into this state
	state.client = client

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Authentication) OnEnter() {
	// Keep track of last activity time
	state.lastActivity = time.Now()

	// Create a timer that will disconnect after two minutes
	state.inactivityTimer = time.AfterFunc(disconnectTimeout*time.Minute, func() {
		// Check that our client hasn't disconnected already
		if state.client != nil {
			state.client.Close("authentication timeout")
		}
	})

	// Send the client the server's info
	// We send the number of accounts connected
	state.client.SendPacket(packets.NewServerMetrics(state.client.GetHub().GetConnectedAccounts()))
}

func (state *Authentication) HandlePacket(senderId uint64, payload packets.Payload) {
	// If this packet was sent by our client
	if senderId == state.client.GetId() {

		// Reset activity timer on any packet
		state.lastActivity = time.Now()
		if state.inactivityTimer != nil {
			// If timer already fired, client should be disconnected
			if !state.inactivityTimer.Stop() {
				return
			}
			state.inactivityTimer.Reset(disconnectTimeout * time.Minute)
		}

		// Switch based on the type of packet
		// We also save the casted packet in case we need to access specific fields
		switch casted_payload := payload.(type) {

		// LOGIN REQUEST
		case *packets.Packet_LoginRequest:
			state.HandleLoginRequest(senderId, casted_payload.LoginRequest)

		// REGISTER REQUEST
		case *packets.Packet_RegisterRequest:
			state.HandleRegisterRequest(senderId, casted_payload.RegisterRequest)

		case nil:
			// Ignore packet if not a valid payload type
		default:
			// Ignore packet if no payload was sent
		}

	} else {
		// If another client passed us this packet, forward it to our client
		state.client.SendPacketAs(senderId, payload)
	}
}

func (state *Authentication) HandleLoginRequest(senderId uint64, payload *packets.LoginRequest) {
	// If client used a different ID than his own ID, ignore this packet
	if senderId != state.client.GetId() {
		state.logger.Printf("Unauthorized login packet: ID#%d != ID#%d", senderId, state.client.GetId())
		return
	}

	// We make the username lowercase before trying to access the database
	username := strings.ToLower(payload.Username)

	// We validate the username and if we find an error we deny the request
	err := validateUsername(username)
	if err != nil {
		reason := fmt.Sprintf("Invalid username: %v", err)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// We store the password for ease of use here
	password := payload.Password

	// We validate the password and if we find an error we deny the request
	err = validatePassword(password)
	if err != nil {
		reason := fmt.Sprintf("Invalid password: %v", err)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// Generic failure message to prevent attackers from brute-forcing credentials
	deniedMessage := packets.NewRequestDenied("Invalid username or password")

	// Check if the username exists in the database (case insensitive)
	user, err := state.client.GetHub().GetUserByUsername(username)
	if err != nil {
		state.logger.Printf("Username %s error: %v", username, err)
		state.client.SendPacket(deniedMessage)
		return
	}

	// If the username exists, we compare the passwords to see if they match
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password))
	if err != nil {
		state.logger.Printf("Invalid password attempt from %s", user.Nickname)
		state.client.SendPacket(deniedMessage)
		return
	}

	// Make sure the account is not already connected to a region (logged in)
	if state.client.GetHub().IsAlreadyConnected(username) {
		state.logger.Printf("%s is already logged in", user.Nickname)
		// We override the denied message
		deniedMessage = packets.NewRequestDenied("Account already connected")
		state.client.SendPacket(deniedMessage)
		return

	}

	// We save the username in our server's memory to prevent others from connecting
	// On client disconnect, the whole client object gets removed from memory, so we don't
	// have to set the username when the client leaves
	state.client.SetAccountUsername(username)
	state.client.SetCharacterId(user.CharacterID.Int64)
	// Register this username in our Hub's usernameToClient map for 0(1) lookups
	state.client.GetHub().RegisterUsername(username, state.client.GetId())

	character, weapons, err := state.client.GetHub().GetFullCharacterData(user.CharacterID.Int64)

	// If we got an error trying to load this character from database
	if err != nil {
		deniedMessage = packets.NewRequestDenied("Error loading character from database")
		state.client.SendPacket(deniedMessage)
		return
	}

	// TO FIX -> Load all of this from the database [eventually!]
	var level uint64 = 1
	var experience uint64 = 1

	// Validate some data before setting the player
	var health uint64 = uint64(character.Health)
	var maxHealth uint64 = uint64(character.MaxHealth)
	if health <= 0 || health > maxHealth {
		health = maxHealth
	}

	// Recreate this client's player/character data from the database!
	state.client.SetPlayerCharacter(objects.CreatePlayer(
		// Basic data
		user.Nickname,
		character.Gender,
		uint64(character.Speed),
		character.RotationY,
		// Weapon Data
		uint64(character.WeaponSlot),
		*weapons,
		// Stats
		level, experience, // TO FIX -> Load this from the database too!
		// Atributes
		health,
		maxHealth,
	))

	state.logger.Printf("%s logged in as %s", username, user.Nickname)
	// We send the nickname to the client so he can display it on his own game client
	state.client.SendPacket(packets.NewLoginSuccess(user.Nickname))
	// After the client logs in, switch to the Game state
	state.client.SetState(&Game{})
}

func (state *Authentication) HandleRegisterRequest(senderId uint64, payload *packets.RegisterRequest) {
	// If client used a different ID than his own ID, ignore this packet
	if senderId != state.client.GetId() {
		state.logger.Printf("Unauthorized register packet: ID#%d != ID#%d", senderId, state.client.GetId())
		return
	}

	// Get the password from the packet for ease of use
	// We store usernames in lowercase to avoid case-sensitivity issues
	username := strings.ToLower(payload.Username)

	// We validate the username and if we find an error we deny the request
	err := validateUsername(username)
	if err != nil {
		reason := fmt.Sprintf("Invalid username: %v", err)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// Check if the username already exists in the database
	_, err = state.client.GetHub().GetUserByUsername(username)
	// If we DIDN'T FIND an error, then we found a user, that means username is already in use
	if err == nil {
		reason := fmt.Sprintf("Username %s already in use", username)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// Get the nickname from the packet for ease of use
	nickname := payload.Nickname

	// We validate the nickname and if we find an error we deny the request
	err = validateNickname(nickname)
	if err != nil {
		reason := fmt.Sprintf("Invalid nickname: %v", err)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// We store nicknames in lowercase except the first character to avoid case-sensitivity issues
	nickname, err = capitalize(nickname)
	if err != nil {
		reason := fmt.Sprintf("Invalid nickname: %v", err)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// Check if the nickname already exists in the database
	_, err = state.client.GetHub().GetUserByNickname(nickname)
	// If we DIDN'T FIND an error, then we found a user, that means nickname is already in use
	if err == nil {
		reason := fmt.Sprintf("Nickname %s already in use", nickname)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// Get the password from the packet for ease of use
	password := payload.Password

	// We validate the password and if we find an error we deny the request
	err = validatePassword(password)
	if err != nil {
		reason := fmt.Sprintf("Invalid password: %v", err)
		state.logger.Println(reason)
		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	// If we got this far, it means the user inputted valid data!

	// We setup a generic denied message if the registration fails
	deniedMessage := packets.NewRequestDenied("Error registering user (internal server error)")

	// Attempt to hash the password
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(payload.Password), bcrypt.DefaultCost)
	if err != nil {
		state.logger.Printf("Error registering user (Bcrypt failure)")
		state.client.SendPacket(deniedMessage)
		return
	}

	// Attempt to register a new user
	user, err := state.client.GetHub().CreateUser(username, nickname, string(passwordHash), payload.Gender)
	if err != nil {
		var reason string
		if strings.Contains(err.Error(), "UNIQUE constraint") {
			if strings.Contains(err.Error(), "username") {
				reason = "Username already exists"
			} else if strings.Contains(err.Error(), "nickname") {
				reason = "Nickname already exists"
			} else {
				reason = "Account creation failed"
			}
		} else {
			reason = "Internal server error"
			state.logger.Printf("Registration error :%v", err)
		}

		state.client.SendPacket(packets.NewRequestDenied(reason))
		return
	}

	state.logger.Printf("New user %s registered successfully (ID: %d)", nickname, user.ID)
	state.client.SendPacket(packets.NewRequestGranted())
}

// FIX -> No symbols on the username
// Validate username before registration
func validateUsername(username string) error {
	if len(username) <= 0 {
		return errors.New("username can't be empty")
	}
	if len(username) > 32 {
		return errors.New("username is too long")
	}
	if username != strings.TrimSpace(username) {
		return errors.New("username can't have spaces")
	}
	return nil
}

// FIX -> No symbols on the username
// Validate nickname before registration
func validateNickname(nickname string) error {
	if len(nickname) <= 0 {
		return errors.New("nickname can't be empty")
	}
	if len(nickname) > 20 {
		return errors.New("nickname is too long")
	}
	if nickname != strings.TrimSpace(nickname) {
		return errors.New("nickname can't have spaces")
	}
	return nil
}

// Validate password before registration
func validatePassword(password string) error {
	if len(password) <= 0 {
		return errors.New("password can't be empty")
	}
	if len(password) < 8 {
		return errors.New("password is too short")
	}
	if len(password) > 64 {
		return errors.New("password is too long")
	}
	if password != strings.TrimSpace(password) {
		return errors.New("password can't have spaces")
	}

	return nil
}

// Gets the first character and make it a capital letter, append the rest as lowercase
func capitalize(text string) (string, error) {
	// If we pass an empty string to this function it will crash!
	if len(text) <= 0 {
		return "", errors.New("can't be empty")
	}

	return strings.ToUpper(string(text[0])) + strings.ToLower(string(text[1:])), nil
}

func (state *Authentication) OnExit() {
	// Stop the timer when leaving this state
	if state.inactivityTimer != nil {
		state.inactivityTimer.Stop()
	}
}
