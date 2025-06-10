package game_coordinator

import steam "../../third_party/steamworks"

game_coordinator_state: struct {
    client_infos: map[steam.CSteamID]ClientInfo,
    server_infos: map[steam.CSteamID]ServerInfo,
    secret_key: rawptr,
    secret_key_size: int
}

ClientInfo :: struct {
    auth_ticket: steam.SteamDatagramRelayAuthTicketPtr,
    steamID:     steam.CSteamID,
    serverID:    steam.CSteamID,
}

ServerInfo :: struct {
    serverID:    steam.CSteamID,
    sdr_address: steam.SteamDatagramHostedAddress,
}

init :: proc() {
    game_coordinator_state.client_infos = make(map[steam.CSteamID]ClientInfo)
    game_coordinator_state.server_infos = make(map[steam.CSteamID]ServerInfo)
}

update :: proc() {
    
}

cleanup :: proc() {
    
}

register_server :: proc(serverID: steam.CSteamID, sdr_address: steam.SteamDatagramHostedAddress) {
    game_coordinator_state.server_infos[serverID] = ServerInfo {
        serverID = serverID,
        sdr_address = sdr_address
    }
}

