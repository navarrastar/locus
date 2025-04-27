#+feature dynamic-literals
package game

import "core:time"

import sdl "vendor:sdl3"

SHADER_DIR :: "./assets/shaders/"

WORLD_BOUNDS :: 100

start_time: time.Time

shader_should_check_for_changes: bool

window: ^sdl.Window
swapchain_texture_format: sdl.GPUTextureFormat
window_width, window_height: i32
dt: f32

world: ^World
window_state: ^WindowState
render_state: ^RenderState
ui_state:     ^UIState
phys_world:   ^PhysicsWorld

materials: [MaterialType]Material
shader_name_to_material_type := map[string]MaterialType {
    "default" = .Default,
    "grid"    = .Grid,
    "capsule" = .Capsule
}

every_vertex: [dynamic]f32


