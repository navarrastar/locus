package window

import "core:log"
import "base:runtime"
import "pkg:core/event"
import "pkg:core/input"
import "vendor:wgpu"
import "vendor:wgpu/glfwglue"

import "vendor:glfw"

@(private)
window: glfw.WindowHandle

@(private)
global_context: ^runtime.Context

@(private)
window_width: u32
@(private)
window_height: u32

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
    window_width = u32(width)
    window_height = u32(height)
    
    resize_event: event.Event = event.WindowResize_Event {
        width = window_width,
        height = window_height,
    }

    event.trigger(resize_event)
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

init :: proc(ctx: ^runtime.Context) -> bool {
    global_context = ctx

    if !bool(glfw.Init()) {
        log.warn("Failed to initialize GLFW")
        return false
    }

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

    window_width = 800
    window_height = 600
    window = glfw.CreateWindow(i32(window_width), i32(window_height), "Locke", nil, nil)
    if window == nil {
        log.warn("Failed to create GLFW window")
        return false
    }

    glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)
    glfw.SetKeyCallback(window, key_callback)

    return true
}

cleanup :: proc() {
    if window != nil {
        glfw.DestroyWindow(window)
    }
    glfw.Terminate()
}

poll_events :: proc() {
    glfw.PollEvents()
}

should_close :: proc() -> bool {
    return bool(glfw.WindowShouldClose(window))
}

vulkan_supported :: proc() -> bool {
    return bool(glfw.VulkanSupported())
}

get_required_extensions :: proc() -> []cstring {
    return glfw.GetRequiredInstanceExtensions()
}

get_window_size :: proc() -> (width, height: u32) {
    return window_width, window_height
}

get_window_handle :: proc() -> glfw.WindowHandle {
    return window
}

get_surface :: proc(instance: wgpu.Instance) -> wgpu.Surface {
    return glfwglue.GetSurface(instance, window)
}