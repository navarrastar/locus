package event

import "core:log"
import "pkg:core/input"

manager: Manager

Manager :: struct {
    specific_handlers: map[Event][dynamic]Handler,
    generic_handlers: map[Type][dynamic]Handler,
}

Event :: union {
    Event_Input,
    Event_WindowResize,
}

Event_Input :: struct {
    key: int,
    action: InputAction,
}

Event_WindowResize :: struct {
    width: u32,
    height: u32,
}

Handler :: struct {
    callback: proc(event: Event) -> bool,
}

Type :: enum {
    Input,
    WindowResize,
}

InputAction :: enum {
    Press,
    Down,
    Release
}

init :: proc() -> bool {
    manager = Manager {
        specific_handlers = make(map[Event][dynamic]Handler),
        generic_handlers = make(map[Type][dynamic]Handler),
    }
    return true
}

cleanup :: proc() {
    delete(manager.specific_handlers)
    delete(manager.generic_handlers)
}

get_event_type :: proc(e: Event) -> Type {
    switch v in e {
        case Event_Input: return .Input
        case Event_WindowResize: return .WindowResize
        case:
            log.error("Unknown event type")
            return nil
    }
}


add_handler :: proc{add_specific_handler, add_generic_handler}

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
add_generic_handler :: proc(event_type: Type, handler: Handler) -> bool {
    if event_type in manager.generic_handlers {
        append(&manager.generic_handlers[event_type], handler)
    } else {
        manager.generic_handlers[event_type] = make([dynamic]Handler)
        append(&manager.generic_handlers[event_type], handler)
    }
    return true
}

trigger :: proc(e: Event) {
    log.debug(e)

    if e in manager.specific_handlers {
        for handler in manager.specific_handlers[e] {
            handler.callback(e)
        }
    }
    
    event_type := get_event_type(e)
    if event_type in manager.generic_handlers {
        for handler in manager.generic_handlers[event_type] {
            handler.callback(e)
        }
    }
}


