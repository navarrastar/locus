package game

import "core:log"

import "pkg:core/ecs"
import "pkg:core/event"
import "pkg:core/input"
import m "pkg:core/math"



spawn_camera :: proc() {
    entity_camera := ecs.spawn(name="Perspective Camera")

    camera: ecs.Camera = ecs.Perspective {
        near = 0.01,
        far = 10000.0,
        fov = 103.0,
    };
    ecs.add_components(entity_camera, camera)

    setup_camera_controls()
}

setup_camera_controls :: proc() {
    w_press_event := event.Input_Event {
        key = input.KEY_W,
        action = input.ACTION_PRESS,
    }

    w_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            entity_camera := ecs.get_first_camera()
            camera_transform, camera_comp := ecs.get_components(ecs.Transform{}, ecs.Camera{}, entity_camera)
            camera_transform.pos += m.Vec3{0, 0, 0.1}
            log.debug("camera_transform.pos: %v", camera_transform.pos)
            return true
        },
    }

    event.add_handler(w_press_event, w_handler)

    s_press_event := event.Input_Event {
        key = input.KEY_S,
        action = input.ACTION_PRESS,
    }

    s_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            entity_camera := ecs.get_first_camera()
            camera_transform, camera_comp := ecs.get_components(ecs.Transform{}, ecs.Camera{}, entity_camera)
            camera_transform.pos -= m.Vec3{0, 0, 0.1}
            log.debug("camera_transform.pos: %v", camera_transform.pos)
            return true
        },
    }

    event.add_handler(s_press_event, s_handler)

    a_press_event := event.Input_Event {
        key = input.KEY_A,
        action = input.ACTION_PRESS,
    }

    a_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            entity_camera := ecs.get_first_camera()
            camera_transform, camera_comp := ecs.get_components(ecs.Transform{}, ecs.Camera{}, entity_camera)
            camera_transform.pos -= m.Vec3{0.1, 0, 0}
            log.debug("camera_transform.pos: %v", camera_transform.pos)
            return true
        },
    }

    event.add_handler(a_press_event, a_handler)

    d_press_event := event.Input_Event {
        key = input.KEY_D,
        action = input.ACTION_PRESS,
    }

    d_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            entity_camera := ecs.get_first_camera()
            camera_transform, camera_comp := ecs.get_components(ecs.Transform{}, ecs.Camera{}, entity_camera)
            camera_transform.pos += m.Vec3{0.1, 0, 0}
            log.debug("camera_transform.pos: %v", camera_transform.pos)
            return true
        },
    }

    event.add_handler(d_press_event, d_handler)

    q_press_event := event.Input_Event {
        key = input.KEY_Q,
        action = input.ACTION_PRESS,
    }

    q_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            entity_camera := ecs.get_first_camera()
            camera_transform, camera_comp := ecs.get_components(ecs.Transform{}, ecs.Camera{}, entity_camera)
            camera_transform.pos += m.Vec3{0, 0.1, 0}
            log.debug("camera_transform.pos: %v", camera_transform.pos)
            return true
        },
    }

    event.add_handler(q_press_event, q_handler)

    e_press_event := event.Input_Event {
        key = input.KEY_E,
        action = input.ACTION_PRESS,
    }

    e_handler := event.Handler {
        callback = proc(e: event.Event) -> bool {
            entity_camera := ecs.get_first_camera()
            camera_transform, camera_comp := ecs.get_components(ecs.Transform{}, ecs.Camera{}, entity_camera)
            camera_transform.pos -= m.Vec3{0, 0.1, 0}
            log.debug("camera_transform.pos: %v", camera_transform.pos)
            return true
        },
    }

    event.add_handler(e_press_event, e_handler)
}