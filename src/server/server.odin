package server

import "base:runtime"

import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sync"
import "core:time"

import steam "../../third_party/steamworks"
import toml "../../third_party/toml_parser"


CONFIG :: #load("config.toml")
AUTH_TICKET_SIZE :: 1024 // in bytes
STEAM_ID_SIZE :: 8 // in bytes

//SERVER_IP_STR :: "2600:3c00::f03c:95ff:fe44:bdfc"

Connection :: struct {
	idx:        int,
	steamID:    steam.CSteamID,
	steam_conn: steam.HSteamNetConnection,
	bConnected: bool,
	bAuthed:    bool,
}

ConnectionCallback :: proc(args: ^ConnectionArgs)

ConnectionArgs :: struct {
	user:     ^steam.IUser,
	serverID: steam.CSteamID,
	err:      ServerError,
	callback: ConnectionCallback,
}

Network_Authentication :: struct {
	type:    Network_MessageType,
	ticket:  [AUTH_TICKET_SIZE]byte,
	steamID: steam.CSteamID,
}

Network_MessageType :: enum u8 {
	Unknown,
	Authentication,
}

ServerError :: enum {
	None,
	DuplicateRequest,
	Timeout,
	AlreadyFull,
	Dial,
	Send,
	EndpointParse,
	Unknown,
}

Config :: struct {
	// [Network]
	game_port:   u16,
	query_port:  u16,

	// [Gameplay]
	tick_rate:   u16,
	server_name: string,
	max_players: u16,

	// [Steam]
	server_mode: u16,
}

server_state: struct {
	config:        Config,
	steamID:       steam.CSteamID,
	net_utils:     ^steam.INetworkingUtils,
	game_server:   ^steam.IGameServer,
	net_sockets:   ^steam.INetworkingSockets,
	listen_socket: steam.HSteamListenSocket,
	connections:   []Connection,
	poll_group:    steam.HSteamNetPollGroup,
	err_msg:       steam.SteamErrMsg,
}

_init_connections :: proc() {
	server_state.connections = make([]Connection, server_state.config.max_players)
	for &conn in server_state.connections {
		conn.idx = -1
	}
}

init :: proc() {
	log.info("Initializing Server")

	_init_config()
	_init_connections()

	log.info("Starting SteamGameServer")

	server_mode: steam.EServerMode
	res := steam.SteamGameServer_InitEx(
		0,
		server_state.config.game_port,
		server_state.config.query_port,
		steam.EServerMode(server_state.config.server_mode),
		"0.0.1",
		&server_state.err_msg,
	)
	log.assertf(res == .OK, "SteamGameServer_InitEx: ", res)
	log.info("SteamGameServer_InitEx successful")

	server_state.game_server = steam.GameServer()
	server_state.steamID = steam.GameServer_GetSteamID(server_state.game_server)
	server_state.net_utils = steam.NetworkingUtils_SteamAPI()

	steam.GameServer_SetModDir(server_state.game_server, "locus")
	steam.GameServer_SetProduct(server_state.game_server, "3070970")
	steam.GameServer_SetGameDescription(server_state.game_server, "locus server description")
	steam.GameServer_SetGameTags(server_state.game_server, "pvp,multiplayer")
	steam.GameServer_SetMaxPlayerCount(
		server_state.game_server,
		i32(server_state.config.max_players),
	)
	steam.GameServer_SetServerName(server_state.game_server, "locus server")
	steam.GameServer_SetDedicatedServer(server_state.game_server, true)
	steam.GameServer_LogOnAnonymous(server_state.game_server)

	steam.NetworkingUtils_InitRelayNetworkAccess(server_state.net_utils)

	steam.GameServer_SetAdvertiseServerActive(server_state.game_server, true)

	steam.ManualDispatch_Init()

	server_state.net_sockets = steam.GameServerNetworkingSockets()
	server_state.listen_socket = steam.NetworkingSockets_CreateListenSocketP2P(
		server_state.net_sockets,
		0,
		0,
		nil,
	)
	log.infof("Steam SDR Listen Socket created on virtual port %v", 0)

	server_state.poll_group = steam.NetworkingSockets_CreatePollGroup(server_state.net_sockets)
	log.assertf(
		server_state.poll_group != steam.HSteamNetPollGroup_Invalid,
		"Failed to create poll group",
	)
	log.info("Steam Networking Poll Group created.")

}

