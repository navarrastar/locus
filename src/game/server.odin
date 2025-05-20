package game

import "core:log"

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:net"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:thread"

import steam "../../third_party/steamworks"

client_ticket: steam.HAuthTicket
AUTH_TICKET_SIZE :: 1024 // in bytes
STEAM_ID_SIZE :: 8 // in bytes

SERVER_IP_STR :: "2600:3c00::f03c:95ff:fe44:bdfc"
SERVER_IP: [16]u8
SERVER_PORT :: 27015
QUERY_PORT :: 27030

MAX_PLAYERS :: 8
PlayerSpot :: enum {
	None,
	Player1,
	Player2,
	Player3,
	Player4,
	PLayer5,
	Player6,
	Player7,
	Player8,
}

Connection :: struct {
	spot:    PlayerSpot,
	steamID: steam.CSteamID,
}

ConnectionCallback :: proc(args: ^ConnectionArgs)

ConnectionArgs :: struct {
	user:     ^steam.IUser,
	err:      ServerError,
	callback: ConnectionCallback,
}

Network_AttemptConnection :: struct {
	ticket:  [AUTH_TICKET_SIZE]byte,
	steamID: steam.CSteamID,
}

ServerError :: enum {
	None,
	Timeout,
	AlreadyFull,
	Dial,
	Send,
	EndpointParse,
	Unknown,
}

@(init)
_init_server_ip :: proc() {
	SERVER_IP, _ = _ip6_string_to_bytes(SERVER_IP_STR)
}

server_state: struct {
	game_server:   ^steam.IGameServer,
	connections:   [MAX_PLAYERS]Connection,
	listen_socket: net.TCP_Socket,
	listen_thread: ^thread.Thread,
	bRunning:      bool,
	err_msg:       steam.SteamErrMsg,
}

server_init :: proc(port: u16) {
	log.info("Initializing Server")

	networking_ip := &steam.SteamNetworkingIPAddr{ipv6 = SERVER_IP, port = port}

	log.info("Starting SteamGameServer")

	res := steam.SteamGameServer_InitEx(
		0,
		SERVER_PORT,
		QUERY_PORT,
		.NoAuthentication,
		"0.0.1",
		&server_state.err_msg,
	)

	log.assertf(res == .OK, "SteamGameServer_InitEx: ", res)
	log.info("SteamGameServer_InitEx successful")

	server_state.game_server = steam.GameServer()

	steam.GameServer_SetProduct(server_state.game_server, "locus")
	steam.GameServer_SetGameDescription(server_state.game_server, "Game Server Description")
	steam.GameServer_SetGameTags(server_state.game_server, "pvp,multiplayer")
	steam.GameServer_SetMaxPlayerCount(server_state.game_server, 4)
	steam.GameServer_SetPasswordProtected(server_state.game_server, false)
	steam.GameServer_SetServerName(server_state.game_server, "My First Server")
	steam.GameServer_SetDedicatedServer(server_state.game_server, true)

	steam.GameServer_LogOnAnonymous(server_state.game_server)

	addr, ok := net.parse_ip6_address(SERVER_IP_STR)
	if !ok do log.panic("Failed to parse SERVER_IP_STR")

	server_endpoint := net.Endpoint {
		address = addr,
		port    = SERVER_PORT,
	}

	listen_err: net.Network_Error
	server_state.listen_socket, listen_err = net.listen_tcp(server_endpoint)
	log.assertf(listen_err == nil, "Failed to start TCP listener: %v", listen_err)

	log.info("listen_tcp successful")

	server_state.bRunning = true
	server_state.listen_thread = thread.create_and_start(_server_proc_connection_listener)
}

server_update :: proc() {

}

server_cleanup :: proc() {


	steam.SteamGameServer_Shutdown()
}

user_connect_to_server_async :: proc(user: ^steam.IUser) {
	args := new(ConnectionArgs)
	args^ = ConnectionArgs {
		user     = user,
		err      = .None,
		callback = user_connection_finished,
	}

	thread.create_and_start_with_data(args, _user_proc_connect_to_server)
}

_user_proc_connect_to_server :: proc(args_ptr: rawptr) {
	args := cast(^ConnectionArgs)args_ptr
	defer (args->callback())

	networking_identity: steam.SteamNetworkingIdentity
	networking_identity.eType = .IPAddress
	mem.copy(&networking_identity.szUnknownRawString, &SERVER_IP, size_of(SERVER_IP))
	ticket: [AUTH_TICKET_SIZE]byte
	ticket_length: u32
	client_ticket = steam.User_GetAuthSessionTicket(
		args.user,
		&ticket[0],
		1024,
		&ticket_length,
		networking_identity,
	)

	server_endpoint_str := fmt.tprintf("[%s]:%d", SERVER_IP_STR, SERVER_PORT)

	fmt.printfln("Attempting to connect to server at %s", server_endpoint_str)
	endpoint, ok := net.parse_endpoint(server_endpoint_str)
	if ok != true {
		steam.User_CancelAuthTicket(args.user, client_ticket)

		fmt.printfln("Networking: Error parsing server endpoint '%s': %v", server_endpoint_str)
		args.err = .EndpointParse
		return
	}

	network_data: Network_AttemptConnection
	network_data.ticket = ticket
	steamID := steam.User_GetSteamID(args.user)
	mem.copy(&network_data.steamID, &steamID, STEAM_ID_SIZE)
	network_data_bytes := mem.byte_slice(&network_data, size_of(Network_AttemptConnection))

	socket, dial_err := net.dial_tcp(endpoint)
	defer net.close(socket)
	if dial_err != nil {
		steam.User_CancelAuthTicket(args.user, client_ticket)

		fmt.printf("Error dialing endpoint\n    Endpoint: %d\n    Error: %v\n", endpoint, dial_err)
		args.err = .Dial
		return
	}

	bytes_written_count, send_err := net.send_tcp(socket, network_data_bytes)
	if send_err != nil {
		steam.User_CancelAuthTicket(args.user, client_ticket)

		fmt.printf(
			"Error sending ticket to socket\n    Ticket: %v\n    Socket: %v\n    Error: %v\n",
			ticket,
			socket,
			send_err,
		)
		args.err = .Send
		return
	}

	args.err = .None
	return
}

