package game

import "core:log"
import sdl "vendor:sdl3"



pipeline_init :: proc() {
    pipeline_mesh_create()
    pipeline_triangle_create()
    pipeline_grid_create()
}

pipeline_mesh_create :: proc() {}

pipeline_triangle_create :: proc() {
    vert_shader := shader_load(SHADER_DEFAULT_VERT, .VERTEX, 1)
    frag_shader := shader_load(SHADER_DEFAULT_FRAG, .FRAGMENT, 0)
    assert(vert_shader != nil && frag_shader != nil, "Failed to load triangle shaders")

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
    materials[.Default].pipeline = sdl.CreateGPUGraphicsPipeline(render_state.gpu, pipeline_desc)
    assert(materials[.Default].pipeline != nil, "Failed to create Default pipeline")

    sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
    sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
}

pipeline_grid_create :: proc() {
    vert_shader := shader_load(SHADER_GRID_VERT, .VERTEX, 1)
    frag_shader := shader_load(SHADER_GRID_FRAG, .FRAGMENT, 0)
    assert(vert_shader != nil && frag_shader != nil, "Failed to load grid shaders")
    
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
    assert(materials[.Grid].pipeline != nil, "Failed to create Default pipeline")

    sdl.ReleaseGPUShader(render_state.gpu, vert_shader)
    sdl.ReleaseGPUShader(render_state.gpu, frag_shader)
    
}