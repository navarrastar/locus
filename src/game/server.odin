package game

import "core:log"

import "core:fmt"
import "core:mem"
import "core:net"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:slice"

import steam "../../third_party/steamworks"

AUTH_TICKET_SIZE :: 1024 // in bytes
STEAM_ID_SIZE :: 8 // in bytes
MAX_PLAYERS :: 16

SERVER_IP_STR :: "2600:3c00::f03c:95ff:fe44:bdfc"
SERVER_IP: [16]u8
SERVER_PORT :: 27015
QUERY_PORT :: 27030

Connection :: struct {
	socket:         net.TCP_Socket,
	steamID:        steam.CSteamID,
	bAuthenticated: bool,
}

Network_AttemptConnection :: struct {
    ticket:  [AUTH_TICKET_SIZE]byte,
    steamID: [STEAM_ID_SIZE]byte
}

ServerError :: enum {
    None,
    Timeout,
    AlreadyFull,
    Unknown
}

@(init)
_init_server_ip :: proc() {
	SERVER_IP, _ = _ip6_string_to_bytes(SERVER_IP_STR)
}

server_state: struct {
	game_server:      ^steam.IGameServer,
	connections:      [MAX_PLAYERS]Connection,
	connection_mutex: sync.Mutex,
	listen_socket:    net.TCP_Socket,
	listen_thread:    ^thread.Thread,
	bRunning:         bool,
	err_msg:          steam.SteamErrMsg,
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
		port = SERVER_PORT,
	}
	
    listen_err: net.Network_Error
    server_state.listen_socket, listen_err = net.listen_tcp(server_endpoint)
    
    log.assertf(listen_err == nil, "Failed to start TCP listener: %v", listen_err)
    log.info("listen_tcp successful")
    
    server_state.listen_thread = thread.create_and_start(_server_proc_connection_listener)
}

server_update :: proc() {

}

server_cleanup :: proc() {


	steam.SteamGameServer_Shutdown()
}

user_connect_to_server :: proc(user: ^steam.IUser) -> bool {
	networking_identity: steam.SteamNetworkingIdentity
	networking_identity.eType = .IPAddress
	mem.copy(&networking_identity.szUnknownRawString, &SERVER_IP, size_of(SERVER_IP))
	ticket: rawptr
	ticket_length: u32
	ticket_handle := steam.User_GetAuthSessionTicket(
		user,
		ticket,
		1024,
		&ticket_length,
		networking_identity,
	)

	server_endpoint_str := fmt.tprintf("[%s]:%d", SERVER_IP_STR, SERVER_PORT)

	log.infof("Networking: Attempting to connect to server at %s", server_endpoint_str)
	endpoint, ok := net.parse_endpoint(server_endpoint_str)
	if ok != true {
		log.errorf("Networking: Error parsing server endpoint '%s': %v", server_endpoint_str)
		steam.User_CancelAuthTicket(user, ticket_handle)
		return false
	}

	network_data: Network_AttemptConnection
	ticket_slice := slice.bytes_from_ptr(ticket, int(ticket_length))
	copy(network_data.ticket[:], ticket_slice)
	steamID := steam.User_GetSteamID(user)
	mem.copy(&network_data.steamID, &steamID, STEAM_ID_SIZE)
	network_data_bytes := mem.slice_ptr(&network_data, size_of(Network_AttemptConnection))
	
	socket, dial_err := net.dial_tcp(endpoint)
	defer net.close(socket)
	if dial_err != nil {
	    log.errorf("Error dialing endpoint\n    Endpoint: %v\n    Error: %v\n", endpoint, dial_err)
		return false
	}
	
	bytes_written_count, send_err := net.send_tcp(socket, transmute([]byte)network_data_bytes)
	if send_err != nil {
		log.errorf("Error sending ticket to socket\n    Ticket: %v\n    Socket: %v\n    Error: %v", ticket, socket, send_err)
		return false
	}

	return true
}


server_is_ready :: proc() -> bool {
	return true
}

_server_proc_connection_listener :: proc() {
    log.info("Started connection listener thread")
    
    for server_state.bRunning {
        client_socket, endpoint, accept_err := net.accept_tcp(server_state.listen_socket)
        if accept_err != nil {
            log.errorf("Error accepting connection: %v", accept_err)
            continue
        }
        
        _server_handle_client_connection(client_socket)
    }
}

_server_handle_client_connection :: proc(socket: net.TCP_Socket) -> ServerError {
    log.info("Connecting a client...")
    
    sync.mutex_lock(&server_state.connection_mutex)
    defer(sync.mutex_unlock(&server_state.connection_mutex))
    
    open_spot := -1
    for i in 0..<MAX_PLAYERS {
        if server_state.connections[i].socket == 0 {
            open_spot = i
            break
        }
    }
    if open_spot == -1 { 
        log.error("Tried to connect a client when the server is full")
        return .AlreadyFull
    }
    
    server_state.connections[open_spot].socket = socket
    log.infof("Client joined spot", open_spot)
    
    attempt_connection_buf: []byte
    net.recv_tcp(socket, attempt_connection_buf)
    
    return .None
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
