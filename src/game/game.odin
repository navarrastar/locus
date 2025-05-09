package game

// import "core:log"
import "core:time"

import m "../math"
import t "../types"

SERVER :: #config(SERVER, false)

init :: proc() {
    when SERVER {
        steam_init()
        server_init(SERVER_PORT)
    } else {
    
	start_time = time.now()

	world = new(World)
	render_state = new(RenderState)
	ui_state = new(UIState)

	window_init()
	renderer_init()
	ui_init()

	root_entity: EntityBase
	world_spawn(&root_entity)

	game_default_level()
	
	steam_init()
	server_connect(SERVER_IP, SERVER_PORT)
	
    }
}

update :: proc() {
	window_poll_events()
	run_steam_callbacks()

	@(static) time_last_checked: time.Time
	time_now := time.now()
	if shader_should_check_for_changes {
		if time.duration_seconds(time.diff(time_last_checked, time_now)) >= 1.0 {
			shader_check_for_changes(time_last_checked)
			time_last_checked = time_now
		}
	}

	renderer_begin_cmd_buffer()
	pass := renderer_begin_pass()

	for &entity in world.entities {
		if .None in ui_state.visible_panels {
			world_update_entity(&entity)
		}
		base := cast(^EntityBase)&entity
		renderer_draw_entity(pass, base)
	}


	renderer_end_pass(pass)

	ui_draw_data := ui_update()
	renderer_draw_ui(ui_draw_data)

	renderer_end_cmd_buffer()

	input_tick()
}

cleanup :: proc() {
	free(ui_state)
	free(render_state)
	free(world)
	
	steam_cleanup()
}

should_shutdown :: proc() -> bool {
	return window_should_close
}

game_default_level :: proc() {
	player := Entity_Player {
		transform = {pos = {-3, 0, -1}, rot = {0, 0, 0}, scale = 2},
		geom = mesh("michelle"),
		speed = 10,
		phys = {layer = {.Layer0}, mask = {.Mask0}},
		face_dir = {1, 0, 0},
	}
	world_spawn(&player)

	michelle := Entity_Opp {
		name = "michelle",
		transform = {pos = {0, 0, -10}, rot = {0, 0, 0}, scale = 2},
		geom = mesh("michelle"),
		health = t.DEFAULT_HEALTH,
		phys = {layer = {.Layer0}, mask = {.Mask0}},
	}
	world_spawn(&michelle)


	grid := Entity_Mesh {
		transform = m.DEFAULT_TRANSFORM,
		geom      = grid(color = {0.4, 0.84, 0.9, 1}),
	}
	world_spawn(&grid)


	// capsule := Entity_Mesh {
	//     transform = { pos ={3, 0, -1}, rot={0, 0, 0}, scale=1 },
	//     geom = capsule(color=COLOR_ORANGE, material=.Test)
	// }
	// world_spawn(&capsule)

	// random_rectangle := Entity_Mesh {
	//     transform = { pos={3, 0, -1}, rot={0, 0, 0}, scale=1 },
	//     geometry = rectangle(material=.Default)
	// }
	// world_spawn(random_rectangle)

	// random_triangle_2 := Entity_Mesh {
	//     transform = m.DEFAULT_TRANSFORM,
	//     geometry = triangle(color={0, 0, 1, 1})
	// }
	// world_spawn(random_triangle_2)

	// default_box := Entity_Mesh {
	//     transform = { pos={0, 0, -1}, rot={0, 0, 0}, scale=1 },
	//     geometry = cube(color={0.43, 0.87, 0.87, 1})
	// }
	// world_spawn(default_box)

	random_triangle := Entity_Mesh {
		transform = {pos = {0, 0, -5}, rot = {0, 0, 0}, scale = 1},
		geom = triangle(material = .Test),
	}
	world_spawn(&random_triangle)

	camera := Entity_Camera {
		name = "cam",
		target = {0, 0, -4},
		transform = {pos = {0, 12, 2}, rot = {0, 0, 0}, scale = 1},
		up = {0.0, 1.0, 0.0},
		fovy = m.to_radians(80),
		projection = .Perspective,
	}
	world_spawn(&camera)

}
