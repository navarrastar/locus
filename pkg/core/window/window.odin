package window

import "core:log"
import "base:runtime"
import "pkg:game/event"
import "pkg:game/input"

import "vendor:glfw"

@(private)
window: glfw.WindowHandle

@(private)
global_context: ^runtime.Context

@(private)
window_width: i32
@(private)
window_height: i32

@(private)
error_callback :: proc "c" (code: i32, desc: cstring) {
    context = global_context^
    log.error("GLFW Error: %d: %s", code, desc)
    when ODIN_DEBUG {
        panic("")
    }
}

@(private)
framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    context = global_context^
    window_width = width
    window_height = height
    
    e: event.Event = event.WindowResize_Event {
        width = int(width),
        height = int(height),
    }

    event.trigger(e)
}

@(private)
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
    context = global_context^
    
    if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
        glfw.SetWindowShouldClose(window, glfw.TRUE)
    }

    input_event: event.Input_Event = {
        key = int(key),
        action = int(action),
    }

    event.trigger(input_event)
}

init :: proc(ctx: ^runtime.Context) -> rawptr {
    global_context = ctx

    glfw.SetErrorCallback(error_callback)

    if !glfw.Init() { panic("Failed to initialize GLFW") }

    window = glfw.CreateWindow(1280, 720, "Locke", nil, nil)
    if window == nil { panic("Failed to create window") }

    glfw.SetKeyCallback(window, key_callback)
    glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)
    
    // Get initial window size
    width, height := glfw.GetFramebufferSize(window)
    window_width = width
    window_height = height

    return window
}

cleanup :: proc() {
    glfw.DestroyWindow(window)
    glfw.Terminate()
}

poll_events :: proc() {
    glfw.PollEvents()
}

should_close :: proc() -> b32 {
    return glfw.WindowShouldClose(window)
}

get_required_extensions :: proc() -> []cstring {
    return glfw.GetRequiredInstanceExtensions()
}

get_window_size :: proc() -> (width, height: i32) {
    return window_width, window_height
}