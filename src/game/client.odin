package game

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:net"
import "core:thread"
import "core:time"

import steam "../../third_party/steamworks"

import "../server"

MAX_SERVER_INFOS :: 128

client_state: struct {
	user:        ^steam.IUser,
	ticket:      steam.HAuthTicket,
	conn:        steam.HSteamNetConnection,
	conn_info:   ^steam.SteamNetConnectionInfo,
	net_sockets: ^steam.INetworkingSockets,
	mm_servers:  ^steam.IMatchmakingServers,
	mm_response: ^steam.IMatchmakingServerListResponse,
}

client_serverlist_state: struct {
	server_infos:      [MAX_SERVER_INFOS]^steam.gameserveritet,
	server_info_count: u8,
	request:           steam.HServerListRequest,
	response:          ^ServerListResponse,
}

ServerListResponse :: struct {
    vtable: ^ServerListResponseVTable
}

ServerListResponseVTable :: struct {
		ServerResponded:       proc "c" (
			self: ^ServerListResponse,
			request: steam.HServerListRequest,
			server_index: i32,
		),
		ServerFailedToRespond: proc "c" (
			self: ^ServerListResponse,
			request: steam.HServerListRequest,
			server_index: i32,
		),
		RefreshComplete:       proc "c" (
			self: ^ServerListResponse,
			request: steam.HServerListRequest,
			response: steam.EMatchMakingServerResponse,
		),
}

client_init :: proc() {
	client_state.net_sockets = steam.NetworkingSockets_SteamAPI()
	client_state.mm_servers = steam.MatchmakingServers()

	client_update_serverlist()
}

client_cleanup :: proc() {
	if client_state.ticket != 0 {
		steam.User_CancelAuthTicket(steam_user.user, client_state.ticket)
	}
	if client_state.conn != 0 {
		steam.NetworkingSockets_CloseConnection(
			client_state.net_sockets,
			client_state.conn,
			0,
			"client_cleanup",
			false,
		)
	}
}

client_leave :: proc() {
	steam.User_CancelAuthTicket(steam_user.user, client_state.ticket)
	steam.NetworkingSockets_CloseConnection(
		client_state.net_sockets,
		client_state.conn,
		0,
		"client_leave",
		false,
	)
}


_client_update_serverlist_vtable: ServerListResponseVTable = {
    ServerResponded = _client_update_serverlist_ServerResponded_callback,
    ServerFailedToRespond = _client_update_serverlist_ServerFailedToRespond_callback,
    RefreshComplete = _client_update_serverlist_RefreshComplete_callback
}
client_update_serverlist :: proc() {
	response := new(ServerListResponse)
	response.vtable = &_client_update_serverlist_vtable

	client_serverlist_state.response = response

	client_serverlist_state.request = steam.MatchmakingServers_RequestInternetServerList(
		client_state.mm_servers,
		3070970,
		nil,
		0,
		cast(^steam.IMatchmakingServerListResponse)response,
	)
}

user_connect_to_server_async :: proc(user: ^steam.IUser, serverID: steam.CSteamID) {
	args := new(server.ConnectionArgs)
	args^ = server.ConnectionArgs {
		user     = user,
		serverID = serverID,
		err      = .None,
		callback = user_connection_finished,
	}

	thread.create_and_start_with_data(args, _user_proc_connect_to_server)
}