update :: proc() {
	time.sleep(time.Duration(1_000_000_000 / time.Duration(server_state.config.tick_rate)))

	_run_callbacks()
	_poll_network()
}

cleanup :: proc() {
	for conn in server_state.connections {
		if conn.idx != -1 do steam.GameServer_EndAuthSession(server_state.game_server, conn.steamID)
		steam.NetworkingSockets_CloseConnection(
			server_state.net_sockets,
			conn.steam_conn,
			0,
			"server_cleanup",
			false,
		)
	}
	delete(server_state.connections)

	steam.NetworkingSockets_CloseListenSocket(server_state.net_sockets, server_state.listen_socket)
	steam.NetworkingSockets_DestroyPollGroup(server_state.net_sockets, server_state.poll_group)

	steam.SteamGameServer_Shutdown()
}

_run_callbacks :: proc() {
	temp_mem := make([dynamic]byte, context.temp_allocator)

	steam_pipe := steam.SteamGameServer_GetHSteamPipe()
	steam.ManualDispatch_RunFrame(steam_pipe)
	callback: steam.CallbackMsg

	for steam.ManualDispatch_GetNextCallback(steam_pipe, &callback) {
		defer (steam.ManualDispatch_FreeLastCallback(steam_pipe))

		#partial switch callback.iCallback {
		case .SteamAPICallCompleted:
			fmt.println("CallResult: ", callback)

			call_completed := transmute(^steam.SteamAPICallCompleted)callback.pubParam
			resize(&temp_mem, int(callback.cubParam))
			temp_call_res, ok := mem.alloc(
				int(callback.cubParam),
				allocator = context.temp_allocator,
			)

			// failed: bool
			// steam.ManualDispatch_GetAPICallResult(
			// 	steam_pipe,
			// 	call_completed.hAsyncCall,
			// 	temp_call_res,
			// 	callback.cubParam,
			// 	callback.iCallback,
			// 	&failed,
			// )
			// if failed == true {
			// 	log.errorf(
			// 		"Failed to get steam api call result for callback: %s",
			// 		callback.iCallback,
			// 	)
			// 	return
			// }

			_handle_api_call_result(call_completed, temp_call_res)

		case .ValidateAuthTicketResponse:
			_callback_ValidateAuthTicketResponse(
				cast(^steam.ValidateAuthTicketResponse)callback.pubParam,
			)

		case .SteamNetConnectionStatusChangedCallback:
			_callback_NetConnectionStatusChanged(
				cast(^steam.SteamNetConnectionStatusChangedCallback)callback.pubParam,
			)

		case .SteamNetAuthenticationStatus:
			_callback_NetAuthenticationStatus(
				cast(^steam.SteamNetAuthenticationStatus)callback.pubParam,
			)

		case:
			fmt.println("Unhandled Callback:", callback.iCallback)
		}
	}
}

_callback_NetConnectionStatusChanged :: proc(
	data: ^steam.SteamNetConnectionStatusChangedCallback,
) {

	#partial switch data.info.eState {
	case .None:
		break

	case .Connecting:
		player_spot := _get_open_spot()
		if player_spot == -1 {
			log.warnf("Rejecting connection from %v, server full.", data.info.addrRemote)
			steam.NetworkingSockets_CloseConnection(
				server_state.net_sockets,
				data.hConn,
				0,
				"Server Full",
				false,
			)
			return
		}

		log.infof("Accepting connection from %v...", data.info.addrRemote)
		res := steam.NetworkingSockets_AcceptConnection(server_state.net_sockets, data.hConn)
		if res != .OK {
			log.errorf("Failed to accept connection %v: %v", data.hConn, res)
			return
		}

	case .Connected:
		log.infof("Connection %v established.", data.hConn)
		player_spot := _get_open_spot()
		if player_spot == -1 {
			log.errorf("Connection %v established, but no spots left? Closing.", data.hConn)
			steam.NetworkingSockets_CloseConnection(
				server_state.net_sockets,
				data.hConn,
				0,
				"Internal Error",
				true,
			)
			return
		}

		server_state.connections[player_spot] = Connection {
			idx        = player_spot,
			steam_conn = data.hConn,
			bConnected = true,
		}
		log.infof("Connection %v assigned to spot %v. Awaiting auth.", data.hConn, player_spot)


	case .ClosedByPeer, .ProblemDetectedLocally:
		log.infof(
			"Connection %v closed. Reason: %v, Description: %s",
			data.hConn,
			data.info.eState,
			data.info.szEndDebug,
		)
		_remove_client_by_handle(data.hConn)
		steam.NetworkingSockets_CloseConnection(
			server_state.net_sockets,
			data.hConn,
			0,
			nil,
			false,
		)

	}
}

