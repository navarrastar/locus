#+private
package game

import sdl "vendor:sdl3"

when ODIN_OS == .Windows {
	SHADER_FORMAT: sdl.GPUShaderFormatFlag : .SPIRV
	SHADER_DEFAULT_FRAG := #load("../../assets/shaders/spirv/default.frag.spv")
	SHADER_DEFAULT_VERT := #load("../../assets/shaders/spirv/default.vert.spv")
	SHADER_GRID_FRAG    := #load("../../assets/shaders/spirv/plane.frag.spv")
	SHADER_GRID_VERT    := #load("../../assets/shaders/spirv/plane.vert.spv")
	
} else when ODIN_OS == .Darwin {
	SHADER_FORMAT: sdl.GPUShaderFormatFlag : .MSL
	SHADER_DEFAULT_FRAG := #load("../../assets/shaders/msl/default.frag.msl")
	SHADER_DEFAULT_VERT := #load("../../assets/shaders/msl/default.vert.msl")
	SHADER_GRID_FRAG    := #load("../../assets/shaders/msl/grid.frag.msl")
	SHADER_GRID_VERT    := #load("../../assets/shaders/msl/grid.vert.msl")
}


shader_load :: proc(code: []u8, stage: sdl.GPUShaderStage, num_uniform_buffers: u32) -> ^sdl.GPUShader {
    using render_state
    return sdl.CreateGPUShader(gpu, {
        code_size = len(code),
        code = raw_data(code),
        entrypoint = SHADER_FORMAT == .SPIRV ? "main" : "main0",
        format = { SHADER_FORMAT },
        stage = stage,
        num_uniform_buffers = num_uniform_buffers,
    })
}