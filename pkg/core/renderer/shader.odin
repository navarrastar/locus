#+private
package renderer



import sdl "vendor:sdl3"





load_shader :: proc(code: []u8, stage: sdl.GPUShaderStage, num_uniform_buffers: u32) -> ^sdl.GPUShader {
    return sdl.CreateGPUShader(gpu, {
        code_size = len(code),
        code = raw_data(code),
        entrypoint = SHADER_FORMAT == .SPIRV ? "main" : "main0",
        format = { SHADER_FORMAT },
        stage = stage,
        num_uniform_buffers = num_uniform_buffers,
    })
}