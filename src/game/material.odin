package game



import sdl "vendor:sdl3"



MaterialType :: enum {
    Default,
    Capsule,
    Grid,
}

Material :: struct {
    type:             MaterialType,
    pipeline:         ^sdl.GPUGraphicsPipeline,
    shader_info_vert: ShaderInfo,
    shader_info_frag: ShaderInfo
}

material_create :: proc(type: MaterialType) {
    pipeline_create(type)
}