_callback_ValidateAuthTicketResponse :: proc(data: ^steam.ValidateAuthTicketResponse) {
	fmt.printfln("ValidateAuthTicketResponse callback called with data: %v", data)

	conn_idx := _find_connection_by_steamID(data.SteamID)
	if conn_idx == -1 {
		log.warnf("Received auth response for unknown SteamID: %v", data.SteamID)
		return
	}

	conn := &server_state.connections[conn_idx]
	#partial switch data.eAuthSessionResponse {
	case .OK:
		log.infof(
			"SteamID %v successfully validated! Spot %v is now fully authed.",
			data.SteamID,
			conn.idx,
		)
		conn.bAuthed = true
	// Here you would send a "Welcome" message or similar to the client
	// e.g., send_message_to_client(conn.hConnection, "Welcome!")
	case .AuthTicketCanceled:
		_remove_client(data.SteamID)
	}
}

_callback_NetAuthenticationStatus :: proc(data: ^steam.SteamNetAuthenticationStatus) {
   	fmt.println("SteamNetAuthenticationStatus callback called with data:")
    fmt.printfln("    eAvail: %v", data.eAvail)
    fmt.printfln("    dbgMsg: %v", steam_dbgmsg_to_string(&data.debugMsg))
}

_find_connection_by_steamID :: proc(steamID: steam.CSteamID) -> int {
	for conn, i in server_state.connections {
		if conn.idx != -1 && conn.steamID == steamID {
			return i
		}
	}
	return -1
}

_find_connection_by_handle :: proc(hConn: steam.HSteamNetConnection) -> int {
	for conn, i in server_state.connections {
		if conn.steam_conn == hConn {
			return i
		}
	}
	return -1
}

_remove_client :: proc(steamID: steam.CSteamID) {
	conn_idx := _find_connection_by_steamID(steamID)
	if conn_idx != -1 {
		_remove_client_by_index(conn_idx)
	}
}

_remove_client_by_handle :: proc(hConn: steam.HSteamNetConnection) {
	conn_idx := _find_connection_by_handle(hConn)
	if conn_idx != -1 {
		_remove_client_by_index(conn_idx)
	}
}

_remove_client_by_index :: proc(idx: int) {
	conn := &server_state.connections[idx]
	if conn.idx == -1 do return

	log.infof(
		"Removing client at spot %v (SteamID: %v, Handle: %v)",
		idx,
		conn.steamID,
		conn.steam_conn,
	)

	if conn.bAuthed do steam.GameServer_EndAuthSession(server_state.game_server, conn.steamID)

	if conn.steam_conn != steam.HSteamNetConnection_Invalid {
		steam.NetworkingSockets_CloseConnection(
			server_state.net_sockets,
			conn.steam_conn,
			0,
			"Client Removed",
			false,
		)
	}

	server_state.connections[idx] = Connection {
		idx        = -1,
		steam_conn = steam.HSteamNetConnection_Invalid,
	}
}

_poll_network :: proc() {
	net_sockets := server_state.net_sockets
	if net_sockets == nil do return

	messages: [16]^steam.SteamNetworkingMessage

	for {
		num_msgs := steam.NetworkingSockets_ReceiveMessagesOnPollGroup(
			net_sockets,
			server_state.poll_group,
			&messages[0],
			len(messages),
		)

		if num_msgs == 0 do break
		if num_msgs < 0 {
			log.errorf("Error receiving messages: %v", num_msgs)
			break
		}

		for i: i32 = 0; i < num_msgs; i += 1 {
			msg := messages[i]
			_handle_network_message(msg)
			steam.NetworkingMessage_t_Release(msg)
		}
	}
}

_handle_network_message :: proc(msg: ^steam.SteamNetworkingMessage) {
	conn_idx := _find_connection_by_handle(msg.conn)
	if conn_idx == -1 {
		log.warnf("Received message from unknown connection handle: %v. Ignoring.", msg.conn)
		return
	}

	conn := &server_state.connections[conn_idx]

	msg_type := cast(^Network_MessageType)msg.pData
	switch msg_type^ {
	case .Unknown:
		fmt.println("Received unknown message from", conn^)

	case .Authentication:
		if msg.cbSize != size_of(Network_Authentication) {
			fmt.eprintln("[Server Error] msg.cbSize != size_of(Network_Authentication)")
		}
		_handle_Authentication(conn, cast(^Network_Authentication)msg.pData)

	case:
		fmt.printfln("Received a message of unknown type %v from conn %v", msg_type^, conn^)
		return
	}
}

