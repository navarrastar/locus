package game


import sdl "vendor:sdl3"



window: ^sdl.Window
swapchain_texture_format: sdl.GPUTextureFormat
window_width, window_height: i32
dt: f32

world: ^World
window_state: ^WindowState
render_state: ^RenderState
ui_state: ^UIState

materials: [MaterialType]Material

every_vertex: [dynamic]f32


