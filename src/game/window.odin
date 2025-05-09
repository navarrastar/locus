package game

import "core:log"
import "base:runtime"

import sdl "vendor:sdl3"
import im_sdl "../../third_party/imgui/imgui_impl_sdl3"

import m "../math"

WINDOW_START_WIDTH  :: 1280
WINDOW_START_HEIGHT :: 720

window_init :: proc() {
    sdl.SetLogPriorities(.VERBOSE)
    sdl.SetLogOutputFunction(proc "c" (userdata: rawptr, category: sdl.LogCategory, priority: sdl.LogPriority, message: cstring) {
        context = ctx
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
                window_should_close = true
            case .KEY_DOWN:
                input_handle_down_event(event.key.scancode)
                if event.key.scancode == .ESCAPE    do window_should_close = true
                if event.key.scancode == .GRAVE     do ui_toggle_visibility({ .None })
                if event.key.scancode == .D         do ui_toggle_visibility({ .Demo })
                if event.key.scancode == .G         do ui_toggle_visibility({ .General })
                if event.key.scancode == .BACKSLASH do shader_toggle_should_check_for_changes()
            case .KEY_UP:
                input_handle_up_event(event.key.scancode)
        }

    }

    _ = sdl.GetMouseState(&mouse_pos.x, &mouse_pos.y)
    
    // update_mouse_pos_ground(&mouse_pos_ground.x, &mouse_pos_ground.y)
    
    sdl.GetWindowSize(window, &window_width, &window_height)
    
}

window_aspect_ratio :: proc() -> f32 {
    return f32(window_width) / f32(window_height)
}

window_set_should_close :: proc() {
    window_should_close = !window_should_close
}

window_get_mouse_poss :: proc() {
    
}

update_mouse_pos_ground :: proc(x, y: ^f32) {
    camera := world_camera()
    
    // Convert mouse position to normalized device coordinates (NDC)
    mouse_ndc_x := (2.0 * mouse_pos.x / f32(window_width)) - 1.0
    mouse_ndc_y := 1.0 - (2.0 * mouse_pos.y / f32(window_height))
    
    // Create ray in clip space
    ray_clip := m.Vec4{mouse_ndc_x, mouse_ndc_y, -1.0, 1.0}
    
    // Transform to eye space
    ray_eye := m.inverse(camera.proj) * ray_clip
    ray_eye.z = -1.0
    ray_eye.w = 0.0
    
    // Transform to world space
    ray_world := (m.inverse(camera.view) * ray_eye)
    ray_dir := m.normalize(m.Vec3{ray_world.x, ray_world.y, ray_world.z})
    
    // Intersect ray with ground plane (y = 0)
    t := -camera.pos.y / ray_dir.y
    
    // Calculate intersection point
    intersection := camera.pos + ray_dir * t
    
    x^ = intersection.x
    y^ = intersection.y
}

screen_to_NDC :: proc(screen_pos: m.Vec2) -> m.Vec2 {
    ndc_x := (2 * screen_pos.x / f32(window_width)) - 1
    ndc_y := 1 - (2 * screen_pos.y / f32(window_height))
    return {}
}