_handle_Authentication :: proc(conn: ^Connection, msg: ^Network_Authentication) {
	if conn.bAuthed == true {
		fmt.println("Tried to authenticate a connection that is already authenticated", conn)
		return
	}
	auth_result := steam.GameServer_BeginAuthSession(
		server_state.game_server,
		&msg.ticket,
		AUTH_TICKET_SIZE,
		msg.steamID,
	)

	if _handle_auth_result(auth_result) != .None {
		log.warnf(
			"BeginAuthSession failed for SteamID %v. Error: %v. Removing.",
			conn.steamID,
			auth_result,
		)
		_remove_client_by_handle(conn.steam_conn)
		return
	}

	fmt.println("client %v just became authenticated", conn.steamID)
}

_handle_auth_result :: proc(res: steam.EBeginAuthSessionResult) -> ServerError {
	#partial switch res {
	case .DuplicateRequest:
		fmt.println("Tried to begin an auth session with a user who is already authenticated")
	case .OK:
		return .None
	case:
		fmt.println("Unhandled auth_result: %v", res)
	}

	return .None
}

_get_open_spot :: proc() -> int {
	for conn, i in server_state.connections {
		if conn.idx == -1 do return i
	}
	return -1
}

_handle_api_call_result :: proc(call: ^steam.SteamAPICallCompleted, res: rawptr) {
	fmt.printfln("handle_api_call_result: %v", call)
}

_init_config :: proc() {
	table, err := toml.parse_data(CONFIG, "config.toml")
	if err.type != .None do panic("Failed to parse server config toml")
	defer toml.deep_delete(table)

	// [Network]
	net_game_port_i64, ok_sp := toml.get_i64(table, "Network", "game_port")
	if !ok_sp do panic("config.toml: Missing or invalid [Network].game_port (integer)")
	server_state.config.game_port = u16(net_game_port_i64)

	net_query_port_i64, ok_qp := toml.get_i64(table, "Network", "query_port")
	if !ok_qp do panic("config.toml: Missing or invalid [Network].query_port (integer)")
	server_state.config.query_port = u16(net_query_port_i64)
	// [Network]

	// [Gameplay]
	game_server_name, ok_name := toml.get_string(table, "Gameplay", "server_name")
	if !ok_name do panic("config.toml: Missing or invalid [Gameplay].server_name (string)")
	server_state.config.server_name = strings.clone(game_server_name)

	tick_rate_i64, ok_tr := toml.get_i64(table, "Gameplay", "tick_rate")
	if !ok_tr do panic("config.toml: Missing or invalid [Gameplay].server_name (string)")
	server_state.config.tick_rate = u16(tick_rate_i64)

	game_max_players_i64, ok_mp := toml.get_i64(table, "Gameplay", "max_players")
	if !ok_mp do panic("config.toml: Missing or invalid [Gameplay].max_players (integer)")
	server_state.config.max_players = u16(game_max_players_i64)
	// [Gameplay]

	// [Steam]
	steam_server_mode_i64, ok_anon := toml.get_i64(table, "Steam", "server_mode")
	if !ok_anon do panic("config.toml: Missing or invalid [Steam].server_mode (integer)")
	server_state.config.server_mode = u16(steam_server_mode_i64)
	// [Steam]

	log.info("Server configuration loaded:")
	log.infof("  Network.game_port: %d", server_state.config.game_port)
	log.infof("  Network.query_port: %d", server_state.config.query_port)
	log.infof("  Gameplay.server_name: %s", server_state.config.server_name)
	log.infof("  Gameplay.max_players: %d", server_state.config.max_players)
	log.infof("  Steam.server_mode: %v", server_state.config.server_mode)
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

steam_dbgmsg_to_string :: proc(msg: ^[256]u8) -> string {
    // Find the length of the message (up to the null terminator)
    msg_len := 0
    for i := 0; i < len(msg); i += 1 {
        if msg[i] == 0 {
            msg_len = i
            break
        }
    }
    
    msg_str, err := strings.clone_from_bytes(msg[:msg_len], context.temp_allocator)
    if err != .None {
        log.error("strings.clone_from_bytes failed with error:", err)
    }
    
    return msg_str
}