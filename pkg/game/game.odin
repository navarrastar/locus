package game

import "core:log"
import "core:os"

import "pkg:core/window"
import "pkg:core/ecs"
import m "pkg:core/math"
import c "pkg:core/ecs/component"
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
    // Update World
}

default_level :: proc() {
    e0 := ecs.spawn()

    camera: c.Camera = c.Perspective {
        near = 0.1,
        far = 100.0,
        fov = 103.0,
    };
    ecs.add_component(camera, e0)

    light: c.Light = c.Point {
        color = m.Vec3{0, 0, 0},
        intensity = 1.0,
        range = 10.0,
    };
    ecs.add_component(light, e0)

    e1 := ecs.spawn(name="test")

    
    w_press_event := event.Input_Event {
        key = input.KEY_W,
        action = input.ACTION_PRESS,
    }

    w_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            return true
        },
    }

    event.add_handler(w_press_event, w_handler)

    any_resize_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            resize_data := e.(event.WindowResize_Event)
            return true
        },
    }

    event.add_handler(event.Type.WindowResize, any_resize_handler) 

}
