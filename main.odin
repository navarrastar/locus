package main

import "core:log"
import "core:math/linalg"
import "core:slice"
import "core:time"

import "pkg:core"
import m "pkg:core/math"
import "pkg:game"
import "pkg:renderer/vk"

main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(
			opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
		)
	}

	ctx := context
	core.init(&ctx)
	defer core.cleanup()

	game.init()
	defer game.cleanup()

	game.loop()
}
