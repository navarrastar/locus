package renderer

import "vendor:wgpu"

import m "pkg:core/math"



create_bind_group_0 :: proc() {
    buffer_desc := wgpu.BufferDescriptor {
        size = size_of(m.Mat4),
        usage = {.Uniform, .CopyDst},
    }
    state.model_buffer = wgpu.DeviceCreateBuffer(state.device, &buffer_desc)
    
    entries := [?]wgpu.BindGroupEntry {
        { 
            binding = 0, 
            buffer = state.model_buffer,
            size = size_of(m.Mat4),
        },
    }

    bind_group_desc := wgpu.BindGroupDescriptor {
        layout = shaders["default"].bind_group_layouts[0], // Hardcoded
        entryCount = len(entries),
        entries = &entries[0]
    }

    state.bind_group_0 = wgpu.DeviceCreateBindGroup(state.device, &bind_group_desc)
}

update_bind_group_0 :: proc(mvp: ^m.Mat4) {
    wgpu.QueueWriteBuffer(state.queue, state.model_buffer, 0, mvp, size_of(m.Mat4))
}