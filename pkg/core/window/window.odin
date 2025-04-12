package window

import "core:log"
import "base:runtime"
import "pkg:core/event"
import "pkg:core/input"

import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600



init :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "desmond")
}

cleanup :: proc() {
    rl.CloseWindow()
}

poll_events :: proc() {
    handle_resize()
    handle_inputs()
}

has_resized :: proc() -> bool {
    return rl.IsWindowResized() 
}

@(private)
handle_resize :: proc() {
    if !has_resized() do return

    resize_event: event.Event_WindowResize = {
        width = u32(rl.GetRenderWidth()),
        height = u32(rl.GetRenderHeight())
    }
}
 
handle_inputs :: proc() {  
    for key := rl.GetKeyPressed(); int(key) != 0; key = rl.GetKeyPressed() {
        input_event: event.Event_Input = {
            key = int(key),
            action = .Down
        }
         
        event.trigger(input_event)
    }
 
}

should_close :: proc() -> bool {
    return rl.WindowShouldClose()
}

get_window_size :: proc() -> (width, height: u32) {
    return u32(rl.GetRenderWidth()), u32(rl.GetRenderHeight())
}