package main

import "core:log"
import "core:math/linalg"
import "core:slice"
import "core:time"
import "core:os"
import "core:path/filepath"
import "core:fmt"

import "pkg:core"
import "pkg:core/filesystem/loader"
import "pkg:core/filesystem/loaded"
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

	filepath.walk("./assets/models", load_model, nil)

	ctx := context
	core.init(&ctx)
	defer core.cleanup()

	game.init()
	defer game.cleanup()

	for !window.should_close() {
		window.poll_events()
		
		game.loop()
		core.loop()
	}
	
}

load_model :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
	fmt.assertf(in_err == nil, "Error loading model file:", info.name)
	
	if info.is_dir do return

	model := loader.load_gltf(info.fullpath)
	loaded.add_model(model)

	return
}