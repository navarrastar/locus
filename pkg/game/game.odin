package game

import "core:log"
import "core:os"

import "pkg:core/window"
import w "pkg:core/world"
import m "pkg:core/math"
import r "pkg:core/renderer"
import "pkg:core/event"
import "pkg:core/input"



init :: proc() {
    default_level()
}

cleanup :: proc() {

}

loop :: proc() {
}

default_level :: proc() {
    spawn_player()

    any_resize_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            resize_data := e.(event.Event_WindowResize)
            return true
        },
    }

    event.add_handler(event.Type.WindowResize, any_resize_handler) 

}
