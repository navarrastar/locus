package main

import "core:log"
import "core:math/linalg"
import "core:slice"
import "core:time"
import "core:os"
import "core:path/filepath"
import "core:fmt"

import "pkg:core"
import m "pkg:core/math"
import "pkg:game"
import r "pkg/core/renderer"
import "pkg:core/window"



main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(
			opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
		)
	}

	ctx := context
	core.init(&ctx)
	defer core.cleanup()

	world := game.init()
	defer game.cleanup()

	for window.poll_events() {
		world = game.update()
		core.update(world)
	}
	
}