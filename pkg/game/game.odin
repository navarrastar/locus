package game

import "core:log"

import "pkg:core/window"
import "pkg:game/ecs"
import m "pkg:core/math"
import c "pkg:game/ecs/component"
import r "pkg:renderer"
import "pkg:game/event"
import "pkg:game/input"
import "pkg:core/filesystem/loaded"
import "pkg:core/filesystem/loader"
import "core:os"


init :: proc() {
    if !r.init() {
        panic("Failed to initialize renderer")
    }

    event.init()
   
    default_level()
}

cleanup :: proc() {
    event.cleanup()
}

loop :: proc() {
    ecs.for_each(.Mesh, proc(e: ecs.Entity) {
        mesh_comp := ecs.get_component(.Mesh, e).(^c.Mesh)
        mesh := loaded.get_mesh(mesh_comp.name)
        r.render(mesh)
    })
}

default_level :: proc() {
    if damaged_helmet := loaded.get_model("DamagedHelmet"); damaged_helmet != nil {
        ecs.spawn_from_model(damaged_helmet)
    }

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
