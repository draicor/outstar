package states

import (
	"context"
	"errors"
	"fmt"
	"log"
	"server/internal/server"
	"server/internal/server/db"
	"strings"

	"server/pkg/packets"

	"golang.org/x/crypto/bcrypt"
)

type Connected struct {
	client  server.ClientInterfacer
	logger  *log.Logger
	queries *db.Queries
	dbCtx   context.Context
}

func (state *Connected) Name() string {
	return "Connected"
}

func (state *Connected) SetClient(client server.ClientInterfacer) {
	// We save the client's data into this state
	state.client = client
	state.queries = client.GetDBTX().Queries
	state.dbCtx = client.GetDBTX().Ctx

	// Logging data in the server console
	prefix := fmt.Sprintf("Client %d [%s]: ", client.Id(), state.Name())
	state.logger = log.New(log.Writer(), prefix, log.LstdFlags)
}

func (state *Connected) OnEnter() {
	// A newly connected client will receive its own ID
	state.client.SocketSend(packets.NewHandshake())
	// We don't broadcast this client's arrival here because
	// we are doing it from the Godot client
}

func (state *Connected) HandleMessage(senderId uint64, payload packets.Payload) {
	// If this message was sent by our client
	if senderId == state.client.Id() {
		// Switch based on the type of packet
		// We also save the casted packet in case we need to access specific fields
		switch casted_payload := payload.(type) {

		// PUBLIC MESSAGE
		case *packets.Packet_ChatMessage:
			state.client.Broadcast(payload)

		// HEARTBEAT
		case *packets.Packet_Heartbeat:
			state.client.SocketSend(packets.NewHeartbeat())

		// CLIENT ENTERED
		case *packets.Packet_ClientEntered:
			state.HandleClientEntered(state.client.GetNickname())

		// CLIENT LEFT
		case *packets.Packet_ClientLeft:
			state.HandleClientLeft(state.client.GetNickname())

		// SWITCH ZONE
		case *packets.Packet_SwitchZoneRequest:
			state.HandleSwitchZoneRequest(casted_payload)

		// LOGIN
		case *packets.Packet_LoginRequest:
			state.HandleLoginRequest(senderId, casted_payload)

		// REGISTER
		case *packets.Packet_RegisterRequest:
			state.HandleRegisterRequest(senderId, casted_payload)

		case nil:
			// Ignore packet if not a valid payload type
		default:
			// Ignore packet if no payload was sent
		}

	} else {
		// If another client or the hub passed us this message, forward it to our client
		state.client.SocketSendAs(payload, senderId)
	}
}

func (state *Connected) HandleLoginRequest(senderId uint64, payload *packets.Packet_LoginRequest) {
	// If client used a different ID than his own ID, ignore this packet
	if senderId != state.client.Id() {
		state.logger.Printf("Unauthorized login packet: ID#%d != ID#%d", senderId, state.client.Id())
		return
	}

	// We make the username lowercase before trying to access the database
	username := strings.ToLower(payload.LoginRequest.Username)

	// We validate the username and if we find an error we deny the request
	err := validateUsername(username)
	if err != nil {
		reason := fmt.Sprintf("Invalid username: %v", err)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// We store the password for ease of use here
	password := payload.LoginRequest.Password

	// We validate the password and if we find an error we deny the request
	err = validatePassword(password)
	if err != nil {
		reason := fmt.Sprintf("Invalid password: %v", err)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// Generic failure message to prevent attackers from brute-forcing credentials
	deniedMessage := packets.NewRequestDenied("Invalid username or password")

	// Check if the username exists in the database (case insensitive)
	user, err := state.queries.GetUserByUsername(state.dbCtx, username)
	if err != nil {
		state.logger.Printf("Username %s error: %v", username, err)
		state.client.SocketSend(deniedMessage)
		return
	}

	// If the username exists, we compare the passwords to see if they match
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password))
	if err != nil {
		state.logger.Printf("Invalid password attempt from %s", user.Nickname)
		state.client.SocketSend(deniedMessage)
		return
	}

	// Store this client's nickname in memory
	state.client.SetNickname(user.Nickname)
	state.logger.Printf("%s logged in as %s", username, user.Nickname)
	state.client.SocketSend(packets.NewRequestGranted())
}

