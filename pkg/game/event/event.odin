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

Event_Type :: enum {
    Input,
    WindowResize,
}

get_event_type :: proc(e: Event) -> Event_Type {
    switch v in e {
        case Input_Event: return .Input
        case WindowResize_Event: return .WindowResize
        case:
            log.error("Unknown event type")
            return nil
    }
}

Manager :: struct {
    specific_handlers: map[Event][dynamic]Handler,
    generic_handlers: map[Event_Type][dynamic]Handler,
}

init :: proc() {
    manager = Manager {
        specific_handlers = make(map[Event][dynamic]Handler),
        generic_handlers = make(map[Event_Type][dynamic]Handler),
    }
}

@(private)
add_specific_handler :: proc(e: Event, handler: Handler) -> bool {
    if e in manager.specific_handlers {
        append(&manager.specific_handlers[e], handler)
    } else {
        manager.specific_handlers[e] = make([dynamic]Handler)
        append(&manager.specific_handlers[e], handler)
    }
    return true
}

@(private)
add_generic_handler :: proc(event_type: Event_Type, handler: Handler) -> bool {
    if event_type in manager.generic_handlers {
        append(&manager.generic_handlers[event_type], handler)
    } else {
        manager.generic_handlers[event_type] = make([dynamic]Handler)
        append(&manager.generic_handlers[event_type], handler)
    }
    return true
}

add_handler :: proc{add_specific_handler, add_generic_handler}

trigger :: proc(e: Event) {
    // Call handlers for the specific event data
    if e in manager.specific_handlers {
        for handler in manager.specific_handlers[e] {
            handler.callback(e)
        }
    }
    
    // Call handlers for the event type
    event_type := get_event_type(e)
    if event_type in manager.generic_handlers {
        for handler in manager.generic_handlers[event_type] {
            handler.callback(e)
        }
    }
}


