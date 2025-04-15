package renderer


import sdl "vendor:sdl3"

import geo "pkg:core/geometry"
import "pkg:core/window"




pipelines: [PipelineType]^sdl.GPUGraphicsPipeline

PipelineType :: enum {
    None,
    Mesh,
    Triangle,
}

create_pipelines :: proc() {
    create_mesh_pipeline()
    create_triangle_pipeline()
}

create_mesh_pipeline :: proc() {}

create_triangle_pipeline :: proc() {
    vert_shader := load_shader(shader_code_vert, .VERTEX, 1)
    frag_shader := load_shader(shader_code_frag, .FRAGMENT, 0)
    assert(vert_shader != nil && frag_shader != nil, "Failed to load triangle shaders")

    attributes := geo.triangle_attributes()
    pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
        vertex_shader = vert_shader,
        fragment_shader = frag_shader,
        primitive_type = .TRIANGLELIST,
        vertex_input_state = {
            num_vertex_buffers = 1,
            vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription {
                slot = 0,
                pitch = size_of(geo.TriangleVertex)
            }),
            num_vertex_attributes = u32(len(attributes)),
            vertex_attributes = &attributes[0]
        },
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription {
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window.window) 
            })
        }
    }
    pipelines[.Triangle] = sdl.CreateGPUGraphicsPipeline(gpu, pipeline_desc)
    assert(pipelines[.Triangle] != nil, "Failed to create triangle pipeline")

    sdl.ReleaseGPUShader(gpu, vert_shader)
    sdl.ReleaseGPUShader(gpu, frag_shader)
}