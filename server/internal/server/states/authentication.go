package states

import (
	"context"
	"errors"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"server/internal/server/math"
	"server/internal/server/objects"
	"strings"

	"server/pkg/packets"

	"golang.org/x/crypto/bcrypt"
)

type Authentication struct {
	client  server.Client
	logger  *log.Logger
	queries *db.Queries
	dbCtx   context.Context
}

func (state *Authentication) GetName() string {
	return "Authentication"
}

func (state *Authentication) SetClient(client server.Client) {
	// We save the client's data into this state
	state.client = client
	state.queries = client.GetDBTX().Queries
	state.dbCtx = client.GetDBTX().Ctx

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.GetId(), state.GetName())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Authentication) OnEnter() {
	// Pass
}

func (state *Authentication) HandlePacket(senderId uint64, payload packets.Payload) {
	// If this packet was sent by our client
	if senderId == state.client.GetId() {
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
	user, err := state.queries.GetUserByUsername(state.dbCtx, username)
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

	// TO FIX -> Load all of this from the database
	var regionId uint64 = 1
	var rotationY float64 = math.DegreesToRadians(180)
	// TO FIX -> Implement a variable to switch between walk/run
	var level uint64 = 1
	var experience uint64 = 1
	var speed uint64 = 3

	// Create this client's player/character data from the database!
	state.client.SetPlayerCharacter(objects.CreatePlayer(
		user.Nickname, regionId,
		// Position
		rotationY,
		// Stats
		level, experience,
		// Atributes
		speed,
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
	_, err = state.queries.GetUserByUsername(state.dbCtx, username)
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
	_, err = state.queries.GetUserByNickname(state.dbCtx, nickname)
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

	// TO FIX -> Save all of the DEFAULT character data to the database

	// Attempt to register a new user
	_, err = state.queries.CreateUser(state.dbCtx, db.CreateUserParams{
		Username:     username,
		Nickname:     nickname,
		PasswordHash: string(passwordHash),
	})
	if err != nil {
		state.logger.Printf("Error registering user (Database failure)")
		state.client.SendPacket(deniedMessage)
		return
	}

	state.logger.Printf("New user %s registered successfully", nickname)
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
	// pass
}
