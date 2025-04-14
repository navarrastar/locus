package game

import "core:log"
import "core:os"

import "pkg:core/window"
import m "pkg:core/math"
import "pkg:core/event"
import "pkg:core/input"



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
        transform = m.DEFAULT_TRANSFORM
    }
    spawn(player)

    camera := Entity_Camera {
        name = "camera",
        transform = m.DEFAULT_TRANSFORM,
        up = { 0.0, 1.0, 0.0 },
        fovy = 103,
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
