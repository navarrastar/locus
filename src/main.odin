package main

import "core:log"

import "game"



main :: proc() {
	context.logger = log.create_console_logger(
		opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
	)
	
   	game.ctx = context
   	game.init()
   	defer game.cleanup()

	for !game.should_shutdown() {
	    free_all(context.temp_allocator)
	    game.update()
	}

}
