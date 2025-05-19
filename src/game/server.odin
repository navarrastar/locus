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

ConnectionCallback :: proc(args: ^ConnectionArgs)

ConnectionArgs :: struct {
    user: ^steam.IUser,
    err:  ServerError,
    mutex: sync.Mutex,
    callback: ConnectionCallback
}

Network_AttemptConnection :: struct {
    ticket:  [AUTH_TICKET_SIZE]byte,
    steamID: [STEAM_ID_SIZE]byte
}

ServerError :: enum {
    None,
    Timeout,
    AlreadyFull,
    Dial,
    Send,
    EndpointParse,
    Unknown
}

@(init)
_init_server_ip :: proc() {
	SERVER_IP, _ = _ip6_string_to_bytes(SERVER_IP_STR)
}

client_state: struct {
    args: ^ConnectionArgs,
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

user_connect_to_server_async :: proc(user: ^steam.IUser) {
    client_state.args = &ConnectionArgs {
            user = user,
            err = .None,
            callback = user_connection_finished
        }
    thread.create_and_start_with_data(client_state.args, _user_proc_connect_to_server)
}

user_connection_finished :: proc(args: ^ConnectionArgs) {
    if args.err == .None do return
    
}

_user_proc_connect_to_server :: proc(args_ptr: rawptr) {
    args := cast(^ConnectionArgs)args_ptr
    
    networking_identity: steam.SteamNetworkingIdentity
	networking_identity.eType = .IPAddress
	mem.copy(&networking_identity.szUnknownRawString, &SERVER_IP, size_of(SERVER_IP))
	ticket: [AUTH_TICKET_SIZE]byte
	ticket_length: u32
	ticket_handle := steam.User_GetAuthSessionTicket(
		args.user,
		&ticket[0],
		1024,
		&ticket_length,
		networking_identity,
	)
   
	server_endpoint_str := fmt.tprintf("[%s]:%d", SERVER_IP_STR, SERVER_PORT)
   
	log.infof("Attempting to connect to server at %s", server_endpoint_str)
	endpoint, ok := net.parse_endpoint(server_endpoint_str)
	if ok != true {
	    steam.User_CancelAuthTicket(args.user, ticket_handle)
		
		log.errorf("Networking: Error parsing server endpoint '%s': %v", server_endpoint_str)
		args.err = .EndpointParse
		return
	}
   
	network_data: Network_AttemptConnection
	network_data.ticket = ticket
	steamID := steam.User_GetSteamID(args.user)
	mem.copy(&network_data.steamID, &steamID, STEAM_ID_SIZE)
	network_data_bytes := mem.slice_ptr(&network_data, size_of(Network_AttemptConnection))
	
	socket, dial_err := net.dial_tcp(endpoint)
	defer net.close(socket)
	if dial_err != nil {
	    steam.User_CancelAuthTicket(args.user, ticket_handle)
		
	    log.errorf("Error dialing endpoint\n    Endpoint: %d\n    Error: %v\n", endpoint, dial_err)
		args.err = .Dial
		return
	}
	
	bytes_written_count, send_err := net.send_tcp(socket, transmute([]byte)network_data_bytes)
	if send_err != nil {
        steam.User_CancelAuthTicket(args.user, ticket_handle)
        
		log.errorf("Error sending ticket to socket\n    Ticket: %v\n    Socket: %v\n    Error: %v", ticket, socket, send_err)
		args.err = .Send
		return
	}
   
	args.err = .None
	args->callback()
	return
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
    bytes_read_count, recv_err := net.recv_tcp(socket, attempt_connection_buf)
    log.assertf(recv_err == nil, "")
    log.info("recv_tcp successful")
    
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
