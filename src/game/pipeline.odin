package game

import "core:log"

import sdl "vendor:sdl3"



pipeline_create :: proc(type: MaterialType) {
    switch type {
    case .Default:
        pipeline_default_create()
    case .Grid:
        pipeline_grid_create()
    case .Capsule:
        pipeline_capsule_create()
    }
}

pipeline_default_create :: proc() {
    vert_shader := shader_load(SHADER_DIR + "hlsl/default.vert.hlsl")
    frag_shader := shader_load(SHADER_DIR + "hlsl/default.frag.hlsl")
    if vert_shader == nil || frag_shader == nil {
        log.error("Failed to load default shaders")
        return
    }
    attributes := ATTRIBUTES_POS_COLOR
    pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
        vertex_shader = vert_shader,
        fragment_shader = frag_shader,
        primitive_type = .TRIANGLELIST,
        vertex_input_state = {
            num_vertex_buffers = 1,
            vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
                slot = 0,
                pitch = size_of(Vertex_PosColorNormal)
            }),
            num_vertex_attributes = u32(len(attributes)),
            vertex_attributes = &attributes[0]
        },
        depth_stencil_state = {
            compare_op = .LESS,
            enable_depth_test = true,
            enable_depth_write = true
        },
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription {
                format = swapchain_texture_format
            }),
            has_depth_stencil_target = true,
            depth_stencil_format = DEPTH_STENCIL_FORMAT
        }
    }
    materials[.Default].pipeline = sdl.CreateGPUGraphicsPipeline(render_state.gpu, pipeline_desc)
    assert(materials[.Default].pipeline != nil, string(sdl.GetError()))

    sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
    sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
}

pipeline_grid_create :: proc() {
    vert_shader := shader_load(SHADER_DIR + "hlsl/grid.vert.hlsl")
    frag_shader := shader_load(SHADER_DIR + "hlsl/grid.frag.hlsl")
    if vert_shader == nil || frag_shader == nil {
        log.error("Failed to load grid shaders")
        return
    }
    
    attributes := ATTRIBUTES_POS_COLOR
    pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
        vertex_shader = vert_shader,
        fragment_shader = frag_shader,
        primitive_type = .TRIANGLELIST,
        vertex_input_state = {
            num_vertex_buffers = 1,
            vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
                slot = 0,
                pitch = size_of(Vertex_PosColor)
            }),
            num_vertex_attributes = u32(len(attributes)),
            vertex_attributes = &attributes[0]
        },
        depth_stencil_state = {
            compare_op = .LESS,
            enable_depth_test = true,
            enable_depth_write = true
        },
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription {
                format = swapchain_texture_format
            }),
            has_depth_stencil_target = true,
            depth_stencil_format = DEPTH_STENCIL_FORMAT
        }
    }
    materials[.Grid].pipeline = sdl.CreateGPUGraphicsPipeline(render_state.gpu, pipeline_desc)
    assert(materials[.Grid].pipeline != nil, string(sdl.GetError()))

    sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
    sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
}

pipeline_capsule_create :: proc() {
    
}
