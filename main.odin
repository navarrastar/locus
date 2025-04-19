package main

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:time"

import m "pkg:math"
import "pkg:game"


main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(
			opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
		)
	}

	game.init()
	defer game.cleanup()

	for !game.should_shutdown() {
		game.update()
	}

}
