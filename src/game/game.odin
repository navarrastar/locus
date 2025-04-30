package game

// import "core:log"
import "core:time"

import m "../math"
import t "../types"


init :: proc() {
	start_time = time.now()

	world = new(World)
	window_state = new(WindowState)
	render_state = new(RenderState)
	ui_state = new(UIState)
	every_vertex = make([dynamic]f32)

	window_init(context)
	renderer_init()
	ui_init()
	
	root_entity: EntityBase
	world_spawn(&root_entity)

	game_default_level()
}

update :: proc() {
	window_poll_events()

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

	if .None in ui_state.visible_panels {
        update_player()
        player := world_get_player()
        renderer_draw_entity(pass, &player.base)

		for &entity in world.entities {
			world_update_entity(&entity)

			base := cast(^EntityBase)&entity
			renderer_draw_entity(pass, base)
		}
	}

	renderer_end_pass(pass)

	ui_draw_data := ui_update()
	renderer_draw_ui(ui_draw_data)

	renderer_end_cmd_buffer()

	input_tick()
}

cleanup :: proc() {
	free(&every_vertex)
	free(ui_state)
	free(render_state)
	free(window_state)
	free(world)
}

should_shutdown :: proc() -> bool {
	return window_state.should_close
}

game_default_level :: proc() {
	grid := Entity_Mesh {
		transform = m.DEFAULT_TRANSFORM,
		geom      = grid(color = {0.4, 0.84, 0.9, 1}),
	}
	world_spawn(&grid)

	opponent_1 := Entity_Opp {
		name = "opp_0",
		transform = {pos = {0, 0, -10}, rot = {0, 0, 0}, scale = 1},
		geom = capsule(material = .Test),
		phys = {layer = .Layer1, mask = .Mask0},
		health = t.DEFAULT_HEALTH
	}
	world_spawn(&opponent_1)
	
	player := Entity_Player {
		transform = {pos = {-3, 0, -1}, rot = {0, 0, 0}, scale = 1},
		geom = capsule(material = .Test),
		speed = 10,
		phys = {layer= .Layer1, mask = .Mask1},
		face_dir = {1, 0, 0},
	}
	world_spawn(&player)


	// capsule := Entity_Mesh {
	//     transform = { pos ={3, 0, -1}, rot={0, 0, 0}, scale=1 },
	//     geometry = capsule(color=COLOR_ORANGE, material=.Test)
	// }
	// world_spawn(capsule)

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

	// random_triangle := Entity_Mesh {
	//     transform = { pos={3, 0, -10}, rot={0, 0, 0}, scale=1 },
	//     geometry = triangle({0, -1, -1}, {1, 0, -1}, {0.5, 1, -1}, {0, 0, 1, 1})
	// }
	// world_spawn(random_triangle)

	camera := Entity_Camera {
		target = {0, 0, -4},
		transform = {pos = {0, 12, 2}, rot = {0, 0, 0}, scale = 1},
		up = {0.0, 1.0, 0.0},
		fovy = m.to_radians(80),
		projection = .Perspective,
	}
	world_spawn(&camera)

}
