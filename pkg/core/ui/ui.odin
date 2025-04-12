package ui

import "base:runtime"
import "core:fmt"
import "core:log"

import "third_party:clay"



init :: proc() {
    min_memory_size: u32 = clay.MinMemorySize()
    memory := make([^]u8, min_memory_size)
    arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(uint(min_memory_size), memory)
    clay.Initialize(arena, { width = 1080, height = 720 }, { handler = error_handler })
    clay.SetMeasureTextFunction(measure_text, nil)
}

loop :: proc() -> clay.ClayArray(clay.RenderCommand) {
    return create_layout()
}

cleanup :: proc() {
}

measure_text :: proc "c" (
    text: clay.StringSlice,
    config: ^clay.TextElementConfig,
    userData: rawptr,
) -> clay.Dimensions {
    return {
        width = f32(text.length * i32(config.fontSize)),
        height = f32(config.fontSize),
    }
}


error_handler :: proc "c" (error: clay.ErrorData) {
    context = runtime.default_context()
    fmt.panicf("Clay Error Type: %v\nMessage:\n%v", error.errorType, error.errorText)
}

min_memory_size: u32 = clay.MinMemorySize()


