package game

import "core:thread"
import "core:mem"
import "core:fmt"
import "core:net"

import steam "../../third_party/steamworks"

import "../server"



client_ticket: steam.HAuthTicket

user_connect_to_server_async :: proc(user: ^steam.IUser, ip_str: string, port: int) {
	args := new(server.ConnectionArgs)
	args^ = server.ConnectionArgs {
		user     = user,
		err      = .None,
		callback = user_connection_finished,
		ip_str   = ip_str,
		port     = port
	}

	thread.create_and_start_with_data(args, _user_proc_connect_to_server)
}

_user_proc_connect_to_server :: proc(args_ptr: rawptr) {
	args := cast(^server.ConnectionArgs)args_ptr
	defer free(args)
	defer (args->callback())

	networking_identity: steam.SteamNetworkingIdentity
	networking_identity.eType = .IPAddress
	ip_bytes, _ := server._ip6_string_to_bytes(args.ip_str)
	mem.copy(&networking_identity.szUnknownRawString, &ip_bytes, size_of(ip_bytes))
	ticket: [server.AUTH_TICKET_SIZE]byte
	ticket_length: u32
	client_ticket = steam.User_GetAuthSessionTicket(
		args.user,
		&ticket[0],
		1024,
		&ticket_length,
		networking_identity,
	)

	server_endpoint_str := fmt.tprintf("[%s]:%d", args.ip_str, args.port)

	fmt.printfln("Attempting to connect to server at %s", server_endpoint_str)
	endpoint, ok := net.parse_endpoint(server_endpoint_str)
	if ok != true {
		steam.User_CancelAuthTicket(args.user, client_ticket)

		fmt.printfln("Networking: Error parsing server endpoint '%s': %v", server_endpoint_str)
		args.err = .EndpointParse
		return
	}

	network_data: server.Network_AttemptConnection
	network_data.ticket = ticket
	steamID := steam.User_GetSteamID(args.user)
	mem.copy(&network_data.steamID, &steamID, server.STEAM_ID_SIZE)
	network_data_bytes := mem.byte_slice(&network_data, size_of(server.Network_AttemptConnection))

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