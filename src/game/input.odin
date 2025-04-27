package game

// import "core:log"
import "base:intrinsics"

import sdl "vendor:sdl3"



@(private="file")
keys: #sparse [sdl.Scancode]bool

@(private="file")
prev_keys: #sparse [sdl.Scancode]bool

input_handle_down_event :: proc(e: sdl.Scancode) {
    keys[e] = true
}

input_handle_up_event :: proc(e: sdl.Scancode) {
    keys[e] = false
}

input_tick :: proc() {
    prev_keys = keys
}

input_key_down :: proc(key: sdl.Scancode) -> bool {
    return keys[key]
}

input_key_newly_down :: proc(key: sdl.Scancode) -> bool {
    return keys[key] && !prev_keys[key]
}

input_key_released :: proc(key: sdl.Scancode) -> bool {
    return prev_keys[key] && !keys[key]
}

