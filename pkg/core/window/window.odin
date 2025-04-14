package window

import "core:log"
import "base:runtime"
import "pkg:core/event"
import "pkg:core/input"

import sdl "vendor:sdl3"


window: ^sdl.Window
global_context: ^runtime.Context

width, height: i32

init :: proc(ctx: ^runtime.Context) {
    global_context = ctx
    sdl.SetLogPriorities(.VERBOSE)
    sdl.SetLogOutputFunction(proc "c" (userdata: rawptr, category: sdl.LogCategory, priority: sdl.LogPriority, message: cstring) {
        context = global_context^
        #partial switch priority {
            case .INFO:
                log.infof("SDL {}: {}", category, message)
            case .ERROR:
                log.errorf("SDL {}: {}", category,message)
        }
    }, nil)

    ok := sdl.Init({ .VIDEO })
    assert(ok, "Failed to initialize sdl3")

    window = sdl.CreateWindow("desmond", 800, 600, {})
    assert(window != nil, "Failed to create sdl3 window")
}

cleanup :: proc() {
    //rl.CloseWindow()
}

poll_events :: proc() -> (window_open: bool){
    event: sdl.Event
    for sdl.PollEvent(&event) {
        #partial switch event.type {
            case .QUIT:
                return false
            case .KEY_DOWN:
                if event.key.scancode == .ESCAPE do return false
        }

    }

    sdl.GetWindowSize(window, &width, &height)

    return true
}

size :: proc() -> (w: i32, h: i32) {
    return width, height
}