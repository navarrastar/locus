package main

import "core:log"

import "game"



main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(
			opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
		)
	}
	
	game.init()
	defer game.cleanup()
	
	for !game.should_shutdown() {
	    free_all(context.temp_allocator)
	    game.update()
	}

}
