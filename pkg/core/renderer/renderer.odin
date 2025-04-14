package renderer

import "core:log"
import "base:runtime"
import "core:path/filepath"

import sdl "vendor:sdl3"

import "pkg:core/window"
import m "pkg:core/math"
import geo "pkg:core/geometry"

when ODIN_OS == .Windows {
    SHADER_FORMAT: sdl.GPUShaderFormatFlag : .SPIRV
    shader_code_frag := #load("../../../assets/shaders/spirv/default.frag.spv")
    shader_code_vert := #load("../../../assets/shaders/spirv/default.vert.spv")
} else when ODIN_OS == .Darwin {
    SHADER_FORMAT: sdl.GPUShaderFormatFlag : .MSL
    shader_code_frag := #load("../../../assets/shaders/msl/default.frag.metal")
    shader_code_vert := #load("../../../assets/shaders/msl/default.vert.metal")
}



gpu: ^sdl.GPUDevice
pipeline: ^sdl.GPUGraphicsPipeline
swapchain_texture: ^sdl.GPUTexture

RenderData :: struct {
    view_proj:  m.Mat4,
    model_mat:  m.Mat4,

    meshes:     []geo.Mesh,
    triangles:  []geo.Triangle,
    pyramids:   []geo.Pyramid,
    rectangles: []geo.Rectangle,
    cubes:      []geo.Cube,
    circles:    []geo.Circle,
    spheres:    []geo.Sphere,
    capsules:   []geo.Capsule,
    cylinders:  []geo.Cylinder
}

init :: proc() {
    gpu = sdl.CreateGPUDevice({ SHADER_FORMAT }, true, nil)
    assert(gpu != nil, "Failed to create GPU device")

    assert(sdl.ClaimWindowForGPUDevice(gpu, window.window), "GPU failed to claim window")

    vert_shader := load_shader(shader_code_vert, .VERTEX, 1)
    frag_shader := load_shader(shader_code_frag, .FRAGMENT, 0)
    assert(vert_shader != nil && frag_shader != nil, "Failed to load shaders")

    pipeline_desc := sdl.GPUGraphicsPipelineCreateInfo {
        vertex_shader = vert_shader,
        fragment_shader = frag_shader,
        primitive_type = .TRIANGLELIST,
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription {
                format = sdl.GetGPUSwapchainTextureFormat(gpu, window.window) 
            })
        }
    }
    pipeline = sdl.CreateGPUGraphicsPipeline(gpu, pipeline_desc)
    assert(pipeline != nil, "Failed to create pipeline")

    sdl.ReleaseGPUShader(gpu, vert_shader)
    sdl.ReleaseGPUShader(gpu, frag_shader)
    
}

update :: proc(using rd: ^RenderData) {
    cmd_buffer := sdl.AcquireGPUCommandBuffer(gpu)

    assert(sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window.window, &swapchain_texture, nil, nil))

    if swapchain_texture == nil do return

    color_target := sdl.GPUColorTargetInfo {
        texture = swapchain_texture,
        load_op = .CLEAR,
        clear_color = { 0.2, 0.2, 0.4, 1.0 },
        store_op = .STORE
    }
    render_pass := sdl.BeginGPURenderPass(cmd_buffer, &color_target, 1, nil)

    sdl.BindGPUGraphicsPipeline(render_pass, pipeline)

    sdl.PushGPUVertexUniformData(cmd_buffer, 0, &view_proj, size_of(view_proj))

    sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
    // rl.ClearBackground({ 74, 45, 83, 100 })
    // rl.BeginDrawing()

    // rl.BeginMode3D(w.camera)
    // rl.DrawGrid(10, 1)

    draw_render_data(rd)

    // rl.EndMode3D()
    // rl.EndDrawing()
    sdl.EndGPURenderPass(render_pass)
    assert(sdl.SubmitGPUCommandBuffer(cmd_buffer))
}

cleanup :: proc() {

}