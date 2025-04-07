package main

import "core:log"
import "core:math/linalg"
import "core:slice"
import "core:time"
import "core:os"
import "core:path/filepath"
import "pkg:core"
import "pkg:core/filesystem/loader"
import "pkg:core/filesystem/loaded"
import m "pkg:core/math"
import "pkg:game"
import "pkg:renderer"
import "pkg:core/window"
import "core:fmt"



main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(
			opt = log.Options{.Level, .Terminal_Color, .Short_File_Path, .Line, .Time},
		)
	}

	ctx := context
	core.init(&ctx)
	defer core.cleanup()

	renderer.init()
	defer renderer.cleanup()

	filepath.walk("./assets/models", load_model, nil)

	game.init()
	defer game.cleanup()

	for !window.should_close() {
		window.poll_events()
		
		if ok := renderer.begin_frame(); ok {
			
			game.loop()

			renderer.end_frame()
		}
	}
	
}

load_model :: proc(info: os.File_Info, in_err: os.Error, user_data: rawptr) -> (err: os.Error, skip_dir: bool) {
	fmt.assertf(in_err == nil, "Error loading model file:", info.name)
	
	if info.is_dir do return err, skip_dir

	model := loader.load_gltf(info.fullpath)
	loaded.add_model(model)

	return err, skip_dir
}