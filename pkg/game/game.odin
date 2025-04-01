package game

import "core:log"

import "pkg:core/window"
import "pkg:game/ecs"
import m "pkg:core/math"
import c "pkg:game/ecs/component"
import "pkg:game/event"
import "pkg:game/input"
import "pkg:core/filesystem/gltf"
import "core:os"



init :: proc() {
    ecs.init()
    
    e0 := ecs.spawn_entity()

    camera: c.Camera = c.Perspective {
        near = 0.1,
        far = 100.0,
        fov = 103.0,
    };
    ecs.add_component(e0, camera)


    light: c.Light = c.Point {
        color = m.Vec3{0, 0, 0},
        intensity = 1.0,
        range = 10.0,
    };
    ecs.add_component(e0, light)

    e1 := ecs.spawn_entity(name="test")

    w_press_event := event.Input_Event {
        key = input.KEY_W,
        action = input.ACTION_PRESS,
    }

    w_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            log.debug(e)
            return true
        },
    }

    event.add_handler(w_press_event, w_handler)

    s_release_event := event.Input_Event {
        key = input.KEY_W,
        action = input.ACTION_RELEASE,
    }

    s_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            log.debug("key s released")
            return true
        },
    }

    event.add_handler(s_release_event, s_handler)

    resize_event := event.WindowResize_Event{}

    resize_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            resize_data := e.(event.WindowResize_Event)
            log.debug("Window resized to:", resize_data.width, "x", resize_data.height)
            return true
        },
    }

    event.add_handler(resize_event, resize_handler)
    
    model, _ := gltf.load("./assets/models/DamagedHelmet.glb")
    log.debug(model.nodes)
}

cleanup :: proc() {
    ecs.cleanup()
}

loop :: proc() {
    ecs.loop()
    for !window.should_close() {
        window.poll_events()
    }
}