_user_proc_connect_to_server :: proc(args_ptr: rawptr) {
	args := cast(^server.ConnectionArgs)args_ptr
	defer free(args)
	defer (args->callback())

	client_state.user = args.user // is this needed?

	net_identity: steam.SteamNetworkingIdentity
	steam.NetworkingIdentity_SetSteamID(&net_identity, args.serverID)
	fmt.printfln("Client: Attempting SDR connect to Server: %v", args.serverID)

	client_state.conn = steam.NetworkingSockets_ConnectToHostedDedicatedServer(
		client_state.net_sockets,
		&net_identity,
		0,
		0,
		nil,
	)

	timeout_start := time.tick_now()
	timeout_end :: 15 * time.Second
	for client_state.conn_info.eState != .Connected {
		fmt.println("Client: client_state.conn_info.eState: ", client_state.conn_info.eState)

		conn_ok := steam.NetworkingSockets_GetConnectionInfo(
			client_state.net_sockets,
			client_state.conn,
			client_state.conn_info,
		)
		if !conn_ok {
			args.err = .Unknown
			break
		}

		if time.tick_since(timeout_start) > timeout_end {
			fmt.println("Client: Connection timed out.")
			if client_state.conn != steam.HSteamNetConnection_Invalid {
				steam.NetworkingSockets_CloseConnection(
					client_state.net_sockets,
					client_state.conn,
					0,
					"Timeout",
					false,
				)
				client_state.conn = steam.HSteamNetConnection_Invalid
			}
			args.err = .Timeout
			break
		}
		time.sleep(100 * time.Millisecond)
	}

	clientID := steam.User_GetSteamID(args.user)
	fmt.printfln("Client: %v has successfully connected to Server %v", clientID, args.serverID)

	ticket: [server.AUTH_TICKET_SIZE]byte
	ticket_length: u32
	client_state.ticket = steam.User_GetAuthSessionTicket(
		args.user,
		&ticket,
		server.AUTH_TICKET_SIZE,
		&ticket_length,
		{},
	)

	if ticket == 0 || ticket_length == 0 {
		fmt.println("Client: Failed to get auth session ticket.")
		steam.NetworkingSockets_CloseConnection(
			client_state.net_sockets,
			client_state.conn,
			0,
			"Auth Fail",
			false,
		)
		args.err = .Unknown
		return
	}

	network_data: server.Network_Authentication
	network_data.type = .Authentication
	mem.copy(&network_data.ticket, &ticket, int(ticket_length))
	network_data.steamID = clientID

	send_res := steam.NetworkingSockets_SendMessageToConnection(
		client_state.net_sockets,
		client_state.conn,
		&network_data,
		size_of(server.Network_Authentication),
		steam.nSteamNetworkingSend_Reliable,
		nil,
	)
	if send_res != .OK {
		fmt.printfln("Client: Failed to send auth ticket: %v", send_res)
		steam.User_CancelAuthTicket(args.user, client_state.ticket)
		steam.NetworkingSockets_CloseConnection(
			client_state.net_sockets,
			client_state.conn,
			0,
			"Send Fail",
			false,
		)
		args.err = .Send
		return
	}


	fmt.println("Client: Auth ticket sent successfully.")
	args.err = .None
	return
}

user_connection_finished :: proc(args: ^server.ConnectionArgs) {
	switch args.err {
	case .None:
		fmt.println("User successfully sent join request to server")
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
	case .DuplicateRequest:
		fmt.println("DuplicateRequest error")
	case .Unknown:
		fmt.println("Unknown error while connecting user")
	}
}

// from isteammatchmaking.h in the steamworks sdk:
// //-----------------------------------------------------------------------------
// Purpose: Callback interface for receiving responses after a server list refresh
// or an individual server update.
//
// Since you get these callbacks after requesting full list refreshes you will
// usually implement this interface inside an object like CServerBrowser.  If that
// object is getting destructed you should use ISteamMatchMakingServers()->CancelQuery()
// to cancel any in-progress queries so you don't get a callback into the destructed
// object and crash.
//-----------------------------------------------------------------------------
// class ISteamMatchmakingServerListResponse
// {
// public:
// 	// Server has responded ok with updated data
// 	virtual void ServerResponded( HServerListRequest hRequest, int iServer ) = 0;

// 	// Server has failed to respond
// 	virtual void ServerFailedToRespond( HServerListRequest hRequest, int iServer ) = 0;

// 	// A list refresh you had initiated is now 100% completed
// 	virtual void RefreshComplete( HServerListRequest hRequest, EMatchMakingServerResponse response ) = 0;
// };

// Here are different callbacks for the dynamic dispatch
_client_update_serverlist_ServerResponded_callback :: proc "c" (
	self: ^ServerListResponse,
	request: steam.HServerListRequest,
	server_index: i32,
) {
	context = runtime.default_context()
	defer free(self)
	
	fmt.println("Server responded:", server_index)

}

_client_update_serverlist_ServerFailedToRespond_callback :: proc "c" (
	self: ^ServerListResponse,
	request: steam.HServerListRequest,
	server_index: i32,
) {
	context = runtime.default_context()
	defer free(self)
	
	fmt.println("Server failed to respond:", server_index)
}

_client_update_serverlist_RefreshComplete_callback :: proc "c" (
	self: ^ServerListResponse,
	request: steam.HServerListRequest,
	response: steam.EMatchMakingServerResponse,
) {
    context = runtime.default_context()
    defer free(self)
    
    switch response {
    case .NoServersListedOnMasterServer:
        fmt.println("You made a serverlist request which returned no matching servers")
        return
        
    case .ServerFailedToRespond:
        fmt.println("You tried to refresh the serverlist, but the master server failed to respond")
        return
    
    case .ServerResponded: 
        // continue as usual, do nothing
    }
    
	client_serverlist_state.request = request

	count := steam.MatchmakingServers_GetServerCount(client_state.mm_servers, request)
	assert(count < MAX_SERVER_INFOS, "too many server infos")
	client_serverlist_state.server_info_count = u8(count)
	for i in 0 ..< count {
		client_serverlist_state.server_infos[i] = steam.MatchmakingServers_GetServerDetails(
			client_state.mm_servers,
			request,
			i,
		)
	}
}