user_connection_finished :: proc(args: ^ConnectionArgs) {
	defer free(args)

	switch args.err {
	case .None:
		fmt.println("User successfully sent join request to server")
		connection := Connection {
			steamID = steam.User_GetSteamID(args.user),
		}
		server_state.connections[0] = connection
	case .Dial:
		fmt.println("Error dialing server, make sure it is running")
	case .AlreadyFull:
		fmt.println("Tried to add a user to the server when it is already full")
	case .Timeout:
		fmt.println("Server timed out while trying to add user")
	case .EndpointParse:
		fmt.println("Error parsing the server endpoint")
	case .Send:
		fmt.println("Error sending ticket to socket")
	case .Unknown:
		fmt.println("Unknown error while connecting user")
	}
}


server_is_ready :: proc() -> bool {
	return true
}

_server_proc_connection_listener :: proc() {
	fmt.printfln("Started connection listener thread")

	for server_state.bRunning {
		client_socket, endpoint, accept_err := net.accept_tcp(server_state.listen_socket)
		defer net.close(client_socket)
		if accept_err != nil {
			fmt.printfln("Error accepting connection: %v", accept_err)
			continue
		}
		fmt.println("accept_tcp successful")

		player_spot := _server_get_open_spot()
		if player_spot == .None {
		    fmt.println("Tried to add a player but server is full")
			continue
		} 
		
		if steamID, server_err := _server_handle_client_connection(client_socket); server_err != .None {
            fmt.printfln("SteamID %v joined spot %v", steamID,  player_spot)
            
            conn := Connection {
                spot = player_spot,
                steamID = steamID
            }
            server_state.connections[player_spot] = conn
		}
		

	}
}

_server_handle_client_connection :: proc(socket: net.TCP_Socket) -> (id: steam.CSteamID, err: ServerError) {
	fmt.printfln("Connecting a client...")

	attempt_connection_buf := make([]byte, size_of(Network_AttemptConnection))
	bytes_read_count, recv_err := net.recv_tcp(socket, attempt_connection_buf)
	log.assertf(recv_err == nil, "")

	attempt_connection := transmute(^Network_AttemptConnection)raw_data(attempt_connection_buf)
	
    auth_result := steam.GameServer_BeginAuthSession(
        server_state.game_server,
        &attempt_connection.ticket,
        i32(AUTH_TICKET_SIZE),
        attempt_connection.steamID,
    )
	
	return attempt_connection.steamID, .None
}

user_leave_server :: proc(user: ^steam.IUser) {
    steam.User_CancelAuthTicket(user, client_ticket)
    steamID := steam.User_GetSteamID(user)
    for conn in server_state.connections {
        if conn.steamID == steamID {
            steam.User_EndAuthSession(user, steamID)
        }
    }
}

_server_get_open_spot :: proc() -> PlayerSpot {
	open_spot: PlayerSpot
	for conn, i in server_state.connections {
		if conn.spot == .None do open_spot = PlayerSpot(i)
	}
	return open_spot
}

@(require_results)
_ip6_string_to_bytes :: proc(s: string) -> (bytes: [16]u8, ok: bool) {
	s := s
	if len(s) > 0 && s[0] == '[' && s[len(s) - 1] == ']' {
		s = s[1:len(s) - 1]
	}

	parts := strings.split(s, ":")
	if len(parts) > 8 {
		return {}, false
	}

	compressed_idx := -1
	for part, i in parts {
		if part == "" {
			compressed_idx = i
			break
		}
	}

	zero_groups := 8 - len(parts)
	if compressed_idx == -1 && zero_groups != 0 {
		return {}, false
	}

	byte_idx := 0
	for part, i in parts {
		if i == compressed_idx {
			// Insert zero groups
			for j in 0 ..< zero_groups {
				bytes[byte_idx] = 0
				bytes[byte_idx + 1] = 0
				byte_idx += 2
			}
			continue
		}

		if part == "" {
			continue
		}

		val, ok := strconv.parse_u64(part, 16)
		if !ok {
			return {}, false
		}

		bytes[byte_idx] = u8(val >> 8)
		bytes[byte_idx + 1] = u8(val & 0xFF)
		byte_idx += 2
	}

	return bytes, true
}
