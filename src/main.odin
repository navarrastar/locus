package main

import "core:log"

import "game"

SERVER :: #config(SERVER, false)

main :: proc() {
	context.logger = log.create_console_logger(
		opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
	)
	
   	game.ctx = context
    when !SERVER {
       	game.init()
       	defer game.cleanup()
    } else {
        game.server_init(game.SERVER_PORT)
        defer game.server_cleanup()
    }
    
	for !game.should_shutdown() {
	    free_all(context.temp_allocator)

		when !SERVER {
	        game.update()
		} else {
		    game.server_update()
		}
	}

}
