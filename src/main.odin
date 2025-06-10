package main

import "core:log"
import "core:fmt"

import toml "../third_party/toml_parser"

import "game"
import "server"
import "game_coordinator"

// Define none of these for game client
// Never define both of them
SERVER :: #config(SERVER, false)
GAME_COORDINATOR :: #config(GAME_COORDINATOR, false)

LAUNCH_OPTIONS :: #load("../launch_options.toml")
launch_options: struct {
    // [Steam]
    steam_logon_anon: bool

}

@(init)
_init_launch_options :: proc() {
    table, err := toml.parse_data(LAUNCH_OPTIONS, "launch_options.toml")
    if err.type != .None do panic("Failed to parse launch options toml")
    defer toml.deep_delete(table)
    
    // [Steam]
    steam_logon_anon, ok_anon := toml.get_bool(table, "Steam", "logon_anon")
    if !ok_anon do panic("config.toml: Missing or invalid [Steam].logon_anon (boolean)")
    launch_options.steam_logon_anon = steam_logon_anon
    // [Steam]
    
    fmt.println("Launch options loaded:")
    fmt.printfln("  Steam.logon_anon: %t", launch_options.steam_logon_anon)
}

main :: proc() {
	context.logger = log.create_console_logger(
		opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
	)
	
   	game.ctx = context
    when SERVER {
       	server.init()
       	defer server.cleanup()
    } else when GAME_COORDINATOR {
        game_coordinator.init()
        defer game_coordinator.cleanup()
    } else {
        game.init()
        defer game.cleanup()
    }
    
	for !game.should_shutdown() {
	    free_all(context.temp_allocator)

		when SERVER {
	        server.update()
		} else when GAME_COORDINATOR {
		    game_coordinator.update()
		} else {
		    game.update()
		}
	}

}
