package game

import steam "../../third_party/steamworks"

NetworkState :: struct {
    game_server: steam.IGameServer,
    networking_sockets: steam.INetworkingSockets
}