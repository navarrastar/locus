package server

import "base:runtime"

import "core:log"
import "core:fmt"
import "core:mem"
import "core:net"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:thread"

import steam "../../third_party/steamworks"


AUTH_TICKET_SIZE :: 1024 // in bytes
STEAM_ID_SIZE :: 8 // in bytes

SERVER_IP_STR :: "2600:3c00::f03c:95ff:fe44:bdfc"
SERVER_IP: [16]u8
SERVER_PORT :: 27015
QUERY_PORT :: 27030

MAX_PLAYERS :: 8

Connection :: struct {
	idx:     int,
	steamID: steam.CSteamID
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

init :: proc(port: u16) {
	log.info("Initializing Server")
	
	for &conn in server_state.connections {
	    conn.idx = -1
	}

	networking_ip := &steam.SteamNetworkingIPAddr{ipv6 = SERVER_IP, port = port}

	log.info("Starting SteamGameServer")

	res := steam.SteamGameServer_InitEx(
		0,
		SERVER_PORT,
		QUERY_PORT,
		.Authentication,
		"0.0.1",
		&server_state.err_msg,
	)
	
	steam.ManualDispatch_Init()

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

update :: proc() {
    _server_run_callbacks()
}

cleanup :: proc() {
    for conn in server_state.connections {
        if conn.idx != -1 do steam.GameServer_EndAuthSession(server_state.game_server, conn.steamID)
    }

	steam.SteamGameServer_Shutdown()
}

_server_run_callbacks :: proc() {
    temp_mem := make([dynamic]byte, context.temp_allocator)

    steam_pipe := steam.SteamGameServer_GetHSteamPipe()
    steam.ManualDispatch_RunFrame(steam_pipe)
    callback: steam.CallbackMsg

    for steam.ManualDispatch_GetNextCallback(steam_pipe, &callback) {
        fmt.println("Got a callback")
        #partial switch callback.iCallback {
        case .SteamAPICallCompleted:
            fmt.println("CallResult: ", callback)

            call_completed := transmute(^steam.SteamAPICallCompleted)callback.pubParam
            resize(&temp_mem, int(callback.cubParam))
            temp_call_res, ok := mem.alloc(int(callback.cubParam), allocator = context.temp_allocator)
            
            if !steam.ManualDispatch_GetAPICallResult(steam_pipe, call_completed.hAsyncCall, temp_call_res, callback.cubParam, callback.iCallback, &{}) {
                log.errorf("Failed to get steam api call result for callback: %s", callback.iCallback)
                return
            }
            
            // call identified by call_completed->m_hAsyncCall
            _server_handle_api_call_result(call_completed, temp_call_res)
            
        case .ValidateAuthTicketResponse:
            _server_callback_ValidateAuthTicketResponse(cast(^steam.ValidateAuthTicketResponse)callback.pubParam)
            
        case:
            fmt.println("Unhandled Callback:", callback.iCallback)
        }
        
        steam.ManualDispatch_FreeLastCallback(steam_pipe)
    }
}

_server_callback_ValidateAuthTicketResponse :: proc(data: ^steam.ValidateAuthTicketResponse) {
    fmt.printfln("ValidateAuthTicketResponse callback called with data: %v", data)
    #partial switch data.eAuthSessionResponse {
    case .AuthTicketCanceled:
        _server_remove_client(data.SteamID)
    }
}

_server_remove_client :: proc(steamID: steam.CSteamID) {
    steam.GameServer_EndAuthSession(server_state.game_server, steamID)
    for &conn in server_state.connections {
        if conn.steamID == steamID do conn = Connection{ idx = -1 }
        fmt.printfln("Removed %v from game server", steamID)
        break
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
		if player_spot == -1 {
		    fmt.println("Tried to add a player but server is full")
			continue
		} 
		
		if steamID, server_err := _server_handle_client_connection(client_socket); server_err == .None {
            fmt.printfln("SteamID %v joined spot %v", steamID,  player_spot)
            
            conn := Connection {
                idx = player_spot,
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
    assert(auth_result == .OK)
    fmt.printfln("steamID %v has authenticated with the game server", attempt_connection.steamID)
    
	return attempt_connection.steamID, .None
}

_server_get_open_spot :: proc() -> int {
	open_spot := -1
	for conn, i in server_state.connections {
		if conn.idx == -1 do open_spot = i
		break
	}
	return open_spot
}

_server_handle_api_call_result :: proc(call: ^steam.SteamAPICallCompleted, res: rawptr) {
    fmt.printfln("handle_api_call_result: %v", call)
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
