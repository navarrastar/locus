package renderer

import "core:log"
import "base:runtime"
import "core:path/filepath"

import "vendor:wgpu"

import "pkg:core/window"


@(private)
state: State

@(private)
State :: struct {
    ctx: runtime.Context,

    // General
    instance: wgpu.Instance,
    surface:  wgpu.Surface,
    adapter:  wgpu.Adapter,
    device:   wgpu.Device,
    config:   wgpu.SurfaceConfiguration,
    queue:    wgpu.Queue,

    // Frame Dependent
    surface_texture: wgpu.Texture,
    surface_texture_view: wgpu.TextureView,
    command_encoder: wgpu.CommandEncoder,
    render_pass_encoder: wgpu.RenderPassEncoder,
    module:   wgpu.ShaderModule,
    pipeline: wgpu.RenderPipeline,
    pipeline_layout: wgpu.PipelineLayout,

    // Buffers
    model_buffer: wgpu.Buffer,
    bind_group_0: wgpu.BindGroup,
}

init :: proc() -> bool {
    init_wgpu()

    load_shaders()
    load_materials()

    create_bind_group_0()

    return true
}

loop :: proc() {
    begin_frame()

    draw_world()
    // draw_ui()

    end_frame()
}

cleanup :: proc() {

}

@(private)
begin_frame :: proc() -> bool {
    if !set_surface_texture() do return false

    state.surface_texture_view = wgpu.TextureCreateView(state.surface_texture)

    state.command_encoder = wgpu.DeviceCreateCommandEncoder(state.device)

    render_pass_desc := wgpu.RenderPassDescriptor {
        colorAttachmentCount = 1,
        colorAttachments = &wgpu.RenderPassColorAttachment {
            view = state.surface_texture_view,
            loadOp = .Clear,
            storeOp = .Store,
            depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
            clearValue = { 0, 1, 0, 1 }
        }
    }

    state.render_pass_encoder = wgpu.CommandEncoderBeginRenderPass(state.command_encoder, &render_pass_desc)

    return true
}

@(private)
end_frame :: proc() {
    wgpu.RenderPassEncoderEnd(state.render_pass_encoder)
    wgpu.RenderPassEncoderRelease(state.render_pass_encoder)
    command_buffer := wgpu.CommandEncoderFinish(state.command_encoder)
    wgpu.QueueSubmit(state.queue, { command_buffer })
    wgpu.SurfacePresent(state.surface)
    wgpu.CommandBufferRelease(command_buffer)
    wgpu.CommandEncoderRelease(state.command_encoder)
    wgpu.TextureViewRelease(state.surface_texture_view)
    wgpu.TextureRelease(state.surface_texture)
}