package game

import "core:time"

import m "../math"



init :: proc() {
    world        = new(World)
    window_state = new(WindowState)
    render_state = new(RenderState)
    ui_state     = new(UIState)
    every_vertex = make([dynamic]f32)
    
    window_init(context)
    renderer_init()
    ui_init()
    
    game_default_level()
}

update :: proc() {
    window_poll_events()
    
    @static time_last_checked: time.Time
    time_now := time.now()
    if shader_should_check_for_changes {
        if time.duration_seconds(time.diff(time_last_checked, time_now)) >= 1.0 {
            shader_check_for_changes(time_last_checked)
            time_last_checked = time_now
        }
    }
    
    if .None in ui_state.visible_panels {
        player_update()
    }
    
    renderer_begin_cmd_buffer()
    
    renderer_draw_world()
    
    ui_draw_data := ui_update()
    renderer_draw_ui(ui_draw_data)
    
    renderer_end_cmd_buffer()
}

cleanup :: proc() {
    free(world)
}

should_shutdown :: proc() -> bool {
    return window_state.should_close
}

game_default_level :: proc() {
    player := Entity_Player {
        name = "player",
        variant = typeid_of(Entity_Player),
        transform = { pos = {-3, 2, -1}, rot = {0, 0, 0}, scale = 1 },
        geometry = capsule(material=.Default)
    }
    world_spawn(player)
    
    capsule := Entity_StaticMesh {
        name = "capsule",
        transform = { pos ={3, 5, -1}, rot={0, 0, 0}, scale=1 },
        geometry = capsule()
    }
    world_spawn(capsule)
    
    random_rectangle := Entity_StaticMesh {
        name = "random_rect",
        transform = { pos={3, 2, -1}, rot={0, 0, 0}, scale=1 },
        geometry = rectangle(material=.Default)
    }
    world_spawn(random_rectangle)
    
    // grid := Entity_StaticMesh {
    //     name = "grid",
    //     transform = m.DEFAULT_TRANSFORM,
    //     geometry = grid(color = {0.4, 0.84, 0.9, 1})
    // }
    // world_spawn(grid)
    
    random_triangle_2 := Entity_StaticMesh {
        name = "random_triangle_2",
        transform = m.DEFAULT_TRANSFORM,
        geometry = triangle(color={0, 0, 1, 1})
    }
    world_spawn(random_triangle_2)
    
    default_box := Entity_StaticMesh {
        name = "box",
        transform = { pos={0, 3, -1}, rot={0, 0, 0}, scale=1 },
        geometry = cube(color={0.43, 0.87, 0.87, 1})
    }
    world_spawn(default_box)

    random_triangle := Entity_StaticMesh {
        name = "random_triangle",
        transform = { pos={3, 4, -10}, rot={0, 0, 0}, scale=1 },
        geometry = triangle({0, -1, -1}, {1, 0, -1}, {0.5, 1, -1}, {0, 0, 1, 1})
    }
    world_spawn(random_triangle)

    camera := Entity_Camera {
        name = "camera",
        target = {0, 0, -5},
        transform = { pos = {0, 1, 2}, rot = {0, 0, 0}, scale = 1 },
        up = { 0.0, 1.0, 0.0 },
        fovy = 90,
        projection = .Perspective
    }
    world_spawn(camera, 0)

}