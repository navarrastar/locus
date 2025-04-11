package game

import "core:log"
import "core:os"

import "pkg:core/window"
import "pkg:core/ecs"
import m "pkg:core/math"
import r "pkg:core/renderer"
import "pkg:core/event"
import "pkg:core/input"
import "pkg:core/filesystem/loaded"
import "pkg:core/filesystem/loader"


init :: proc() {
       
    default_level()
}

cleanup :: proc() {
    event.cleanup()
}

loop :: proc() {
    update_player()
}

default_level :: proc() {
    spawn_camera()
    spawn_player()

    any_resize_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            resize_data := e.(event.WindowResize_Event)
            return true
        },
    }

    event.add_handler(event.Type.WindowResize, any_resize_handler) 

}
