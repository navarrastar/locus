package game

import "core:log"
import "core:os"

import "pkg:core/window"
import m "pkg:core/math"
import "pkg:core/event"
import "pkg:core/input"
import geo "pkg:core/geometry"



init :: proc() -> ^World {
    world = new(World)
    default_level()

    return world
}

cleanup :: proc() {
    free(world)
}

update :: proc() -> ^World {
    return world
}

default_level :: proc() {
    player := Entity_Player {
        name = "player",
        transform = { pos = {0, 0, -2}, rot = {0, 0, 0}, scale = 1 },
        geometry = geo.triangle({0, 0.5, 0}, {0.5, 0, 0}, {-0.5, 0, 0}, {0.3, 0.9, 0.3, 1})
    }
    spawn(player)

    camera := Entity_Camera {
        name = "camera",
        transform = m.DEFAULT_TRANSFORM,
        up = { 0.0, 1.0, 0.0 },
        fovy = 90,
        projection = .Perspective
    }
    spawn(camera, 0)

    any_resize_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            resize_data := e.(event.Event_WindowResize)
            return true
        },
    }

    event.add_handler(event.Type.WindowResize, any_resize_handler) 

}
