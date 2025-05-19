#+feature dynamic-literals
package game

import "base:runtime"

import "core:time"
import sdl "vendor:sdl3"

import gltf "../../third_party/gltf2"

import m "../math"

ctx: runtime.Context

SHADER_DIR :: "./assets/shaders/"
MODEL_DIR :: "./assets/models/"

WORLD_BOUNDS :: 100

start_time: time.Time

shader_should_check_for_changes: bool

window: ^sdl.Window
window_should_close: bool
window_width, window_height: i32
mouse_pos: m.Vec2
swapchain_texture_format: sdl.GPUTextureFormat
dt: f32

world: struct {
	entities:     [1024]Entity,
	entity_count: eID,
}

materials: [MaterialType]Material
shader_name_to_material_type := map[string]MaterialType {
	"default" = .Default,
	"grid"    = .Grid,
	"test"    = .Test,
	"mesh"    = .Mesh,
}

phys_visualize: bool

loaded_models: map[string]^gltf.Data

bConnecting_to_server: bool