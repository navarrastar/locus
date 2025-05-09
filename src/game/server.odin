package game

import "core:log"

import "core:strings"
import "core:strconv"
import "core:fmt"
import "core:mem"

import steam "../../third_party/steamworks"

SERVER_IP   :: "2600:3c00::f03c:95ff:fe44:bdfc"
SERVER_PORT :: 27015

server_state: struct {
	net_sockets: ^steam.INetworkingSockets,
	port: u16,
}

server_init :: proc(port: u16) {
    networking_ip := &steam.SteamNetworkingIPAddr {
        port = port
    }
    
	steam.NetworkingSockets_CreateListenSocketIP(
		server_state.net_sockets,
		networking_ip,
		{}, // nOptions
		{}, // pOptions
	)
	
}

server_connect :: proc(ip6_str: string, port: u16) {
    ip6_bytes, ok := _ip6_string_to_bytes(ip6_str)
    log.assertf(ok, "Error parsing ip6 address: %v", ip6_str)
    
    networking_ip := &steam.SteamNetworkingIPAddr {
        ipv6 = ip6_bytes,
        port = port,
    }
    
    steam.NetworkingSockets_ConnectByIPAddress(
        server_state.net_sockets,
        networking_ip,
        {},
        {},
    )
}

server_update :: proc() {
    
}

@(require_results)
_ip6_string_to_bytes :: proc(s: string) -> (bytes: [16]u8, ok: bool) {
    s := s
    if len(s) > 0 && s[0] == '[' && s[len(s)-1] == ']' {
        s = s[1:len(s)-1]
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
            for j in 0..<zero_groups {
                bytes[byte_idx] = 0
                bytes[byte_idx+1] = 0
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
        bytes[byte_idx+1] = u8(val & 0xFF)
        byte_idx += 2
    }
    
    return bytes, true
}