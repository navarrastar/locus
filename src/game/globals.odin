#+feature dynamic-literals
package game

import "core:time"

import sdl "vendor:sdl3"

SHADER_DIR :: "./assets/shaders/"
MODEL_DIR :: "./assets/models/"

WORLD_BOUNDS :: 100

start_time: time.Time

shader_should_check_for_changes: bool

window: ^sdl.Window
window_should_close: bool
window_width, window_height: i32
mouse_pos: [2]f32
swapchain_texture_format: sdl.GPUTextureFormat
dt: f32

world: ^World
render_state: ^RenderState
ui_state: ^UIState

materials: [MaterialType]Material
shader_name_to_material_type := map[string]MaterialType {
	"default" = .Default,
	"grid"    = .Grid,
	"capsule" = .Capsule,
	"test"    = .Test,
	"mesh"    = .Mesh,
}

phys_visualize: bool
