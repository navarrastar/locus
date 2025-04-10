#+private
package renderer

import "core:fmt"

import "vendor:wgpu"

import "pkg:core/window"


init_wgpu :: proc() {
    state.instance = wgpu.CreateInstance(nil)
    assert(state.instance != nil, "Failed to initialize wgpu instance")

    state.surface = window.get_surface(state.instance)
    assert(state.surface != nil, "Failed to initialize wgpu surface")

    adapter_opt := wgpu.RequestAdapterOptions {
        compatibleSurface = state.surface,
    }
    request_adapter_callback_info := wgpu.RequestAdapterCallbackInfo {
        callback = on_adapter
    }
    wgpu.InstanceRequestAdapter(state.instance, &adapter_opt, request_adapter_callback_info)
}

@(require_results)
set_surface_texture :: proc() -> bool {
    surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)
    switch surface_texture.status {
        case .SuccessOptimal, .SuccessSuboptimal:
            // Good, continue frame
            state.surface_texture = surface_texture.texture
            return true
        case .Timeout, .Outdated, .Lost:
            // Bad, skip frame
            return false
        case .OutOfMemory, .DeviceLost, .Error:
            // Fatal, panic
            fmt.panicf("Failed to get current texture\n    Status: %s", surface_texture.status)
    }
    fmt.panicf("surface_texture has an unexpected status: %s", surface_texture.status)
}

on_adapter :: proc "c" (
    status: wgpu.RequestAdapterStatus,
    adapter: wgpu.Adapter,
    message: string,
    user_data1: rawptr,
    user_data2: rawptr
) {
    context = state.ctx

    fmt.assertf(status == .Success, "Failed to initialize wgpu adapter\n    Status: %s", status)
    assert(adapter != nil, "Failed to initialize wgpu adapter")

    state.adapter = adapter

    device_lost_callback_info := wgpu.DeviceLostCallbackInfo {
       callback = on_device_lost 
    }
    device_desc := wgpu.DeviceDescriptor {
       deviceLostCallbackInfo = device_lost_callback_info 
    }
    request_device_callback_info := wgpu.RequestDeviceCallbackInfo {
        callback = on_device
    }
    wgpu.AdapterRequestDevice(adapter, &device_desc, request_device_callback_info) 
}

on_device :: proc "c" (
    status: wgpu.RequestDeviceStatus,
    device: wgpu.Device,
    message: string,
    user_data1: rawptr,
    user_data2: rawptr,
) {
    context = state.ctx
    
    fmt.assertf(status == .Success, "Failed to initialize wgpu device\n    Status: %s", status)
    assert(device != nil, "Failed to initialize wgpu device")
    state.device = device

    width, height := window.get_window_size()

    state.config = wgpu.SurfaceConfiguration {
        device = device,
        usage = { .RenderAttachment },
        format = .BGRA8Unorm,
        width = width,
        height = height,
        presentMode = .Fifo,
        alphaMode = .Opaque,
    }
    assert(state.surface != nil, "Tried to configure a nil wgpu surface")
    wgpu.SurfaceConfigure(state.surface, &state.config)

    state.queue = wgpu.DeviceGetQueue(device)
    assert(state.queue != nil, "Failed to get wgpu queue")

    shader :: `
	@vertex
	fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {
		let x = f32(i32(in_vertex_index) - 1);
		let y = f32(i32(in_vertex_index & 1u) * 2 - 1);
		return vec4<f32>(x, y, 0.0, 1.0);
	}

	@fragment
	fn fs_main() -> @location(0) vec4<f32> {
		return vec4<f32>(1.0, 0.0, 0.0, 1.0);
	}
    `
    shader_module_desc := wgpu.ShaderModuleDescriptor {
        nextInChain = &wgpu.ShaderSourceWGSL {
            sType = .ShaderSourceWGSL,
            code = shader
        }
    }
    state.module = wgpu.DeviceCreateShaderModule(
        device,
        &shader_module_desc
    )

    state.pipeline_layout = wgpu.DeviceCreatePipelineLayout(device, &{})

    render_pipeline_desc := wgpu.RenderPipelineDescriptor {
        layout = state.pipeline_layout,
        vertex = {
            module = state.module,
            entryPoint = "vs_main",
        },
        fragment = &{
            module = state.module,
            entryPoint = "fs_main",
            targetCount = 1,
            targets = &wgpu.ColorTargetState {
                format = .BGRA8Unorm,
                writeMask = wgpu.ColorWriteMaskFlags_All
            }
        },
        primitive = {
            topology = .TriangleList
        },
        multisample = {
            count = 1,
            mask = 0xFFFFFFFF
        }
    }
    state.pipeline = wgpu.DeviceCreateRenderPipeline(device, &render_pipeline_desc)
}

on_device_lost :: proc "c" (
    device: ^wgpu.Device,
    reason: wgpu.DeviceLostReason,
    message: string,
    user_data1: rawptr,
    user_data2: rawptr
) {
    context = state.ctx

    fmt.panicf("wgpu device lost:\n   Reason: %s\n    Message:\n    %s", reason, message)
}