func (state *Connected) HandleRegisterRequest(senderId uint64, payload *packets.Packet_RegisterRequest) {
	// If client used a different ID than his own ID, ignore this packet
	if senderId != state.client.Id() {
		state.logger.Printf("Unauthorized register packet: ID#%d != ID#%d", senderId, state.client.Id())
		return
	}

	// Get the password from the packet for ease of use
	// We store usernames in lowercase to avoid case-sensitivity issues
	username := strings.ToLower(payload.RegisterRequest.Username)

	// We validate the username and if we find an error we deny the request
	err := validateUsername(username)
	if err != nil {
		reason := fmt.Sprintf("Invalid username: %v", err)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// Check if the username already exists in the database
	_, err = state.queries.GetUserByUsername(state.dbCtx, username)
	// If we DIDN'T FIND an error, then we found a user, that means username is already in use
	if err == nil {
		reason := fmt.Sprintf("Username %s already in use", username)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// Get the nickname from the packet for ease of use
	nickname := payload.RegisterRequest.Nickname

	// We validate the nickname and if we find an error we deny the request
	err = validateNickname(nickname)
	if err != nil {
		reason := fmt.Sprintf("Invalid nickname: %v", err)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// We store nicknames in lowercase except the first character to avoid case-sensitivity issues
	nickname, err = capitalize(nickname)
	if err != nil {
		reason := fmt.Sprintf("Invalid nickname: %v", err)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// Check if the nickname already exists in the database
	_, err = state.queries.GetUserByNickname(state.dbCtx, nickname)
	// If we DIDN'T FIND an error, then we found a user, that means nickname is already in use
	if err == nil {
		reason := fmt.Sprintf("Nickname %s already in use", nickname)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// Get the password from the packet for ease of use
	password := payload.RegisterRequest.Password

	// We validate the password and if we find an error we deny the request
	err = validatePassword(password)
	if err != nil {
		reason := fmt.Sprintf("Invalid password: %v", err)
		state.logger.Println(reason)
		state.client.SocketSend(packets.NewRequestDenied(reason))
		return
	}

	// If we got this far, it means the user inputted valid data!

	// We setup a generic denied message if the registration fails
	deniedMessage := packets.NewRequestDenied("Error registering user (internal server error)")

	// Attempt to hash the password
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(payload.RegisterRequest.Password), bcrypt.DefaultCost)
	if err != nil {
		state.logger.Printf("Error registering user (Bcrypt failure)")
		state.client.SocketSend(deniedMessage)
		return
	}

	// Attempt to register a new user
	_, err = state.queries.CreateUser(state.dbCtx, db.CreateUserParams{
		Username:     username,
		Nickname:     nickname,
		PasswordHash: string(passwordHash),
	})
	if err != nil {
		state.logger.Printf("Error registering user (Database failure)")
		state.client.SocketSend(deniedMessage)
		return
	}

	state.logger.Printf("New user %s registered successfully", nickname)
	state.client.SocketSend(packets.NewRequestGranted())
}

// We send this message to everybody
func (state *Connected) HandleClientEntered(nickname string) {
	state.client.Broadcast(packets.NewClientEntered(nickname))
}

// We send this message to everybody
func (state *Connected) HandleClientLeft(nickname string) {
	state.client.Broadcast(packets.NewClientLeft(nickname))
}

// TO FIX -> No symbols on the username
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

// TO FIX -> No symbols on the username
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

func (state *Connected) OnExit() {
	// pass
}

// Sent by the client to request joining a new zone
func (state *Connected) HandleSwitchZoneRequest(payload *packets.Packet_SwitchZoneRequest) {
	state.client.SetZone(payload.SwitchZoneRequest.GetZoneId())
}
