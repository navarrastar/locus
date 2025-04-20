package game

import "base:runtime"
import "core:log"
import "core:os"

import m "pkg:math"


init :: proc() {
    world = new(World)
    window_state = new(WindowState)
    render_state = new(RenderState)
    ui_state = new(UIState)
    every_vertex = make([dynamic]f32, 0, 1000)
    
    window_init(context)
    renderer_init()
    ui_init()
    game_default_level()
}

update :: proc() {
    window_poll_events()
    
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
        transform = { pos = {-3, 2, -1}, rot = {0, 0, 0}, scale = 1 },
        geometry = triangle()
    }
    world_spawn(player)
    random_rectangle := Entity_StaticMesh {
            name = "random_rect",
            transform = { pos = {3, 2, -1}, rot = {0, 0, 0}, scale = 1 },
            geometry = rectangle()
        }
    world_spawn(random_rectangle)
    
    grid := Entity_StaticMesh {
        name = "grid",
        transform = m.DEFAULT_TRANSFORM,
        geometry = grid()
    }
    world_spawn(grid)
    
    random_triangle_2 := Entity_StaticMesh {
        name = "random_triangle_2",
        transform = m.DEFAULT_TRANSFORM,
        geometry = triangle(color={0, 0, 1, 1})
    }
    world_spawn(random_triangle_2)

    random_triangle := Entity_StaticMesh {
        name = "random_triangle",
        transform = { pos = {3, 4, -10}, rot = {0, 0, 0}, scale = 1 },
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