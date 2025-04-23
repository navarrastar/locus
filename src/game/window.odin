package game

import "core:log"
import "base:runtime"

import sdl "vendor:sdl3"
import im_sdl "shared:imgui/imgui_impl_sdl3"

WINDOW_START_WIDTH  :: 1280
WINDOW_START_HEIGHT :: 720

global_context: runtime.Context

WindowState :: struct {
    should_close: bool
}

window_init :: proc(ctx: runtime.Context) {
    global_context = ctx
    sdl.SetLogPriorities(.VERBOSE)
    sdl.SetLogOutputFunction(proc "c" (userdata: rawptr, category: sdl.LogCategory, priority: sdl.LogPriority, message: cstring) {
        context = global_context
        #partial switch priority {
            case .INFO:
                log.infof("SDL {}: {}", category, message)
            case .ERROR:
                log.errorf("SDL {}: {}", category,message)
        }
    }, nil)

    ok := sdl.Init({ .VIDEO })
    assert(ok, "Failed to initialize sdl3")

    window = sdl.CreateWindow("desmond", WINDOW_START_WIDTH, WINDOW_START_HEIGHT, {})
    assert(window != nil, string(sdl.GetError()))
    
    sdl.GetWindowSize(window, &window_width, &window_height)
}

window_cleanup :: proc() {
    //rl.CloseWindow()
}

window_poll_events :: proc() {
    @(static) old_tick: u64
    new_tick := sdl.GetTicks()
    dt = f32(new_tick - old_tick) / 1000
    old_tick = new_tick 

    event: sdl.Event
    for sdl.PollEvent(&event) {
        im_sdl.ProcessEvent(&event)
        #partial switch event.type {
            case .QUIT:
                window_state.should_close = true
            case .KEY_DOWN:
                if event.key.scancode == .ESCAPE    do window_state.should_close = true
                if event.key.scancode == .GRAVE     do ui_toggle_visibility({ .None })
                if event.key.scancode == .D         do ui_toggle_visibility({ .Demo })
                if event.key.scancode == .G         do ui_toggle_visibility({ .General })
                if event.key.scancode == .L         do materials[.Grid].pipeline = nil
                if event.key.scancode == .BACKSLASH do shader_toggle_should_check_for_changes()
        }

    }

    sdl.GetWindowSize(window, &window_width, &window_height)
    
}

window_aspect_ratio :: proc() -> f32 {
    return f32(window_width) / f32(window_height)
}

window_set_should_close :: proc() {
    window_state.should_close = !window_state.should_close
}

