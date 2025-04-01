package event

import "core:log"
import "pkg:game/input"

manager: Manager

Event :: union {
    Input_Event,
    WindowResize_Event,
}

Input_Event :: struct {
    key: int,
    action: int,
}

WindowResize_Event :: struct {
    width: int,
    height: int,
}

Handler :: struct {
    callback: proc(event: Event) -> bool,
}

Manager :: struct {
    handlers: map[Event][dynamic]Handler,
}

init :: proc() {
    manager = Manager {
        handlers = make(map[Event][dynamic]Handler),
    }
}

add_handler :: proc(e: Event, handler: Handler) -> bool {
    if e in manager.handlers {
        append(&manager.handlers[e], handler)
    } else {
        manager.handlers[e] = make([dynamic]Handler)
        append(&manager.handlers[e], handler)
    }
    return true
}

trigger :: proc(e: Event) {
    if e in manager.handlers {
        for handler in manager.handlers[e] {
            handler.callback(e)
        }
    }
}


